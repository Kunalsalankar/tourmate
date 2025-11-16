import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/checkpoint_model.dart';
import '../core/repositories/checkpoint_repository.dart';

// Events
abstract class AdminCheckpointEvent extends Equatable {
  const AdminCheckpointEvent();

  @override
  List<Object> get props => [];
}

class LoadCheckpoints extends AdminCheckpointEvent {
  const LoadCheckpoints();
}

class FilterCheckpoints extends AdminCheckpointEvent {
  final String query;
  
  const FilterCheckpoints(this.query);
  
  @override
  List<Object> get props => [query];
}

class ClearFilter extends AdminCheckpointEvent {
  const ClearFilter();
}

// States
class AdminCheckpointState extends Equatable {
  final List<CheckpointModel> checkpoints;
  final List<CheckpointModel> filteredCheckpoints;
  final String? error;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? filterQuery;
  final List<TripCheckpointGroup> activeTripGroups;

  const AdminCheckpointState({
    this.checkpoints = const [],
    List<CheckpointModel>? filteredCheckpoints,
    this.error,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.filterQuery,
    this.activeTripGroups = const [],
  }) : filteredCheckpoints = filteredCheckpoints ?? checkpoints;

  @override
  List<Object?> get props =>
      [checkpoints, filteredCheckpoints, error, isLoading, isLoadingMore, hasMore, filterQuery, activeTripGroups];

  AdminCheckpointState copyWith({
    List<CheckpointModel>? checkpoints,
    List<CheckpointModel>? filteredCheckpoints,
    String? error,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? filterQuery,
    List<TripCheckpointGroup>? activeTripGroups,
  }) {
    return AdminCheckpointState(
      checkpoints: checkpoints ?? this.checkpoints,
      filteredCheckpoints: filteredCheckpoints ?? this.filteredCheckpoints,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      filterQuery: filterQuery ?? this.filterQuery,
      activeTripGroups: activeTripGroups ?? this.activeTripGroups,
    );
  }
}

class TripCheckpointGroup extends Equatable {
  final String tripId;
  final String? tripNumber;
  final String? tripDestination;
  final String? tripMode;
  final String? userName;
  final List<CheckpointModel> checkpoints;
  final DateTime? lastUpdatedAt;

  const TripCheckpointGroup({
    required this.tripId,
    required this.checkpoints,
    this.tripNumber,
    this.tripDestination,
    this.tripMode,
    this.userName,
    this.lastUpdatedAt,
  });

  @override
  List<Object?> get props =>
      [tripId, tripNumber, tripDestination, tripMode, userName, checkpoints, lastUpdatedAt];
}

// Cubit
class AdminCheckpointCubit extends Cubit<AdminCheckpointState> {
  final CheckpointRepository _checkpointRepository;
  StreamSubscription? _checkpointSubscription;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  AdminCheckpointCubit({required CheckpointRepository checkpointRepository})
      : _checkpointRepository = checkpointRepository,
        super(const AdminCheckpointState());

  @override
  Future<void> close() {
    _checkpointSubscription?.cancel();
    return super.close();
  }

  // Load initial page (paginated)
  Future<void> loadCheckpoints() async {
    emit(state.copyWith(isLoading: true, error: null));
    _checkpointSubscription?.cancel();
    _lastDoc = null;
    _hasMore = true;
    try {
      final snap = await _checkpointRepository.fetchCheckpointsPage(limit: 50);
      final items = snap.docs.map((d) => CheckpointModel.fromMap(d.data(), d.id)).toList();
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == 50;
      emit(state.copyWith(
        checkpoints: items,
        filteredCheckpoints: _applyFilter(items, state.filterQuery),
        activeTripGroups: _buildActiveTripGroups(items),
        isLoading: false,
        hasMore: _hasMore,
      ));
    } catch (e) {
      _onError(e.toString());
    }
  }

  // Load additional page
  Future<void> loadMoreCheckpoints() async {
    if (_isLoadingMore || !_hasMore || state.isLoading) return;
    _isLoadingMore = true;
    emit(state.copyWith(isLoadingMore: true));
    try {
      final snap = await _checkpointRepository.fetchCheckpointsPage(limit: 50, startAfter: _lastDoc);
      final more = snap.docs.map((d) => CheckpointModel.fromMap(d.data(), d.id)).toList();
      final combined = List<CheckpointModel>.from(state.checkpoints)..addAll(more);
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      _hasMore = snap.docs.length == 50;
      emit(state.copyWith(
        checkpoints: combined,
        filteredCheckpoints: _applyFilter(combined, state.filterQuery),
        activeTripGroups: _buildActiveTripGroups(combined),
        isLoadingMore: false,
        hasMore: _hasMore,
      ));
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false));
      _onError(e.toString());
    } finally {
      _isLoadingMore = false;
    }
  }


  // Handle errors
  void _onError(String error) {
    emit(state.copyWith(
      error: error,
      isLoading: false,
    ));
  }

  // Apply search/filter to checkpoints
  void filterCheckpoints(String query) {
    if (query.isEmpty) {
      emit(state.copyWith(
        filteredCheckpoints: state.checkpoints,
        filterQuery: null,
      ));
      return;
    }

    final filtered = _applyFilter(state.checkpoints, query);
    emit(state.copyWith(
      filteredCheckpoints: filtered,
      filterQuery: query,
    ));
  }

  // Helper method to apply filter
  List<CheckpointModel> _applyFilter(List<CheckpointModel> checkpoints, String? query) {
    if (query == null || query.isEmpty) return checkpoints;
    
    final lowerQuery = query.toLowerCase();
    return checkpoints.where((checkpoint) {
      return checkpoint.userName.toLowerCase().contains(lowerQuery) ||
          checkpoint.title.toLowerCase().contains(lowerQuery) ||
          checkpoint.userId.toLowerCase().contains(lowerQuery) ||
          (checkpoint.tripNumber?.toLowerCase().contains(lowerQuery) ?? false) ||
          (checkpoint.tripDestination?.toLowerCase().contains(lowerQuery) ?? false) ||
          (checkpoint.tripMode?.toLowerCase().contains(lowerQuery) ?? false) ||
          '${checkpoint.latitude.toStringAsFixed(4)}, ${checkpoint.longitude.toStringAsFixed(4)}'.contains(lowerQuery) ||
          checkpoint.timestamp.toString().toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Clear current filter
  void clearFilter() {
    emit(state.copyWith(
      filteredCheckpoints: state.checkpoints,
      filterQuery: null,
    ));
  }

  // Delete a checkpoint
  Future<void> deleteCheckpoint(String checkpointId) async {
    try {
      await _checkpointRepository.deleteCheckpoint(checkpointId);
      // The stream will update the state automatically
    } catch (e) {
      emit(state.copyWith(error: 'Failed to delete checkpoint: $e'));
      // Clear the error after a short delay
      await Future.delayed(const Duration(seconds: 3));
      emit(state.copyWith(error: null));
    }
  }

  List<TripCheckpointGroup> _buildActiveTripGroups(List<CheckpointModel> checkpoints) {
    final Map<String, List<CheckpointModel>> grouped = {};
    for (final checkpoint in checkpoints) {
      final tripId = checkpoint.tripId;
      final status = checkpoint.tripStatus?.toLowerCase();
      if (tripId == null) continue;
      if (status != null && status != 'active') continue;
      grouped.putIfAbsent(tripId, () => []).add(checkpoint);
    }

    final List<TripCheckpointGroup> groups = [];
    grouped.forEach((tripId, tripCheckpoints) {
      if (tripCheckpoints.isEmpty) {
        return;
      }
      final sorted = List<CheckpointModel>.from(tripCheckpoints)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final mostRecent = sorted.first;

      groups.add(TripCheckpointGroup(
        tripId: tripId,
        checkpoints: sorted,
        tripNumber: mostRecent.tripNumber,
        tripDestination: mostRecent.tripDestination,
        tripMode: mostRecent.tripMode,
        userName: mostRecent.userName,
        lastUpdatedAt: mostRecent.timestamp,
      ));
    });

    groups.sort((a, b) {
      final aTime = a.lastUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return groups;
  }
}
