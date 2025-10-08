// Example: How to integrate NearbyPlacePopup into NavigationScreen
// This shows the minimal changes needed to display the popup

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/models/place_model.dart';
import '../core/services/route_tracking_service.dart';
import '../widgets/nearby_place_popup.dart';

/// Example mixin to add to _NavigationScreenState
/// 
/// Usage:
/// class _NavigationScreenState extends State<NavigationScreen> with NearbyPlacePopupMixin {
///   // ... existing code
/// }
mixin NearbyPlacePopupMixin<T extends StatefulWidget> on State<T> {
  // State for popup
  PlaceModel? _currentNearbyPlace;
  double _currentDistance = 0;
  bool _showNearbyPlacePopup = false;
  StreamSubscription<Position>? _positionSubscription;
  
  final RouteTrackingService _routeTrackingService = RouteTrackingService();

  /// Call this in initState()
  void initNearbyPlacePopup() {
    // Listen to position updates
    _positionSubscription = _routeTrackingService.currentPositionStream.listen((position) {
      _checkNearbyPlaces(position);
    });
  }

  /// Call this in dispose()
  void disposeNearbyPlacePopup() {
    _positionSubscription?.cancel();
  }

  /// Check for nearby places and show popup
  void _checkNearbyPlaces(Position position) {
    final nearbyPlaces = _routeTrackingService.nearbyPlaces;
    
    for (final place in nearbyPlaces) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        place.location.latitude,
        place.location.longitude,
      );

      // Show popup if within 500 meters and not already showing
      if (distance <= 500 && !_showNearbyPlacePopup) {
        setState(() {
          _currentNearbyPlace = place;
          _currentDistance = distance;
          _showNearbyPlacePopup = true;
        });
        
        // Auto-dismiss after 10 seconds
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted && _showNearbyPlacePopup) {
            setState(() => _showNearbyPlacePopup = false);
          }
        });
        
        break; // Show only one popup at a time
      }
    }
  }

  /// Widget to add in the Stack (where map overlays are)
  Widget buildNearbyPlacePopupWidget() {
    if (!_showNearbyPlacePopup || _currentNearbyPlace == null) {
      return const SizedBox.shrink();
    }

    return NearbyPlacePopup(
      place: _currentNearbyPlace!,
      distanceInMeters: _currentDistance,
      onDismiss: () {
        setState(() => _showNearbyPlacePopup = false);
      },
      onViewDetails: () {
        // Focus camera on the place
        // Call your existing _moveCamera method:
        // _moveCamera(_currentNearbyPlace!.location);
        setState(() => _showNearbyPlacePopup = false);
      },
    );
  }
}

/// INTEGRATION STEPS:
/// 
/// 1. Add mixin to _NavigationScreenState:
///    class _NavigationScreenState extends State<NavigationScreen> with NearbyPlacePopupMixin {
/// 
/// 2. In initState(), add:
///    initNearbyPlacePopup();
/// 
/// 3. In dispose(), add:
///    disposeNearbyPlacePopup();
/// 
/// 4. In your Stack widget (where you have GoogleMap), add:
///    Stack(
///      children: [
///        GoogleMap(...),
///        if (state is MapsNavigationLoading)
///          const Center(child: CircularProgressIndicator()),
///        buildNearbyPlacePopupWidget(),  // <-- Add this
///      ],
///    )
/// 
/// That's it! The popup will automatically appear when users are within 500m of tourist places.
