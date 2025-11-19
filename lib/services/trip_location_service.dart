import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_location.dart';
import 'analytics_service.dart';

class TripLocationService {
  TripLocationService(this._db, {AnalyticsService? analytics})
      : _analytics = analytics ?? AnalyticsService();
  final FirebaseFirestore _db;
  final AnalyticsService _analytics;

  Future<void> upsertLatestTripLocation(TripLocation loc) async {
    await _db.collection('latest_trip_locations').doc(loc.tripId).set(
      loc.toMap(),
      SetOptions(merge: true),
    );
    await _analytics.writeLatestUserLocation(userId: loc.driverId, loc: loc);
  }

  // Append to per-trip history: trip_location_history/{tripId}/positions/{autoId}
  Future<void> addTripLocationHistory(TripLocation loc) async {
    final col = _db
        .collection('trip_location_history')
        .doc(loc.tripId)
        .collection('positions');
    await col.add(loc.toMap());
    await _analytics.logLocation(loc);
  }

  // Stream history for a trip ordered by recordedAt desc
  Stream<QuerySnapshot<Map<String, dynamic>>> streamTripHistory(String tripId,
      {int? limit}) {
    var q = _db
        .collection('trip_location_history')
        .doc(tripId)
        .collection('positions')
        .orderBy('recordedAt', descending: true);
    if (limit != null) q = q.limit(limit);
    return q.snapshots();
  }
}
