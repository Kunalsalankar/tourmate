import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/auto_trip_model.dart';
import '../models/trip_model.dart';

/// Service providing aggregated analytics for the admin dashboard.
///
/// This is intentionally Firestore-based so it works both for mobile and web
/// without requiring an external backend.
class AdminAnalyticsService {
  final FirebaseFirestore _firestore;

  AdminAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Shared analytics entrypoint used by the admin dashboard filters.
  ///
  /// Parameters are plain values so they can also be encoded as JSON if you
  /// call this through a custom backend:
  /// {
  ///   "startDate": "2024-01-01T00:00:00.000Z",
  ///   "endDate": "2024-01-07T23:59:59.999Z",
  ///   "travelMode": "car | bike | bus | walk | all"
  /// }
  Future<Map<String, dynamic>> fetchAnalytics({
    required DateTime startDate,
    required DateTime endDate,
    required String travelMode,
  }) async {
    // Normalize bounds to avoid subtle off‑by‑one issues.
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    // Fetch manual trips from "trips" collection (filter by date only).
    final manualSnap = await _firestore
        .collection('trips')
        .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('time', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    var manualTrips = manualSnap.docs
        .map((d) => TripModel.fromMap(d.data(), d.id))
        .toList();

    // Fetch auto trips from "auto_trips" collection (date + status only).
    final autoSnap = await _firestore
        .collection('auto_trips')
        .where('status', isEqualTo: 'confirmed')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    var autoTrips = autoSnap.docs
        .map((d) => AutoTripModel.fromMap(d.data(), d.id))
        .toList();

    // Apply travel mode filter in memory to avoid composite index requirements.
    final modeLower = travelMode.toLowerCase();
    if (modeLower != 'all') {
      manualTrips = manualTrips
          .where((t) => t.mode.toLowerCase() == modeLower)
          .toList();
      autoTrips = autoTrips
          .where((t) =>
              (t.confirmedMode ?? t.detectedMode ?? '')
                  .toLowerCase() ==
              modeLower)
          .toList();
    }

    return _buildAggregates(
      manualTrips: manualTrips,
      autoTrips: autoTrips,
      start: start,
      end: end,
    );
  }

  Map<String, dynamic> _buildAggregates({
    required List<TripModel> manualTrips,
    required List<AutoTripModel> autoTrips,
    required DateTime start,
    required DateTime end,
  }) {
    final totalManual = manualTrips.length;
    final totalAuto = autoTrips.length;
    final totalTrips = totalManual + totalAuto;

    // Unique users.
    final userIds = <String>{};
    for (final t in manualTrips) {
      userIds.add(t.userId);
    }
    for (final t in autoTrips) {
      userIds.add(t.userId);
    }

    // Distance and duration (auto trips only – they have precise data).
    final totalDistanceKm =
        autoTrips.fold<double>(0, (sum, t) => sum + t.distanceKm);
    final totalDurationMinutes =
        autoTrips.fold<int>(0, (sum, t) => sum + t.durationMinutes);
    final avgDurationMinutes =
        totalAuto > 0 ? totalDurationMinutes / totalAuto : 0.0;

    // Trips by travel mode (manual + auto).
    final Map<String, int> tripsByMode = {};

    for (final t in manualTrips) {
      final mode = (t.mode.isEmpty ? 'unknown' : t.mode).toLowerCase();
      tripsByMode[mode] = (tripsByMode[mode] ?? 0) + 1;
    }

    for (final t in autoTrips) {
      final mode =
          (t.confirmedMode ?? t.detectedMode ?? 'unknown').toLowerCase();
      tripsByMode[mode] = (tripsByMode[mode] ?? 0) + 1;
    }

    // Build simple per‑day trend for line chart.
    final List<Map<String, dynamic>> dailyTrend = [];
    final Map<String, int> countsByDate = {};

    void addToDate(DateTime dt) {
      final key = _formatDate(dt);
      countsByDate[key] = (countsByDate[key] ?? 0) + 1;
    }

    for (final t in manualTrips) {
      addToDate(t.time);
    }
    for (final t in autoTrips) {
      addToDate(t.startTime);
    }

    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      final key = _formatDate(cursor);
      dailyTrend.add({'date': key, 'count': countsByDate[key] ?? 0});
      cursor = cursor.add(const Duration(days: 1));
    }

    // Mode comparison list for bar chart.
    final List<Map<String, dynamic>> modeComparison = tripsByMode.entries
        .map((e) => {'mode': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return {
      'totalTrips': totalTrips,
      'totalManualTrips': totalManual,
      'totalAutoTrips': totalAuto,
      'totalUsers': userIds.length,
      'totalDistanceKm': totalDistanceKm,
      'avgTripDurationMinutes': avgDurationMinutes,
      'tripsByMode': tripsByMode,
      'trend': dailyTrend,
      'modeComparison': modeComparison,
      'startDate': start.toIso8601String(),
      'endDate': end.toIso8601String(),
    };
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}

