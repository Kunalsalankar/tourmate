import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/colors.dart';
import '../core/models/trip_model.dart';
import '../cubit/trip_cubit.dart';
import '../core/repositories/user_location_repository.dart';
import '../core/models/place_model.dart';
import '../core/services/maps_service.dart';

/// Admin screen to view all trip data from users
/// This screen provides comprehensive trip management and analytics for administrators
class AdminTripsScreen extends StatefulWidget {
  const AdminTripsScreen({super.key});

  @override
  State<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends State<AdminTripsScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  int _currentTabIndex = 0;
  final List<TripType> _tripTypes = TripType.values;
  final MapsService _mapsService = MapsService();
  bool _mapsInitialized = false;

  @override
  void initState() {
    super.initState();
    // Use the TripCubit from parent BlocProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrips();
    });
    _initializeMaps();
  }

  void _loadTrips() {
    final tripCubit = context.read<TripCubit>();
    if (_currentTabIndex == 0) {
      tripCubit.getAllTrips();
    } else {
      // For admin, we still load all trips but will filter them locally
      tripCubit.getAllTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Admin - Trip Management',
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.appBarBackground,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: AppColors.appBarText),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsSection(),
          _buildTripTypeTabs(),
          const SizedBox(height: 8),
          _buildFilterSection(),
          Expanded(child: _buildTripsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshTrips,
        backgroundColor: AppColors.buttonPrimary,
        child: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
      ),
    );
  }

  Widget _buildStatsSection() {
    return BlocBuilder<TripCubit, TripState>(
      builder: (context, state) {
        if (state is TripLoaded) {
          final trips = state.trips;
          final totalTrips = trips.length;
          final totalTravellers = trips.fold<int>(
            0,
            (sum, trip) => sum + trip.accompanyingTravellers.length,
          );
          final uniqueUsers = trips.map((trip) => trip.userId).toSet().length;
          final uniqueDestinations = trips
              .map((trip) => trip.destination)
              .toSet()
              .length;

          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Analytics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.directions_car,
                      label: 'Total Trips',
                      value: totalTrips.toString(),
                      color: AppColors.textOnPrimary,
                    ),
                    _buildStatItem(
                      icon: Icons.people,
                      label: 'Total Travellers',
                      value: totalTravellers.toString(),
                      color: AppColors.textOnPrimary,
                    ),
                    _buildStatItem(
                      icon: Icons.person,
                      label: 'Active Users',
                      value: uniqueUsers.toString(),
                      color: AppColors.textOnPrimary,
                    ),
                    _buildStatItem(
                      icon: Icons.place,
                      label: 'Destinations',
                      value: uniqueDestinations.toString(),
                      color: AppColors.textOnPrimary,
                    ),
                  ],
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
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
        ),
      ],
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

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search trips...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.iconPrimary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              filled: true,
              fillColor: AppColors.inputBackground,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Car', 'Car'),
                const SizedBox(width: 8),
                _buildFilterChip('Bus', 'Bus'),
                const SizedBox(width: 8),
                _buildFilterChip('Train', 'Train'),
                const SizedBox(width: 8),
                _buildFilterChip('Flight', 'Flight'),
                const SizedBox(width: 8),
                _buildFilterChip('Other', 'Other'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
        });
      },
      selectedColor: AppColors.primaryLight,
      checkmarkColor: AppColors.textOnPrimary,
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
                  onPressed: _refreshTrips,
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
          final filteredTrips = _filterTrips(state.trips);

          if (filteredTrips.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredTrips.length,
            itemBuilder: (context, index) {
              return _buildTripCard(filteredTrips[index]);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  List<TripModel> _filterTrips(List<TripModel> trips) {
    var filteredTrips = trips;

    // Filter by trip type
    if (_currentTabIndex > 0) {
      final selectedType = _tripTypes[_currentTabIndex - 1];
      filteredTrips = filteredTrips
          .where((trip) => trip.tripType == selectedType)
          .toList();
    }

    // Filter by transport mode
    if (_selectedFilter != 'all') {
      filteredTrips = filteredTrips
          .where((trip) => trip.mode == _selectedFilter)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filteredTrips = filteredTrips.where((trip) {
        return trip.tripNumber.toLowerCase().contains(_searchQuery) ||
            trip.origin.toLowerCase().contains(_searchQuery) ||
            trip.destination.toLowerCase().contains(_searchQuery) ||
            trip.mode.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return filteredTrips;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            'No trips found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter criteria',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(typeIcon, size: 20, color: typeColor),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        trip.tripNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trip.tripType
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          trip.mode,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.iconSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${trip.origin} → ${trip.destination}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.iconSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(trip.time),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.person, size: 16, color: AppColors.iconSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'User: ${trip.userId.substring(0, 8)}...',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (trip.accompanyingTravellers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 16,
                      color: AppColors.iconSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.accompanyingTravellers.length} traveller${trip.accompanyingTravellers.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              if (trip.activities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: trip.activities.take(3).map((activity) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (trip.activities.length > 3)
                  Text(
                    '+${trip.activities.length - 3} more',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _viewTripDetails(TripModel trip) {
    showDialog(
      context: context,
      builder: (context) => _buildTripDetailsDialog(trip),
    );
  }

  Widget _buildTripDetailsDialog(TripModel trip) {
    return AlertDialog(
      title: Text(trip.tripNumber),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Trip Number', trip.tripNumber),
            _buildDetailRow(
              'Trip Type',
              trip.tripType.toString().split('.').last.toUpperCase(),
            ),
            _buildDetailRow('Origin', trip.origin),
            _buildPlaceCoordinatesRow('Origin Coords', trip.origin),
            _buildDetailRow('Destination', trip.destination),
            _buildPlaceCoordinatesRow('Destination Coords', trip.destination),
            _buildDetailRow(
              trip.tripType == TripType.past ? 'Start Time' : 'Time',
              _formatDateTime(trip.time),
            ),
            if (trip.tripType == TripType.past && trip.endTime != null)
              _buildDetailRow('End Time', _formatDateTime(trip.endTime!)),
            _buildDetailRow('Mode', trip.mode),
            const SizedBox(height: 8),
            const Text(
              'User Location:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _buildUserLocationRow(trip.userId),
            //  _buildDetailRow('User ID', trip.userId),
            _buildDetailRow('Created', _formatDateTime(trip.createdAt)),
            if (trip.activities.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Activities:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...trip.activities.map((activity) => Text('• $activity')),
            ],
            if (trip.accompanyingTravellers.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Travellers:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...trip.accompanyingTravellers.map(
                (traveller) => Text(
                  '• ${traveller.name} (${traveller.age} years old)${traveller.phoneNumber != null ? ' - ${traveller.phoneNumber}' : ''}',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  Widget _buildUserLocationRow(String userId) {
    final repo = UserLocationRepository();
    return FutureBuilder<
      ({double latitude, double longitude, DateTime? updatedAt})?
    >(
      future: repo.getUserLocation(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Fetching location...'),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Text('No location available');
        }
        final data = snapshot.data!;
        final lat = data.latitude.toStringAsFixed(6);
        final lng = data.longitude.toStringAsFixed(6);
        final updatedAt = data.updatedAt != null
            ? ' • Updated: ${_formatDateTime(data.updatedAt!)}'
            : '';
        return Text('Lat: $lat, Lng: $lng$updatedAt');
      },
    );
  }

  void _refreshTrips() {
    _loadTrips();
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

  Future<void> _initializeMaps() async {
    if (_mapsInitialized) return;
    try {
      await _mapsService.initialize();
      _mapsInitialized = true;
    } catch (_) {
      _mapsInitialized = false;
    }
  }

  Widget _buildPlaceCoordinatesRow(String label, String query) {
    return FutureBuilder<List<PlaceModel>>(
      future: _mapsInitialized
          ? _mapsService.searchPlaces(query)
          : _initializeMaps().then((_) => _mapsService.searchPlaces(query)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDetailRow(label, 'Fetching...');
        }
        final results = snapshot.data;
        if (results == null || results.isEmpty) {
          return _buildDetailRow(label, 'Not available');
        }
        final loc = results.first.location;
        final lat = loc.latitude.toStringAsFixed(6);
        final lng = loc.longitude.toStringAsFixed(6);
        return _buildDetailRow(label, 'Lat: $lat, Lng: $lng');
      },
    );
  }
}
