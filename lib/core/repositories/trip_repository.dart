import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_model.dart';

/// Repository class for handling Trip-related Firestore operations
/// This class provides methods to interact with the Firestore database
/// for trip creation, retrieval, updating, and deletion
class TripRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collectionName = 'trips';

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
          .map((doc) => TripModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all trips: $e');
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
              .map((doc) => TripModel.fromMap(doc.data(), doc.id))
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
              .map((doc) => TripModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}
