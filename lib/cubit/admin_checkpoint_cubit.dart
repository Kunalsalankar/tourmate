import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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
  final String? filterQuery;

  const AdminCheckpointState({
    this.checkpoints = const [],
    List<CheckpointModel>? filteredCheckpoints,
    this.error,
    this.isLoading = false,
    this.filterQuery,
  }) : filteredCheckpoints = filteredCheckpoints ?? checkpoints;

  @override
  List<Object?> get props => [checkpoints, filteredCheckpoints, error, isLoading, filterQuery];

  AdminCheckpointState copyWith({
    List<CheckpointModel>? checkpoints,
    List<CheckpointModel>? filteredCheckpoints,
    String? error,
    bool? isLoading,
    String? filterQuery,
  }) {
    return AdminCheckpointState(
      checkpoints: checkpoints ?? this.checkpoints,
      filteredCheckpoints: filteredCheckpoints ?? this.filteredCheckpoints,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      filterQuery: filterQuery ?? this.filterQuery,
    );
  }
}

// Cubit
class AdminCheckpointCubit extends Cubit<AdminCheckpointState> {
  final CheckpointRepository _checkpointRepository;
  StreamSubscription? _checkpointSubscription;

  AdminCheckpointCubit({required CheckpointRepository checkpointRepository})
      : _checkpointRepository = checkpointRepository,
        super(const AdminCheckpointState());

  @override
  Future<void> close() {
    _checkpointSubscription?.cancel();
    return super.close();
  }

  // Load checkpoints from Firestore
  void loadCheckpoints() {
    emit(state.copyWith(isLoading: true));
    
    _checkpointSubscription?.cancel();
    _checkpointSubscription = _checkpointRepository
        .getAllCheckpoints()
        .listen(
          (checkpoints) => _onCheckpointsUpdated(checkpoints),
          onError: (error) => _onError(error.toString()),
        );
  }

  // Handle updated checkpoints from Firestore
  void _onCheckpointsUpdated(List<CheckpointModel> checkpoints) {
    emit(state.copyWith(
      checkpoints: checkpoints,
      filteredCheckpoints: _applyFilter(checkpoints, state.filterQuery),
      isLoading: false,
      error: null,
    ));
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
}
