import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/colors.dart';
import '../core/models/trip_model.dart';
import '../core/models/location_comment_model.dart';
import '../cubit/trip_cubit.dart';
import '../core/repositories/trip_repository.dart';
import '../core/repositories/location_comment_repository.dart';
import '../core/navigation/app_router.dart';
import '../cubit/location_comment_cubit.dart';
import '../user/location_comments_screen.dart';
import '../screens/recent_data_screen.dart';
import 'analytics_screen.dart';

/// Production-ready Admin screen for comprehensive trip management
/// Features:
/// - Real-time analytics dashboard
/// - Advanced filtering and search
/// - Export capabilities
/// - Responsive design
/// - Enhanced UX with animations
class AdminTripsScreen extends StatefulWidget {
  const AdminTripsScreen({super.key});

  @override
  State<AdminTripsScreen> createState() => _AdminTripsScreenState();
}

class _AdminTripsScreenState extends State<AdminTripsScreen> with SingleTickerProviderStateMixin {
  late TripCubit _tripCubit;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  String _selectedFilter = 'all';
  String _searchQuery = '';
  int _currentTabIndex = 0;
  int _bottomNavIndex = 0;
  final List<TripType> _tripTypes = TripType.values;
  final TextEditingController _searchController = TextEditingController();
  
  // View mode
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
    
    // Initialize cubit
    _tripCubit = TripCubit(tripRepository: TripRepository());
    _loadTrips();
  }

  void _loadTrips() {
    if (_currentTabIndex == 0) {
      _tripCubit.getAllTrips();
    } else {
      // For admin, we still load all trips but will filter them locally
      _tripCubit.getAllTrips();
    }
  }

  @override
  void dispose() {
    _tripCubit.close();
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _tripCubit),
        BlocProvider(create: (_) => LocationCommentCubit()),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _bottomNavIndex == 0
            ? AppBar(
                title: const Text(
                  'Admin - Trip Management',
                  style: TextStyle(
                    color: AppColors.appBarText,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                backgroundColor: AppColors.appBarBackground,
                elevation: 0,
                actions: [
                  // Checkpoints dashboard
                  IconButton(
                    onPressed: () => Navigator.of(context).pushNamed(AppRouter.adminCheckpoints),
                    icon: const Icon(Icons.flag, color: AppColors.appBarText),
                    tooltip: 'Checkpoints',
                  ),
                  // Research analytics (OD, time-series)
                  IconButton(
                    onPressed: () => Navigator.of(context).pushNamed(AppRouter.adminResearchAnalytics),
                    icon: const Icon(Icons.science, color: AppColors.appBarText),
                    tooltip: 'Research Analytics',
                  ),
                  // View mode toggle
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                    icon: Icon(
                      _isGridView ? Icons.list : Icons.grid_view,
                      color: AppColors.appBarText,
                    ),
                    tooltip: _isGridView ? 'List View' : 'Grid View',
                  ),
                  // Refresh button
                  IconButton(
                    onPressed: _refreshTrips,
                    icon: const Icon(Icons.refresh, color: AppColors.appBarText),
                    tooltip: 'Refresh',
                  ),
                  // Sign out
                  IconButton(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: AppColors.appBarText),
                    tooltip: 'Sign Out',
                  ),
                ],
              )
            : null,
        body: IndexedStack(
          index: _bottomNavIndex,
          children: [
            // Home (admin trips management)
            FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildStatsSection(),
                        _buildTripTypeTabs(),
                        const SizedBox(height: 8),
                        _buildFilterSection(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  _buildTripsListSliver(),
                ],
              ),
            ),
            // Analysis dashboard
            const AnalyticsScreen(),
            // Recent Data dashboard
            const RecentDataScreen(),
            // Comments (reuse existing screen)
            const LocationCommentsScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _bottomNavIndex,
          onTap: (index) => setState(() => _bottomNavIndex = index),
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Analysis',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.update),
              label: 'Recent Data',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.comment),
              label: 'Comments',
            ),
          ],
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
            (sum, trip) => sum + trip.accompanyingTravellers.length + 1,
          );
          final uniqueUsers = trips.map((trip) => trip.userId).toSet().length;
          final uniqueDestinations = trips
              .map((trip) => trip.destination)
              .toSet()
              .length;

          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trip Analytics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textOnPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.textOnPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: AppColors.textOnPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Live',
                            style: TextStyle(
                              color: AppColors.textOnPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.directions_car,
                      label: 'Total Trips',
                      value: totalTrips.toString(),
                      color: AppColors.textOnPrimary,
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppColors.textOnPrimary.withOpacity(0.2),
                    ),
                    _buildStatItem(
                      icon: Icons.people,
                      label: 'Total Travellers',
                      value: totalTravellers.toString(),
                      color: AppColors.textOnPrimary,
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppColors.textOnPrimary.withOpacity(0.2),
                    ),
                    _buildStatItem(
                      icon: Icons.person,
                      label: 'Active Users',
                      value: uniqueUsers.toString(),
                      color: AppColors.textOnPrimary,
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: AppColors.textOnPrimary.withOpacity(0.2),
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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Search & Filter',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              if (_searchQuery.isNotEmpty || _selectedFilter != 'all')
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _selectedFilter = 'all';
                      _searchController.clear();
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by trip number, origin, destination...',
              hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.iconPrimary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorderFocused, width: 2),
              ),
              filled: true,
              fillColor: AppColors.inputBackground,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Transport Mode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', Icons.all_inclusive),
                const SizedBox(width: 8),
                _buildFilterChip('Car', 'Car', Icons.directions_car),
                const SizedBox(width: 8),
                _buildFilterChip('Bus', 'Bus', Icons.directions_bus),
                const SizedBox(width: 8),
                _buildFilterChip('Train', 'Train', Icons.train),
                const SizedBox(width: 8),
                _buildFilterChip('Flight', 'Flight', Icons.flight),
                const SizedBox(width: 8),
                _buildFilterChip('Other', 'Other', Icons.more_horiz),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.iconSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
        });
      },
      selectedColor: AppColors.primaryLight.withOpacity(0.3),
      checkmarkColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }
  

  Widget _buildTripsListSliver() {
    return BlocBuilder<TripCubit, TripState>(
      builder: (context, state) {
        if (state is TripLoading) {
          return SliverFillRemaining(
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        } else if (state is TripError) {
          return SliverFillRemaining(
            child: Center(
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
            ),
          );
        } else if (state is TripLoaded) {
          final filteredTrips = _filterTrips(state.trips);

          if (filteredTrips.isEmpty) {
            return SliverFillRemaining(
              child: _buildEmptyState(),
            );
          }

          return _isGridView
            ? SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildTripGridCard(filteredTrips[index]);
                    },
                    childCount: filteredTrips.length,
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildTripCard(filteredTrips[index]);
                    },
                    childCount: filteredTrips.length,
                  ),
                ),
              );
        }
        return SliverToBoxAdapter(child: const SizedBox.shrink());
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
    
    // Sort by date (most recent first)
    filteredTrips.sort((a, b) => b.time.compareTo(a.time));

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
                          trip.tripType.toString().split('.').last.toUpperCase(),
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

  Widget _buildTripGridCard(TripModel trip) {
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: typeColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: () => _viewTripDetails(trip),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(typeIcon, size: 20, color: typeColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trip.mode,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                trip.tripNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: AppColors.iconSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.origin,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place, size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.destination,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: AppColors.iconSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.accompanyingTravellers.length + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      trip.tripType.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
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

  void _viewTripDetails(TripModel trip) {
    showDialog(
      context: context,
      builder: (context) => _buildTripDetailsDialog(trip),
    );
  }

  Widget _buildTripDetailsDialog(TripModel trip) {
    Color typeColor;
    if (trip.time.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      typeColor = Colors.blue;
    } else if (trip.time.isAfter(DateTime.now())) {
      typeColor = Colors.green;
    } else {
      typeColor = Colors.grey;
    }
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typeColor, typeColor.withOpacity(0.7)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.info_outline, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.tripNumber,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          trip.tripType.toString().split('.').last.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
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
                    _buildDetailSection(
                      'Trip Information',
                      Icons.directions_car,
                      [
                        _buildDetailRow('Trip Number', trip.tripNumber),
                        _buildDetailRow('Mode of Transport', trip.mode),
                        _buildDetailRow('Trip Type', trip.tripType.toString().split('.').last.toUpperCase()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Route Details',
                      Icons.route,
                      [
                        _buildDetailRow('Origin', trip.origin),
                        _buildDetailRow('Destination', trip.destination),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Time Information',
                      Icons.schedule,
                      [
                        _buildDetailRow(
                          trip.tripType == TripType.past ? 'Start Time' : 'Trip Time',
                          _formatDateTime(trip.time),
                        ),
                        if (trip.tripType == TripType.past && trip.endTime != null)
                          _buildDetailRow('End Time', _formatDateTime(trip.endTime!)),
                        _buildDetailRow('Created', _formatDateTime(trip.createdAt)),
                      ],
                    ),
                    if (trip.activities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection(
                        'Activities',
                        Icons.local_activity,
                        trip.activities.map((activity) => 
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(activity)),
                              ],
                            ),
                          )
                        ).toList(),
                      ),
                    ],
                    if (trip.accompanyingTravellers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailSection(
                        'Accompanying Travellers',
                        Icons.people,
                        trip.accompanyingTravellers.map((traveller) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    traveller.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Age: ${traveller.age} years',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (traveller.phoneNumber != null)
                                    Text(
                                      'Phone: ${traveller.phoneNumber}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        ).toList(),
                      ),
                    ],
                    // User Information Section
                    const SizedBox(height: 16),
                    // Journey Comments Section
                    const SizedBox(height: 16),
                    _buildCommentsSection(trip.id),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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

  Widget _buildCommentsSection(String? tripId) {
    if (tripId == null) {
      return const SizedBox.shrink();
    }

    final commentRepository = LocationCommentRepository();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.comment, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Journey Comments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<LocationCommentModel>>(
            stream: commentRepository.getTripComments(tripId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading comments: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.comment_outlined, size: 32, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: comments.map((comment) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                              child: Text(
                                comment.userName.isNotEmpty 
                                    ? comment.userName[0].toUpperCase() 
                                    : 'U',
                                style: const TextStyle(
                                  color: AppColors.accent,
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
                                  Text(
                                    comment.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (comment.tags != null && comment.tags!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Wrap(
                              spacing: 4,
                              children: comment.tags!.map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
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
                          ),
                        Text(
                          comment.comment,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${comment.lat.toStringAsFixed(4)}, ${comment.lng.toStringAsFixed(4)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _fetchUserInfo(String userId) async {
    try {
      // First try to get from Firestore users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final email = userData?['email'] as String?;
        final name = userData?['name'] as String? ?? userData?['displayName'] as String?;
        
        if (email != null) {
          return {
            'email': email,
            'name': name ?? email.split('@')[0],
          };
        }
      }

      // If not found in Firestore, try to get from Firebase Auth
      // Note: This requires admin SDK or we can just show the userId
      // For now, we'll show a formatted version of userId
      return {
        'email': 'User ID: $userId',
        'name': 'User ${userId.substring(0, 8)}',
      };
    } catch (e) {
      return {
        'email': 'Error loading user',
        'name': 'N/A',
      };
    }
  }

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
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _refreshTrips() {
    _loadTrips();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.refresh, color: AppColors.textOnPrimary, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Refreshing trips...',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.download, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Export Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose export format:'),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.table_chart, color: AppColors.primary),
              title: const Text('CSV'),
              subtitle: const Text('Comma-separated values'),
              onTap: () {
                Navigator.pop(context);
                _performExport('CSV');
              },
            ),
            ListTile(
              leading: Icon(Icons.code, color: AppColors.secondary),
              title: const Text('JSON'),
              subtitle: const Text('JavaScript Object Notation'),
              onTap: () {
                Navigator.pop(context);
                _performExport('JSON');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _performExport(String format) {
    // This is a placeholder for actual export functionality
    // In production, you would implement actual file export here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.textOnPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Export to $format initiated. This feature requires platform-specific implementation.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
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