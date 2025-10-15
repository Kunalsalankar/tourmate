import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import '../core/models/auto_trip_model.dart';
import '../core/services/trip_detection_service.dart';
import '../core/repositories/auto_trip_repository.dart';
import '../core/services/notification_service.dart';

// States
abstract class TripDetectionState extends Equatable {
  const TripDetectionState();

  @override
  List<Object?> get props => [];
}

class TripDetectionInitial extends TripDetectionState {}

class TripDetectionIdle extends TripDetectionState {}

class TripDetectionActive extends TripDetectionState {
  final AutoTripModel? currentTrip;

  const TripDetectionActive({this.currentTrip});

  @override
  List<Object?> get props => [currentTrip];
}

class TripDetected extends TripDetectionState {
  final AutoTripModel trip;

  const TripDetected(this.trip);

  @override
  List<Object?> get props => [trip];
}

class TripConfirmed extends TripDetectionState {
  final String tripId;

  const TripConfirmed(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class TripDetectionError extends TripDetectionState {
  final String message;

  const TripDetectionError(this.message);

  @override
  List<Object?> get props => [message];
}

class TripDetectionLoading extends TripDetectionState {}

// Cubit
class TripDetectionCubit extends Cubit<TripDetectionState> {
  final TripDetectionService _detectionService;
  final AutoTripRepository _repository;
  final NotificationService _notificationService;

  StreamSubscription<AutoTripModel>? _tripStartSubscription;
  StreamSubscription<AutoTripModel>? _tripEndSubscription;
  StreamSubscription<AutoTripModel>? _tripUpdateSubscription;
  StreamSubscription<List<AutoTripModel>>? _pendingTripsSubscription;

  List<AutoTripModel> _pendingTrips = [];
  List<AutoTripModel> get pendingTrips => _pendingTrips;

  TripDetectionCubit({
    TripDetectionService? detectionService,
    AutoTripRepository? repository,
    NotificationService? notificationService,
  })  : _detectionService = detectionService ?? TripDetectionService(),
        _repository = repository ?? AutoTripRepository(),
        _notificationService = notificationService ?? NotificationService(),
        super(TripDetectionInitial());

  /// Start automatic trip detection
  Future<void> startDetection(String userId) async {
    try {
      emit(TripDetectionLoading());

      // Start detection service
      final success = await _detectionService.startDetection(userId);

      if (!success) {
        emit(const TripDetectionError('Failed to start trip detection. Please check location permissions.'));
        return;
      }

      // Listen to trip events
      _tripStartSubscription = _detectionService.onTripStart.listen((trip) {
        _handleTripStart(trip);
      });

      _tripEndSubscription = _detectionService.onTripEnd.listen((trip) {
        _handleTripEnd(trip);
      });

      _tripUpdateSubscription = _detectionService.onTripUpdate.listen((trip) {
        _handleTripUpdate(trip);
      });

      // Listen to pending trips
      _pendingTripsSubscription = _repository.getPendingTrips(userId).listen((trips) {
        _pendingTrips = trips;
      });

      emit(TripDetectionActive(currentTrip: null));

      if (kDebugMode) {
        print('[TripDetectionCubit] Detection started for user: $userId');
      }
    } catch (e) {
      emit(TripDetectionError('Error starting detection: $e'));
      if (kDebugMode) {
        print('[TripDetectionCubit] Error: $e');
      }
    }
  }

  /// Stop automatic trip detection
  void stopDetection() {
    _detectionService.stopDetection();
    _tripStartSubscription?.cancel();
    _tripEndSubscription?.cancel();
    _tripUpdateSubscription?.cancel();
    _pendingTripsSubscription?.cancel();
    emit(TripDetectionIdle());

    if (kDebugMode) {
      print('[TripDetectionCubit] Detection stopped');
    }
  }

  /// Handle trip start event
  void _handleTripStart(AutoTripModel trip) async {
    if (kDebugMode) {
      print('[TripDetectionCubit] Trip started: ${trip.origin.coordinates}');
    }
    emit(TripDetectionActive(currentTrip: trip));
    
    // Show notification for trip start
    try {
      final locationName = await _getLocationName(
        trip.origin.coordinates.latitude,
        trip.origin.coordinates.longitude,
      );
      
      await _notificationService.showTripDetectedNotification(
        mode: trip.detectedMode ?? 'Unknown',
        origin: locationName,
      );
      
      if (kDebugMode) {
        print('[TripDetectionCubit] Trip start notification sent');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[TripDetectionCubit] Error sending trip start notification: $e');
      }
    }
  }

  /// Handle trip update event
  void _handleTripUpdate(AutoTripModel trip) {
    if (state is TripDetectionActive) {
      emit(TripDetectionActive(currentTrip: trip));
    }
  }

  /// Handle trip end event
  Future<void> _handleTripEnd(AutoTripModel trip) async {
    try {
      // Save trip to Firestore
      final tripId = await _repository.saveAutoTrip(trip);

      if (tripId != null) {
        final savedTrip = trip.copyWith(id: tripId);
        emit(TripDetected(savedTrip));

        if (kDebugMode) {
          print('[TripDetectionCubit] Trip saved: $tripId');
        }
        
        // Show notification for trip end
        try {
          final locationName = await _getLocationName(
            trip.destination?.coordinates.latitude ?? trip.origin.coordinates.latitude,
            trip.destination?.coordinates.longitude ?? trip.origin.coordinates.longitude,
          );
          
          await _notificationService.showTripEndedNotification(
            mode: trip.detectedMode ?? 'Unknown',
            destination: locationName,
            distanceKm: trip.distanceKm,
            durationMinutes: trip.durationMinutes,
          );
          
          if (kDebugMode) {
            print('[TripDetectionCubit] Trip end notification sent');
          }
        } catch (e) {
          if (kDebugMode) {
            print('[TripDetectionCubit] Error sending trip end notification: $e');
          }
        }

        // Return to active detection after a delay
        await Future.delayed(const Duration(seconds: 2));
        if (!isClosed) {
          emit(TripDetectionActive(currentTrip: null));
        }
      } else {
        emit(const TripDetectionError('Failed to save trip'));
      }
    } catch (e) {
      emit(TripDetectionError('Error saving trip: $e'));
      if (kDebugMode) {
        print('[TripDetectionCubit] Error saving trip: $e');
      }
    }
  }

  /// Confirm a detected trip with user-provided details
  Future<void> confirmTrip({
    required String tripId,
    required String purpose,
    required String confirmedMode,
    List<String>? companions,
    double? cost,
    String? notes,
  }) async {
    try {
      emit(TripDetectionLoading());

      final success = await _repository.confirmTrip(
        tripId: tripId,
        purpose: purpose,
        confirmedMode: confirmedMode,
        companions: companions,
        cost: cost,
        notes: notes,
      );

      if (success) {
        emit(TripConfirmed(tripId));

        if (kDebugMode) {
          print('[TripDetectionCubit] Trip confirmed: $tripId');
        }

        // Return to active detection
        await Future.delayed(const Duration(seconds: 1));
        if (!isClosed) {
          emit(TripDetectionActive(currentTrip: _detectionService.currentTrip));
        }
      } else {
        emit(const TripDetectionError('Failed to confirm trip'));
      }
    } catch (e) {
      emit(TripDetectionError('Error confirming trip: $e'));
      if (kDebugMode) {
        print('[TripDetectionCubit] Error confirming trip: $e');
      }
    }
  }

  /// Reject a detected trip
  Future<void> rejectTrip(String tripId) async {
    try {
      emit(TripDetectionLoading());

      final success = await _repository.rejectTrip(tripId);

      if (success) {
        if (kDebugMode) {
          print('[TripDetectionCubit] Trip rejected: $tripId');
        }

        // Return to active detection
        emit(TripDetectionActive(currentTrip: _detectionService.currentTrip));
      } else {
        emit(const TripDetectionError('Failed to reject trip'));
      }
    } catch (e) {
      emit(TripDetectionError('Error rejecting trip: $e'));
      if (kDebugMode) {
        print('[TripDetectionCubit] Error rejecting trip: $e');
      }
    }
  }

  /// Get trip statistics for the user
  Future<Map<String, dynamic>> getTripStatistics(String userId) async {
    return await _repository.getTripStatistics(userId);
  }

  /// Get current trip summary
  String getCurrentTripSummary() {
    return _detectionService.getCurrentTripSummary();
  }

  /// Check if detection is active
  bool get isDetecting => _detectionService.isDetecting;

  /// Get current trip
  AutoTripModel? get currentTrip => _detectionService.currentTrip;

  /// Get location name from coordinates using reverse geocoding
  Future<String> _getLocationName(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        
        // Build location string from available data
        final parts = <String>[];
        
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          parts.add(placemark.locality!);
        }
        if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
          parts.add(placemark.subLocality!);
        }
        if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
          parts.add(placemark.administrativeArea!);
        }
        
        if (parts.isNotEmpty) {
          return parts.take(2).join(', '); // Return first 2 parts
        }
      }
      
      // Fallback to coordinates
      return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    } catch (e) {
      if (kDebugMode) {
        print('[TripDetectionCubit] Error getting location name: $e');
      }
      return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }
  }

  @override
  Future<void> close() {
    _tripStartSubscription?.cancel();
    _tripEndSubscription?.cancel();
    _tripUpdateSubscription?.cancel();
    _pendingTripsSubscription?.cancel();
    return super.close();
  }
}
