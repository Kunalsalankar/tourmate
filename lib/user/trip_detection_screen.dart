import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/colors.dart';
import '../core/models/auto_trip_model.dart';
import '../cubit/trip_detection_cubit.dart';
import 'trip_confirmation_screen.dart';

/// Screen for managing automatic trip detection
class TripDetectionScreen extends StatefulWidget {
  const TripDetectionScreen({super.key});

  @override
  State<TripDetectionScreen> createState() => _TripDetectionScreenState();
}

class _TripDetectionScreenState extends State<TripDetectionScreen> {
  late TripDetectionCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = TripDetectionCubit();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _toggleDetection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (_cubit.isDetecting) {
      _cubit.stopDetection();
    } else {
      _cubit.startDetection(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Automatic Trip Detection',
            style: TextStyle(
              color: AppColors.appBarText,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.appBarBackground,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.appBarText),
        ),
        body: BlocConsumer<TripDetectionCubit, TripDetectionState>(
          listener: (context, state) {
            if (state is TripDetectionError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is TripDetected) {
              // Show notification and navigate to confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip detected! Please confirm details.'),
                  backgroundColor: Colors.green,
                ),
              );
              _showTripConfirmation(context, state.trip);
            } else if (state is TripConfirmed) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip confirmed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDetectionCard(state),
                  const SizedBox(height: 20),
                  _buildCurrentTripCard(state),
                  const SizedBox(height: 20),
                  _buildPendingTripsCard(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetectionCard(TripDetectionState state) {
    final isActive = state is TripDetectionActive || 
                     state is TripDetected ||
                     _cubit.isDetecting;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              isActive ? Icons.location_on : Icons.location_off,
              size: 64,
              color: isActive ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Detection Active' : 'Detection Inactive',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Your trips are being automatically tracked'
                  : 'Start detection to track your trips automatically',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: state is TripDetectionLoading ? null : _toggleDetection,
              icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
              label: Text(
                isActive ? 'Stop Detection' : 'Start Detection',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTripCard(TripDetectionState state) {
    if (state is! TripDetectionActive || state.currentTrip == null) {
      return const SizedBox.shrink();
    }

    final trip = state.currentTrip!;
    return Card(
      elevation: 4,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Trip in Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildTripInfoRow(
              Icons.straighten,
              'Distance',
              '${trip.distanceKm.toStringAsFixed(2)} km',
            ),
            _buildTripInfoRow(
              Icons.timer,
              'Duration',
              '${trip.durationMinutes} min',
            ),
            _buildTripInfoRow(
              Icons.speed,
              'Avg Speed',
              '${trip.averageSpeedKmh.toStringAsFixed(1)} km/h',
            ),
            if (trip.detectedMode != null)
              _buildTripInfoRow(
                Icons.directions_transit,
                'Detected Mode',
                trip.detectedMode!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTripsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pending_actions, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Pending Confirmations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _cubit.pendingTrips.isEmpty
                ? Text(
                    'No pending trips to confirm',
                    style: TextStyle(color: Colors.grey[600]),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cubit.pendingTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _cubit.pendingTrips[index];
                      return _buildPendingTripItem(trip);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTripItem(AutoTripModel trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: const Icon(Icons.trip_origin, color: Colors.orange),
        ),
        title: Text(
          '${trip.distanceKm.toStringAsFixed(2)} km • ${trip.durationMinutes} min',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_formatDateTime(trip.startTime)} → ${_formatDateTime(trip.endTime!)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: ElevatedButton(
          onPressed: () => _showTripConfirmation(context, trip),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm'),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'How It Works',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('1', 'Enable detection to start tracking'),
            _buildInfoItem('2', 'App detects when you start moving'),
            _buildInfoItem('3', 'Trip ends when you stop for 5 minutes'),
            _buildInfoItem('4', 'Confirm trip details and purpose'),
            const SizedBox(height: 8),
            Text(
              'Note: Keep location permission enabled for accurate detection.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showTripConfirmation(BuildContext context, AutoTripModel trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _cubit,
          child: TripConfirmationScreen(trip: trip),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
