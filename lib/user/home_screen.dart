import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:overlay_support/overlay_support.dart';
import '../core/colors.dart';
import '../core/models/trip_model.dart';
import '../cubit/trip_cubit.dart';
import '../core/repositories/trip_repository.dart';
import '../widgets/trip_form_widget.dart';
import '../cubit/bottom_nav_cubit.dart';
import '../cubit/notification_cubit.dart';

/// User Home Screen with trip creation and management functionality
/// This screen provides the main interface for users to create, view, and manage their trips
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  late TripCubit _tripCubit;

  @override
  void initState() {
    super.initState();
    _tripCubit = TripCubit(tripRepository: TripRepository());
    _tripCubit.getUserTrips();
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
                        Expanded(child: _buildTripsList()),
                        // Example: Button to trigger a notification
                       
                      ],
                    ),
                    
                   
                  ],
                ),
                floatingActionButton: selectedIndex == 0
                    ? FloatingActionButton.extended(
                        onPressed: _createNewTrip,
                        backgroundColor: AppColors.buttonPrimary,
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
                      label: 'Notifications',
                    ),
                  ],
                ),
              ),
            
          );
        },
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
        ],
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
                  onPressed: () => _tripCubit.getUserTrips(),
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
            return _buildEmptyState();
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_outlined, size: 0, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            'No trips yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your journey by creating your first trip!',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleTripAction(value, trip),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: AppColors.iconPrimary),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
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
                  Icon(
                    Icons.directions_car,
                    size: 16,
                    color: AppColors.iconSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trip.mode,
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
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activity,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
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

  void _createNewTrip() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _tripCubit,
          child: const TripFormWidget(),
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
            _buildDetailRow('Origin', trip.origin),
            _buildDetailRow('Destination', trip.destination),
            _buildDetailRow('Time', _formatDateTime(trip.time)),
            _buildDetailRow('Mode', trip.mode),
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
                (traveller) =>
                    Text('• ${traveller.name} (${traveller.age} years old)'),
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
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _editTrip(trip);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonPrimary,
          ),
          child: const Text(
            'Edit',
            style: TextStyle(color: AppColors.textOnPrimary),
          ),
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