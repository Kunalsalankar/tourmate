import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:geolocator/geolocator.dart';

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

  NotificationState({
    this.message,
    List<Checkpoint>? checkpoints,
    this.isLoading = false,
    this.error,
  }) : checkpoints = checkpoints ?? [];

  NotificationState copyWith({
    String? message,
    List<Checkpoint>? checkpoints,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      message: message ?? this.message,
      checkpoints: checkpoints ?? this.checkpoints,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationState &&
        other.message == message &&
        const ListEquality().equals(other.checkpoints, checkpoints) &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(message, checkpoints, isLoading, error);
}

class NotificationCubit extends Cubit<NotificationState> {
  Timer? _checkpointTimer;
  int _checkpointCounter = 0;
  StreamSubscription<Position>? _positionStream;
  Position? _lastKnownPosition;

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

  void _startCheckpointTimer() {
    // Cancel any existing timer
    _checkpointTimer?.cancel();

    // Create a new timer that fires every 10 seconds
    _checkpointTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _addCheckpoint();
    });
  }

  Future<void> _addCheckpoint() async {
    try {
      _checkpointCounter++;
      
      // Get current position or use last known position
      Position? position = _lastKnownPosition;
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _lastKnownPosition = position;
      }

      final newCheckpoint = Checkpoint(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Checkpoint #$_checkpointCounter',
        timestamp: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final updatedCheckpoints = List<Checkpoint>.from(state.checkpoints)
        ..insert(0, newCheckpoint);

      emit(state.copyWith(checkpoints: updatedCheckpoints));
    } catch (e) {
      // If we can't get the current position, create a checkpoint without location
      final newCheckpoint = Checkpoint(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Checkpoint #$_checkpointCounter',
        timestamp: DateTime.now(),
      );

      final updatedCheckpoints = List<Checkpoint>.from(state.checkpoints)
        ..insert(0, newCheckpoint);

      emit(state.copyWith(
        checkpoints: updatedCheckpoints,
        error: 'Could not get location: $e',
      ));
    }
  }
}
