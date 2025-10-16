import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../core/colors.dart';
import '../../core/models/trip_model.dart';
import '../../cubit/trip_cubit.dart';
import '../core/services/places_autocomplete_service.dart';

/// Production-ready widget for creating and editing trips
/// Features:
/// - Comprehensive form validation
/// - Enhanced UX with animations and visual feedback
/// - Accessibility support
/// - Error handling and loading states
/// - Responsive design
class TripFormWidget extends StatefulWidget {
  final TripModel? trip;
  final bool isEditing;

  const TripFormWidget({super.key, this.trip, this.isEditing = false});

  @override
  State<TripFormWidget> createState() => _TripFormWidgetState();
}

class _TripFormWidgetState extends State<TripFormWidget> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _tripNumberController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _modeController = TextEditingController();
  final _activityController = TextEditingController();
  
  // Focus nodes for better keyboard navigation
  final _tripNumberFocus = FocusNode();
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();
  final _activityFocus = FocusNode();

  DateTime _selectedTime = DateTime.now();
  DateTime? _selectedEndTime;
  TripType _selectedTripType = TripType.active;
  List<String> _activities = [];
  List<TravellerInfo> _accompanyingTravellers = [];
  bool _isRandomTrip = false; // For trips without destination
  
  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Form validation state
  bool _autoValidate = false;
  bool _isFormDirty = false;

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
  
  // Places autocomplete service
  final PlacesAutocompleteService _placesService = PlacesAutocompleteService();
  
  // Debounce timer for autocomplete
  Timer? _debounceTimer;
  
  // Session token for Places API (to reduce costs)
  String? _sessionToken;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Start animation
    _animationController.forward();
    
    // Initialize Places API service
    _initializePlacesService();
    
    // Initialize form if editing
    if (widget.trip != null) {
      _initializeForm();
    }
    
    // Add listeners to track form changes
    _tripNumberController.addListener(_onFormChanged);
    _originController.addListener(_onFormChanged);
    _destinationController.addListener(_onFormChanged);
    _modeController.addListener(_onFormChanged);
  }
  
  Future<void> _initializePlacesService() async {
    try {
      await _placesService.initialize();
      // Generate a session token for this form session
      _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Places autocomplete may not work properly'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }
  
  void _onFormChanged() {
    if (!_isFormDirty) {
      setState(() {
        _isFormDirty = true;
      });
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
    // Dispose controllers
    _tripNumberController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _modeController.dispose();
    _activityController.dispose();
    
    // Dispose focus nodes
    _tripNumberFocus.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    _activityFocus.dispose();
    
    // Dispose animation controller
    _animationController.dispose();
    
    // Cancel debounce timer
    _debounceTimer?.cancel();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
          actions: [
            if (_isFormDirty)
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reset Form',
                onPressed: _resetForm,
              ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              autovalidateMode: _autoValidate 
                ? AutovalidateMode.onUserInteraction 
                : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  _buildProgressIndicator(),
                  const SizedBox(height: 24),
                  
                  // Basic Information Section
                  _buildSectionHeader('Basic Information', Icons.info_outline),
                  const SizedBox(height: 12),
                  _buildTripNumberField(),
                  const SizedBox(height: 16),
                  _buildOriginField(),
                  const SizedBox(height: 16),
                  _buildRandomTripToggle(),
                  const SizedBox(height: 16),
                  if (!_isRandomTrip) _buildDestinationField(),
                  if (_isRandomTrip) _buildRandomTripInfo(),
                  const SizedBox(height: 24),
                  
                  // Trip Details Section
                  _buildSectionHeader('Trip Details', Icons.event),
                  const SizedBox(height: 12),
                  _buildTimeField(),
                  const SizedBox(height: 16),
                  _buildTripTypeField(),
                  const SizedBox(height: 16),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _selectedTripType == TripType.past
                      ? Column(
                          children: [
                            _buildEndTimeField(),
                            const SizedBox(height: 16),
                          ],
                        )
                      : const SizedBox.shrink(),
                  ),
                  _buildModeField(),
                  const SizedBox(height: 24),
                  
                  // Activities Section
                  _buildSectionHeader('Activities', Icons.local_activity),
                  const SizedBox(height: 12),
                  _buildActivitiesSection(),
                  const SizedBox(height: 24),
                  
                  // Travellers Section
                  _buildSectionHeader('Travellers', Icons.people),
                  const SizedBox(height: 12),
                  _buildTravellersSection(),
                  const SizedBox(height: 32),
                  
                  _buildSubmitButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Future<bool> _onWillPop() async {
    if (!_isFormDirty) return true;
    
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.textOnPrimary),
            ),
          ),
        ],
      ),
    );
    
    return shouldPop ?? false;
  }
  
  void _resetForm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Form?'),
        content: const Text('This will clear all your changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _formKey.currentState?.reset();
              setState(() {
                _tripNumberController.clear();
                _originController.clear();
                _destinationController.clear();
                _modeController.clear();
                _activityController.clear();
                _activities.clear();
                _accompanyingTravellers.clear();
                _selectedTime = DateTime.now();
                _selectedEndTime = null;
                _selectedTripType = TripType.active;
                _isFormDirty = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text(
              'Reset',
              style: TextStyle(color: AppColors.textOnPrimary),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    int completedFields = 0;
    int totalFields = 5; // Trip number, origin, destination, time, mode
    
    if (_tripNumberController.text.isNotEmpty) completedFields++;
    if (_originController.text.isNotEmpty) completedFields++;
    if (_destinationController.text.isNotEmpty) completedFields++;
    if (_modeController.text.isNotEmpty) completedFields++;
    completedFields++; // Time is always set
    
    double progress = completedFields / totalFields;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Form Progress',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? AppColors.success : AppColors.primary,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTripNumberField() {
    return TextFormField(
      controller: _tripNumberController,
      focusNode: _tripNumberFocus,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: 'Trip Number *',
        hintText: 'e.g., TRP001',
        helperText: 'Unique identifier for this trip',
        prefixIcon: const Icon(
          Icons.confirmation_number,
          color: AppColors.iconPrimary,
        ),
        suffixIcon: _tripNumberController.text.isNotEmpty
          ? Icon(Icons.check_circle, color: AppColors.success)
          : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorderFocused, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        filled: true,
        fillColor: AppColors.inputBackground,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Trip number is required';
        }
        if (value.trim().length < 3) {
          return 'Trip number must be at least 3 characters';
        }
        return null;
      },
      onFieldSubmitted: (_) => _originFocus.requestFocus(),
    );
  }

  Widget _buildOriginField() {
    return Autocomplete<PlaceAutocompletePrediction>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty || textEditingValue.text.length < 2) {
          return const Iterable<PlaceAutocompletePrediction>.empty();
        }
        
        // Use debouncing to avoid too many API calls
        _debounceTimer?.cancel();
        final completer = Completer<List<PlaceAutocompletePrediction>>();
        
        _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
          final suggestions = await _placesService.getAutocompleteSuggestions(
            textEditingValue.text,
            sessionToken: _sessionToken,
          );
          completer.complete(suggestions);
        });
        
        return completer.future;
      },
      displayStringForOption: (PlaceAutocompletePrediction option) => option.description,
      onSelected: (PlaceAutocompletePrediction selection) {
        _originController.text = selection.description;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync with our controller
        if (_originController.text.isNotEmpty && controller.text.isEmpty) {
          controller.text = _originController.text;
        }
        
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Origin *',
            hintText: 'Where are you starting from?',
            helperText: 'Your starting location',
            prefixIcon: const Icon(Icons.trip_origin, color: AppColors.iconPrimary),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location, size: 20),
                  onPressed: () => _useCurrentLocationAsOrigin(controller),
                  tooltip: 'Use current location',
                  color: AppColors.primary,
                ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      _originController.clear();
                    },
                  ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorderFocused, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            filled: true,
            fillColor: AppColors.inputBackground,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Origin location is required';
            }
            if (value.trim().length < 2) {
              return 'Please enter a valid location';
            }
            return null;
          },
          onChanged: (value) {
            _originController.text = value;
          },
          onFieldSubmitted: (_) => _destinationFocus.requestFocus(),
        );
      },
    );
  }

  Widget _buildRandomTripToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRandomTrip ? AppColors.primaryLight.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRandomTrip ? AppColors.primary : AppColors.border,
          width: _isRandomTrip ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.explore,
            color: _isRandomTrip ? AppColors.primary : AppColors.iconSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Random Trip / Exploration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isRandomTrip ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Don\'t know where you\'re going? Enable this!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isRandomTrip,
            onChanged: (value) {
              setState(() {
                _isRandomTrip = value;
                if (value) {
                  _destinationController.clear();
                }
              });
            },
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildRandomTripInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.accent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Destination will be set to "Unknown" and can be updated when you end the trip.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationField() {
    return Autocomplete<PlaceAutocompletePrediction>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty || textEditingValue.text.length < 2) {
          return const Iterable<PlaceAutocompletePrediction>.empty();
        }
        
        // Use debouncing to avoid too many API calls
        _debounceTimer?.cancel();
        final completer = Completer<List<PlaceAutocompletePrediction>>();
        
        _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
          final suggestions = await _placesService.getAutocompleteSuggestions(
            textEditingValue.text,
            sessionToken: _sessionToken,
          );
          completer.complete(suggestions);
        });
        
        return completer.future;
      },
      displayStringForOption: (PlaceAutocompletePrediction option) => option.description,
      onSelected: (PlaceAutocompletePrediction selection) {
        _destinationController.text = selection.description;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync with our controller
        if (_destinationController.text.isNotEmpty && controller.text.isEmpty) {
          controller.text = _destinationController.text;
        }
        
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Destination *',
            hintText: 'Where are you going?',
            helperText: 'Your destination location',
            prefixIcon: const Icon(Icons.location_on, color: AppColors.error),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location, size: 20),
                  onPressed: () => _useCurrentLocationAsDestination(controller),
                  tooltip: 'Use current location',
                  color: AppColors.primary,
                ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      _destinationController.clear();
                    },
                  ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorderFocused, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            filled: true,
            fillColor: AppColors.inputBackground,
          ),
          validator: (value) {
            // Skip validation if random trip
            if (_isRandomTrip) return null;
            
            if (value == null || value.trim().isEmpty) {
              return 'Destination location is required';
            }
            if (value.trim().length < 2) {
              return 'Please enter a valid location';
            }
            if (value.trim().toLowerCase() == _originController.text.trim().toLowerCase()) {
              return 'Destination cannot be same as origin';
            }
            return null;
          },
          onChanged: (value) {
            _destinationController.text = value;
          },
        );
      },
    );
  }

  Widget _buildTimeField() {
    final bool isToday = _selectedTime.year == DateTime.now().year &&
        _selectedTime.month == DateTime.now().month &&
        _selectedTime.day == DateTime.now().day;
    
    return InkWell(
      onTap: _selectTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.inputBorder, width: 1),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.inputBackground,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.access_time, color: AppColors.iconPrimary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedTripType == TripType.past ? 'Start Time *' : 'Trip Time *',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(_selectedTime),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isToday)
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today, color: AppColors.iconSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEndTimeField() {
    return InkWell(
      onTap: _selectEndTime,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedEndTime == null ? AppColors.warning : AppColors.inputBorder,
            width: _selectedEndTime == null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.inputBackground,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (_selectedEndTime != null ? AppColors.success : AppColors.warning).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _selectedEndTime != null ? Icons.event_available : Icons.event_busy,
                color: _selectedEndTime != null ? AppColors.success : AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'End Time *',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedEndTime != null
                        ? _formatDateTime(_selectedEndTime!)
                        : 'Tap to select end time',
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedEndTime != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: _selectedEndTime != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (_selectedEndTime != null)
                    Text(
                      'Duration: ${_calculateDuration()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today, color: AppColors.iconSecondary, size: 20),
          ],
        ),
      ),
    );
  }
  
  String _calculateDuration() {
    if (_selectedEndTime == null) return '';
    
    final duration = _selectedEndTime!.difference(_selectedTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0 && minutes > 0) {
      return '$hours hrs $minutes mins';
    } else if (hours > 0) {
      return '$hours hrs';
    } else {
      return '$minutes mins';
    }
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
              Expanded(
                child: TextFormField(
                  controller: _activityController,
                  focusNode: _activityFocus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g., Sightseeing, Shopping',
                    labelText: 'Add Activity',
                    prefixIcon: const Icon(Icons.add_task, color: AppColors.iconPrimary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.inputBorderFocused, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onFieldSubmitted: (_) => _addActivity(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _addActivity,
                  icon: const Icon(Icons.add, color: AppColors.textOnPrimary),
                  tooltip: 'Add Activity',
                ),
              ),
            ],
          ),
          if (_activities.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '${_activities.length} ${_activities.length == 1 ? 'Activity' : 'Activities'} Added',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _activities.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    label: Text(
                      activity,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onDeleted: () => _removeActivity(activity),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                    deleteIconColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No activities added yet',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTravellersSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accompanying Travellers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_accompanyingTravellers.isNotEmpty)
                    Text(
                      '${_accompanyingTravellers.length} ${_accompanyingTravellers.length == 1 ? 'person' : 'people'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addTraveller,
                icon: const Icon(
                  Icons.person_add,
                  color: AppColors.textOnPrimary,
                  size: 18,
                ),
                label: const Text(
                  'Add',
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          if (_accompanyingTravellers.isEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: AppColors.iconLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No travellers added',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ..._accompanyingTravellers.asMap().entries.map((entry) {
              return _buildTravellerCard(entry.key, entry.value);
            }),
          ],
        ],
      ),
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
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.textOnPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isEditing
                          ? 'Trip updated successfully!'
                          : 'Trip created successfully!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.snackbarSuccess,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 3),
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
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.textOnPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.message,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.snackbarError,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is TripLoading;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: !isLoading ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonPrimary,
                disabledBackgroundColor: AppColors.buttonDisabled,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isLoading ? 0 : 2,
              ),
              child: isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.textOnPrimary,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.isEditing ? 'Updating...' : 'Creating...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isEditing ? Icons.update : Icons.add_circle,
                          color: AppColors.textOnPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isEditing ? 'Update Trip' : 'Create Trip',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ],
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

  /// Get current location and use it as origin
  Future<void> _useCurrentLocationAsOrigin(TextEditingController controller) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Getting your location...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates using reverse geocoding
      final suggestions = await _placesService.getAutocompleteSuggestions(
        '${position.latitude},${position.longitude}',
        sessionToken: _sessionToken,
      );

      String locationText = 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      
      if (suggestions.isNotEmpty) {
        locationText = suggestions.first.description;
      }

      // Update the text field
      setState(() {
        controller.text = locationText;
        _originController.text = locationText;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Location set successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error getting location: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Get current location and use it as destination
  Future<void> _useCurrentLocationAsDestination(TextEditingController controller) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Getting your location...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates using reverse geocoding
      final suggestions = await _placesService.getAutocompleteSuggestions(
        '${position.latitude},${position.longitude}',
        sessionToken: _sessionToken,
      );

      String locationText = 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      
      if (suggestions.isNotEmpty) {
        locationText = suggestions.first.description;
      }

      // Update the text field
      setState(() {
        controller.text = locationText;
        _destinationController.text = locationText;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Location set successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error getting location: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _submitForm() {
    // Enable auto-validation for future interactions
    setState(() {
      _autoValidate = true;
    });
    
    // Validate form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: AppColors.textOnPrimary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Please fix the errors in the form',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.snackbarWarning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }
    
    // Additional validation for past trips
    if (_selectedTripType == TripType.past && _selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.textOnPrimary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Please select an end time for past trips',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.snackbarError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }
    
    // Validate end time is after start time
    if (_selectedEndTime != null && _selectedEndTime!.isBefore(_selectedTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.textOnPrimary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'End time must be after start time',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.snackbarError,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }
    
    // Create trip model
    final trip = TripModel(
      tripNumber: _tripNumberController.text.trim(),
      origin: _originController.text.trim(),
      destination: _isRandomTrip ? 'Unknown' : _destinationController.text.trim(),
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

    // Submit to cubit
    if (widget.isEditing && widget.trip != null) {
      context.read<TripCubit>().updateTrip(widget.trip!.id!, trip);
    } else {
      context.read<TripCubit>().createTrip(trip);
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
