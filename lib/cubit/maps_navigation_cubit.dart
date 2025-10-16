// ignore_for_file: unused_local_variable, unused_field

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/models/place_model.dart';
import '../core/services/location_service.dart';
import '../core/services/maps_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/route_tracking_service.dart';

// Maps Navigation States
class MapsNavigationState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MapsNavigationInitial extends MapsNavigationState {}

class MapsNavigationLoading extends MapsNavigationState {}

class MapsNavigationError extends MapsNavigationState {
  final String message;

  MapsNavigationError(this.message);

  @override
  List<Object?> get props => [message];
}

class MapsNavigationReady extends MapsNavigationState {
  final Position? currentPosition;

  MapsNavigationReady({this.currentPosition});

  @override
  List<Object?> get props => [currentPosition];
}

class RouteLoaded extends MapsNavigationState {
  final LatLng origin;
  final LatLng destination;
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final List<PlaceModel> nearbyPlaces;

  RouteLoaded({
    required this.origin,
    required this.destination,
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.nearbyPlaces,
  });

  @override
  List<Object?> get props => [
        origin,
        destination,
        polylinePoints,
        distance,
        duration,
        nearbyPlaces,
      ];
}

class MapsNavigationActive extends MapsNavigationState {
  final LatLng? currentLocation;
  final PlaceModel? destination;
  final List<LatLng> polylinePoints;
  final List<PlaceModel> nearbyPlaces;
  final bool isNavigating;
  final bool isOffRoute;

  MapsNavigationActive({
    this.currentLocation,
    this.destination,
    required this.polylinePoints,
    required this.nearbyPlaces,
    this.isNavigating = false,
    this.isOffRoute = false,
  });

  @override
  List<Object?> get props => [
        currentLocation,
        destination,
        polylinePoints,
        nearbyPlaces,
        isNavigating,
        isOffRoute,
      ];
}

class MapsNavigationCubit extends Cubit<MapsNavigationState> {
  final LocationService _locationService = LocationService();
  final MapsService _mapsService = MapsService();
  final NotificationService _notificationService = NotificationService();
  final RouteTrackingService _routeTrackingService = RouteTrackingService();

  // Current route information
  List<LatLng> _routePoints = [];
  List<PlaceModel> _nearbyPlaces = [];
  Set<String> _notifiedPlaceIds = {};

  // Subscriptions
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription? _nearbyPlacesSubscription;
  StreamSubscription? _routeDeviationSubscription;

  MapsNavigationCubit() : super(MapsNavigationInitial());

  /// Initialize navigation services
  Future<void> initialize() async {
    emit(MapsNavigationLoading());

    try {
      // Initialize services
      await _locationService.initialize();
      await _mapsService.initialize();
      await _notificationService.initialize();

      // Get current position
      final position = await _locationService.getCurrentPosition();

      emit(MapsNavigationReady(currentPosition: position));
    } catch (e) {
      emit(MapsNavigationError('Failed to initialize navigation: $e'));
    }
  }

  /// Search for places using the Places API
  Future<List<PlaceModel>> searchPlaces(String query) async {
    try {
      return await _mapsService.searchPlaces(query);
    } catch (e) {
      emit(MapsNavigationError('Failed to search places: $e'));
      return [];
    }
  }

  /// Set route origin and destination
  Future<void> setRoute(LatLng origin, LatLng destination) async {
    print('[DEBUG] setRoute called: origin=$origin, destination=$destination');
    emit(MapsNavigationLoading());

    try {
      // Validate coordinates
      if (origin.latitude == 0 && origin.longitude == 0) {
        emit(MapsNavigationError('Invalid origin coordinates. Please select a valid location.'));
        return;
      }
      
      if (destination.latitude == 0 && destination.longitude == 0) {
        emit(MapsNavigationError('Invalid destination coordinates. Please select a valid location.'));
        return;
      }

      print('[DEBUG] Getting directions from Maps Service...');
      // Get route directions
      final directions = await _mapsService.getDirections(origin, destination);
      print('[DEBUG] Directions received: ${directions.keys}');

      if (directions.isEmpty) {
        emit(MapsNavigationError('Failed to get directions. Please try again.'));
        return;
      }

      _routePoints = directions['polylineCoordinates'];

      // Skip nearby places for maximum performance
      // This eliminates ZERO_RESULTS errors and speeds up route loading
      // You can re-enable this later if needed
      _nearbyPlaces = [];
      
      // OPTIONAL: Uncomment below to enable nearby places (slower)
      // try {
      //   if (_routePoints.length < 100) {
      //     _nearbyPlaces = await _mapsService.getNearbyPlaces(
      //       _routePoints,
      //       500,
      //       ['tourist_attraction'],
      //     );
      //   }
      // } catch (e) {
      //   print('Failed to get nearby places: $e');
      //   _nearbyPlaces = [];
      // }

      emit(RouteLoaded(
        origin: origin,
        destination: destination,
        polylinePoints: _routePoints,
        distance: directions['distance'],
        duration: directions['duration'],
        nearbyPlaces: _nearbyPlaces,
      ));

      // Start tracking location
      await _startLocationTracking();
    } catch (e) {
      emit(MapsNavigationError('Failed to set route: $e'));
    }
  }

  /// Start tracking user location
  Future<void> _startLocationTracking() async {
    // Cancel existing subscription
    await _locationSubscription?.cancel();
    await _nearbyPlacesSubscription?.cancel();
    await _routeDeviationSubscription?.cancel();

    // Start route tracking with the current route points
    await _routeTrackingService.initRouteTracking(_routePoints);
    
    // Listen to location updates
    _locationSubscription = _routeTrackingService.currentPositionStream.listen(
      (position) {
        // Update navigation state with new position
        if (state is MapsNavigationActive) {
          final currentState = state as MapsNavigationActive;
          emit(MapsNavigationActive(
            currentLocation: LatLng(position.latitude, position.longitude),
            destination: currentState.destination,
            polylinePoints: currentState.polylinePoints,
            nearbyPlaces: _nearbyPlaces,
            isNavigating: currentState.isNavigating,
            isOffRoute: currentState.isOffRoute,
          ));
        }
      },
      onError: (error) {
        emit(MapsNavigationError('Location tracking error: $error'));
      },
    );
    
    // Subscribe to nearby places updates
    _nearbyPlacesSubscription = _routeTrackingService.nearbyPlacesStream.listen((places) {
      // Update nearby places from the service
      _nearbyPlaces = places;
      
      // Update navigation state with new nearby places
      if (state is MapsNavigationActive) {
        final currentState = state as MapsNavigationActive;
        emit(MapsNavigationActive(
          currentLocation: currentState.currentLocation,
          destination: currentState.destination,
          polylinePoints: currentState.polylinePoints,
          nearbyPlaces: places,
          isNavigating: currentState.isNavigating,
          isOffRoute: currentState.isOffRoute,
        ));
      }
    });
    
    // Subscribe to route deviation updates
    _routeDeviationSubscription = _routeTrackingService.routeDeviationStream.listen((isDeviated) {
      if (isDeviated) {
        // Handle route deviation
        _notificationService.showRouteDeviationNotification();
        
        // Update navigation state with route deviation
        if (state is MapsNavigationActive) {
          final currentState = state as MapsNavigationActive;
          emit(MapsNavigationActive(
            currentLocation: currentState.currentLocation,
            destination: currentState.destination,
            polylinePoints: currentState.polylinePoints,
            nearbyPlaces: currentState.nearbyPlaces,
            isNavigating: currentState.isNavigating,
            isOffRoute: true,
          ));
        }
      }
    });
  }


  /// Start navigation
  void startNavigation() {
    if (state is RouteLoaded) {
      final routeState = state as RouteLoaded;
      
      emit(MapsNavigationActive(
        currentLocation: _locationService.currentPosition != null
            ? LatLng(_locationService.currentPosition!.latitude, _locationService.currentPosition!.longitude)
            : null,
        destination: _nearbyPlaces.isNotEmpty
            ? PlaceModel(
                placeId: 'destination',
                name: 'Destination',
                address: '',
                location: routeState.destination,
              )
            : null,
        polylinePoints: routeState.polylinePoints,
        nearbyPlaces: _nearbyPlaces,
        isNavigating: true,
        isOffRoute: false,
      ));
    }
  }

  /// Stop navigation
  void stopNavigation() {
    _locationSubscription?.cancel();
    _nearbyPlacesSubscription?.cancel();
    _routeDeviationSubscription?.cancel();
    _locationSubscription = null;
    _nearbyPlacesSubscription = null;
    _routeDeviationSubscription = null;
    _routeTrackingService.stopRouteTracking();
    _routePoints = [];
    _nearbyPlaces = [];
    _notifiedPlaceIds = {};

    emit(MapsNavigationReady(currentPosition: _locationService.currentPosition));
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _nearbyPlacesSubscription?.cancel();
    _routeDeviationSubscription?.cancel();
    _locationService.dispose();
    _routeTrackingService.dispose();
    return super.close();
  }
}