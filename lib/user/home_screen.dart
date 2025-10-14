// ignore_for_file: unused_element

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

  int _currentTabIndex = 0;
  final List<TripType> _tripTypes = TripType.values;

  @override
  void initState() {
    super.initState();
    _tripCubit = TripCubit(tripRepository: TripRepository());
    _loadTrips();
  }

  void _loadTrips() {
    if (_currentTabIndex == 0) {
      _tripCubit.getUserTrips();
    } else {
      _tripCubit.getTripsByType(_tripTypes[_currentTabIndex - 1]);
    }
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
                        _buildTripTypeTabs(),
                        const SizedBox(height: 8),
                        Expanded(child: _buildTripsList()),
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
                children: [
                  Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                trip.destination == 'Unknown' 
                                  ? '${trip.origin} → ???'
                                  : '${trip.origin} → ${trip.destination}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
                          ),
                        ],
                      ),
                    ],
                  ),
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
                    '${trip.accompanyingTravellers.length + 1} ${trip.accompanyingTravellers.length == 0 ? 'Person' : 'People'}' ,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              // Add End Trip button for active trips
              if (trip.tripType == TripType.active) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
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
    return AlertDialog(
      title: Text(trip.tripNumber),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Origin', trip.origin),
            _buildDetailRow('Destination', trip.destination),
            _buildDetailRow(
              trip.tripType == TripType.past ? 'Start Time' : 'Time',
              _formatDateTime(trip.time),
            ),
            if (trip.tripType == TripType.past && trip.endTime != null)
              _buildDetailRow('End Time', _formatDateTime(trip.endTime!)),
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
        content: Column(
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
            TextField(
              controller: destinationController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Final Destination',
                hintText: 'e.g., Mumbai, Goa, etc.',
                prefixIcon: const Icon(Icons.location_on, color: AppColors.error),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
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
                  Expanded(
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