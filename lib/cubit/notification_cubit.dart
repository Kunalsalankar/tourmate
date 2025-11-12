import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/models/checkpoint_model.dart';

abstract class CheckpointEvent {
  const CheckpointEvent();
}

class AddCheckpointEvent extends CheckpointEvent {
  const AddCheckpointEvent() : super();
}

class Checkpoint {
  final String id;
  final String title;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;

  Checkpoint({
    required this.id,
    required this.title,
    required this.timestamp,
    this.latitude,
    this.longitude,
  });

  String get coordinatesText {
    if (latitude == null || longitude == null) return 'Location unavailable';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Checkpoint &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class NotificationState {
  final String? message;
  final List<Checkpoint> checkpoints;
  final bool isLoading;
  final String? error;
  final String? activeTripId;
  final String? activeTripTitle;
  final String? activeTripDestination;
  final String? activeTripMode;

  NotificationState({
    this.message,
    List<Checkpoint>? checkpoints,
    this.isLoading = false,
    this.error,
    this.activeTripId,
    this.activeTripTitle,
    this.activeTripDestination,
    this.activeTripMode,
  }) : checkpoints = checkpoints ?? [];

  NotificationState copyWith({
    String? message,
    List<Checkpoint>? checkpoints,
    bool? isLoading,
    String? error,
    String? activeTripId,
    String? activeTripTitle,
    String? activeTripDestination,
    String? activeTripMode,
  }) {
    return NotificationState(
      message: message ?? this.message,
      checkpoints: checkpoints ?? this.checkpoints,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeTripId: activeTripId ?? this.activeTripId,
      activeTripTitle: activeTripTitle ?? this.activeTripTitle,
      activeTripDestination:
          activeTripDestination ?? this.activeTripDestination,
      activeTripMode: activeTripMode ?? this.activeTripMode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationState &&
        other.message == message &&
        const ListEquality().equals(other.checkpoints, checkpoints) &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.activeTripId == activeTripId &&
        other.activeTripTitle == activeTripTitle &&
        other.activeTripDestination == activeTripDestination &&
        other.activeTripMode == activeTripMode;
  }

  @override
  int get hashCode => Object.hash(
        message,
        checkpoints,
        isLoading,
        error,
        activeTripId,
        activeTripTitle,
        activeTripDestination,
        activeTripMode,
      );
}

class NotificationCubit extends Cubit<NotificationState> {
  Timer? _checkpointTimer;
  int _checkpointCounter = 0;
  StreamSubscription<Position>? _positionStream;
  Position? _lastKnownPosition;
  Map<String, dynamic>? _activeTripData;
  bool _activeTripMissingNotified = false;

  NotificationCubit() : super(NotificationState()) {
    _initializeLocationService();
  }

  Future<void> _initializeLocationService() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        emit(state.copyWith(
          error: 'Location services are disabled. Please enable the services',
        ));
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          emit(state.copyWith(
            error: 'Location permissions are denied',
          ));
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        emit(state.copyWith(
          error: 'Location permissions are permanently denied, we cannot request permissions.',
        ));
        return;
      }

      // Get the current position
      _lastKnownPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Start listening to location updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update only if the device moves 10 meters
        ),
      ).listen((Position position) {
        _lastKnownPosition = position;
      });

      await _loadActiveTrip();

      // Start the checkpoint timer
      _startCheckpointTimer();
    } catch (e) {
      emit(state.copyWith(
        error: 'Error initializing location service: $e',
      ));
    }
  }

  @override
  Future<void> close() {
    _checkpointTimer?.cancel();
    _positionStream?.cancel();
    return super.close();
  }

  void showNotification(String message) {
    emit(state.copyWith(message: message));
    // Reset after showing so it doesn't repeat
    emit(state.copyWith(message: null));
  }

  void clearError() {
    if (state.error != null) {
      emit(state.copyWith(error: null));
    }
  }

  void add(CheckpointEvent event) {
    if (event is AddCheckpointEvent) {
      _addCheckpoint();
    }
  }

  Future<void> refreshActiveTrip() async {
    await _loadActiveTrip();
  }

  void _startCheckpointTimer() {
    // Cancel any existing timer
    _checkpointTimer?.cancel();

    // Create a new timer that fires every 10 seconds
    _checkpointTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      _addCheckpoint();
    });
  }

  Future<void> _addCheckpoint() async {
    if (isClosed) return;
    try {
      if (_activeTripData == null) {
        await _loadActiveTrip();
      }

      if (_activeTripData == null) {
        if (!_activeTripMissingNotified) {
          _activeTripMissingNotified = true;
          emit(state.copyWith(
            error: 'No active trip found. Start or resume a trip to record checkpoints.',
          ));
        }
        return;
      }
      _activeTripMissingNotified = false;

      _checkpointCounter++;
      
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown User';
      final checkpointId = const Uuid().v4();
      final now = DateTime.now();
      
      // Create a new checkpoint model
      final newCheckpoint = CheckpointModel(
        id: checkpointId,
        userId: userId,
        userName: userName,
        title: 'Checkpoint #$_checkpointCounter',
        timestamp: now,
        latitude: _lastKnownPosition?.latitude ?? 0.0,
        longitude: _lastKnownPosition?.longitude ?? 0.0,
        tripId: _activeTripData?['id'] as String?,
        tripNumber: _activeTripData?['number'] as String?,
        tripDestination: _activeTripData?['destination'] as String?,
        tripMode: _activeTripData?['mode'] as String?,
        tripStatus: _activeTripData?['status'] as String?,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('checkpoints')
          .doc(checkpointId)
          .set(newCheckpoint.toMap());
          
      // Update local state with a simplified checkpoint
      final updatedCheckpoints = List<Checkpoint>.from(state.checkpoints)
        ..insert(0, Checkpoint(
          id: checkpointId,
          title: 'Checkpoint #$_checkpointCounter',
          timestamp: now,
          latitude: _lastKnownPosition?.latitude,
          longitude: _lastKnownPosition?.longitude,
        ));

      if (!isClosed) {
        emit(state.copyWith(checkpoints: updatedCheckpoints));
      }
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: 'Failed to add checkpoint: $e'));
      // Clear the error after a short delay
      await Future.delayed(const Duration(seconds: 3));
      if (!isClosed) {
        emit(state.copyWith(error: null));
      }
    }
  }

  Future<void> _loadActiveTrip() async {
    if (isClosed) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        emit(state.copyWith(
          activeTripId: null,
          activeTripTitle: null,
          activeTripDestination: null,
          activeTripMode: null,
        ));
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: userId)
          .where('tripType', isEqualTo: 'active')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _activeTripData = null;
        emit(state.copyWith(
          activeTripId: null,
          activeTripTitle: null,
          activeTripDestination: null,
          activeTripMode: null,
        ));
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final timestamp = data['time'];
      DateTime? scheduled;
      if (timestamp is Timestamp) {
        scheduled = timestamp.toDate();
      }

      final tripTitle = (data['tripNumber'] as String?)?.isNotEmpty == true
          ? data['tripNumber'] as String
          : 'Trip ${doc.id.substring(0, 6)}';

      _activeTripData = {
        'id': doc.id,
        'number': data['tripNumber'],
        'destination': data['destination'],
        'mode': data['mode'],
        'status': data['tripType'] ?? 'active',
        'scheduledFor': scheduled,
      };

      emit(state.copyWith(
        activeTripId: doc.id,
        activeTripTitle: tripTitle,
        activeTripDestination: data['destination'] as String?,
        activeTripMode: data['mode'] as String?,
      ));
      _activeTripMissingNotified = false;
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        error: 'Unable to load active trip: $e',
      ));
    }
  }
}
