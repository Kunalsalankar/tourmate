// ignore_for_file: unused_field

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../core/colors.dart';
import '../core/models/place_model.dart';
import '../cubit/maps_navigation_cubit.dart';
import '../core/services/route_tracking_service.dart';
import '../core/services/connectivity_service.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  // Google Maps controller
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  // Map markers, polylines, and circles
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};

  // Text editing controllers for origin and destination
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Selected places
  PlaceModel? _selectedOrigin;
  PlaceModel? _selectedDestination;

  // Search results
  List<PlaceModel> _originSearchResults = [];
  List<PlaceModel> _destinationSearchResults = [];

  // Loading state
  bool _isSearching = false;
  
  // Connectivity service
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    print('[DEBUG] NavigationScreen initState');
    // Initialize the maps navigation cubit
    context.read<MapsNavigationCubit>().initialize();
    
    // Setup connectivity listener
    _connectivityService.connectivityStream.listen((isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
      
      if (!isConnected) {
        _showConnectivityWarning();
      }
    });
  }

  @override
  void dispose() {
    print('[DEBUG] NavigationScreen dispose');
    _originController.dispose();
    _destinationController.dispose();
    _connectivityService.dispose();
    super.dispose();
  }
  
  /// Show connectivity warning when network is lost
  void _showConnectivityWarning() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Network connection lost. Some features may not work properly.'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () async {
            final isConnected = await _connectivityService.checkConnectivity();
            if (isConnected && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Network connection restored')),
              );
            }
          },
        ),
      ),
    );
  }

  // Last map position for tracking camera movements
  CameraPosition? _lastMapPosition;

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] NavigationScreen build');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<MapsNavigationCubit, MapsNavigationState>(
        listener: (context, state) {
          print('[DEBUG] BlocConsumer listener: $state');
          if (state is MapsNavigationError) {
            print('[DEBUG] Showing error: ${state.message}');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is RouteLoaded) {
            print('[DEBUG] RouteLoaded: updating map');
            _updateMapWithRoute(state);
          }
        },
        builder: (context, state) {
          print('[DEBUG] BlocConsumer builder: $state');
          return Column(
            children: [
              // Search bars for origin and destination
              _buildSearchSection(),

              // Google Map
              Expanded(
                child: Stack(
                  children: [
                    // Map
                    GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(20.5937, 78.9629), // Center of India
                        zoom: 5,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _controller.complete(controller);
                      },
                      markers: _markers,
                      polylines: _polylines,
                      circles: _circles,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      compassEnabled: true,
                      zoomControlsEnabled: true,
                      onCameraMove: (CameraPosition position) {
                        // Store the current camera position
                        _lastMapPosition = position;
                      },
                    ),

                    // Loading indicator
                    if (state is MapsNavigationLoading)
                      const Center(child: CircularProgressIndicator()),

                    // Navigation overlay when active
                    if (state is MapsNavigationActive && state.isNavigating)
                      _buildNavigationOverlay(state),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  // Build search section for origin and destination
  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Origin search
          _buildSearchField(
            controller: _originController,
            hint: 'Enter origin',
            onChanged: _searchOrigin,
            results: _originSearchResults,
            onResultTap: (place) {
              setState(() {
                _selectedOrigin = place;
                _originController.text = place.name;
                _originSearchResults = [];
              });
              _addMarker(
                place.location,
                place.name,
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
              );
              _moveCamera(place.location);
            },
          ),

          const SizedBox(height: 8),

          // Destination search
          _buildSearchField(
            controller: _destinationController,
            hint: 'Enter destination',
            onChanged: _searchDestination,
            results: _destinationSearchResults,
            onResultTap: (place) {
              setState(() {
                _selectedDestination = place;
                _destinationController.text = place.name;
                _destinationSearchResults = [];
              });
              _addMarker(
                place.location,
                place.name,
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              );
              _moveCamera(place.location);
            },
          ),

          const SizedBox(height: 16),

          // Get directions button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedOrigin != null && _selectedDestination != null
                  ? _getDirections
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Get Directions'),
            ),
          ),
        ],
      ),
    );
  }

  // Build search field with results
  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
    required List<PlaceModel> results,
    required Function(PlaceModel) onResultTap,
  }) {
    // Only show location button for origin field
    final bool isOriginField = hint == 'Enter origin';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: isOriginField ? IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () => _useCurrentLocationAsOrigin(),
              tooltip: 'Use current location',
            ) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
          onChanged: onChanged,
        ),

        // Search results
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(76), // 0.3 * 255 = 76
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length > 5 ? 5 : results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = results[index];
                return ListTile(
                  title: Text(place.name),
                  subtitle: Text(
                    place.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onResultTap(place),
                );
              },
            ),
          ),
      ],
    );
  }

  // Search for origin places
  Future<void> _searchOrigin(String query) async {
    print('[DEBUG] _searchOrigin called with query: $query');
    if (query.length < 3) {
      setState(() {
        _originSearchResults = [];
      });
      return;
    }
    
    // Check connectivity before making network request
    if (!_isConnected) {
      _showConnectivityWarning();
      return;
    }

    setState(() {
      _isSearching = true;
      _originSearchResults = []; // Clear previous results
    });

    try {
      final results = await context.read<MapsNavigationCubit>().searchPlaces(
        query,
      );

      if (!mounted) return;

      setState(() {
        _originSearchResults = results;
        _isSearching = false;
        
        // If we have exactly one result, auto-select it
        if (results.length == 1) {
          _selectedOrigin = results.first;
          _originController.text = results.first.name;
          _originSearchResults = []; // Clear search results after selection
          
          // Add marker for the selected origin
          _addMarker(
            results.first.location,
            results.first.name,
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          );
          _moveCamera(results.first.location);
          
          // Force UI update to enable Get Directions button if destination is also selected
          if (_selectedDestination != null) {
            print('[DEBUG] Both origin and destination selected, enabling Get Directions button');
            setState(() {}); // Explicitly trigger rebuild to update button state
          }
        }
      });
      print('[DEBUG] _searchOrigin results: ${results.length}');
    } catch (e) {
      print('[DEBUG] Error searching for origin: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _originSearchResults = []; // Clear results on error
        });
        
        // Check if error is related to network connectivity
        if (!_isConnected) {
          _showConnectivityWarning();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error searching for places: $e')),
          );
        }
      }
    }
  }

  // Search for destination places
  Future<void> _searchDestination(String query) async {
    print('[DEBUG] _searchDestination called with query: $query');
    if (query.length < 3) {
      setState(() {
        _destinationSearchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await context.read<MapsNavigationCubit>().searchPlaces(
        query,
      );

      if (!mounted) return;

      setState(() {
        _destinationSearchResults = results;
        _isSearching = false;
        // If we have exactly one result, auto-select it
        if (results.length == 1) {
          _selectedDestination = results.first;
          _destinationController.text = results.first.name;
          _destinationSearchResults = []; // Clear search results after selection
          
          // Add marker for the selected destination
          _addMarker(
            results.first.location,
            results.first.name,
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          );
          _moveCamera(results.first.location);
          
          // Force UI update to enable Get Directions button if origin is also selected
          if (_selectedOrigin != null) {
            print('[DEBUG] Both origin and destination selected, enabling Get Directions button');
            setState(() {}); // Explicitly trigger rebuild to update button state
          }
        }
      });
      print('[DEBUG] _searchDestination results: ${results.length}');
    } catch (e) {
      print('[DEBUG] Error searching for destination: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _destinationSearchResults = []; // Clear results on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for places: $e')),
        );
      }
    }
  }

  // Get directions between origin and destination
  void _getDirections() {
    print('[DEBUG] _getDirections called');
    if (_selectedOrigin == null || _selectedDestination == null) {
      print('[DEBUG] Origin or destination is null');
      return;
    }

    context.read<MapsNavigationCubit>().setRoute(
      _selectedOrigin!.location,
      _selectedDestination!.location,
    );
  }

  // Update map with route information
  void _updateMapWithRoute(RouteLoaded state) {
    print('[DEBUG] _updateMapWithRoute called');
    setState(() {
      // Clear previous markers, polylines, and circles
      _markers.clear();
      _polylines.clear();
      _circles.clear();

      // Add origin marker
      _addMarker(
        state.origin,
        'Origin',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );

      // Add destination marker
      _addMarker(
        state.destination,
        'Destination',
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );

      // Add nearby place markers
      for (final place in state.nearbyPlaces) {
        _addMarker(
          place.location,
          place.name,
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        );

        // Add circle around nearby place
        _circles.add(
          Circle(
            circleId: CircleId('circle_${place.placeId}'),
            center: place.location,
            radius: 100, // 100 meters
            fillColor: AppColors.primary.withAlpha(51), // 0.2 * 255 = 51
            strokeColor: AppColors.primary,
            strokeWidth: 1,
          ),
        );
      }

      // Add polyline for the route
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: state.polylinePoints,
          color: AppColors.primary,
          width: 5,
        ),
      );
    });

    // Fit the map to show the entire route
    _fitMapToRoute(state.polylinePoints);
  }

  // Add marker to the map
  void _addMarker(LatLng position, String title, BitmapDescriptor icon) {
    print('[DEBUG] _addMarker: $title at $position');
    final markerId = MarkerId(position.toString());
    final marker = Marker(
      markerId: markerId,
      position: position,
      infoWindow: InfoWindow(title: title),
      icon: icon,
    );

    setState(() {
      _markers.add(marker);
    });
  }

  // Move camera to a specific position
  Future<void> _moveCamera(LatLng position) async {
    print('[DEBUG] _moveCamera to $position');
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  // Fit map to show the entire route
  Future<void> _fitMapToRoute(List<LatLng> points) async {
    print('[DEBUG] _fitMapToRoute called with ${points.length} points');
    if (points.isEmpty) return;

    final GoogleMapController controller = await _controller.future;

    // Calculate the bounds of the route
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Create bounds and add padding
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Animate camera to show the entire route with padding
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // Get current location and move camera to it
  Future<void> _getCurrentLocation() async {
    print('[DEBUG] _getCurrentLocation called');
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      _moveCamera(latLng);
    } catch (e) {
      if (!mounted) return;
      print('[DEBUG] Error getting current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting current location: $e')),
      );
    }
  }
  
  // Use current location as origin
  Future<void> _useCurrentLocationAsOrigin() async {
    print('[DEBUG] _useCurrentLocationAsOrigin called');
    setState(() {
      _isSearching = true;
    });
    
    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (!mounted) return;
      
      // Create a place model for current location
      final latLng = LatLng(position.latitude, position.longitude);
      
      // Get address for current location using reverse geocoding
      final results = await context.read<MapsNavigationCubit>().searchPlaces(
        '${position.latitude},${position.longitude}',
      );
      
      String placeName = 'Current Location';
      String placeAddress = 'Your Location';
      
      // If we got results from reverse geocoding, use the first one
      if (results.isNotEmpty) {
        placeName = results.first.name;
        placeAddress = results.first.address;
      }
      
      // Create a place model for current location
      final currentPlace = PlaceModel(
        placeId: 'current_location',
        name: placeName,
        address: placeAddress,
        location: latLng,
      );
      
      // Set as selected origin
      setState(() {
        _selectedOrigin = currentPlace;
        _originController.text = placeName;
        _originSearchResults = [];
        _isSearching = false;
        
        // Add marker for current location
        _addMarker(
          latLng,
          placeName,
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
        _moveCamera(latLng);
        
        // Force UI update to enable Get Directions button if destination is also selected
        if (_selectedDestination != null) {
          setState(() {});
        }
      });
      
    } catch (e) {
      if (!mounted) return;
      print('[DEBUG] Error getting current location: $e');
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error using current location: $e')),
      );
    }
  }

  // Build navigation overlay with route tracking information
  Widget _buildNavigationOverlay(MapsNavigationActive state) {
    // ignore: unused_local_variable
    final routeTrackingService = RouteTrackingService();
    final isNavigating = state.isNavigating;
    final isOffRoute = state.isOffRoute;

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Navigation Active',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (isOffRoute)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Off Route',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.destination?.name ?? 'Destination',
                      style: TextStyle(color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                    Icons.speed,
                    'Distance',
                    '${_calculateRemainingDistance(state)} km',
                  ),
                  _buildInfoItem(Icons.timer, 'ETA', _calculateETA(state)),
                  _buildInfoItem(
                    Icons.place,
                    'POIs',
                    '${state.nearbyPlaces.length}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (isNavigating) {
                          context.read<MapsNavigationCubit>().stopNavigation();
                        } else {
                          context.read<MapsNavigationCubit>().startNavigation();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isNavigating
                            ? Colors.red
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        isNavigating ? 'Stop Navigation' : 'Start Navigation',
                      ),
                    ),
                  ),
                  if (isOffRoute)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // Recalculate route
                          _recalculateRoute(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Recalculate'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.black54)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _calculateRemainingDistance(MapsNavigationActive state) {
    if (state.currentLocation == null || state.polylinePoints.isEmpty) {
      return '0.0';
    }

    // Find the closest point on the route to the current location
    final currentLocation = state.currentLocation!;
    int closestPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < state.polylinePoints.length; i++) {
      final point = state.polylinePoints[i];
      final distance = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        point.latitude,
        point.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // Calculate remaining distance from the closest point to the destination
    double remainingDistance = 0;
    for (int i = closestPointIndex; i < state.polylinePoints.length - 1; i++) {
      final point1 = state.polylinePoints[i];
      final point2 = state.polylinePoints[i + 1];

      remainingDistance += Geolocator.distanceBetween(
        point1.latitude,
        point1.longitude,
        point2.latitude,
        point2.longitude,
      );
    }

    // Convert to kilometers and format
    return (remainingDistance / 1000).toStringAsFixed(1);
  }

  String _calculateETA(MapsNavigationActive state) {
    if (state.currentLocation == null || state.polylinePoints.isEmpty) {
      return '--:--';
    }

    // Estimate time based on remaining distance and average speed (50 km/h)
    final remainingDistanceKm = double.parse(
      _calculateRemainingDistance(state),
    );
    final estimatedHours =
        remainingDistanceKm / 50.0; // Assuming 50 km/h average speed

    // Calculate arrival time
    final now = DateTime.now();
    final arrivalTime = now.add(
      Duration(minutes: (estimatedHours * 60).round()),
    );

    // Format as HH:MM
    return '${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}';
  }

  void _recalculateRoute(BuildContext context) async {
    print('[DEBUG] _recalculateRoute called');
    // Store references before the async gap
    final cubit = context.read<MapsNavigationCubit>();
    final state = cubit.state;

    if (state is MapsNavigationActive &&
        state.currentLocation != null &&
        state.destination != null) {
      // Get current location as new origin
      final currentLocation = state.currentLocation!;
      final destinationLocation = state.destination!.location;

      // Stop current navigation
      cubit.stopNavigation();

      // Recalculate route from current location to destination
      await cubit.setRoute(currentLocation, destinationLocation);

      // Check if the widget is still mounted before continuing
      if (!mounted) return;

      // Restart navigation
      cubit.startNavigation();
    }
  }
}
