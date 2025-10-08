# Tourmate - Travel Management App

A comprehensive Flutter application for managing travel trips with user and admin interfaces. The app allows users to create, manage, and track their trips while providing administrators with comprehensive trip analytics and management capabilities.

## Features

### User Features
- **Automatic Trip Detection** ⭐ NEW:
  - Automatically detect trip start/end using GPS
  - Track distance, duration, and speed
  - Infer mode of transport based on speed patterns
  - User confirmation with purpose, companions, and cost
  - Background location tracking
- **Trip Creation**: Create detailed trip records with:
  - Trip number
  - Origin and destination
  - Travel time and date
  - Mode of transport
  - Travel activities
  - Accompanying travellers (with details)
- **Trip Management**: View, edit, and delete trips
- **Trip Statistics**: View personal trip analytics
- **Modern UI**: Beautiful, responsive interface with light blue theme

### Admin Features
- **Trip Analytics**: Comprehensive overview of all user trips
- **Trip Management**: View all trips with filtering and search capabilities
- **Real-time Updates**: Live data updates from Firestore

## Technical Architecture

### State Management
- **BLoC/Cubit Pattern**: Clean separation of business logic and UI
- **TripCubit**: Manages trip-related state and operations
- **AuthCubit**: Handles authentication state
- **NavigationCubit**: Manages navigation state

### Data Layer
- **Firestore Integration**: Cloud-based data storage
- **TripRepository**: Handles all Firestore operations
- **TripModel**: Comprehensive data model with validation

### Project Structure
```
lib/
├── admin/
│   ├── admin_trips_screen.dart      # Admin trip management
│   └── sign_up/
│       ├── admin_sign_in_screen.dart
│       └── admin_sign_up_screen.dart
├── app/
│   └── app.dart                     # Main app configuration
├── core/
│   ├── colors.dart                  # App color scheme
│   ├── models/
│   │   ├── trip_model.dart          # Trip data model
│   │   └── auto_trip_model.dart     # Auto-detected trip model ⭐
│   ├── navigation/
│   │   ├── app_router.dart          # Route configuration
│   │   └── navigation_service.dart   # Navigation utilities
│   ├── repositories/
│   │   ├── trip_repository.dart     # Firestore operations
│   │   └── auto_trip_repository.dart # Auto-trip operations ⭐
│   └── services/
│       ├── location_service.dart    # Location tracking
│       └── trip_detection_service.dart # Trip detection logic ⭐
├── cubit/
│   ├── auth_cubit.dart              # Authentication state
│   ├── navigation_cubit.dart        # Navigation state
│   ├── trip_cubit.dart              # Trip state management
│   └── trip_detection_cubit.dart    # Auto-detection state ⭐
├── screens/
│   ├── role_selection_screen.dart   # User/Admin selection
│   └── splash_screen.dart           # App splash screen
├── user/
│   ├── home_screen.dart             # User main interface
│   ├── sign_in_screen.dart          # User authentication
│   ├── trip_detection_screen.dart   # Auto-detection UI ⭐
│   ├── trip_confirmation_screen.dart # Trip confirmation UI ⭐
│   └── sign_up/
│       └── sign_up_screen.dart      # User registration
└── widgets/
    └── trip_form_widget.dart        # Trip creation/editing form
```

## Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Firebase project with Firestore enabled
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd tourmate
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project
   - Enable Authentication and Firestore
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the appropriate platform directories

4. **Run the application**
   ```bash
   flutter run
   ```

## Usage

### For Users
1. **Sign Up/Login**: Create an account or sign in
2. **Create Trips**: Use the "New Trip" button to create detailed trip records
3. **Manage Trips**: View, edit, or delete existing trips
4. **View Statistics**: Check your personal trip analytics

### For Admins
1. **Admin Login**: Sign in with admin credentials
2. **View All Trips**: Access comprehensive trip data from all users
3. **Filter & Search**: Use filters and search to find specific trips
4. **Analytics**: View overall trip statistics and user activity

## Data Model

### Trip Model
```dart
class TripModel {
  String? id;
  String tripNumber;
  String origin;
  DateTime time;
  String mode;
  String destination;
  List<String> activities;
  List<TravellerInfo> accompanyingTravellers;
  String userId;
  DateTime createdAt;
  DateTime updatedAt;
}
```

### Traveller Info
```dart
class TravellerInfo {
  String name;
  String? phoneNumber;
  String? email;
  String? relationship;
  int age;
}
```

## Key Features Implementation

### Trip Creation Form
- Comprehensive form with validation
- Dynamic traveller addition/removal
- Activity management with chips
- Date/time picker integration
- Mode of transport selection

### Real-time Data Sync
- Firestore streams for live updates
- Optimistic UI updates
- Error handling and retry mechanisms

### Responsive Design
- Material Design 3
- Consistent color scheme
- Adaptive layouts for different screen sizes

## Dependencies

- `flutter_bloc`: State management
- `firebase_core`: Firebase integration
- `firebase_auth`: User authentication
- `cloud_firestore`: Database operations
- `geolocator`: GPS location tracking
- `google_maps_flutter`: Map display and route visualization
- `permission_handler`: Location permissions
- `cupertino_icons`: iOS-style icons

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Automatic Trip Detection

The app now includes an **Automatic Trip Detection** feature that uses GPS to automatically track user trips. This feature:

- Detects trip start when user moves continuously for 3 minutes
- Tracks the entire route with GPS coordinates
- Detects trip end when user stops for 5 minutes
- Calculates distance, duration, and average speed
- Infers mode of transport (walking, cycling, car, bus, etc.)
- Prompts user to confirm details and add purpose/companions/cost

### Documentation

- **Full Documentation**: See `AUTOMATIC_TRIP_DETECTION.md`
- **Integration Guide**: See `INTEGRATION_GUIDE.md`
- **Quick Reference**: See `QUICK_REFERENCE.md`

### How It Works

1. User enables automatic detection
2. App monitors GPS in background
3. Trip starts when sustained movement detected
4. App tracks route and calculates statistics
5. Trip ends when user stops moving
6. User confirms trip details and purpose
7. Data saved to Firestore for analysis

### Detection Algorithm

- **Trip Start**: Speed > 2 m/s for 3 minutes
- **Trip End**: Speed < 1 m/s for 5 minutes
- **Minimum Distance**: 300 meters
- **GPS Updates**: Every 30 seconds or 10 meters

### Mode Detection

Based on speed patterns:
- Walking: 0-7 km/h
- Cycling: 7-25 km/h
- Motorcycle: 25-60 km/h
- Car: 40-120 km/h
- Bus: 30-80 km/h (with stops)
- Train: >80 km/h

## Support

For support and questions, please contact the development team or create an issue in the repository.