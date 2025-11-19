// ignore_for_file: unnecessary_cast

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_model.dart';
import '../../services/analytics_service.dart';

/// Repository class for handling Trip-related Firestore operations
/// This class provides methods to interact with the Firestore database
/// for trip creation, retrieval, updating, and deletion
/// 
/// all the backened of the analytic is done here
class TripRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AnalyticsService _analytics;

  static const String _collectionName = 'trips';

  TripRepository({AnalyticsService? analyticsService})
      : _analytics = analyticsService ?? AnalyticsService();

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Create a new trip in Firestore
  Future<String> createTrip(TripModel trip) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Always set ownership and timestamps on the server side
      final Map<String, dynamic> data = {
        ...trip.toMap(),
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection(_collectionName).add(data);
      await _analytics.writeUserTrip(userId, docRef.id, data);
      await _analytics.logTripEvent(
        userId: userId,
        tripId: docRef.id,
        type: 'start',
        time: trip.time,
        extra: {
          'mode': trip.mode,
          'origin': trip.origin,
          'destination': trip.destination,
        },
      );
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create trip: $e');
    }
  }

  /// Get all trips for the current user
  Future<List<TripModel>> getUserTrips() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => TripModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user trips: $e');
    }
  }

  /// Get all trips (for admin view)
  Future<List<TripModel>> getAllTrips() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => TripModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all trips: $e');
    }
  }

  /// Get trips by type (active, past, future)
  Future<List<TripModel>> getTripsByType(String type) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      Query query = _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId);

      // Filter by stored tripType to ensure correct classification
      switch (type) {
        case 'active':
          query = query.where('tripType', isEqualTo: 'active');
          break;
        case 'past':
          query = query.where('tripType', isEqualTo: 'past');
          break;
        case 'future':
          query = query.where('tripType', isEqualTo: 'future');
          break;
        default:
          break;
      }

      // Consistent ordering with user trips
      query = query.orderBy('createdAt', descending: true);
      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => TripModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } on FirebaseException catch (e) {
      // Graceful fallback when a composite index is required but missing
      final needsIndex = e.code == 'failed-precondition' &&
          (e.message?.toLowerCase().contains('requires an index') ?? false);

      if (needsIndex) {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('User not authenticated');
        }
        // Fallback: fetch by userId and order, filter by tripType client-side
        final qs = await _firestore
            .collection(_collectionName)
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();
        final all = qs.docs
            .map((doc) => TripModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList();
        if (type == 'active' || type == 'past' || type == 'future') {
          return all
              .where((t) => t.tripType.toString().split('.').last == type)
              .toList();
        }
        return all;
      }
      throw Exception('Failed to get $type trips: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Failed to get $type trips: $e');
    }
  }

  /// Get a specific trip by ID
  Future<TripModel?> getTripById(String tripId) async {
    try {
      final doc = await _firestore
          .collection(_collectionName)
          .doc(tripId)
          .get();
      if (doc.exists) {
        return TripModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get trip: $e');
    }
  }

  /// Update an existing trip
  Future<void> updateTrip(String tripId, TripModel trip) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Prevent changing owner; always refresh updatedAt on the server
      final Map<String, dynamic> data = {
        ...trip.toMap(),
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_collectionName).doc(tripId).update(data);
      await _analytics.writeUserTrip(userId, tripId, data);
      if (trip.tripType == TripType.past) {
        await _analytics.logTripEvent(
          userId: userId,
          tripId: tripId,
          type: 'end',
          time: trip.endTime ?? DateTime.now(),
          extra: {
            'mode': trip.mode,
            'origin': trip.origin,
            'destination': trip.destination,
          },
        );
        await _analytics.logOdDaily(trip: trip, userId: userId, tripId: tripId);
      }
    } catch (e) {
      throw Exception('Failed to update trip: $e');
    }
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    try {
      await _firestore.collection(_collectionName).doc(tripId).delete();
    } catch (e) {
      throw Exception('Failed to delete trip: $e');
    }
  }

  /// Get trips by date range
  Future<List<TripModel>> getTripsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('time', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('time', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => TripModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get trips by date range: $e');
    }
  }

  /// Get trips by mode of transport
  Future<List<TripModel>> getTripsByMode(String mode) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('mode', isEqualTo: mode)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => TripModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get trips by mode: $e');
    }
  }

  /// Get trips statistics for the current user
  Future<Map<String, dynamic>> getTripStatistics() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .get();

      final trips = querySnapshot.docs
          .map((doc) => TripModel.fromMap(doc.data(), doc.id))
          .toList();

      // Calculate statistics
      final totalTrips = trips.length;
      final modes = trips.map((trip) => trip.mode).toSet();
      final modeCounts = <String, int>{};

      for (final mode in modes) {
        modeCounts[mode] = trips.where((trip) => trip.mode == mode).length;
      }

      final totalTravellers = trips.fold<int>(
        0,
        (total, trip) => total + trip.accompanyingTravellers.length,
      );

      return {
        'totalTrips': totalTrips,
        'totalTravellers': totalTravellers,
        'modeCounts': modeCounts,
        'uniqueDestinations': trips
            .map((trip) => trip.destination)
            .toSet()
            .length,
        'uniqueOrigins': trips.map((trip) => trip.origin).toSet().length,
      };
    } catch (e) {
      throw Exception('Failed to get trip statistics: $e');
    }
  }

  /// Stream of user trips for real-time updates
  Stream<List<TripModel>> getUserTripsStream() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.error('User not authenticated');
    }

    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TripModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList(),
        );
  }

  /// Stream of all trips for admin real-time updates
  Stream<List<TripModel>> getAllTripsStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TripModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList(),
        );
  }
}
