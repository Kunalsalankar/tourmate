# TourMate - Transportation Planning Application

## Executive Summary

TourMate is a comprehensive mobile application designed to capture trip-related information for transportation planning. The app combines **automatic trip detection** with **manual trip entry** to build a complete record of individual travel behavior, addressing the limitations of traditional household travel surveys.

## Key Capabilities

### 1. Automatic Trip Detection ⭐

The app automatically captures trips using GPS and intelligent algorithms:

- **Automatic Start Detection**: Detects trip start when user moves continuously for 3 minutes (speed > 2 m/s)
- **Real-time Tracking**: Records GPS coordinates, speed, and distance every 30 seconds
- **Automatic End Detection**: Ends trip when user is stationary for 5 minutes (speed < 1 m/s)
- **Mode Inference**: Automatically detects mode of transport based on speed patterns:
  - Walking: 0-7 km/h
  - Cycling: 7-25 km/h
  - E-Bike: 12-25 km/h
  - Motorcycle: 25-60 km/h
  - Car: 40-120 km/h
  - Bus: 30-80 km/h (with frequent stops)
  - Train: >80 km/h

**Data Captured Automatically:**
- Origin and destination coordinates
- Start and end timestamps
- Complete route trace (GPS points)
- Distance traveled (meters)
- Average and maximum speed
- Trip duration
- Detected mode of transport

### 2. User Confirmation & Enrichment

After automatic detection, users are prompted to confirm and enrich trip data:

- **Trip Purpose**: Work, Shopping, Education, Recreation, Healthcare, Social, Other
- **Mode Confirmation**: User can confirm or correct the auto-detected mode
- **Companions**: Names of accompanying travelers
- **Cost**: Trip cost (fuel, fare, parking, etc.)
- **Notes**: Additional context or observations

### 3. Manual Trip Entry

Users can manually create trips with comprehensive details:

- **Trip Number**: Unique identifier
- **Origin & Destination**: Location names
- **Date & Time**: Start time (and end time for past trips)
- **Mode of Transport**: Car, Bus, Train, Walk, Bike, etc.
- **Activities**: Multiple activities associated with the trip
- **Accompanying Travelers**: 
  - Name
  - Age
  - Phone number (optional)
  - Email (optional)
  - Relationship (optional)

### 4. Trip Management

- **Trip Types**:
  - **Active**: Currently ongoing trips
  - **Past**: Completed trips
  - **Future**: Scheduled trips
- **Trip Operations**:
  - View trip details
  - Edit trip information
  - Delete trips
  - End active trips
- **Random Trips**: Special trip type where destination is unknown initially

### 5. Trip Analytics

**User Statistics:**
- Total number of trips
- Total number of travelers
- Unique destinations visited
- Trip distribution by type

**Admin Analytics:**
- Comprehensive view of all user trips
- Filtering and search capabilities
- Real-time data updates from Firestore

## Technical Architecture

### Data Models

#### AutoTripModel (Automatic Detection)
```dart
{
  id: String
  userId: String
  origin: LocationPoint
  destination: LocationPoint
  startTime: DateTime
  endTime: DateTime
  distanceCovered: double (meters)
  averageSpeed: double (m/s)
  maxSpeed: double (m/s)
  routePoints: List<LocationPoint>
  status: AutoTripStatus (detecting/detected/confirmed/rejected)
  purpose: String
  detectedMode: String
  confirmedMode: String
  companions: List<String>
  cost: double
  notes: String
  createdAt: DateTime
  updatedAt: DateTime
}
```

#### TripModel (Manual Entry)
```dart
{
  id: String
  tripNumber: String
  origin: String
  destination: String
  time: DateTime
  endTime: DateTime
  mode: String
  activities: List<String>
  accompanyingTravellers: List<TravellerInfo>
  userId: String
  tripType: TripType (active/past/future)
  createdAt: DateTime
  updatedAt: DateTime
}
```

#### TravellerInfo
```dart
{
  name: String
  age: int
  phoneNumber: String
  email: String
  relationship: String
}
```

### Core Services

1. **TripDetectionService**: GPS monitoring and trip detection logic
2. **LocationService**: Location permission and GPS access
3. **TripRepository**: Firestore CRUD operations for manual trips
4. **AutoTripRepository**: Firestore operations for auto-detected trips
5. **NotificationService**: User notifications for trip events
6. **CacheService**: Local data caching for offline support
7. **ConnectivityService**: Network status monitoring
8. **MapsService**: Google Maps integration for route visualization

### State Management

- **BLoC/Cubit Pattern**: Clean separation of business logic and UI
- **TripCubit**: Manages manual trip state
- **TripDetectionCubit**: Manages automatic detection state
- **AuthCubit**: Authentication state
- **NavigationCubit**: Navigation state
- **NotificationCubit**: Notification state

## Transportation Planning Benefits

### Advantages Over Traditional Surveys

| Traditional Survey | TourMate App |
|-------------------|--------------|
| Manual data entry | Automatic GPS tracking |
| Recall bias | Real-time capture |
| Limited sample size | Scalable to thousands |
| Snapshot in time | Continuous monitoring |
| High cost per respondent | Low marginal cost |
| Inaccurate distances | Precise GPS measurements |
| Estimated times | Exact timestamps |
| Missing short trips | Captures all trips >300m |

### Data Quality Improvements

1. **Accuracy**: GPS-based measurements eliminate estimation errors
2. **Completeness**: Automatic detection captures trips users might forget
3. **Timeliness**: Real-time data collection vs. delayed recall
4. **Granularity**: Detailed route traces enable micro-level analysis
5. **Verification**: Speed patterns validate mode of transport

### Planning Applications

The data collected enables:

1. **Origin-Destination Matrices**: Understand travel patterns between zones
2. **Mode Share Analysis**: Actual distribution of transport modes
3. **Trip Purpose Analysis**: Why people travel and when
4. **Peak Hour Identification**: Traffic patterns by time of day
5. **Route Choice Analysis**: Preferred paths between locations
6. **Travel Time Analysis**: Actual vs. expected travel times
7. **Multi-modal Trip Analysis**: Mode changes within journeys
8. **Demographic Segmentation**: Travel behavior by age, household composition
9. **Cost Analysis**: Transportation expenditure patterns
10. **Accessibility Studies**: Identify underserved areas

## Data Collection Workflow

### Automatic Detection Flow

```
1. User enables detection
   ↓
2. App monitors GPS in background
   ↓
3. Movement detected (speed > 2 m/s for 3 min)
   ↓
4. Trip starts - GPS tracking begins
   ↓
5. Route recorded with 30-second intervals
   ↓
6. User stops (speed < 1 m/s for 5 min)
   ↓
7. Trip ends - data saved
   ↓
8. User notified to confirm
   ↓
9. User adds purpose, confirms mode, adds companions/cost
   ↓
10. Trip marked as confirmed
   ↓
11. Data available for analysis
```

### Manual Entry Flow

```
1. User taps "New Trip"
   ↓
2. Fills trip form:
   - Origin & destination
   - Date & time
   - Mode of transport
   - Activities
   - Accompanying travelers
   ↓
3. Validates input
   ↓
4. Saves to Firestore
   ↓
5. Data available for analysis
```

## Privacy & Permissions

### Required Permissions

**Android:**
- `ACCESS_FINE_LOCATION`: Precise GPS tracking
- `ACCESS_COARSE_LOCATION`: Network-based location
- `ACCESS_BACKGROUND_LOCATION`: Detection when app is closed
- `FOREGROUND_SERVICE`: Persistent tracking
- `FOREGROUND_SERVICE_LOCATION`: Location service type
- `INTERNET`: Firebase sync

**iOS:**
- `NSLocationWhenInUseUsageDescription`: Location while using app
- `NSLocationAlwaysAndWhenInUseUsageDescription`: Background location
- `UIBackgroundModes`: Background location updates

### Privacy Considerations

- Location data encrypted in transit and at rest
- User consent required before tracking
- Users can stop detection anytime
- Users can delete their trips
- Admin access requires authentication
- Data used only for transportation planning

## Performance Optimization

### Battery Efficiency

- GPS updates every 30 seconds (not continuous)
- Distance filter: 10 meters (reduces unnecessary updates)
- Detection stops when user disables it
- Adaptive accuracy based on movement

### Data Efficiency

- Route points batched and uploaded at trip end
- Local caching reduces network requests
- Minimal data structure (only essential fields)
- Compressed route storage for long trips

### Storage Efficiency

- Average trip: ~5-10 KB
- 100 trips: ~500 KB - 1 MB
- Firestore indexes optimized for queries

## Detection Algorithm Details

### Trip Start Logic

```
IF speed > 2.0 m/s:
    IF movement_duration >= 180 seconds:
        START TRIP
        Record origin coordinates
        Record start timestamp
        Initialize route tracking
```

### Trip End Logic

```
IF speed < 1.0 m/s:
    IF stationary_duration >= 300 seconds:
        IF total_distance >= 300 meters:
            END TRIP
            Record destination coordinates
            Record end timestamp
            Calculate statistics
            Save to database
        ELSE:
            DISCARD (too short)
```

### Mode Detection Algorithm

```dart
String detectMode(List<double> speeds, double maxSpeed, double avgSpeed) {
  double maxSpeedKmh = maxSpeed * 3.6;
  double avgSpeedKmh = avgSpeed * 3.6;
  double speedVariance = calculateVariance(speeds);
  
  if (maxSpeedKmh <= 7.0) return 'Walking';
  if (maxSpeedKmh <= 25.0) {
    return avgSpeedKmh < 12 ? 'Cycling' : 'E-Bike';
  }
  if (maxSpeedKmh <= 60.0) return 'Motorcycle';
  if (maxSpeedKmh <= 120.0) {
    return speedVariance > 15 ? 'Bus' : 'Car';
  }
  return 'Train/Fast Transit';
}
```

## Database Schema

### Firestore Collections

**`trips`** (Manual Entries)
```javascript
{
  tripNumber: "TRIP-001",
  origin: "Kozhikode",
  destination: "Kochi",
  time: Timestamp,
  endTime: Timestamp,
  mode: "Car",
  activities: ["Work", "Meeting"],
  accompanyingTravellers: [
    {
      name: "John Doe",
      age: 30,
      phoneNumber: "+91...",
      email: "john@example.com",
      relationship: "Colleague"
    }
  ],
  userId: "user123",
  tripType: "past",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

**`auto_trips`** (Automatic Detection)
```javascript
{
  userId: "user123",
  origin: {
    latitude: 11.2588,
    longitude: 75.7804,
    timestamp: Timestamp,
    speed: 0.5,
    accuracy: 10.0
  },
  destination: {...},
  startTime: Timestamp,
  endTime: Timestamp,
  distanceCovered: 8200.0,
  averageSpeed: 6.5,
  maxSpeed: 15.0,
  routePoints: [{...}, {...}, ...],
  status: "confirmed",
  purpose: "Work",
  detectedMode: "Bus",
  confirmedMode: "Bus",
  companions: ["Jane Doe"],
  cost: 50.0,
  notes: "Morning commute",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Required Indexes

```javascript
// For user trip queries
userId + startTime (descending)

// For pending trip confirmations
userId + status + startTime (descending)

// For trip type filtering
userId + tripType + time (descending)
```

## User Interface

### Screens

1. **Home Screen**: Trip overview, statistics, trip list
2. **Trip Detection Screen**: Enable/disable detection, view active trip
3. **Trip Confirmation Screen**: Confirm auto-detected trips
4. **Trip Form**: Create/edit manual trips
5. **Admin Dashboard**: View all trips, analytics

### Key Features

- **Modern UI**: Material Design 3 with gradient themes
- **Real-time Updates**: Live trip statistics during detection
- **Responsive Design**: Adapts to different screen sizes
- **Intuitive Navigation**: Bottom navigation bar
- **Visual Feedback**: Loading states, success/error messages
- **Trip Cards**: Color-coded by type (active/past/future)

## Configuration

### Adjustable Thresholds

Located in `TripDetectionConfig`:

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

These can be adjusted based on field testing and regional characteristics.

## Future Enhancements

### Planned Features

1. **Machine Learning Mode Detection**: Train ML models on confirmed trips
2. **Geofencing**: Auto-detect home, work, and frequent locations
3. **Trip Pattern Recognition**: Identify recurring trips (daily commute)
4. **Offline Support**: Queue trips when offline, sync later
5. **Multi-modal Detection**: Detect mode changes within a trip
6. **Social Features**: Share trips with family/friends
7. **Advanced Analytics**: 
   - Carbon footprint calculation
   - Cost optimization suggestions
   - Alternative route recommendations
8. **Data Export**: CSV/Excel export for external analysis
9. **API Integration**: REST API for third-party analysis tools
10. **Predictive Analytics**: Predict future travel patterns

### Research Applications

- **Travel Demand Modeling**: Calibrate transport models
- **Public Transit Planning**: Optimize routes and schedules
- **Infrastructure Planning**: Identify bottlenecks
- **Policy Evaluation**: Measure impact of interventions
- **Behavioral Studies**: Understand travel decision-making
- **Sustainability Analysis**: Environmental impact assessment

## Testing & Validation

### Test Scenarios

1. **Short walk** (<300m): Should be discarded
2. **Walking trip** (1 km): Should detect as "Walking"
3. **Cycling trip** (5 km): Should detect as "Cycling"
4. **Car trip** (20 km): Should detect as "Car"
5. **Bus trip** (15 km with stops): Should detect as "Bus"
6. **Multi-stop trip**: Should capture entire journey
7. **Background detection**: Should work when app is closed
8. **Battery impact**: Should not drain battery excessively

### Validation Metrics

- **Detection Accuracy**: % of trips correctly detected
- **Mode Accuracy**: % of modes correctly inferred
- **Distance Accuracy**: GPS distance vs. actual distance
- **Time Accuracy**: Recorded time vs. actual time
- **Completeness**: % of daily trips captured
- **User Acceptance**: User satisfaction with auto-detection

## Deployment

### Prerequisites

- Flutter SDK 3.8.0+
- Firebase project with Firestore enabled
- Google Maps API key
- Android Studio / Xcode

### Setup Steps

1. Clone repository
2. Install dependencies: `flutter pub get`
3. Configure Firebase (google-services.json, GoogleService-Info.plist)
4. Add Google Maps API key to .env file
5. Build and run: `flutter run`

### Production Considerations

- Enable Firestore security rules
- Set up Firebase Analytics
- Configure crash reporting
- Implement rate limiting
- Set up backup and recovery
- Monitor API usage and costs

## Support & Documentation

### Available Documentation

- `README.md`: Project overview
- `AUTOMATIC_TRIP_DETECTION.md`: Detailed detection algorithm
- `INTEGRATION_GUIDE.md`: Integration instructions
- `QUICK_REFERENCE.md`: Quick start guide
- `TESTING_GUIDE.md`: Testing procedures
- `WORKFLOW_DIAGRAM.md`: Visual workflows
- `TRANSPORTATION_PLANNING_GUIDE.md`: This document

### Contact

For questions, issues, or collaboration:
- Create an issue in the repository
- Contact the development team
- Refer to inline code documentation

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-14  
**Developed for**: Transportation Planning and Research  
**License**: MIT
