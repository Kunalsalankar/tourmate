import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/trip_service.dart';
import '../services/device_location_service.dart';
import '../services/trip_location_service.dart';
import '../models/trip_location.dart';
import 'trip_location_history_screen.dart';

class AdminLocationDashboard extends StatelessWidget {
  const AdminLocationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('latest_trip_locations')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Real-time Trip Locations')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No active trip locations'));
          }
          docs.sort((a, b) {
            final at = a.data()['recordedAt'];
            final bt = b.data()['recordedAt'];
            final ad = at is Timestamp ? at.toDate() : null;
            final bd = bt is Timestamp ? bt.toDate() : null;
            return (bd ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(ad ?? DateTime.fromMillisecondsSinceEpoch(0));
          });
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final tripId = data['tripId'] ?? docs[i].id;
              final driverId = data['driverId']?.toString() ?? '';
              final lat = (data['lat'] as num?)?.toDouble();
              final lng = (data['lng'] as num?)?.toDouble();
              final ts = data['recordedAt'];
              final dt = ts is Timestamp ? ts.toDate() : null;
              final when = dt?.toLocal().toString().substring(0, 16) ?? 'N/A';
              return ListTile(
                title: Text('Trip: $tripId'),
                subtitle: Text('($lat, $lng)\nUpdated: $when'),
                isThreeLine: true,
                trailing: Text(driverId),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripLocationHistoryScreen(tripId: tripId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final db = FirebaseFirestore.instance;
          final svc = TripService(db);
          final locSvc = TripLocationService(db);
          final device = DeviceLocationService();
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Not signed in')),
            );
            return;
          }
          final ok = await device.ensurePermissions();
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission not granted')),
            );
            return;
          }
          final trips = await svc.fetchActiveTripsForDriver(uid);
          if (trips.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active trips for this driver')),
            );
            return;
          }
          final pos = await device.getCurrentPosition();
          if (pos == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not get current position')),
            );
            return;
          }
          final now = DateTime.now();
          for (final t in trips.where((t) => t.isActive)) {
            await locSvc.upsertLatestTripLocation(TripLocation(
              tripId: t.id,
              latitude: pos.latitude,
              longitude: pos.longitude,
              recordedAt: now,
              driverId: uid,
            ));
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated ${trips.length} trip(s)')),
          );
        },
        label: const Text('Update Now'),
        icon: const Icon(Icons.my_location),
      ),
    );
  }
}
