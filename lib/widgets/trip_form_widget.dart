import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/colors.dart';
import '../../core/models/trip_model.dart';
import '../../cubit/trip_cubit.dart';

/// Widget for creating and editing trips
/// This form captures all required trip information including
/// trip number, origin, time, mode, destination, activities, and accompanying travellers
class TripFormWidget extends StatefulWidget {
  final TripModel? trip;
  final bool isEditing;

  const TripFormWidget({super.key, this.trip, this.isEditing = false});

  @override
  State<TripFormWidget> createState() => _TripFormWidgetState();
}

class _TripFormWidgetState extends State<TripFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _tripNumberController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _modeController = TextEditingController();
  final _activityController = TextEditingController();

  DateTime _selectedTime = DateTime.now();
  List<String> _activities = [];
  List<TravellerInfo> _accompanyingTravellers = [];

  final List<String> _transportModes = [
    'Car',
    'Bus',
    'Train',
    'Flight',
    'Motorcycle',
    'Bicycle',
    'Walking',
    'Taxi',
    'Ride Share',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.trip != null) {
      _initializeForm();
    }
  }

  void _initializeForm() {
    final trip = widget.trip!;
    _tripNumberController.text = trip.tripNumber;
    _originController.text = trip.origin;
    _destinationController.text = trip.destination;
    _modeController.text = trip.mode;
    _selectedTime = trip.time;
    _activities = List.from(trip.activities);
    _accompanyingTravellers = List.from(trip.accompanyingTravellers);
  }

  @override
  void dispose() {
    _tripNumberController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _modeController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Trip' : 'Create New Trip',
          style: const TextStyle(
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTripNumberField(),
              const SizedBox(height: 16),
              _buildOriginField(),
              const SizedBox(height: 16),
              _buildDestinationField(),
              const SizedBox(height: 16),
              _buildTimeField(),
              const SizedBox(height: 16),
              _buildModeField(),
              const SizedBox(height: 16),
              _buildActivitiesSection(),
              const SizedBox(height: 16),
              _buildTravellersSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripNumberField() {
    return TextFormField(
      controller: _tripNumberController,
      decoration: InputDecoration(
        labelText: 'Trip Number',
        hintText: 'Enter trip number',
        prefixIcon: const Icon(
          Icons.confirmation_number,
          color: AppColors.iconPrimary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorderFocused),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a trip number';
        }
        return null;
      },
    );
  }

  Widget _buildOriginField() {
    return TextFormField(
      controller: _originController,
      decoration: InputDecoration(
        labelText: 'Origin',
        hintText: 'Enter origin location',
        prefixIcon: const Icon(Icons.location_on, color: AppColors.iconPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorderFocused),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter origin location';
        }
        return null;
      },
    );
  }

  Widget _buildDestinationField() {
    return TextFormField(
      controller: _destinationController,
      decoration: InputDecoration(
        labelText: 'Destination',
        hintText: 'Enter destination location',
        prefixIcon: const Icon(Icons.place, color: AppColors.iconPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorderFocused),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter destination location';
        }
        return null;
      },
    );
  }

  Widget _buildTimeField() {
    return InkWell(
      onTap: _selectTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.inputBackground,
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: AppColors.iconPrimary),
            const SizedBox(width: 12),
            Text(
              'Time: ${_formatDateTime(_selectedTime)}',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeField() {
    return DropdownButtonFormField<String>(
      value: _modeController.text.isEmpty ? null : _modeController.text,
      decoration: InputDecoration(
        labelText: 'Mode of Transport',
        prefixIcon: const Icon(
          Icons.directions_car,
          color: AppColors.iconPrimary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorderFocused),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
      ),
      items: _transportModes.map((mode) {
        return DropdownMenuItem(value: mode, child: Text(mode));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _modeController.text = value ?? '';
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a mode of transport';
        }
        return null;
      },
    );
  }

  Widget _buildActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Travel Activities',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _activityController,
                decoration: InputDecoration(
                  hintText: 'Add activity',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addActivity,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.add, color: AppColors.textOnPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activities.map((activity) {
            return Chip(
              label: Text(activity),
              onDeleted: () => _removeActivity(activity),
              backgroundColor: AppColors.primaryLight,
              deleteIconColor: AppColors.textOnPrimary,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTravellersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Accompanying Travellers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addTraveller,
              icon: const Icon(
                Icons.person_add,
                color: AppColors.textOnPrimary,
              ),
              label: const Text(
                'Add Traveller',
                style: TextStyle(color: AppColors.textOnPrimary),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._accompanyingTravellers.asMap().entries.map((entry) {
          return _buildTravellerCard(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildTravellerCard(int index, TravellerInfo traveller) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Traveller ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeTraveller(index),
                  icon: const Icon(Icons.delete, color: AppColors.error),
                ),
              ],
            ),
            TextFormField(
              initialValue: traveller.name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.inputBackground,
              ),
              onChanged: (value) {
                _accompanyingTravellers[index] = traveller.copyWith(
                  name: value,
                );
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: traveller.age.toString(),
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.inputBackground,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final age = int.tryParse(value) ?? 0;
                _accompanyingTravellers[index] = traveller.copyWith(age: age);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: traveller.phoneNumber ?? '',
              decoration: const InputDecoration(
                labelText: 'Phone Number (Optional)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.inputBackground,
              ),
              onChanged: (value) {
                _accompanyingTravellers[index] = traveller.copyWith(
                  phoneNumber: value.isEmpty ? null : value,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return BlocConsumer<TripCubit, TripState>(
      listener: (context, state) {
        if (state is TripCreated || state is TripUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEditing
                    ? 'Trip updated successfully!'
                    : 'Trip created successfully!',
              ),
              backgroundColor: AppColors.snackbarSuccess,
            ),
          );
          Navigator.of(context).pop();
        } else if (state is TripError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.snackbarError,
            ),
          );
        }
      },
      builder: (context, state) {
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: state is TripLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state is TripLoading
                ? const CircularProgressIndicator(
                    color: AppColors.textOnPrimary,
                  )
                : Text(
                    widget.isEditing ? 'Update Trip' : 'Create Trip',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _selectTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedTime),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _addActivity() {
    final activity = _activityController.text.trim();
    if (activity.isNotEmpty && !_activities.contains(activity)) {
      setState(() {
        _activities.add(activity);
        _activityController.clear();
      });
    }
  }

  void _removeActivity(String activity) {
    setState(() {
      _activities.remove(activity);
    });
  }

  void _addTraveller() {
    setState(() {
      _accompanyingTravellers.add(TravellerInfo(name: '', age: 0));
    });
  }

  void _removeTraveller(int index) {
    setState(() {
      _accompanyingTravellers.removeAt(index);
    });
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final trip = TripModel(
        tripNumber: _tripNumberController.text.trim(),
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
        time: _selectedTime,
        mode: _modeController.text,
        activities: _activities,
        accompanyingTravellers: _accompanyingTravellers,
        userId: '', // Will be set by the repository
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.isEditing && widget.trip != null) {
        context.read<TripCubit>().updateTrip(widget.trip!.id!, trip);
      } else {
        context.read<TripCubit>().createTrip(trip);
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Extension to add copyWith method to TravellerInfo
extension TravellerInfoExtension on TravellerInfo {
  TravellerInfo copyWith({
    String? name,
    String? phoneNumber,
    String? email,
    String? relationship,
    int? age,
  }) {
    return TravellerInfo(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      age: age ?? this.age,
    );
  }
}
