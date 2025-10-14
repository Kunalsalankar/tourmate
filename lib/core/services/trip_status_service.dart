import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_model.dart';

/// Service for automatically updating trip statuses based on time
/// This service monitors active trips and updates their status when they should end
class TripStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _collectionName = 'trips';
  Timer? _statusCheckTimer;
  StreamSubscription? _tripSubscription;

  /// Start monitoring trip statuses
  /// Checks every minute for trips that need status updates
  void startMonitoring() {
    // Check immediately on start
    _checkAndUpdateTripStatuses();
    
    // Then check every minute
    _statusCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkAndUpdateTripStatuses(),
    );
  }

  /// Stop monitoring trip statuses
  void stopMonitoring() {
    _statusCheckTimer?.cancel();
    _tripSubscription?.cancel();
  }

  /// Check and update trip statuses based on current time
  Future<void> _checkAndUpdateTripStatuses() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final now = DateTime.now();
      
      // Get all active trips for the current user
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('tripType', isEqualTo: 'active')
          .get();

      for (final doc in querySnapshot.docs) {
        final trip = TripModel.fromMap(doc.data(), doc.id);
        
        // Check if trip should be marked as past
        if (_shouldMarkAsPast(trip, now)) {
          await _updateTripStatus(doc.id, trip, now);
        }
      }
      
      // Also check future trips that should become active
      await _checkFutureTrips(userId, now);
    } catch (e) {
      print('Error checking trip statuses: $e');
    }
  }

  /// Check if a trip should be marked as past
  bool _shouldMarkAsPast(TripModel trip, DateTime now) {
    // If trip has an end time and it's passed
    if (trip.endTime != null && trip.endTime!.isBefore(now)) {
      return true;
    }
    
    // If trip is active and started more than 24 hours ago (default duration)
    // and no end time is set
    if (trip.endTime == null && trip.time.isBefore(now.subtract(const Duration(hours: 24)))) {
      return true;
    }
    
    return false;
  }

  /// Update trip status from active to past
  Future<void> _updateTripStatus(String tripId, TripModel trip, DateTime now) async {
    try {
      // Set end time to now if not already set
      final endTime = trip.endTime ?? now;
      
      await _firestore.collection(_collectionName).doc(tripId).update({
        'tripType': 'past',
        'endTime': Timestamp.fromDate(endTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Updated trip ${trip.tripNumber} status to past');
    } catch (e) {
      print('Error updating trip status: $e');
    }
  }

  /// Check future trips that should become active
  Future<void> _checkFutureTrips(String userId, DateTime now) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('tripType', isEqualTo: 'future')
          .get();

      for (final doc in querySnapshot.docs) {
        final trip = TripModel.fromMap(doc.data(), doc.id);
        
        // If trip time has arrived or passed, make it active
        if (trip.time.isBefore(now) || trip.time.isAtSameMomentAs(now)) {
          await _firestore.collection(_collectionName).doc(doc.id).update({
            'tripType': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          print('Updated trip ${trip.tripNumber} status to active');
        }
      }
    } catch (e) {
      print('Error checking future trips: $e');
    }
  }

  /// Manually end a trip (user-initiated)
  Future<void> endTrip(String tripId) async {
    try {
      final now = DateTime.now();
      
      await _firestore.collection(_collectionName).doc(tripId).update({
        'tripType': 'past',
        'endTime': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to end trip: $e');
    }
  }

  /// Check status for a specific trip
  Future<void> checkTripStatus(String tripId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(tripId).get();
      
      if (!doc.exists) return;
      
      final trip = TripModel.fromMap(doc.data()!, doc.id);
      final now = DateTime.now();
      
      if (trip.tripType == TripType.active && _shouldMarkAsPast(trip, now)) {
        await _updateTripStatus(tripId, trip, now);
      }
    } catch (e) {
      print('Error checking trip status: $e');
    }
  }
}
