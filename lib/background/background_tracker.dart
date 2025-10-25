import 'dart:async';
import 'package:background_fetch/background_fetch.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/trip_service.dart';
import '../services/device_location_service.dart';
import '../services/trip_location_service.dart';
import '../models/trip_location.dart';

@pragma('vm:entry-point')
Future<void> backgroundTripLocationTask(String taskId) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final db = FirebaseFirestore.instance;
    final tripService = TripService(db);
    final deviceLocation = DeviceLocationService();
    final locationService = TripLocationService(db);

    // Try to resolve driverId from auth; fallback to runtime/device doc
    String driverId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_driver';
    if (driverId == 'unknown_driver') {
      try {
        final d = await db.collection('runtime').doc('device').get();
        driverId = (d.data() ?? const {})['driverId'] as String? ?? driverId;
      } catch (_) {}
    }

    final hasPerm = await deviceLocation.ensurePermissions();
    if (!hasPerm) {
      BackgroundFetch.finish(taskId);
      return;
    }

    final trips = await tripService.fetchActiveTripsForDriver(driverId);
    if (trips.isEmpty) {
      BackgroundFetch.finish(taskId);
      return;
    }

    final pos = await deviceLocation.getCurrentPosition();
    if (pos == null) {
      BackgroundFetch.finish(taskId);
      return;
    }

    final now = DateTime.now();
    for (final t in trips.where((t) => t.isActive)) {
      final loc = TripLocation(
        tripId: t.id,
        latitude: pos.latitude,
        longitude: pos.longitude,
        recordedAt: now,
        driverId: driverId,
      );
      await locationService.upsertLatestTripLocation(loc);
      await locationService.addTripLocationHistory(loc);
    }
  } catch (e) {
    try {
      await FirebaseFirestore.instance.collection('logs').add({
        'source': 'backgroundTripLocationTask',
        'error': e.toString(),
        'ts': DateTime.now(),
      });
    } catch (_) {}
  } finally {
    BackgroundFetch.finish(taskId);
  }
}

class BackgroundTracker {
  static Future<void> init() async {
    // Only initialize on Android/iOS. Avoid dart:io by using defaultTargetPlatform.
    if (kIsWeb) return;
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) return;
    try {
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          stopOnTerminate: false,
          enableHeadless: true,
          startOnBoot: true,
          requiredNetworkType: NetworkType.ANY,
        ),
        backgroundTripLocationTask,
        (String taskId) async {
          BackgroundFetch.finish(taskId);
        },
      );

      BackgroundFetch.registerHeadlessTask(backgroundTripLocationTask);
    } catch (_) {
      // MissingPluginException or platform not supported: ignore gracefully
    }
  }
}
