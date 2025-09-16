import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/colors.dart';
import '../core/models/trip_model.dart';
import '../cubit/trip_cubit.dart';
import '../core/repositories/trip_repository.dart';

/// Admin screen to view all trip data from users
/// This screen provides comprehensive trip management and analytics for administrators
class AdminTripsScreen extends StatefulWidget {
  const AdminTripsScreen({super.key});

  @override
  State<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends State<AdminTripsScreen> {
  late TripCubit _tripCubit;
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tripCubit = TripCubit(tripRepository: TripRepository());
    _tripCubit.getAllTrips();
  }

  @override
  void dispose() {
    _tripCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _tripCubit,
      child: Scaffold(
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
            _buildFilterSection(),
            Expanded(child: _buildTripsList()),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _refreshTrips,
          backgroundColor: AppColors.buttonPrimary,
          child: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
        ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  Expanded(
                    child: Text(
                      trip.tripNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
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
            _buildDetailRow('Origin', trip.origin),
            _buildDetailRow('Destination', trip.destination),
            _buildDetailRow('Time', _formatDateTime(trip.time)),
            _buildDetailRow('Mode', trip.mode),
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

  void _refreshTrips() {
    _tripCubit.getAllTrips();
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
