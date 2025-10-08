import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/colors.dart';
import '../core/models/auto_trip_model.dart';
import '../cubit/trip_detection_cubit.dart';

/// Screen for confirming detected trip details
class TripConfirmationScreen extends StatefulWidget {
  final AutoTripModel trip;

  const TripConfirmationScreen({
    super.key,
    required this.trip,
  });

  @override
  State<TripConfirmationScreen> createState() => _TripConfirmationScreenState();
}

class _TripConfirmationScreenState extends State<TripConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _companionsController = TextEditingController();
  final _costController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedMode;
  final List<String> _travelModes = [
    'Walking',
    'Cycling',
    'E-Bike',
    'Motorcycle',
    'Car',
    'Bus',
    'Train',
    'Auto/Rickshaw',
    'Other',
  ];

  final List<String> _commonPurposes = [
    'Work',
    'Education',
    'Shopping',
    'Healthcare',
    'Recreation',
    'Social Visit',
    'Religious',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.trip.detectedMode ?? _travelModes.first;
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _companionsController.dispose();
    _costController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _confirmTrip() {
    if (!_formKey.currentState!.validate()) return;

    final companions = _companionsController.text.trim().isEmpty
        ? null
        : _companionsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final cost = _costController.text.trim().isEmpty
        ? null
        : double.tryParse(_costController.text.trim());

    context.read<TripDetectionCubit>().confirmTrip(
          tripId: widget.trip.id!,
          purpose: _purposeController.text.trim(),
          confirmedMode: _selectedMode!,
          companions: companions,
          cost: cost,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    Navigator.pop(context);
  }

  void _rejectTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Trip'),
        content: const Text('Are you sure you want to reject this detected trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TripDetectionCubit>().rejectTrip(widget.trip.id!);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close confirmation screen
            },
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Confirm Trip Details',
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.appBarBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.appBarText),
        actions: [
          IconButton(
            onPressed: _rejectTrip,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Reject Trip',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTripSummaryCard(),
              const SizedBox(height: 20),
              _buildMapPreview(),
              const SizedBox(height: 20),
              _buildDetailsForm(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detected Trip',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            _buildSummaryRow(
              Icons.calendar_today,
              'Date',
              _formatDate(widget.trip.startTime),
            ),
            _buildSummaryRow(
              Icons.access_time,
              'Time',
              '${_formatTime(widget.trip.startTime)} → ${_formatTime(widget.trip.endTime!)}',
            ),
            _buildSummaryRow(
              Icons.straighten,
              'Distance',
              '${widget.trip.distanceKm.toStringAsFixed(2)} km',
            ),
            _buildSummaryRow(
              Icons.timer,
              'Duration',
              '${widget.trip.durationMinutes} minutes',
            ),
            _buildSummaryRow(
              Icons.speed,
              'Avg Speed',
              '${widget.trip.averageSpeedKmh.toStringAsFixed(1)} km/h',
            ),
            if (widget.trip.detectedMode != null)
              _buildSummaryRow(
                Icons.directions_transit,
                'Detected Mode',
                widget.trip.detectedMode!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
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

  Widget _buildMapPreview() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.trip.origin.coordinates,
              zoom: 13,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('origin'),
                position: widget.trip.origin.coordinates,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
                infoWindow: const InfoWindow(title: 'Start'),
              ),
              if (widget.trip.destination != null)
                Marker(
                  markerId: const MarkerId('destination'),
                  position: widget.trip.destination!.coordinates,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                  infoWindow: const InfoWindow(title: 'End'),
                ),
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: widget.trip.routePoints
                    .map((p) => p.coordinates)
                    .toList(),
                color: AppColors.primary,
                width: 4,
              ),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Purpose
            const Text(
              'Purpose *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonPurposes.map((purpose) {
                return ChoiceChip(
                  label: Text(purpose),
                  selected: _purposeController.text == purpose,
                  onSelected: (selected) {
                    setState(() {
                      _purposeController.text = selected ? purpose : '';
                    });
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _purposeController.text == purpose
                        ? Colors.white
                        : Colors.black,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _purposeController,
              decoration: const InputDecoration(
                hintText: 'Or enter custom purpose',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter trip purpose';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Mode of Transport
            const Text(
              'Mode of Transport *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedMode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _travelModes.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMode = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select mode of transport';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Companions
            const Text(
              'Companions (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _companionsController,
              decoration: const InputDecoration(
                hintText: 'Enter names separated by commas',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 16),

            // Cost
            const Text(
              'Cost (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Enter trip cost',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            const Text(
              'Notes (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add any additional notes',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _rejectTrip,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Reject',
              style: TextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _confirmTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Confirm Trip',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
