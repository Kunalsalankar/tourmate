import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import '../core/models/location_comment_model.dart';
import '../core/repositories/location_comment_repository.dart';
import '../core/services/location_service.dart';
import '../core/services/location_comment_notifier_service.dart';

/// States
abstract class LocationCommentState extends Equatable {
  @override
  List<Object?> get props => [];
}

class LocationCommentInitial extends LocationCommentState {}

class LocationCommentLoading extends LocationCommentState {}

class LocationCommentLoaded extends LocationCommentState {
  final List<LocationCommentModel> nearbyComments;
  final List<LocationCommentModel> allComments;
  final Position? currentPosition;

  LocationCommentLoaded({
    required this.nearbyComments,
    required this.allComments,
    this.currentPosition,
  });

  @override
  List<Object?> get props => [nearbyComments, allComments, currentPosition];

  LocationCommentLoaded copyWith({
    List<LocationCommentModel>? nearbyComments,
    List<LocationCommentModel>? allComments,
    Position? currentPosition,
  }) {
    return LocationCommentLoaded(
      nearbyComments: nearbyComments ?? this.nearbyComments,
      allComments: allComments ?? this.allComments,
      currentPosition: currentPosition ?? this.currentPosition,
    );
  }
}

class LocationCommentError extends LocationCommentState {
  final String message;

  LocationCommentError(this.message);

  @override
  List<Object?> get props => [message];
}

class LocationCommentAdding extends LocationCommentState {}

class LocationCommentAdded extends LocationCommentState {
  final LocationCommentModel comment;

  LocationCommentAdded(this.comment);

  @override
  List<Object?> get props => [comment];
}

/// Cubit
class LocationCommentCubit extends Cubit<LocationCommentState> {
  final LocationCommentRepository _repository = LocationCommentRepository();
  final LocationService _locationService = LocationService();
  final LocationCommentNotifierService _notifierService = LocationCommentNotifierService();
  
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<List<LocationCommentModel>>? _commentsSubscription;
  List<LocationCommentModel> _allComments = [];

  LocationCommentCubit() : super(LocationCommentInitial());

  /// Initialize and start tracking
  Future<void> initialize() async {
    emit(LocationCommentLoading());
    
    try {
      // Start location tracking
      await _locationService.initialize();
      final started = await _locationService.startTracking();
      
      if (!started) {
        emit(LocationCommentError('Location permission denied'));
        return;
      }

      // Start notification service
      await _notifierService.start();
      
      // Get current position
      final position = await _locationService.getCurrentPosition();
      
      // Subscribe to all comments
      _commentsSubscription = _repository.getAllComments(limit: 500).listen(
        (comments) {
          _allComments = comments;
          _updateNearbyComments(position);
        },
      );
      
      // Subscribe to location updates
      _locationSubscription = _locationService.locationStream.listen(
        (position) {
          _updateNearbyComments(position);
        },
      );
      
      // Initial load
      _updateNearbyComments(position);
      
    } catch (e) {
      emit(LocationCommentError('Failed to initialize: $e'));
    }
  }

  /// Update nearby comments based on current position
  void _updateNearbyComments(Position? position) {
    if (position == null) {
      emit(LocationCommentLoaded(
        nearbyComments: [],
        allComments: _allComments,
        currentPosition: null,
      ));
      return;
    }

    // Filter comments within 200m
    final nearby = _allComments.where((comment) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        comment.lat,
        comment.lng,
      );
      return distance <= 200; // 200 meters
    }).toList();

    emit(LocationCommentLoaded(
      nearbyComments: nearby,
      allComments: _allComments,
      currentPosition: position,
    ));
  }

  /// Load nearby comments for a specific location
  Future<void> loadNearbyComments(double lat, double lng, {double radiusKm = 0.2}) async {
    try {
      final nearby = await _repository.getCommentsNearLocation(lat, lng, radiusKm);
      final currentState = state;
      
      if (currentState is LocationCommentLoaded) {
        emit(currentState.copyWith(nearbyComments: nearby));
      } else {
        emit(LocationCommentLoaded(
          nearbyComments: nearby,
          allComments: _allComments,
          currentPosition: _locationService.currentPosition,
        ));
      }
    } catch (e) {
      emit(LocationCommentError('Failed to load comments: $e'));
    }
  }

  /// Add a new comment at current location
  Future<void> addComment({
    required String uid,
    required String userName,
    required String comment,
    String? tripId,
    List<String>? tags,
  }) async {
    emit(LocationCommentAdding());
    
    try {
      final position = await _locationService.getCurrentPosition();
      
      if (position == null) {
        emit(LocationCommentError('Could not get current location'));
        return;
      }

      final newComment = LocationCommentModel(
        uid: uid,
        userName: userName,
        comment: comment,
        lat: position.latitude,
        lng: position.longitude,
        timestamp: DateTime.now(),
        tripId: tripId,
        tags: tags,
      );

      final commentId = await _repository.addComment(newComment);
      
      if (commentId != null) {
        emit(LocationCommentAdded(newComment.copyWith(id: commentId)));
        // Reload to show the new comment
        await loadNearbyComments(position.latitude, position.longitude);
      } else {
        emit(LocationCommentError('Failed to add comment'));
      }
    } catch (e) {
      emit(LocationCommentError('Error adding comment: $e'));
    }
  }

  /// Add a comment at a specific location
  Future<void> addCommentAtLocation({
    required String uid,
    required String userName,
    required String comment,
    required double lat,
    required double lng,
    String? tripId,
    List<String>? tags,
  }) async {
    emit(LocationCommentAdding());
    
    try {
      final newComment = LocationCommentModel(
        uid: uid,
        userName: userName,
        comment: comment,
        lat: lat,
        lng: lng,
        timestamp: DateTime.now(),
        tripId: tripId,
        tags: tags,
      );

      final commentId = await _repository.addComment(newComment);
      
      if (commentId != null) {
        emit(LocationCommentAdded(newComment.copyWith(id: commentId)));
        // Reload to show the new comment
        await loadNearbyComments(lat, lng);
      } else {
        emit(LocationCommentError('Failed to add comment'));
      }
    } catch (e) {
      emit(LocationCommentError('Error adding comment: $e'));
    }
  }

  /// Get comments for a specific trip
  Stream<List<LocationCommentModel>> getTripComments(String tripId) {
    return _repository.getTripComments(tripId);
  }

  /// Refresh comments
  Future<void> refresh() async {
    final position = _locationService.currentPosition;
    if (position != null) {
      await loadNearbyComments(position.latitude, position.longitude);
    }
  }

  /// Stop tracking and clean up
  void stopTracking() {
    _notifierService.stop();
    _locationService.stopTracking();
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _commentsSubscription?.cancel();
    _notifierService.dispose();
    return super.close();
  }
}