# Automatic Trip Detection - Integration Guide

## Quick Start

This guide helps you integrate the automatic trip detection feature into your existing TourMate app.

---

## Step 1: Add Navigation Route

Add the trip detection screen to your app router.

**File: `lib/core/navigation/app_router.dart`**

```dart
import '../user/trip_detection_screen.dart';

// Add route
static const String tripDetection = '/trip-detection';

// In route generation
case tripDetection:
  return MaterialPageRoute(
    builder: (_) => const TripDetectionScreen(),
  );
```

---

## Step 2: Add Menu Item in Home Screen

Add a button/menu item to access the trip detection feature.

**File: `lib/user/home_screen.dart`**

```dart
// In AppBar actions or drawer
IconButton(
  icon: const Icon(Icons.location_on),
  tooltip: 'Auto Trip Detection',
  onPressed: () {
    Navigator.pushNamed(context, AppRouter.tripDetection);
  },
),
```

Or add as a card in the home screen body:

```dart
Card(
  child: ListTile(
    leading: const Icon(Icons.gps_fixed, color: AppColors.primary),
    title: const Text('Automatic Trip Detection'),
    subtitle: const Text('Let the app track your trips automatically'),
    trailing: const Icon(Icons.arrow_forward_ios),
    onTap: () {
      Navigator.pushNamed(context, AppRouter.tripDetection);
    },
  ),
),
```

---

## Step 3: Initialize Detection on App Start (Optional)

If you want detection to start automatically when the app launches:

**File: `lib/app/app.dart` or `lib/main.dart`**

```dart
import 'package:tourmate/cubit/trip_detection_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late TripDetectionCubit _tripDetectionCubit;

  @override
  void initState() {
    super.initState();
    _tripDetectionCubit = TripDetectionCubit();
    _startAutoDetection();
  }

  Future<void> _startAutoDetection() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if user has enabled auto-detection (from preferences)
      final prefs = await SharedPreferences.getInstance();
      final autoDetectEnabled = prefs.getBool('auto_detect_enabled') ?? false;
      
      if (autoDetectEnabled) {
        await _tripDetectionCubit.startDetection(user.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _tripDetectionCubit,
      child: MaterialApp(
        // ... your app config
      ),
    );
  }

  @override
  void dispose() {
    _tripDetectionCubit.close();
    super.dispose();
  }
}
```

---

## Step 4: Add Notification for Detected Trips

Show a notification when a trip is detected.

**File: `lib/user/home_screen.dart` or main app widget**

```dart
import 'package:tourmate/cubit/trip_detection_cubit.dart';

// In your widget
BlocListener<TripDetectionCubit, TripDetectionState>(
  listener: (context, state) {
    if (state is TripDetected) {
      // Show notification
      showSimpleNotification(
        const Text('Trip Detected!'),
        subtitle: Text(
          '${state.trip.distanceKm.toStringAsFixed(1)} km • '
          '${state.trip.durationMinutes} min'
        ),
        background: Colors.green,
        duration: const Duration(seconds: 5),
        trailing: TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripConfirmationScreen(trip: state.trip),
              ),
            );
          },
          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  },
  child: YourWidget(),
)
```

---

## Step 5: Add Settings Toggle

Allow users to enable/disable auto-detection.

**Create: `lib/user/settings_screen.dart`** (if not exists)

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourmate/cubit/trip_detection_cubit.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoDetectEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoDetectEnabled = prefs.getBool('auto_detect_enabled') ?? false;
    });
  }

  Future<void> _toggleAutoDetect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_detect_enabled', value);
    
    setState(() {
      _autoDetectEnabled = value;
    });

    // Start/stop detection
    final cubit = context.read<TripDetectionCubit>();
    if (value) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await cubit.startDetection(userId);
      }
    } else {
      cubit.stopDetection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Automatic Trip Detection'),
            subtitle: const Text('Automatically track your trips in background'),
            value: _autoDetectEnabled,
            onChanged: _toggleAutoDetect,
          ),
        ],
      ),
    );
  }
}
```

---

## Step 6: View Auto-Detected Trips

Add a screen to view all auto-detected trips.

**Create: `lib/user/auto_trips_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tourmate/core/repositories/auto_trip_repository.dart';
import 'package:tourmate/core/models/auto_trip_model.dart';

class AutoTripsScreen extends StatelessWidget {
  final _repository = AutoTripRepository();

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Auto-Detected Trips')),
      body: StreamBuilder<List<AutoTripModel>>(
        stream: _repository.getConfirmedTrips(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No trips yet'));
          }

          final trips = snapshot.data!;
          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_getModeIcon(trip.confirmedMode)),
                  ),
                  title: Text(trip.purpose ?? 'Unknown Purpose'),
                  subtitle: Text(
                    '${trip.distanceKm.toStringAsFixed(1)} km • '
                    '${trip.durationMinutes} min • '
                    '${trip.confirmedMode ?? trip.detectedMode}'
                  ),
                  trailing: Text(
                    '${trip.startTime.day}/${trip.startTime.month}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getModeIcon(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'walking': return Icons.directions_walk;
      case 'cycling': return Icons.directions_bike;
      case 'car': return Icons.directions_car;
      case 'bus': return Icons.directions_bus;
      case 'train': return Icons.train;
      default: return Icons.trip_origin;
    }
  }
}
```

---

## Step 7: Add Dependencies (if missing)

Ensure these packages are in `pubspec.yaml`:

```yaml
dependencies:
  geolocator: ^11.0.0
  permission_handler: ^11.3.0
  google_maps_flutter: ^2.5.3
  shared_preferences: ^2.2.0  # For settings
```

Run:
```bash
flutter pub get
```

---

## Step 8: Test the Feature

### Testing Checklist:

1. **Start Detection**
   - Open trip detection screen
   - Tap "Start Detection"
   - Verify permissions are requested
   - Check that status shows "Detection Active"

2. **Simulate a Trip**
   - Walk/drive for at least 3 minutes
   - Move at least 300 meters
   - Stop for 5 minutes
   - Verify trip is detected

3. **Confirm Trip**
   - Open pending trip
   - Fill in purpose and mode
   - Tap "Confirm Trip"
   - Verify trip is saved

4. **View Trips**
   - Navigate to auto trips screen
   - Verify confirmed trips are displayed

---

## Step 9: Production Considerations

### 1. Background Location Permission (Android 10+)

Users need to grant "Allow all the time" permission:

```dart
// Request background location
if (Platform.isAndroid) {
  final status = await Permission.locationAlways.request();
  if (!status.isGranted) {
    // Show dialog explaining why background location is needed
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Location Required'),
        content: const Text(
          'To automatically detect trips, please allow location access all the time.'
        ),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
```

### 2. Battery Optimization

Inform users about battery usage:

```dart
// Show battery info dialog
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Battery Usage'),
    content: const Text(
      'Automatic trip detection uses GPS in the background. '
      'This may increase battery usage. You can disable it anytime in settings.'
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('OK'),
      ),
    ],
  ),
);
```

### 3. Privacy Notice

Add to your privacy policy:
- Location data is collected for trip detection
- Data is stored securely in Firestore
- Users can disable detection anytime
- Data is only used for transportation planning

---

## Troubleshooting

### Issue: Detection not working in background (Android)

**Solution**: Disable battery optimization for your app

```dart
// Check if battery optimization is disabled
final isIgnoringBatteryOptimizations = 
    await Permission.ignoreBatteryOptimizations.isGranted;

if (!isIgnoringBatteryOptimizations) {
  await Permission.ignoreBatteryOptimizations.request();
}
```

### Issue: Trips not detected on iOS

**Solution**: Ensure `Info.plist` has correct permissions and background modes enabled.

---

## Next Steps

1. ✅ Integrate the feature into your app
2. ✅ Test thoroughly on real devices
3. ✅ Collect user feedback
4. ✅ Adjust detection thresholds based on feedback
5. ✅ Monitor battery usage and optimize
6. ✅ Add analytics to track feature usage

---

## Support

For issues or questions:
- Review `AUTOMATIC_TRIP_DETECTION.md` for detailed documentation
- Check code comments in source files
- Contact the development team

---

**Happy Coding! 🚀**
