import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/colors.dart';
import '../core/models/auto_trip_model.dart';
import 'trip_confirmation_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/trip_detection_cubit.dart';

/// Demo screen to test UI without real GPS
/// This allows testing on Windows/Web/Emulator
class TripDetectionDemo extends StatefulWidget {
  const TripDetectionDemo({super.key});

  @override
  State<TripDetectionDemo> createState() => _TripDetectionDemoState();
}

class _TripDetectionDemoState extends State<TripDetectionDemo> {
  bool _isDetecting = false;
  bool _isTripActive = false;
  double _distance = 0.0;
  int _duration = 0;
  double _avgSpeed = 0.0;
  String _detectedMode = 'Walking';

  AutoTripModel? _demoTrip;

  void _toggleDetection() {
    setState(() {
      _isDetecting = !_isDetecting;
      if (!_isDetecting) {
        _isTripActive = false;
        _distance = 0.0;
        _duration = 0;
        _avgSpeed = 0.0;
      }
    });
  }

  void _simulateTrip() {
    if (!_isDetecting) return;

    setState(() {
      _isTripActive = true;
      _distance = 8.2; // km
      _duration = 35; // minutes
      _avgSpeed = 14.1; // km/h
      _detectedMode = 'Bus';
    });

    // Simulate trip end after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _createDemoTrip();
      }
    });
  }

  void _createDemoTrip() {
    final now = DateTime.now();
    final startTime = now.subtract(Duration(minutes: _duration));

    final origin = LocationPoint(
      coordinates: const LatLng(11.2588, 75.7804), // Kozhikode
      timestamp: startTime,
      speed: 0.5,
      accuracy: 10.0,
    );

    final destination = LocationPoint(
      coordinates: const LatLng(11.2488, 75.7904),
      timestamp: now,
      speed: 0.3,
      accuracy: 12.0,
    );

    // Create route points
    final routePoints = <LocationPoint>[
      origin,
      LocationPoint(
        coordinates: const LatLng(11.2550, 75.7850),
        timestamp: startTime.add(const Duration(minutes: 10)),
        speed: 12.0,
        accuracy: 10.0,
      ),
      LocationPoint(
        coordinates: const LatLng(11.2520, 75.7880),
        timestamp: startTime.add(const Duration(minutes: 20)),
        speed: 15.0,
        accuracy: 10.0,
      ),
      destination,
    ];

    setState(() {
      _demoTrip = AutoTripModel(
        id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'demo_user',
        origin: origin,
        destination: destination,
        startTime: startTime,
        endTime: now,
        distanceCovered: _distance * 1000, // Convert to meters
        averageSpeed: _avgSpeed / 3.6, // Convert to m/s
        maxSpeed: 20.0,
        routePoints: routePoints,
        status: AutoTripStatus.detected,
        detectedMode: _detectedMode,
        createdAt: now,
        updatedAt: now,
      );
      _isTripActive = false;
    });

    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demo Trip Detected! Tap to confirm.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Trip Detection Demo',
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.appBarBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.appBarText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDemoNotice(),
            const SizedBox(height: 20),
            _buildDetectionCard(),
            const SizedBox(height: 20),
            if (_isTripActive) _buildCurrentTripCard(),
            if (_demoTrip != null) _buildPendingTripCard(),
            const SizedBox(height: 20),
            _buildSimulateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoNotice() {
    return Card(
      elevation: 4,
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demo Mode',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This is a demo to test the UI without GPS. '
                    'For real trip detection, test on a physical device.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
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

  Widget _buildDetectionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              _isDetecting ? Icons.location_on : Icons.location_off,
              size: 64,
              color: _isDetecting ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _isDetecting ? 'Detection Active (Demo)' : 'Detection Inactive',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isDetecting
                  ? 'Demo mode - Click "Simulate Trip" below'
                  : 'Start detection to begin demo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _toggleDetection,
              icon: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isDetecting ? 'Stop Detection' : 'Start Detection',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDetecting ? Colors.red : AppColors.primary,
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

  Widget _buildCurrentTripCard() {
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
                  'Demo Trip in Progress',
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
                    'DEMO',
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
            _buildTripInfoRow(Icons.straighten, 'Distance', '${_distance.toStringAsFixed(2)} km'),
            _buildTripInfoRow(Icons.timer, 'Duration', '$_duration min'),
            _buildTripInfoRow(Icons.speed, 'Avg Speed', '${_avgSpeed.toStringAsFixed(1)} km/h'),
            _buildTripInfoRow(Icons.directions_transit, 'Detected Mode', _detectedMode),
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

  Widget _buildPendingTripCard() {
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
                  'Pending Confirmation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange[100],
                  child: const Icon(Icons.trip_origin, color: Colors.orange),
                ),
                title: Text(
                  '${_demoTrip!.distanceKm.toStringAsFixed(2)} km • ${_demoTrip!.durationMinutes} min',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Demo trip - ${_demoTrip!.detectedMode}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _showTripConfirmation(_demoTrip!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulateButton() {
    return Card(
      elevation: 4,
      color: Colors.purple[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.science, size: 48, color: Colors.purple),
            const SizedBox(height: 12),
            const Text(
              'Simulate a Trip',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click below to simulate a bus trip of 8.2 km',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isDetecting ? _simulateTrip : null,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text(
                'Simulate Trip',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
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

  void _showTripConfirmation(AutoTripModel trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (_) => TripDetectionCubit(),
          child: TripConfirmationScreen(trip: trip),
        ),
      ),
    );
  }
}
