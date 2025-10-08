import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/auto_trip_model.dart';

/// Repository for managing automatically detected trips in Firestore
class AutoTripRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'auto_trips';

  /// Save a detected trip to Firestore
  Future<String?> saveAutoTrip(AutoTripModel trip) async {
    try {
      final docRef = await _firestore.collection(_collectionName).add(trip.toMap());
      if (kDebugMode) {
        print('[AutoTripRepo] Saved trip: ${docRef.id}');
      }
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        print('[AutoTripRepo] Error saving trip: $e');
      }
      return null;
    }
  }

  /// Update an existing auto trip
  Future<bool> updateAutoTrip(String tripId, AutoTripModel trip) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(tripId)
          .update(trip.toMap());
      if (kDebugMode) {
        print('[AutoTripRepo] Updated trip: $tripId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AutoTripRepo] Error updating trip: $e');
      }
      return false;
    }
  }

  /// Confirm a detected trip with user-provided details
  Future<bool> confirmTrip({
    required String tripId,
    required String purpose,
    required String confirmedMode,
    List<String>? companions,
    double? cost,
    String? notes,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(tripId).update({
        'status': AutoTripStatus.confirmed.toString().split('.').last,
        'purpose': purpose,
        'confirmedMode': confirmedMode,
        'companions': companions,
        'cost': cost,
        'notes': notes,
        'updatedAt': Timestamp.now(),
      });
      if (kDebugMode) {
        print('[AutoTripRepo] Confirmed trip: $tripId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AutoTripRepo] Error confirming trip: $e');
      }
      return false;
    }
  }

  /// Reject a detected trip
  Future<bool> rejectTrip(String tripId) async {
    try {
      await _firestore.collection(_collectionName).doc(tripId).update({
        'status': AutoTripStatus.rejected.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      });
      if (kDebugMode) {
        print('[AutoTripRepo] Rejected trip: $tripId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AutoTripRepo] Error rejecting trip: $e');
      }
      return false;
    }
  }

  /// Delete an auto trip
  Future<bool> deleteAutoTrip(String tripId) async {
    try {
      await _firestore.collection(_collectionName).doc(tripId).delete();
      if (kDebugMode) {
        print('[AutoTripRepo] Deleted trip: $tripId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[AutoTripRepo] Error deleting trip: $e');
      }
      return false;
    }
  }

  /// Get a single auto trip by ID
  Future<AutoTripModel?> getAutoTrip(String tripId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(tripId).get();
      if (doc.exists && doc.data() != null) {
        return AutoTripModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[AutoTripRepo] Error getting trip: $e');
      }
      return null;
    }
  }

  /// Stream of auto trips for a specific user
  Stream<List<AutoTripModel>> getUserAutoTrips(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AutoTripModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get detected trips awaiting confirmation for a user
  Stream<List<AutoTripModel>> getPendingTrips(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: AutoTripStatus.detected.toString().split('.').last)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AutoTripModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get confirmed trips for a user
  Stream<List<AutoTripModel>> getConfirmedTrips(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: AutoTripStatus.confirmed.toString().split('.').last)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AutoTripModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Get trips within a date range
  Future<List<AutoTripModel>> getTripsInDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('startTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AutoTripModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('[AutoTripRepo] Error getting trips in date range: $e');
      }
      return [];
    }
  }

  /// Get trip statistics for a user
  Future<Map<String, dynamic>> getTripStatistics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: AutoTripStatus.confirmed.toString().split('.').last)
          .get();

      final trips = snapshot.docs
          .map((doc) => AutoTripModel.fromMap(doc.data(), doc.id))
          .toList();

      if (trips.isEmpty) {
        return {
          'totalTrips': 0,
          'totalDistance': 0.0,
          'totalDuration': 0,
          'averageDistance': 0.0,
          'averageDuration': 0,
          'modeDistribution': <String, int>{},
        };
      }

      final totalDistance = trips.fold<double>(
        0.0,
        (sum, trip) => sum + trip.distanceKm,
      );

      final totalDuration = trips.fold<int>(
        0,
        (sum, trip) => sum + trip.durationMinutes,
      );

      final modeDistribution = <String, int>{};
      for (final trip in trips) {
        final mode = trip.confirmedMode ?? trip.detectedMode ?? 'Unknown';
        modeDistribution[mode] = (modeDistribution[mode] ?? 0) + 1;
      }

      return {
        'totalTrips': trips.length,
        'totalDistance': totalDistance,
        'totalDuration': totalDuration,
        'averageDistance': totalDistance / trips.length,
        'averageDuration': totalDuration ~/ trips.length,
        'modeDistribution': modeDistribution,
      };
    } catch (e) {
      if (kDebugMode) {
        print('[AutoTripRepo] Error getting statistics: $e');
      }
      return {
        'totalTrips': 0,
        'totalDistance': 0.0,
        'totalDuration': 0,
        'averageDistance': 0.0,
        'averageDuration': 0,
        'modeDistribution': <String, int>{},
      };
    }
  }

  /// Get all auto trips (for admin)
  Stream<List<AutoTripModel>> getAllAutoTrips() {
    return _firestore
        .collection(_collectionName)
        .orderBy('startTime', descending: true)
        .limit(100) // Limit for performance
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AutoTripModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Convert auto trip to manual trip format (for integration with existing trip system)
  Future<Map<String, dynamic>> convertToManualTrip(AutoTripModel autoTrip) async {
    return {
      'tripNumber': 'AUTO-${autoTrip.id}',
      'origin': '${autoTrip.origin.coordinates.latitude},${autoTrip.origin.coordinates.longitude}',
      'destination': autoTrip.destination != null
          ? '${autoTrip.destination!.coordinates.latitude},${autoTrip.destination!.coordinates.longitude}'
          : 'Unknown',
      'time': Timestamp.fromDate(autoTrip.startTime),
      'endTime': autoTrip.endTime != null ? Timestamp.fromDate(autoTrip.endTime!) : null,
      'mode': autoTrip.confirmedMode ?? autoTrip.detectedMode ?? 'Unknown',
      'activities': [autoTrip.purpose ?? 'Auto-detected trip'],
      'accompanyingTravellers': (autoTrip.companions ?? [])
          .map((name) => {
                'name': name,
                'age': 0,
              })
          .toList(),
      'userId': autoTrip.userId,
      'createdAt': Timestamp.fromDate(autoTrip.createdAt),
      'updatedAt': Timestamp.fromDate(autoTrip.updatedAt),
      'tripType': 'active',
      'autoDetected': true,
      'distance': autoTrip.distanceKm,
      'duration': autoTrip.durationMinutes,
      'cost': autoTrip.cost,
      'notes': autoTrip.notes,
    };
  }
}
