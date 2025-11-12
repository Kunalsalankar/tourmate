import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../core/colors.dart';
import '../core/models/checkpoint_model.dart';
import '../cubit/admin_checkpoint_cubit.dart';
import '../core/repositories/checkpoint_repository.dart';

class AdminCheckpointsScreen extends StatefulWidget {
  const AdminCheckpointsScreen({Key? key}) : super(key: key);

  @override
  _AdminCheckpointsScreenState createState() => _AdminCheckpointsScreenState();
}

class _AdminCheckpointsScreenState extends State<AdminCheckpointsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');

  @override
  void initState() {
    super.initState();
    // Add listener to scroll controller for infinite scroll if needed
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Load more checkpoints if needed
      // context.read<AdminCheckpointCubit>().loadMoreCheckpoints();
    }
  }

  void _showCheckpointDetails(CheckpointModel checkpoint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(checkpoint.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('User', '${checkpoint.userName} (${checkpoint.userId})'),
              const SizedBox(height: 12),
              _buildDetailRow('Location', 
                '${checkpoint.latitude.toStringAsFixed(6)}, ${checkpoint.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openMaps(checkpoint.latitude, checkpoint.longitude),
                child: Text(
                  'View on Map',
                  style: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Recorded', _dateFormat.format(checkpoint.timestamp)),
              _buildDetailRow('Added', _dateFormat.format(checkpoint.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _openMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  Widget _buildActiveTripGroupsSection(List<TripCheckpointGroup> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Trips',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            return _buildActiveTripCard(groups[index]);
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActiveTripCard(TripCheckpointGroup group) {
    final subtitleParts = <String>[];
    if (group.tripDestination != null && group.tripDestination!.isNotEmpty) {
      subtitleParts.add('Destination: ${group.tripDestination}');
    }
    if (group.tripMode != null && group.tripMode!.isNotEmpty) {
      subtitleParts.add('Mode: ${group.tripMode}');
    }
    final subtitleText = subtitleParts.join(' • ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          group.tripNumber ?? 'Trip ${group.tripId}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.userName != null && group.userName!.isNotEmpty)
              Text(
                group.userName!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            if (subtitleText.isNotEmpty)
              Text(
                subtitleText,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            if (group.lastUpdatedAt != null)
              Text(
                'Last checkpoint: ${_dateFormat.format(group.lastUpdatedAt!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recent checkpoints (${group.checkpoints.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...group.checkpoints.take(5).map(
            (checkpoint) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dateFormat.format(checkpoint.timestamp),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${checkpoint.latitude.toStringAsFixed(5)}, ${checkpoint.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (group.checkpoints.length > 5)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '+ ${group.checkpoints.length - 5} more checkpoints',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckpointCard(CheckpointModel checkpoint) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => _showCheckpointDetails(checkpoint),
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
                      checkpoint.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _dateFormat.format(checkpoint.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                checkpoint.userName,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${checkpoint.latitude.toStringAsFixed(6)}, ${checkpoint.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminCheckpointCubit(
        checkpointRepository: CheckpointRepository(),
      )..loadCheckpoints(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkpoints'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
        ),
        body: BlocBuilder<AdminCheckpointCubit, AdminCheckpointState>(
          builder: (context, state) {
            // Show loading indicator
            if (state.isLoading && state.checkpoints.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // Show error message
            if (state.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading checkpoints: ${state.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Show empty state
            if (state.filteredCheckpoints.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      state.filterQuery != null
                          ? 'No checkpoints found for "${state.filterQuery}"'
                          : 'No checkpoints available',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (state.filterQuery != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.read<AdminCheckpointCubit>().clearFilter(),
                        child: const Text('Clear filter'),
                      ),
                    ],
                  ],
                ),
              );
            }

            // Show checkpoints list
            return Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search checkpoints...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                context.read<AdminCheckpointCubit>().clearFilter();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (value) =>
                        context.read<AdminCheckpointCubit>().filterCheckpoints(value),
                  ),
                ),

                // Checkpoints count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${state.filteredCheckpoints.length} checkpoints',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (state.filterQuery != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.read<AdminCheckpointCubit>().clearFilter(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Filter: ${state.filterQuery}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.close, size: 14),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (state.activeTripGroups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildActiveTripGroupsSection(state.activeTripGroups),
                  ),

                // Checkpoints list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      context.read<AdminCheckpointCubit>().loadCheckpoints();
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: state.filteredCheckpoints.length,
                      itemBuilder: (context, index) {
                        return _buildCheckpointCard(state.filteredCheckpoints[index]);
                      },
                    ),
                  ),
                ),

                // Loading indicator for pagination
                if (state.isLoading && state.checkpoints.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
