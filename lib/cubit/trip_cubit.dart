import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/models/trip_model.dart';
import '../core/repositories/trip_repository.dart';

/// Cubit for managing trip-related state
/// This cubit handles all trip operations including creation, retrieval, and management
class TripCubit extends Cubit<TripState> {
  final TripRepository _tripRepository;

  TripCubit({required TripRepository tripRepository})
    : _tripRepository = tripRepository,
      super(TripInitial());

  /// Create a new trip
  Future<void> createTrip(TripModel trip) async {
    emit(TripLoading());
    try {
      await _tripRepository.createTrip(trip);
      emit(TripCreated());
      // Refresh the trips list
      await getUserTrips();
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Get all trips for the current user
  Future<void> getUserTrips() async {
    emit(TripLoading());
    try {
      final trips = await _tripRepository.getUserTrips();
      emit(TripLoaded(trips));
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Get all trips (for admin)
  Future<void> getAllTrips() async {
    emit(TripLoading());
    try {
      final trips = await _tripRepository.getAllTrips();
      emit(TripLoaded(trips));
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Get a specific trip by ID
  Future<void> getTripById(String tripId) async {
    emit(TripLoading());
    try {
      final trip = await _tripRepository.getTripById(tripId);
      if (trip != null) {
        emit(TripDetailLoaded(trip));
      } else {
        emit(TripError('Trip not found'));
      }
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Update an existing trip
  Future<void> updateTrip(String tripId, TripModel trip) async {
    emit(TripLoading());
    try {
      await _tripRepository.updateTrip(tripId, trip);
      emit(TripUpdated());
      // Refresh the trips list
      await getUserTrips();
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    emit(TripLoading());
    try {
      await _tripRepository.deleteTrip(tripId);
      emit(TripDeleted());
      // Refresh the trips list
      await getUserTrips();
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Get trips by date range
  Future<void> getTripsByDateRange(DateTime startDate, DateTime endDate) async {
    emit(TripLoading());
    try {
      final trips = await _tripRepository.getTripsByDateRange(
        startDate,
        endDate,
      );
      emit(TripLoaded(trips));
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Get trips by mode of transport
  Future<void> getTripsByMode(String mode) async {
    emit(TripLoading());
    try {
      final trips = await _tripRepository.getTripsByMode(mode);
      emit(TripLoaded(trips));
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Get trip statistics
  Future<void> getTripStatistics() async {
    emit(TripLoading());
    try {
      final statistics = await _tripRepository.getTripStatistics();
      emit(TripStatisticsLoaded(statistics));
    } catch (e) {
      emit(TripError(e.toString()));
    }
  }

  /// Clear error state
  void clearError() {
    if (state is TripError) {
      emit(TripInitial());
    }
  }

  /// Reset to initial state
  void reset() {
    emit(TripInitial());
  }
}

/// Abstract base class for trip states
abstract class TripState {}

/// Initial state when the cubit is first created
class TripInitial extends TripState {}

/// Loading state when an operation is in progress
class TripLoading extends TripState {}

/// State when trips are successfully loaded
class TripLoaded extends TripState {
  final List<TripModel> trips;
  TripLoaded(this.trips);
}

/// State when a single trip detail is loaded
class TripDetailLoaded extends TripState {
  final TripModel trip;
  TripDetailLoaded(this.trip);
}

/// State when trip statistics are loaded
class TripStatisticsLoaded extends TripState {
  final Map<String, dynamic> statistics;
  TripStatisticsLoaded(this.statistics);
}

/// State when a trip is successfully created
class TripCreated extends TripState {}

/// State when a trip is successfully updated
class TripUpdated extends TripState {}

/// State when a trip is successfully deleted
class TripDeleted extends TripState {}

/// Error state when an operation fails
class TripError extends TripState {
  final String message;
  TripError(this.message);
}




