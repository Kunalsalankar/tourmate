import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../cubit/notification_cubit.dart';
import '../../../core/colors.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationCubit(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Refresh the checkpoints
                final cubit = context.read<NotificationCubit>();
                cubit.add(
                const AddCheckpointEvent(),
              );
                cubit.refreshActiveTrip();
                cubit.clearError();
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: BlocBuilder<NotificationCubit, NotificationState>(
          builder: (context, state) {
            // Show error message if any
            if (state.error != null && state.error!.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.error!),
                    backgroundColor: Colors.red,
                  ),
                );
                // Clear the error after showing it
                context.read<NotificationCubit>().clearError();
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checkpoint Recorder',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTripStatus(state),
                    ],
                  ),
                ),
                if (state.activeTripId == null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 72,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No active trip found.\nStart an active trip to begin recording checkpoints.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'Checkpoints are being recorded every 10 seconds',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: state.checkpoints.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.update,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Waiting for checkpoints...',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  itemCount: state.checkpoints.length,
                                  itemBuilder: (context, index) {
                                    final checkpoint = state.checkpoints[index];
                                    return _buildCheckpointItem(checkpoint, index);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCheckpointItem(Checkpoint checkpoint, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          checkpoint.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${DateFormat('MMM d, yyyy - hh:mm a').format(checkpoint.timestamp)}\n${checkpoint.coordinatesText}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildTripStatus(NotificationState state) {
    if (state.activeTripId == null) {
      return const Text(
        'Waiting for an active trip...',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      );
    }

    final details = <String>[];
    if (state.activeTripDestination != null &&
        state.activeTripDestination!.isNotEmpty) {
      details.add('Destination: ${state.activeTripDestination}');
    }
    if (state.activeTripMode != null && state.activeTripMode!.isNotEmpty) {
      details.add('Mode: ${state.activeTripMode}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recording checkpoints for ${state.activeTripTitle ?? 'active trip'}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            details.join(' • '),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

}
