# Automatic Trip Detection Feature

## Overview

The Automatic Trip Detection feature enables the TourMate app to automatically identify and track user trips without manual input. This feature addresses the limitations of traditional manual household surveys by providing:

- **Automated tracking**: No need for users to manually start/stop trip recording
- **Accurate data**: GPS-based tracking with timestamps and route information
- **Comprehensive coverage**: Continuous monitoring captures all trips
- **Reduced user burden**: Minimal interaction required from users

## Problem Statement

Transportation planning at NATPAC relies on manual household surveys with several limitations:

- ❌ Time-consuming and labour-intensive
- ❌ Limited population coverage
- ❌ Inaccurate data due to forgotten trip details
- ❌ High operational costs

## Solution: Automatic Trip Detection

The app uses smartphone GPS sensors and intelligent algorithms to:

1. ✅ Automatically detect trip start based on movement patterns
2. ✅ Track the entire route with GPS coordinates
3. ✅ Detect trip end when user stops moving
4. ✅ Calculate distance, duration, and average speed
5. ✅ Infer mode of transport based on speed patterns
6. ✅ Prompt user to confirm details and add purpose/companions/cost

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                        │
│  ┌──────────────────┐    ┌─────────────────────────┐   │
│  │ Trip Detection   │    │ Trip Confirmation       │   │
│  │ Screen           │───▶│ Screen                  │   │
│  └──────────────────┘    └─────────────────────────┘   │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│              State Management (Cubit)                    │
│  ┌──────────────────────────────────────────────────┐   │
│  │ TripDetectionCubit                               │   │
│  │ - Manages detection state                        │   │
│  │ - Handles trip events                            │   │
│  │ - Coordinates UI updates                         │   │
│  └──────────────────────────────────────────────────┘   │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│                Business Logic Layer                      │
│  ┌─────────────────────┐    ┌──────────────────────┐   │
│  │ TripDetectionService│    │ AutoTripRepository   │   │
│  │ - Detection logic   │    │ - Firestore ops      │   │
│  │ - GPS tracking      │    │ - CRUD operations    │   │
│  │ - Mode inference    │    │ - Statistics         │   │
│  └─────────────────────┘    └──────────────────────┘   │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│                   Data Layer                             │
│  ┌─────────────────────┐    ┌──────────────────────┐   │
│  │ AutoTripModel       │    │ LocationPoint        │   │
│  │ - Trip data         │    │ - GPS coordinates    │   │
│  │ - Metadata          │    │ - Timestamp & speed  │   │
│  └─────────────────────┘    └──────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

---

## Detection Algorithm

### 1. Trip Start Detection

**Conditions:**
- User speed > 2.0 m/s (7.2 km/h)
- Sustained movement for **3 minutes**
- Distance moved > 50 meters

**Logic:**
```
IF speed > 2.0 m/s:
    IF movement_duration >= 180 seconds:
        START TRIP
        Record origin coordinates
        Record start timestamp
```

### 2. Trip Tracking

**During active trip:**
- GPS updates every **30 seconds** or **10 meters** of movement
- Calculate distance using **Haversine formula**
- Track speed at each point
- Store route points for visualization
- Update statistics (distance, duration, avg/max speed)

**Haversine Formula:**
```dart
distance = 2 * R * arcsin(sqrt(
    sin²((lat2 - lat1) / 2) + 
    cos(lat1) * cos(lat2) * sin²((lon2 - lon1) / 2)
))
```
Where R = 6,371 km (Earth's radius)

### 3. Trip End Detection

**Conditions:**
- User speed < 1.0 m/s (3.6 km/h)
- Stationary for **5 minutes**
- Minimum trip distance: **300 meters**

**Logic:**
```
IF speed < 1.0 m/s:
    IF stationary_duration >= 300 seconds:
        IF total_distance >= 300 meters:
            END TRIP
            Record destination coordinates
            Record end timestamp
            Save to database
```

### 4. Mode Detection

The app infers travel mode based on speed patterns:

| Mode | Speed Range (km/h) | Detection Logic |
|------|-------------------|-----------------|
| **Walking** | 0 - 7 | Max speed ≤ 7 km/h |
| **Cycling** | 7 - 25 | Max speed ≤ 25 km/h, avg < 12 km/h |
| **E-Bike** | 12 - 25 | Max speed ≤ 25 km/h, avg ≥ 12 km/h |
| **Motorcycle** | 25 - 60 | Max speed ≤ 60 km/h |
| **Car** | 40 - 120 | Max speed ≤ 120 km/h, low speed variance |
| **Bus** | 30 - 80 | Max speed ≤ 120 km/h, high speed variance |
| **Train** | > 80 | Max speed > 120 km/h |

**Speed Variance** helps distinguish between car and bus:
- **Bus**: Frequent stops → high variance
- **Car**: Smoother travel → low variance

---

## Data Model

### AutoTripModel

```dart
class AutoTripModel {
  String? id;                    // Firestore document ID
  String userId;                 // User who made the trip
  
  // Detection data
  LocationPoint origin;          // Start location
  LocationPoint? destination;    // End location
  DateTime startTime;            // Trip start timestamp
  DateTime? endTime;             // Trip end timestamp
  double distanceCovered;        // Total distance (meters)
  double averageSpeed;           // Average speed (m/s)
  double maxSpeed;               // Maximum speed (m/s)
  List<LocationPoint> routePoints; // GPS trace
  
  // Status
  AutoTripStatus status;         // detecting/detected/confirmed/rejected
  
  // User-provided data
  String? purpose;               // Work, Shopping, etc.
  String? detectedMode;          // Auto-detected mode
  String? confirmedMode;         // User-confirmed mode
  List<String>? companions;      // Names of companions
  double? cost;                  // Trip cost
  String? notes;                 // Additional notes
  
  // Metadata
  DateTime createdAt;
  DateTime updatedAt;
}
```

### LocationPoint

```dart
class LocationPoint {
  LatLng coordinates;   // Latitude & Longitude
  DateTime timestamp;   // When point was recorded
  double speed;         // Speed at this point (m/s)
  double accuracy;      // GPS accuracy (meters)
}
```

---

## User Workflow

### Step 1: Enable Detection

```
User opens "Trip Detection" screen
  ↓
Taps "Start Detection"
  ↓
App requests location permissions
  ↓
Background GPS tracking begins
```

### Step 2: Automatic Trip Detection

```
User starts moving (e.g., leaves home)
  ↓
App detects sustained movement (3 min)
  ↓
Trip starts automatically
  ↓
App tracks GPS, calculates distance/speed
  ↓
User arrives at destination
  ↓
App detects user stopped (5 min)
  ↓
Trip ends automatically
  ↓
Trip saved to database
```

### Step 3: Trip Confirmation

```
User receives notification: "Trip detected!"
  ↓
Opens confirmation screen
  ↓
Reviews detected trip details:
  - Distance: 8.2 km
  - Duration: 35 min
  - Detected mode: Bus
  - Route map
  ↓
Confirms/edits mode of transport
  ↓
Enters purpose (Work, Shopping, etc.)
  ↓
Adds companions (optional)
  ↓
Enters cost (optional)
  ↓
Adds notes (optional)
  ↓
Taps "Confirm Trip"
  ↓
Trip marked as confirmed in database
```

---

## Implementation Details

### File Structure

```
lib/
├── core/
│   ├── models/
│   │   └── auto_trip_model.dart          # Data models
│   ├── services/
│   │   └── trip_detection_service.dart   # Detection logic
│   └── repositories/
│       └── auto_trip_repository.dart     # Firestore operations
├── cubit/
│   └── trip_detection_cubit.dart         # State management
└── user/
    ├── trip_detection_screen.dart        # Main detection UI
    └── trip_confirmation_screen.dart     # Confirmation UI
```

### Key Classes

#### 1. TripDetectionService

**Responsibilities:**
- Monitor GPS location updates
- Apply detection algorithms
- Emit trip events (start/end/update)
- Calculate trip statistics

**Key Methods:**
```dart
Future<bool> startDetection(String userId)
void stopDetection()
String getCurrentTripSummary()
```

#### 2. AutoTripRepository

**Responsibilities:**
- Save/update trips in Firestore
- Query trips by user/status/date
- Calculate trip statistics
- Handle trip confirmation/rejection

**Key Methods:**
```dart
Future<String?> saveAutoTrip(AutoTripModel trip)
Future<bool> confirmTrip({...})
Stream<List<AutoTripModel>> getPendingTrips(String userId)
Future<Map<String, dynamic>> getTripStatistics(String userId)
```

#### 3. TripDetectionCubit

**Responsibilities:**
- Manage detection state
- Handle trip events from service
- Coordinate UI updates
- Process user actions

**States:**
```dart
TripDetectionInitial    // Not started
TripDetectionIdle       // Stopped
TripDetectionActive     // Detecting (with optional current trip)
TripDetected            // Trip ended, awaiting confirmation
TripConfirmed           // Trip confirmed by user
TripDetectionError      // Error occurred
TripDetectionLoading    // Processing
```

---

## Configuration

### Detection Thresholds

Located in `TripDetectionConfig` class:

```dart
// Speed thresholds (m/s)
static const double idleSpeedThreshold = 1.0;
static const double movementSpeedThreshold = 2.0;

// Distance thresholds (meters)
static const double minimumTripDistance = 300.0;
static const double significantMovementDistance = 50.0;

// Time thresholds (seconds)
static const int movementConfirmationDuration = 180;  // 3 min
static const int stationaryConfirmationDuration = 300; // 5 min
static const int locationUpdateInterval = 30;         // 30 sec

// Mode detection speed ranges (km/h)
static const double walkingMaxSpeed = 7.0;
static const double cyclingMaxSpeed = 25.0;
static const double bikeMaxSpeed = 60.0;
static const double carMaxSpeed = 120.0;
```

**Customization:**
These values can be adjusted based on field testing and user feedback.

---

## Permissions

### Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS (Info.plist)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to automatically detect your trips</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location access to detect trips automatically</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

---

## Database Schema

### Firestore Collection: `auto_trips`

```javascript
{
  "userId": "user123",
  "origin": {
    "latitude": 11.2588,
    "longitude": 75.7804,
    "timestamp": Timestamp,
    "speed": 0.5,
    "accuracy": 10.0
  },
  "destination": {
    "latitude": 11.2488,
    "longitude": 75.7904,
    "timestamp": Timestamp,
    "speed": 0.3,
    "accuracy": 12.0
  },
  "startTime": Timestamp,
  "endTime": Timestamp,
  "distanceCovered": 8200.0,  // meters
  "averageSpeed": 6.5,        // m/s
  "maxSpeed": 15.0,           // m/s
  "routePoints": [
    {
      "latitude": 11.2588,
      "longitude": 75.7804,
      "timestamp": Timestamp,
      "speed": 0.5,
      "accuracy": 10.0
    },
    // ... more points
  ],
  "status": "confirmed",
  "purpose": "Work",
  "detectedMode": "Bus",
  "confirmedMode": "Bus",
  "companions": ["John", "Jane"],
  "cost": 50.0,
  "notes": "Morning commute",
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Indexes Required

```javascript
// For querying user trips
userId + startTime (descending)

// For pending trips
userId + status + startTime (descending)
```

---

## Usage Example

### Starting Detection

```dart
// In your widget
final cubit = TripDetectionCubit();
final userId = FirebaseAuth.instance.currentUser!.uid;

// Start detection
await cubit.startDetection(userId);

// Listen to state changes
cubit.stream.listen((state) {
  if (state is TripDetectionActive) {
    print('Detecting... ${state.currentTrip?.distanceKm ?? 0} km');
  } else if (state is TripDetected) {
    print('Trip detected! Distance: ${state.trip.distanceKm} km');
    // Show confirmation screen
  }
});
```

### Confirming a Trip

```dart
await cubit.confirmTrip(
  tripId: trip.id!,
  purpose: 'Work',
  confirmedMode: 'Bus',
  companions: ['John Doe'],
  cost: 50.0,
  notes: 'Morning commute',
);
```

### Getting Statistics

```dart
final stats = await cubit.getTripStatistics(userId);
print('Total trips: ${stats['totalTrips']}');
print('Total distance: ${stats['totalDistance']} km');
print('Mode distribution: ${stats['modeDistribution']}');
```

---

## Testing

### Manual Testing Checklist

- [ ] **Permission handling**: App requests and handles location permissions
- [ ] **Trip start**: Trip starts after 3 minutes of movement
- [ ] **Trip tracking**: GPS points are recorded during trip
- [ ] **Trip end**: Trip ends after 5 minutes of being stationary
- [ ] **Minimum distance**: Trips < 300m are discarded
- [ ] **Mode detection**: Correct mode inferred based on speed
- [ ] **Confirmation UI**: All fields work correctly
- [ ] **Data persistence**: Trips saved to Firestore
- [ ] **Statistics**: Correct calculations
- [ ] **Background tracking**: Works when app is in background

### Test Scenarios

1. **Short walk** (< 300m): Should be discarded
2. **Walking trip** (1 km): Should detect as "Walking"
3. **Cycling trip** (5 km): Should detect as "Cycling"
4. **Car trip** (20 km): Should detect as "Car"
5. **Bus trip** (15 km with stops): Should detect as "Bus"

---

## Performance Considerations

### Battery Optimization

- GPS updates every 30 seconds (not continuous)
- Distance filter: 10 meters (reduces unnecessary updates)
- High accuracy only when needed
- Stop tracking when detection is disabled

### Data Usage

- Route points stored locally during trip
- Batch upload to Firestore at trip end
- Minimal data structure (only essential fields)

### Storage

- Average trip: ~5-10 KB
- 100 trips: ~500 KB - 1 MB
- Route points can be compressed or sampled for long trips

---

## Future Enhancements

1. **Machine Learning**: Improve mode detection with ML models
2. **Geofencing**: Detect common locations (home, work) automatically
3. **Trip patterns**: Identify recurring trips
4. **Offline support**: Queue trips when offline, sync later
5. **Battery optimization**: Adaptive GPS sampling based on movement
6. **Multi-modal trips**: Detect mode changes within a single trip
7. **Social features**: Share trips with family/friends
8. **Analytics dashboard**: Visualize travel patterns over time

---

## Troubleshooting

### Issue: Detection not starting

**Possible causes:**
- Location permission denied
- GPS disabled
- Background location not granted (Android 10+)

**Solution:**
- Check permission status
- Request background location permission
- Guide user to enable GPS

### Issue: Trips not detected

**Possible causes:**
- Movement too short (< 3 min)
- Speed too low (< 2 m/s)
- GPS accuracy poor

**Solution:**
- Adjust thresholds in `TripDetectionConfig`
- Improve GPS signal (move outdoors)
- Check device GPS settings

### Issue: Wrong mode detected

**Possible causes:**
- Speed patterns don't match typical mode
- GPS inaccuracy causing speed spikes

**Solution:**
- User can manually correct mode in confirmation screen
- Adjust speed ranges in config
- Implement ML-based mode detection

### Issue: Battery drain

**Possible causes:**
- Continuous GPS tracking
- Too frequent location updates

**Solution:**
- Increase `locationUpdateInterval`
- Use lower accuracy when possible
- Implement adaptive sampling

---

## References

- **Haversine Formula**: [Wikipedia](https://en.wikipedia.org/wiki/Haversine_formula)
- **GPS Accuracy**: [Android Location Guide](https://developer.android.com/training/location)
- **Background Location**: [Android Background Location Limits](https://developer.android.com/about/versions/oreo/background-location-limits)
- **Travel Behavior Research**: NATPAC transportation planning methodologies

---

## Support

For questions or issues:
1. Check this documentation
2. Review code comments in source files
3. Contact the development team
4. Create an issue in the repository

---

**Last Updated**: 2025-10-08  
**Version**: 1.0.0  
**Author**: TourMate Development Team
