import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_model.dart';
import '../models/auto_trip_model.dart';

/// Service for exporting trip data for transportation planning analysis
class DataExportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Export all trips for a user to CSV format
  Future<String> exportUserTripsToCSV(String userId) async {
    final manualTrips = await _getUserManualTrips(userId);
    final autoTrips = await _getUserAutoTrips(userId);

    final csvData = StringBuffer();
    
    // CSV Header
    csvData.writeln(
      'Trip ID,Type,Date,Start Time,End Time,Duration (min),Origin,Destination,'
      'Distance (km),Mode,Detected Mode,Avg Speed (km/h),Max Speed (km/h),'
      'Purpose,Activities,Companions,Cost,Notes'
    );

    // Add manual trips
    for (var trip in manualTrips) {
      csvData.writeln(_manualTripToCSVRow(trip));
    }

    // Add auto-detected trips
    for (var trip in autoTrips) {
      csvData.writeln(_autoTripToCSVRow(trip));
    }

    return csvData.toString();
  }

  /// Export all trips (all users) for admin/planner analysis
  Future<String> exportAllTripsToCSV() async {
    final manualTrips = await _getAllManualTrips();
    final autoTrips = await _getAllAutoTrips();

    final csvData = StringBuffer();
    
    // CSV Header with User ID
    csvData.writeln(
      'Trip ID,User ID,Type,Date,Start Time,End Time,Duration (min),Origin,Destination,'
      'Distance (km),Mode,Detected Mode,Avg Speed (km/h),Max Speed (km/h),'
      'Purpose,Activities,Companions,Cost,Notes'
    );

    // Add manual trips
    for (var trip in manualTrips) {
      csvData.writeln(_manualTripToCSVRow(trip, includeUserId: true));
    }

    // Add auto-detected trips
    for (var trip in autoTrips) {
      csvData.writeln(_autoTripToCSVRow(trip, includeUserId: true));
    }

    return csvData.toString();
  }

  /// Export origin-destination matrix
  Future<String> exportODMatrix() async {
    final trips = await _getAllManualTrips();
    final autoTrips = await _getAllAutoTrips();

    // Create OD pairs map
    final Map<String, int> odPairs = {};

    // Process manual trips
    for (var trip in trips) {
      final key = '${trip.origin} -> ${trip.destination}';
      odPairs[key] = (odPairs[key] ?? 0) + 1;
    }

    // Process auto trips (using coordinates, would need geocoding for place names)
    for (var trip in autoTrips) {
      if (trip.destination != null) {
        final key = 'Auto: ${trip.origin.coordinates.latitude.toStringAsFixed(4)},${trip.origin.coordinates.longitude.toStringAsFixed(4)} -> '
                    '${trip.destination!.coordinates.latitude.toStringAsFixed(4)},${trip.destination!.coordinates.longitude.toStringAsFixed(4)}';
        odPairs[key] = (odPairs[key] ?? 0) + 1;
      }
    }

    // Generate CSV
    final csvData = StringBuffer();
    csvData.writeln('Origin,Destination,Trip Count');
    
    odPairs.forEach((key, count) {
      final parts = key.split(' -> ');
      csvData.writeln('${parts[0]},${parts[1]},$count');
    });

    return csvData.toString();
  }

  /// Export mode share analysis
  Future<String> exportModeShareAnalysis() async {
    final trips = await _getAllManualTrips();
    final autoTrips = await _getAllAutoTrips();

    final Map<String, int> modeCount = {};
    final Map<String, double> modeDistance = {};

    // Process manual trips
    for (var trip in trips) {
      modeCount[trip.mode] = (modeCount[trip.mode] ?? 0) + 1;
    }

    // Process auto trips
    for (var trip in autoTrips) {
      final mode = trip.confirmedMode ?? trip.detectedMode ?? 'Unknown';
      modeCount[mode] = (modeCount[mode] ?? 0) + 1;
      modeDistance[mode] = (modeDistance[mode] ?? 0) + trip.distanceKm;
    }

    // Calculate total
    final totalTrips = modeCount.values.fold(0, (sum, count) => sum + count);

    // Generate CSV
    final csvData = StringBuffer();
    csvData.writeln('Mode,Trip Count,Percentage,Total Distance (km),Avg Distance (km)');
    
    modeCount.forEach((mode, count) {
      final percentage = (count / totalTrips * 100).toStringAsFixed(2);
      final distance = modeDistance[mode] ?? 0;
      final avgDistance = count > 0 ? (distance / count).toStringAsFixed(2) : '0';
      csvData.writeln('$mode,$count,$percentage%,${distance.toStringAsFixed(2)},$avgDistance');
    });

    return csvData.toString();
  }

  /// Export trip purpose analysis
  Future<String> exportTripPurposeAnalysis() async {
    final autoTrips = await _getAllAutoTrips();

    final Map<String, int> purposeCount = {};
    final Map<String, double> purposeDistance = {};

    for (var trip in autoTrips) {
      final purpose = trip.purpose ?? 'Not Specified';
      purposeCount[purpose] = (purposeCount[purpose] ?? 0) + 1;
      purposeDistance[purpose] = (purposeDistance[purpose] ?? 0) + trip.distanceKm;
    }

    final totalTrips = purposeCount.values.fold(0, (sum, count) => sum + count);

    final csvData = StringBuffer();
    csvData.writeln('Purpose,Trip Count,Percentage,Total Distance (km),Avg Distance (km)');
    
    purposeCount.forEach((purpose, count) {
      final percentage = (count / totalTrips * 100).toStringAsFixed(2);
      final distance = purposeDistance[purpose] ?? 0;
      final avgDistance = count > 0 ? (distance / count).toStringAsFixed(2) : '0';
      csvData.writeln('$purpose,$count,$percentage%,${distance.toStringAsFixed(2)},$avgDistance');
    });

    return csvData.toString();
  }

  /// Export hourly trip distribution
  Future<String> exportHourlyDistribution() async {
    final trips = await _getAllManualTrips();
    final autoTrips = await _getAllAutoTrips();

    final Map<int, int> hourlyCount = {};

    // Initialize all hours
    for (int i = 0; i < 24; i++) {
      hourlyCount[i] = 0;
    }

    // Process manual trips
    for (var trip in trips) {
      final hour = trip.time.hour;
      hourlyCount[hour] = (hourlyCount[hour] ?? 0) + 1;
    }

    // Process auto trips
    for (var trip in autoTrips) {
      final hour = trip.startTime.hour;
      hourlyCount[hour] = (hourlyCount[hour] ?? 0) + 1;
    }

    final csvData = StringBuffer();
    csvData.writeln('Hour,Trip Count');
    
    for (int hour = 0; hour < 24; hour++) {
      csvData.writeln('$hour:00,${hourlyCount[hour]}');
    }

    return csvData.toString();
  }

  /// Export trip statistics summary
  Future<Map<String, dynamic>> exportTripStatistics() async {
    final manualTrips = await _getAllManualTrips();
    final autoTrips = await _getAllAutoTrips();

    final totalTrips = manualTrips.length + autoTrips.length;
    final totalAutoTrips = autoTrips.length;
    final totalManualTrips = manualTrips.length;

    // Calculate total distance from auto trips
    final totalDistance = autoTrips.fold(0.0, (sum, trip) => sum + trip.distanceKm);
    final avgDistance = totalAutoTrips > 0 ? totalDistance / totalAutoTrips : 0;

    // Calculate average duration
    final totalDuration = autoTrips.fold(0, (sum, trip) => sum + trip.durationMinutes);
    final avgDuration = totalAutoTrips > 0 ? totalDuration / totalAutoTrips : 0;

    // Get unique users
    final uniqueUsers = <String>{};
    for (var trip in manualTrips) {
      uniqueUsers.add(trip.userId);
    }
    for (var trip in autoTrips) {
      uniqueUsers.add(trip.userId);
    }

    // Mode distribution
    final modeDistribution = <String, int>{};
    for (var trip in manualTrips) {
      modeDistribution[trip.mode] = (modeDistribution[trip.mode] ?? 0) + 1;
    }
    for (var trip in autoTrips) {
      final mode = trip.confirmedMode ?? trip.detectedMode ?? 'Unknown';
      modeDistribution[mode] = (modeDistribution[mode] ?? 0) + 1;
    }

    return {
      'totalTrips': totalTrips,
      'totalAutoTrips': totalAutoTrips,
      'totalManualTrips': totalManualTrips,
      'totalUsers': uniqueUsers.length,
      'totalDistance': totalDistance,
      'avgDistance': avgDistance,
      'avgDuration': avgDuration,
      'modeDistribution': modeDistribution,
    };
  }

  // Helper methods

  String _manualTripToCSVRow(TripModel trip, {bool includeUserId = false}) {
    final duration = trip.endTime != null 
        ? trip.endTime!.difference(trip.time).inMinutes 
        : 0;
    
    final activities = trip.activities.join('; ');
    final companions = trip.accompanyingTravellers.map((t) => t.name).join('; ');
    
    final row = [
      if (includeUserId) trip.userId,
      trip.id ?? '',
      'Manual',
      _formatDate(trip.time),
      _formatTime(trip.time),
      trip.endTime != null ? _formatTime(trip.endTime!) : '',
      duration.toString(),
      _escapeCsv(trip.origin),
      _escapeCsv(trip.destination),
      '', // Distance not available for manual trips
      trip.mode,
      '', // No detected mode for manual trips
      '', // No avg speed
      '', // No max speed
      '', // No purpose field in manual trips
      _escapeCsv(activities),
      _escapeCsv(companions),
      '', // No cost field in manual trips
      '', // No notes field in manual trips
    ];
    
    return row.join(',');
  }

  String _autoTripToCSVRow(AutoTripModel trip, {bool includeUserId = false}) {
    final companions = trip.companions?.join('; ') ?? '';
    
    final row = [
      if (includeUserId) trip.userId,
      trip.id ?? '',
      'Auto',
      _formatDate(trip.startTime),
      _formatTime(trip.startTime),
      trip.endTime != null ? _formatTime(trip.endTime!) : '',
      trip.durationMinutes.toString(),
      '${trip.origin.coordinates.latitude.toStringAsFixed(6)},${trip.origin.coordinates.longitude.toStringAsFixed(6)}',
      trip.destination != null 
          ? '${trip.destination!.coordinates.latitude.toStringAsFixed(6)},${trip.destination!.coordinates.longitude.toStringAsFixed(6)}'
          : '',
      trip.distanceKm.toStringAsFixed(2),
      trip.confirmedMode ?? '',
      trip.detectedMode ?? '',
      trip.averageSpeedKmh.toStringAsFixed(2),
      trip.maxSpeedKmh.toStringAsFixed(2),
      trip.purpose ?? '',
      '', // No activities for auto trips
      _escapeCsv(companions),
      trip.cost?.toString() ?? '',
      _escapeCsv(trip.notes ?? ''),
    ];
    
    return row.join(',');
  }

  Future<List<TripModel>> _getUserManualTrips(String userId) async {
    final snapshot = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .orderBy('time', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TripModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<AutoTripModel>> _getUserAutoTrips(String userId) async {
    final snapshot = await _firestore
        .collection('auto_trips')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'confirmed')
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AutoTripModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<TripModel>> _getAllManualTrips() async {
    final snapshot = await _firestore
        .collection('trips')
        .orderBy('time', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TripModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<AutoTripModel>> _getAllAutoTrips() async {
    final snapshot = await _firestore
        .collection('auto_trips')
        .where('status', isEqualTo: 'confirmed')
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AutoTripModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
