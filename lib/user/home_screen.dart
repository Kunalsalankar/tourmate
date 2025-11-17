// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../core/colors.dart';
import '../core/models/trip_model.dart';
import '../core/models/location_comment_model.dart';
import '../core/services/location_service.dart';
import '../core/services/environment_service.dart';
import '../core/repositories/location_comment_repository.dart';
import '../cubit/trip_cubit.dart';
import '../core/repositories/trip_repository.dart';
import '../widgets/trip_form_widget.dart';
import '../core/services/places_autocomplete_service.dart';
import '../widgets/add_comment_dialog.dart';
import '../cubit/bottom_nav_cubit.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/location_comment_cubit.dart';
import 'location_comments_screen.dart';
import '../presentation/screens/notification_screen.dart';
import 'trip_map_screen.dart';
import '../GEMIN_API/trip_planner_chat.dart';

/// User Home Screen with trip creation and management functionality
/// This screen provides the main interface for users to create, view, and manage their trips
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  late TripCubit _tripCubit;

  int _currentTabIndex = 0;
  final List<TripType> _tripTypes = TripType.values;

  EnvironmentInfo? _envInfo;

  // Places autocomplete for dialogs
  final PlacesAutocompleteService _placesService = PlacesAutocompleteService();
  Timer? _placesDebounce;
  String? _placesSessionToken;

  @override
  void initState() {
    super.initState();
    _tripCubit = TripCubit(tripRepository: TripRepository());
    _loadTrips();
    _fetchEnvironment();
    _initializePlaces();
  }

  Future<void> _initializePlaces() async {
    try {
      await _placesService.initialize();
      _placesSessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    } catch (_) {}
  }

  void _loadTrips() {
    if (_currentTabIndex == 0) {
      _tripCubit.getUserTrips();
    } else {
      _tripCubit.getTripsByType(_tripTypes[_currentTabIndex - 1]);
    }
  }

  Future<void> _fetchEnvironment() async {
    if (!mounted) return;
    final pos = await LocationService().getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      return;
    }
    final info = await EnvironmentService().fetch(
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
    if (!mounted) return;
    setState(() {
      _envInfo = info;
    });
  }

  Color _aqiColor(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('good')) return Colors.green;
    if (c.contains('moderate')) return Colors.yellow.shade700;
    if (c.contains('sensitive')) return Colors.orange;
    if (c.contains('unhealthy') && !c.contains('very')) return Colors.red;
    if (c.contains('very')) return Colors.purple;
    if (c.contains('hazard') || c.contains('severe')) return Colors.brown;
    return Colors.grey;
  }

  @override
  void dispose() {
    _tripCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _tripCubit),
        BlocProvider(create: (_) => BottomNavCubit()),
        BlocProvider(create: (_) => NotificationCubit()),
        BlocProvider(create: (_) => LocationCommentCubit()),
      ],
      child: BlocBuilder<BottomNavCubit, int>(
        builder: (context, selectedIndex) {
          return BlocListener<NotificationCubit, NotificationState>(
              listener: (context, state) {
                if (state.message != null && state.message!.isNotEmpty) {
                  showSimpleNotification(
                    Text(
                      state.message!,
                      style: TextStyle(color: AppColors.textOnPrimary),
                    ),
                    background: AppColors.primary,
                  );
                }
              },
              child: Scaffold(
                backgroundColor: AppColors.background,
                appBar: AppBar(
                  title: const Text(
                    'Tourmate',
                    style: TextStyle(
                      color: AppColors.appBarText,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  backgroundColor: AppColors.appBarBackground,
                  elevation: 0,
                  actions: [
                    IconButton(
                      onPressed: _openTravelAssistant,
                      icon: const Icon(
                        Icons.smart_toy,
                        color: AppColors.appBarText,
                      ),
                      tooltip: 'Travel Assistant',
                    ),
                    if (_envInfo != null && _envInfo!.temperatureC != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: _fetchEnvironment,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wb_sunny, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  '${_envInfo!.temperatureC!.toStringAsFixed(0)}°C',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_envInfo != null && _envInfo!.aqi != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: _fetchEnvironment,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.air, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'AQI ${_envInfo!.aqi}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      onPressed: _signOut,
                      icon: const Icon(
                        Icons.logout,
                        color: AppColors.appBarText,
                      ),
                      tooltip: 'Sign Out',
                    ),
                  ],
                ),
                body: IndexedStack(
                  index: selectedIndex,
                  children: [
                    // Home tab
                    Column(
                      children: [
                        _buildWelcomeSection(),
                        _buildQuickStats(),
                        _buildTripTypeTabs(),
                        const SizedBox(height: 8),
                        Expanded(child: _buildTripsList()),
                      ],
                    ),
                    // Notifications tab
                    const NotificationScreen(),
                    // Location Comments tab
                    const LocationCommentsScreen(),
                  ],
                ),
                floatingActionButton: selectedIndex == 0
                    ? FloatingActionButton.extended(
                        onPressed: _createNewTrip,
                        backgroundColor: AppColors.buttonPrimary,
                        heroTag: 'homeFab',
                        icon: const Icon(
                          Icons.add,
                          color: AppColors.textOnPrimary,
                        ),
                        label: const Text(
                          'New Trip',
                          style: TextStyle(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: selectedIndex,
                  onTap: (index) =>
                      context.read<BottomNavCubit>().selectTab(index),
                  backgroundColor: AppColors.surface,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: AppColors.textSecondary,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.notifications),
                      label: 'Checkout',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.location_on),
                      label: 'Comments',
                    ),
                  ],
                ),
              ),
            );
        },
      ),
    );
  }

  void _openTravelAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TripPlannerChat(),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? 'User',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textOnPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/navigation');
            },
            icon: const Icon(Icons.navigation, color: AppColors.textOnPrimary),
            label: const Text(
              'Start Navigation',
              style: TextStyle(color: AppColors.textOnPrimary),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          if (_envInfo != null)
            Row(
              children: [
                if (_envInfo!.temperatureC != null)
                  InkWell(
                    onTap: _fetchEnvironment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wb_sunny, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            '${_envInfo!.temperatureC!.toStringAsFixed(0)}°C'
                            '${_envInfo!.weatherDescription != null ? ' • ${_envInfo!.weatherDescription}' : ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_envInfo!.temperatureC != null) const SizedBox(width: 8),
                if (_envInfo!.aqi != null)
                  InkWell(
                    onTap: _fetchEnvironment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.air, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'AQI ${_envInfo!.aqi}'
                            '${_envInfo!.aqiCategory != null ? ' • ${_envInfo!.aqiCategory}' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTripTypeTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTripTypeTab('All', 0),
          _buildTripTypeTab('Active', 1),
          _buildTripTypeTab('Past', 2),
          _buildTripTypeTab('Future', 3),
        ],
      ),
    );
  }

  Widget _buildTripTypeTab(String label, int index) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTabIndex = index;
            _loadTrips();
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return BlocBuilder<TripCubit, TripState>(
      builder: (context, state) {
        if (state is TripLoaded) {
          final totalTrips = state.trips.length;
          final totalTravellers = state.trips.fold<int>(
            0,
            (sum, trip) => sum + trip.accompanyingTravellers.length,
          );
          final uniqueDestinations = state.trips
              .map((trip) => trip.destination)
              .toSet()
              .length;

          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.directions_car,
                  label: 'Total Trips',
                  value: totalTrips.toString(),
                  color: AppColors.primary,
                ),
                _buildStatItem(
                  icon: Icons.people,
                  label: 'Travellers',
                  value: totalTravellers.toString(),
                  color: AppColors.secondary,
                ),
                _buildStatItem(
                  icon: Icons.place,
                  label: 'Destinations',
                  value: uniqueDestinations.toString(),
                  color: AppColors.accent,
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTripsList() {
    return BlocBuilder<TripCubit, TripState>(
      builder: (context, state) {
        if (state is TripLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        } else if (state is TripError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading trips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadTrips,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonPrimary,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: AppColors.textOnPrimary),
                  ),
                ),
              ],
            ),
          );
        } else if (state is TripLoaded) {
          if (state.trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.card_travel, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _currentTabIndex == 0
                        ? 'No trips found'
                        : 'No ${_tripTypes[_currentTabIndex - 1].toString().split('.').last} trips',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (_currentTabIndex == 0)
                    TextButton(
                      onPressed: _createNewTrip,
                      child: const Text('Create your first trip!'),
                    ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.trips.length,
            itemBuilder: (context, index) {
              return _buildTripCard(state.trips[index]);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTripCard(TripModel trip) {
    // Determine trip type for styling
    Color typeColor;
    IconData typeIcon;

    if (trip.time.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      typeColor = Colors.blue;
      typeIcon = Icons.upcoming;
    } else if (trip.time.isAfter(DateTime.now())) {
      typeColor = Colors.green;
      typeIcon = Icons.timer;
    } else {
      typeColor = Colors.grey;
      typeIcon = Icons.history;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: typeColor.withOpacity(0.2), width: 1),
      ),
      child: InkWell(
        onTap: () => _viewTripDetails(trip),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(typeIcon, size: 24, color: typeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trip.destination == 'Unknown'
                                    ? '${trip.origin} → ???'
                                    : '${trip.origin} → ${trip.destination}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (trip.destination == 'Unknown') ...[
                              const SizedBox(width: 6),
                              Icon(Icons.explore, size: 16, color: AppColors.accent),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trip #${trip.tripNumber} • ${trip.mode}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trip.tripType.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.tripType == TripType.past && trip.endTime != null
                          ? 'Start: ${_formatDateTime(trip.time)}\nEnd: ${_formatDateTime(trip.endTime!)}'
                          : _formatDateTime(trip.time),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  Text(
                    '${trip.accompanyingTravellers.length + 1} ${trip.accompanyingTravellers.length == 0 ? 'Person' : 'People'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              // Add Comment and End Trip buttons for active trips
              if (trip.tripType == TripType.active) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _addCommentToTrip(trip),
                        icon: const Icon(Icons.add_comment, size: 18),
                        label: const Text('Add Comment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _endTrip(trip),
                        icon: const Icon(Icons.stop_circle, size: 18),
                        label: const Text('End Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _createNewTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _tripCubit,
          child: const TripFormWidget(),
        ),
      ),
    ).then((_) {
      _loadTrips();
    });
  }

  void _viewTripDetails(TripModel trip) {
    showDialog(
      context: context,
      builder: (context) => _buildTripDetailsDialog(trip),
    );
  }

  Widget _buildTripDetailsDialog(TripModel trip) {
    final user = FirebaseAuth.instance.currentUser;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getTripIcon(trip.mode),
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.tripNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          trip.mode,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(trip.tripType),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(trip.tripType),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route Section
                    _buildSectionTitle('Route Details', Icons.route),
                    const SizedBox(height: 12),
                    _buildEnhancedDetailRow(
                      Icons.trip_origin,
                      'Origin',
                      trip.origin,
                      AppColors.success,
                    ),
                    const SizedBox(height: 8),
                    _buildEnhancedDetailRow(
                      Icons.location_on,
                      'Destination',
                      trip.destination,
                      AppColors.error,
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Time Section
                    _buildSectionTitle('Time Details', Icons.schedule),
                    const SizedBox(height: 12),
                    _buildEnhancedDetailRow(
                      Icons.access_time,
                      trip.tripType == TripType.past ? 'Start Time' : 'Time',
                      _formatDateTime(trip.time),
                      AppColors.primary,
                    ),
                    if (trip.tripType == TripType.past && trip.endTime != null) ...[
                      const SizedBox(height: 8),
                      _buildEnhancedDetailRow(
                        Icons.event_available,
                        'End Time',
                        _formatDateTime(trip.endTime!),
                        AppColors.primary,
                      ),
                      const SizedBox(height: 8),
                      _buildEnhancedDetailRow(
                        Icons.timer,
                        'Duration',
                        _calculateDuration(trip.time, trip.endTime!),
                        AppColors.accent,
                      ),
                    ],

                    // Activities Section
                    if (trip.activities.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Activities', Icons.local_activity),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: trip.activities.map((activity) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              activity,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    // Travellers Section
                    if (trip.accompanyingTravellers.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Travellers', Icons.people),
                      const SizedBox(height: 12),
                      ...trip.accompanyingTravellers.map((traveller) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                                child: Text(
                                  traveller.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      traveller.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${traveller.age} years old',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // Comments Section
                    if (trip.id != null && user != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Journey Comments', Icons.comment),
                      const SizedBox(height: 13),
                      _buildCommentsSection(trip.id!, user.uid),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (trip.tripType == TripType.past && trip.id != null) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TripMapScreen(
                                tripId: trip.id!,
                                tripTitle: trip.tripNumber,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('View Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _editTrip(trip);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _editTrip(TripModel trip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _tripCubit,
          child: TripFormWidget(trip: trip, isEditing: true),
        ),
      ),
    );
  }

  void _handleTripAction(String action, TripModel trip) {
    switch (action) {
      case 'edit':
        _editTrip(trip);
        break;
      case 'delete':
        _showDeleteConfirmation(trip);
        break;
    }
  }

  void _showDeleteConfirmation(TripModel trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text(
          'Are you sure you want to delete trip "${trip.tripNumber}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _tripCubit.deleteTrip(trip.id!);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.textOnPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // Add comment to active trip
  Future<void> _addCommentToTrip(TripModel trip) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get current location
      final locationService = LocationService();
      await locationService.initialize();
      final position = await locationService.getCurrentPosition();
      
      if (position == null) {
        throw Exception('Unable to get current location. Please enable GPS.');
      }
      
      final currentLocation = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      // Show comment dialog
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AddCommentDialog(
          currentLocation: currentLocation,
          userId: user.uid,
          userName: user.displayName ?? user.email ?? 'User',
          tripId: trip.id,
        ),
      );

      // Show success message if comment was added
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Comment added to "${trip.tripNumber}"!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: ${e.toString()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _endTrip(TripModel trip) {
    // Check if this is a random trip (destination is "Unknown")
    if (trip.destination == 'Unknown') {
      _endRandomTrip(trip);
    } else {
      _endNormalTrip(trip);
    }
  }

  void _endNormalTrip(TripModel trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip'),
        content: Text(
          'Are you sure you want to end trip "${trip.tripNumber}"?\n\nThis will mark the trip as completed and set the end time to now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _tripCubit.endTrip(trip.id!);
              
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Trip "${trip.tripNumber}" has been ended successfully!',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(
              'End Trip',
              style: TextStyle(color: AppColors.textOnPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _endRandomTrip(TripModel trip) {
    final destinationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.explore, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('End Random Trip'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where did you end up?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter the destination where your trip ended.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Autocomplete<PlaceAutocompletePrediction>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty || textEditingValue.text.length < 2) {
                    return const Iterable<PlaceAutocompletePrediction>.empty();
                  }
                  _placesDebounce?.cancel();
                  final completer = Completer<List<PlaceAutocompletePrediction>>();
                  _placesDebounce = Timer(const Duration(milliseconds: 500), () async {
                    final suggestions = await _placesService.getAutocompleteSuggestions(
                      textEditingValue.text,
                      sessionToken: _placesSessionToken,
                    );
                    completer.complete(suggestions);
                  });
                  return completer.future;
                },
                displayStringForOption: (PlaceAutocompletePrediction option) => option.description,
                onSelected: (PlaceAutocompletePrediction selection) {
                  destinationController.text = selection.description;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  if (destinationController.text.isNotEmpty && controller.text.isEmpty) {
                    controller.text = destinationController.text;
                  }
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Final Destination',
                  hintText: 'e.g., Mumbai, Goa, etc.',
                  prefixIcon: const Icon(Icons.location_on, color: AppColors.error),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                          if (controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                controller.clear();
                                destinationController.clear();
                              },
                            ),
                    ],
                  ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      destinationController.text = value;
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You can skip this and update it later if needed.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // End trip without updating destination
              Navigator.of(context).pop();
              _tripCubit.endTrip(trip.id!);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Trip ended. Destination remains "Unknown".'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              final destination = destinationController.text.trim();
              
              if (destination.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Please enter a destination or click Skip'),
                    backgroundColor: AppColors.snackbarWarning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              // Update trip with destination and end it
              final updatedTrip = TripModel(
                id: trip.id,
                tripNumber: trip.tripNumber,
                origin: trip.origin,
                destination: destination,
                time: trip.time,
                endTime: DateTime.now(),
                mode: trip.mode,
                tripType: TripType.past,
                activities: trip.activities,
                accompanyingTravellers: trip.accompanyingTravellers,
                userId: trip.userId,
                createdAt: trip.createdAt,
                updatedAt: DateTime.now(),
              );
              
              _tripCubit.updateTrip(trip.id!, updatedTrip);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Trip ended at $destination!',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text(
              'End Trip',
              style: TextStyle(color: AppColors.textOnPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get trip icon based on mode
  IconData _getTripIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
      case 'bicycle':
        return Icons.directions_bike;
      case 'bus':
        return Icons.directions_bus;
      case 'train':
        return Icons.train;
      case 'flight':
      case 'airplane':
        return Icons.flight;
      case 'walking':
        return Icons.directions_walk;
      default:
        return Icons.trip_origin;
    }
  }

  // Helper method to get status color
  Color _getStatusColor(TripType tripType) {
    switch (tripType) {
      case TripType.active:
        return Colors.green;
      case TripType.future:
        return Colors.orange;
      case TripType.past:
        return Colors.grey;
    }
  }

  // Helper method to get status text
  String _getStatusText(TripType tripType) {
    switch (tripType) {
      case TripType.active:
        return 'ACTIVE';
      case TripType.future:
        return 'UPCOMING';
      case TripType.past:
        return 'COMPLETED';
    }
  }

  // Build section title widget
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // Build enhanced detail row with icon
  Widget _buildEnhancedDetailRow(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Calculate duration between two dates
  String _calculateDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours hr ${minutes} min';
    } else {
      return '$minutes min';
    }
  }

  // Build comments section
  Widget _buildCommentsSection(String tripId, String currentUserId) {
    return StreamBuilder<List<LocationCommentModel>>(
      stream: LocationCommentRepository().getTripComments(tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error loading comments: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        }

        final comments = snapshot.data ?? [];

        if (comments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No comments yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add comments during your journey',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: comments.map((comment) {
            final isOwner = comment.uid == currentUserId;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOwner 
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOwner 
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isOwner
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.accent.withValues(alpha: 0.2),
                        child: Text(
                          comment.userName.isNotEmpty
                              ? comment.userName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: isOwner ? AppColors.primary : AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  comment.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isOwner) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              _formatCommentTime(comment.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.grey[600],
                          onPressed: () => _deleteComment(comment),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  
                  // Tags
                  if (comment.tags != null && comment.tags!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: comment.tags!.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  
                  // Comment text
                  const SizedBox(height: 8),
                  Text(
                    comment.comment,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  
                  // Location
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${comment.lat.toStringAsFixed(4)}, ${comment.lng.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Format comment timestamp
  String _formatCommentTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[timestamp.month - 1]} ${timestamp.day}';
    }
  }

  // Delete comment
  Future<void> _deleteComment(LocationCommentModel comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && comment.id != null) {
      final repository = LocationCommentRepository();
      final success = await repository.deleteComment(comment.id!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Comment deleted successfully' : 'Failed to delete comment',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/role-selection');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
