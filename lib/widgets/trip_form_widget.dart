import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/colors.dart';
import '../../core/models/trip_model.dart';
import '../../core/models/place_model.dart';
import '../../cubit/trip_cubit.dart';
import '../../cubit/maps_navigation_cubit.dart';

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
  DateTime? _selectedEndTime;
  TripType _selectedTripType = TripType.active;
  List<String> _activities = [];
  List<TravellerInfo> _accompanyingTravellers = [];

  // Autocomplete state
  List<PlaceModel> _originSearchResults = [];
  List<PlaceModel> _destinationSearchResults = [];
  PlaceModel? _selectedOrigin;
  PlaceModel? _selectedDestination;
  bool _isSearching = false;
  Timer? _originSearchDebounce;
  Timer? _destinationSearchDebounce;

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
    _selectedEndTime = trip.endTime;
    _activities = List.from(trip.activities);
    _accompanyingTravellers = List.from(trip.accompanyingTravellers);
    _selectedTripType = trip.tripType;
  }

  @override
  void dispose() {
    _tripNumberController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _modeController.dispose();
    _activityController.dispose();
    _originSearchDebounce?.cancel();
    _destinationSearchDebounce?.cancel();
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
              if (_selectedTripType == TripType.past) ...[
                _buildEndTimeField(),
                const SizedBox(height: 16),
              ],
              _buildModeField(),
              const SizedBox(height: 16),
              _buildTripTypeField(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _originController,
          decoration: InputDecoration(
            labelText: 'Origin',
            hintText: 'Enter origin location',
            prefixIcon: const Icon(Icons.location_on, color: AppColors.iconPrimary),
            suffixIcon: IconButton(
              icon: const Icon(Icons.my_location, color: AppColors.iconPrimary),
              onPressed: _useCurrentLocationAsOrigin,
              tooltip: 'Use current location',
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
          onChanged: _searchOrigin,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter origin location';
            }
            return null;
          },
        ),
        // Search results
        if (_originSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(
              maxHeight: 200, // Limit height to prevent overflow
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(76),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Scrollbar(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _originSearchResults.length > 5 ? 5 : _originSearchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = _originSearchResults[index];
                  return ListTile(
                    title: Text(place.name),
                    subtitle: Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectOrigin(place),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDestinationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
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
          onChanged: _searchDestination,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter destination location';
            }
            return null;
          },
        ),
        // Search results
        if (_destinationSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(
              maxHeight: 200, // Limit height to prevent overflow
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(76),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Scrollbar(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _destinationSearchResults.length > 5 ? 5 : _destinationSearchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final place = _destinationSearchResults[index];
                  return ListTile(
                    title: Text(place.name),
                    subtitle: Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectDestination(place),
                  );
                },
              ),
            ),
          ),
      ],
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

  Widget _buildEndTimeField() {
    return InkWell(
      onTap: _selectEndTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.inputBackground,
        ),
        child: Row(
          children: [
            const Icon(Icons.event_available, color: AppColors.iconPrimary),
            const SizedBox(width: 12),
            Text(
              _selectedEndTime != null
                  ? 'End Time: ${_formatDateTime(_selectedEndTime!)}'
                  : 'Select End Time',
              style: TextStyle(
                fontSize: 16,
                color: _selectedEndTime != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripTypeField() {
    return DropdownButtonFormField<TripType>(
      value: _selectedTripType,
      decoration: InputDecoration(
        labelText: 'Trip Type',
        prefixIcon: const Icon(
          Icons.timeline,
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
      items: TripType.values.map((type) {
        return DropdownMenuItem<TripType>(
          value: type,
          child: Text(
            type.toString().split('.').last[0].toUpperCase() + 
            type.toString().split('.').last.substring(1),
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedTripType = value;
          });
        }
      },
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
                fontSize: 14,
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
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
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
          
          // Navigate to navigation screen if trip type is active and not editing
          if (!widget.isEditing && _selectedTripType == TripType.active) {
            Navigator.of(context).pop(); // Pop the form
            Navigator.of(context).pushNamed(
              '/navigation',
              arguments: {
                'origin': _originController.text.trim(),
                'destination': _destinationController.text.trim(),
              },
            );
          } else {
            Navigator.of(context).pop();
          }
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

  void _selectEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndTime ?? _selectedTime,
      firstDate: _selectedTime,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedEndTime ?? _selectedTime),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedEndTime = DateTime(
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
        endTime: _selectedTripType == TripType.past ? _selectedEndTime : null,
        mode: _modeController.text,
        tripType: _selectedTripType,
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

  // Search for origin places with autocomplete
  Future<void> _searchOrigin(String query) async {
    if (query.length < 3) {
      setState(() {
        _originSearchResults = [];
      });
      return;
    }

    // Cancel previous debounce timer
    _originSearchDebounce?.cancel();

    // Debounce the search to reduce API calls
    _originSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isSearching = true;
        _originSearchResults = [];
      });

      try {
        final results = await context.read<MapsNavigationCubit>().searchPlaces(query);

        if (!mounted) return;

        setState(() {
          _originSearchResults = results;
          _isSearching = false;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _originSearchResults = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error searching for places: $e')),
          );
        }
      }
    });
  }

  // Search for destination places with autocomplete
  Future<void> _searchDestination(String query) async {
    if (query.length < 3) {
      setState(() {
        _destinationSearchResults = [];
      });
      return;
    }

    // Cancel previous debounce timer
    _destinationSearchDebounce?.cancel();

    // Debounce the search to reduce API calls
    _destinationSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isSearching = true;
        _destinationSearchResults = [];
      });

      try {
        final results = await context.read<MapsNavigationCubit>().searchPlaces(query);

        if (!mounted) return;

        setState(() {
          _destinationSearchResults = results;
          _isSearching = false;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
            _destinationSearchResults = [];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error searching for places: $e')),
          );
        }
      }
    });
  }

  // Select origin from search results
  void _selectOrigin(PlaceModel place) {
    setState(() {
      _selectedOrigin = place;
      _originController.text = place.name;
      _originSearchResults = [];
    });
  }

  // Select destination from search results
  void _selectDestination(PlaceModel place) {
    setState(() {
      _selectedDestination = place;
      _destinationController.text = place.name;
      _destinationSearchResults = [];
    });
  }

  // Use current location as origin
  Future<void> _useCurrentLocationAsOrigin() async {
    setState(() {
      _isSearching = true;
    });

    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      // Create a place model for current location
      final latLng = LatLng(position.latitude, position.longitude);

      // Get address for current location using reverse geocoding
      final results = await context.read<MapsNavigationCubit>().searchPlaces(
        '${position.latitude},${position.longitude}',
      );

      String placeName = 'Current Location';
      String placeAddress = 'Your Location';

      // If we got results from reverse geocoding, use the first one
      if (results.isNotEmpty) {
        placeName = results.first.name;
        placeAddress = results.first.address;
      }

      // Create a place model for current location
      final currentPlace = PlaceModel(
        placeId: 'current_location',
        name: placeName,
        address: placeAddress,
        location: latLng,
      );

      // Set as selected origin
      setState(() {
        _selectedOrigin = currentPlace;
        _originController.text = placeName;
        _originSearchResults = [];
        _isSearching = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location set as origin')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting current location: $e')),
      );
    }
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
