# Automatic Trip Detection - Quick Reference

## 🚀 Quick Start

```dart
// 1. Start detection
final cubit = TripDetectionCubit();
await cubit.startDetection(userId);

// 2. Listen to events
cubit.stream.listen((state) {
  if (state is TripDetected) {
    print('Trip: ${state.trip.distanceKm} km');
  }
});

// 3. Confirm trip
await cubit.confirmTrip(
  tripId: trip.id!,
  purpose: 'Work',
  confirmedMode: 'Bus',
);
```

---

## 📁 File Structure

```
lib/
├── core/
│   ├── models/
│   │   └── auto_trip_model.dart          ✅ Created
│   ├── services/
│   │   └── trip_detection_service.dart   ✅ Created
│   └── repositories/
│       └── auto_trip_repository.dart     ✅ Created
├── cubit/
│   └── trip_detection_cubit.dart         ✅ Created
└── user/
    ├── trip_detection_screen.dart        ✅ Created
    └── trip_confirmation_screen.dart     ✅ Created
```

---

## ⚙️ Configuration

### Detection Thresholds

```dart
// lib/core/services/trip_detection_service.dart
class TripDetectionConfig {
  static const double idleSpeedThreshold = 1.0;          // m/s
  static const double movementSpeedThreshold = 2.0;      // m/s
  static const double minimumTripDistance = 300.0;       // meters
  static const int movementConfirmationDuration = 180;   // 3 min
  static const int stationaryConfirmationDuration = 300; // 5 min
}
```

---

## 🎯 Key Algorithms

### Trip Start
```
IF speed > 2.0 m/s for 3 minutes
  → START TRIP
```

### Trip End
```
IF speed < 1.0 m/s for 5 minutes AND distance > 300m
  → END TRIP
```

### Mode Detection
```
Walking:    0-7 km/h
Cycling:    7-25 km/h
Car:        40-120 km/h
Bus:        30-80 km/h (high variance)
```

---

## 🗄️ Database

### Collection: `auto_trips`

```javascript
{
  userId: "user123",
  origin: { lat, lng, timestamp, speed, accuracy },
  destination: { lat, lng, timestamp, speed, accuracy },
  startTime: Timestamp,
  endTime: Timestamp,
  distanceCovered: 8200.0,  // meters
  averageSpeed: 6.5,        // m/s
  maxSpeed: 15.0,           // m/s
  routePoints: [...],
  status: "confirmed",      // detecting/detected/confirmed/rejected
  purpose: "Work",
  detectedMode: "Bus",
  confirmedMode: "Bus",
  companions: ["John"],
  cost: 50.0,
  notes: "Morning commute"
}
```

---

## 📱 UI Screens

### 1. Trip Detection Screen
- Start/Stop detection button
- Current trip display (live)
- Pending trips list
- How it works info

### 2. Trip Confirmation Screen
- Trip summary (distance, duration, speed)
- Map with route
- Purpose selection (chips + custom)
- Mode dropdown
- Companions input
- Cost input
- Notes textarea
- Confirm/Reject buttons

---

## 🔐 Permissions

### Android
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

### iOS
```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location to detect trips</string>
```

---

## 🧪 Testing Commands

```bash
# Run the app
flutter run -d <device>

# Test on Android
flutter run -d android

# Test on iOS
flutter run -d ios

# Check for issues
flutter analyze

# Build release
flutter build apk --release
```

---

## 📊 Statistics

```dart
final stats = await repository.getTripStatistics(userId);

// Returns:
{
  'totalTrips': 50,
  'totalDistance': 250.5,      // km
  'totalDuration': 1200,       // minutes
  'averageDistance': 5.01,     // km
  'averageDuration': 24,       // minutes
  'modeDistribution': {
    'Car': 20,
    'Bus': 15,
    'Walking': 10,
    'Cycling': 5
  }
}
```

---

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Detection not starting | Check location permissions |
| Trips not detected | Ensure movement > 3 min, distance > 300m |
| Wrong mode detected | User can correct in confirmation screen |
| Battery drain | Increase update interval (30s → 60s) |
| Background not working | Disable battery optimization |

---

## 🔄 State Flow

```
TripDetectionInitial
  ↓ startDetection()
TripDetectionActive (currentTrip: null)
  ↓ movement detected
TripDetectionActive (currentTrip: tracking...)
  ↓ user stops
TripDetected (trip: complete)
  ↓ confirmTrip()
TripConfirmed
  ↓
TripDetectionActive (ready for next trip)
```

---

## 📚 Documentation

- **Full Documentation**: `AUTOMATIC_TRIP_DETECTION.md`
- **Integration Guide**: `INTEGRATION_GUIDE.md`
- **This File**: Quick reference for developers

---

## 🎨 UI Components

### Detection Card
```dart
Card(
  child: Column(
    children: [
      Icon(isActive ? Icons.location_on : Icons.location_off),
      Text(isActive ? 'Detection Active' : 'Detection Inactive'),
      ElevatedButton(
        onPressed: toggleDetection,
        child: Text(isActive ? 'Stop' : 'Start'),
      ),
    ],
  ),
)
```

### Trip Summary
```dart
_buildTripInfoRow(Icons.straighten, 'Distance', '${trip.distanceKm} km');
_buildTripInfoRow(Icons.timer, 'Duration', '${trip.durationMinutes} min');
_buildTripInfoRow(Icons.speed, 'Avg Speed', '${trip.averageSpeedKmh} km/h');
```

---

## 🔧 Customization

### Adjust Detection Sensitivity

**More sensitive** (detect shorter trips):
```dart
static const double movementSpeedThreshold = 1.5;  // Lower
static const int movementConfirmationDuration = 120; // 2 min
static const double minimumTripDistance = 200.0;   // Lower
```

**Less sensitive** (avoid false detections):
```dart
static const double movementSpeedThreshold = 2.5;  // Higher
static const int movementConfirmationDuration = 240; // 4 min
static const double minimumTripDistance = 500.0;   // Higher
```

---

## 📞 API Reference

### TripDetectionCubit

```dart
// Start detection
Future<void> startDetection(String userId)

// Stop detection
void stopDetection()

// Confirm trip
Future<void> confirmTrip({
  required String tripId,
  required String purpose,
  required String confirmedMode,
  List<String>? companions,
  double? cost,
  String? notes,
})

// Reject trip
Future<void> rejectTrip(String tripId)

// Get statistics
Future<Map<String, dynamic>> getTripStatistics(String userId)

// Properties
bool get isDetecting
AutoTripModel? get currentTrip
List<AutoTripModel> get pendingTrips
```

### AutoTripRepository

```dart
// Save trip
Future<String?> saveAutoTrip(AutoTripModel trip)

// Update trip
Future<bool> updateAutoTrip(String tripId, AutoTripModel trip)

// Confirm trip
Future<bool> confirmTrip({...})

// Reject trip
Future<bool> rejectTrip(String tripId)

// Get trips
Stream<List<AutoTripModel>> getUserAutoTrips(String userId)
Stream<List<AutoTripModel>> getPendingTrips(String userId)
Stream<List<AutoTripModel>> getConfirmedTrips(String userId)

// Statistics
Future<Map<String, dynamic>> getTripStatistics(String userId)
```

---

## 💡 Tips

1. **Test with real movement**: Emulators don't simulate realistic GPS patterns
2. **Start with walking**: Easier to test than driving
3. **Check logs**: Use `kDebugMode` prints to debug
4. **Adjust thresholds**: Fine-tune based on your use case
5. **Battery testing**: Monitor battery usage over 24 hours
6. **User feedback**: Collect data on false positives/negatives

---

## ✅ Checklist for Production

- [ ] Test on multiple devices (Android & iOS)
- [ ] Test different travel modes (walk, cycle, car, bus)
- [ ] Test edge cases (short trips, long trips, stops)
- [ ] Monitor battery usage
- [ ] Add privacy policy section
- [ ] Request background location permission properly
- [ ] Handle permission denials gracefully
- [ ] Add user settings to enable/disable
- [ ] Implement notification for detected trips
- [ ] Add analytics to track feature usage
- [ ] Create user guide/tutorial
- [ ] Test offline behavior
- [ ] Optimize Firestore queries with indexes

---

## 📈 Metrics to Track

- Detection accuracy (% correct mode)
- False positive rate
- False negative rate
- Battery consumption
- User engagement (% users who enable)
- Confirmation rate (% detected trips confirmed)
- Average time to confirm

---

**Last Updated**: 2025-10-08  
**Version**: 1.0.0
