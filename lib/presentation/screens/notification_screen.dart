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
                          Text(
                            state.activeTripId == null
                                ? 'No active trip found.\nStart an active trip to begin recording checkpoints.'
                                : 'Checkpoints are being recorded every 10 seconds and sent to the admin dashboard for monitoring.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
