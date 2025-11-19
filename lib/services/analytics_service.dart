import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/checkpoint_model.dart';
import '../core/models/trip_model.dart';
import '../models/trip_location.dart';

class AnalyticsService {
  final FirebaseFirestore _db;
  AnalyticsService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<void> writeUserTrip(String userId, String tripId, Map<String, dynamic> data) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('trips')
          .doc(tripId)
          .set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> logTripEvent({
    required String userId,
    required String tripId,
    required String type,
    required DateTime time,
    Map<String, dynamic>? extra,
  }) async {
    final date = _dateKey(time);
    final event = <String, dynamic>{
      'userId': userId,
      'tripId': tripId,
      'type': type,
      'time': Timestamp.fromDate(time),
      if (extra != null) ...extra,
    };
    try {
      await _db
          .collection('ts_trips')
          .doc(date)
          .collection('users')
          .doc(userId)
          .collection('events')
          .doc('${tripId}_$type')
          .set(event, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> logCheckpoint(CheckpointModel cp) async {
    final date = _dateKey(cp.timestamp);
    final base = <String, dynamic>{
      'userId': cp.userId,
      'tripId': cp.tripId,
      'lat': cp.latitude,
      'lng': cp.longitude,
      'recordedAt': Timestamp.fromDate(cp.timestamp),
      'createdAt': Timestamp.fromDate(cp.createdAt),
      'title': cp.title,
      'tripNumber': cp.tripNumber,
      'tripDestination': cp.tripDestination,
      'tripMode': cp.tripMode,
      'tripStatus': cp.tripStatus,
    };

    if (cp.tripId != null && cp.userId.isNotEmpty) {
      try {
        await _db
            .collection('users')
            .doc(cp.userId)
            .collection('trips')
            .doc(cp.tripId!)
            .collection('checkpoints')
            .doc(cp.id)
            .set(base, SetOptions(merge: true));
      } catch (_) {}
    }

    try {
      await _db
          .collection('ts_checkpoints')
          .doc(date)
          .collection('users')
          .doc(cp.userId)
          .collection('events')
          .doc(cp.id)
          .set(base, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> logOdDaily({
    required TripModel trip,
    required String userId,
    required String tripId,
  }) async {
    final end = trip.endTime ?? DateTime.now();
    final date = _dateKey(end);
    final doc = <String, dynamic>{
      'userId': userId,
      'tripId': tripId,
      'origin': trip.origin,
      'destination': trip.destination,
      'mode': trip.mode,
      'startTime': Timestamp.fromDate(trip.time),
      'endTime': Timestamp.fromDate(end),
    };
    try {
      await _db
          .collection('od_daily')
          .doc(date)
          .collection('users')
          .doc(userId)
          .collection('trips')
          .doc(tripId)
          .set(doc, SetOptions(merge: true));
      // Flattened doc for efficient range queries in research dashboards
      await _db
          .collection('od_flat')
          .doc('${date}_${userId}_${tripId}')
          .set({
        'dateKey': date,
        'userId': userId,
        'tripId': tripId,
        'origin': trip.origin,
        'destination': trip.destination,
        'mode': trip.mode,
        'startTime': Timestamp.fromDate(trip.time),
        'endTime': Timestamp.fromDate(end),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> logLocation(TripLocation loc) async {
    final date = _dateKey(loc.recordedAt);
    final base = <String, dynamic>{
      'tripId': loc.tripId,
      'userId': loc.driverId,
      'lat': loc.latitude,
      'lng': loc.longitude,
      'recordedAt': Timestamp.fromDate(loc.recordedAt),
    };
    try {
      await _db
          .collection('ts_locations')
          .doc(date)
          .collection('users')
          .doc(loc.driverId)
          .collection('trips')
          .doc(loc.tripId)
          .collection('positions')
          .add(base);
    } catch (_) {}
  }

  Future<void> writeLatestUserLocation({
    required String userId,
    required TripLocation loc,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('latest_location')
          .doc(loc.tripId)
          .set({
        'lat': loc.latitude,
        'lng': loc.longitude,
        'recordedAt': Timestamp.fromDate(loc.recordedAt),
        'tripId': loc.tripId,
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
