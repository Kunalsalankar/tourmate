# Tourmate - Travel Management App

A comprehensive Flutter application for managing travel trips with user and admin interfaces. The app allows users to create, manage, and track their trips while providing administrators with comprehensive trip analytics and management capabilities.

## Features

### User Features
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
- **User Statistics**: Track active users and trip patterns
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
│   │   └── trip_model.dart          # Trip data model
│   ├── navigation/
│   │   ├── app_router.dart          # Route configuration
│   │   └── navigation_service.dart   # Navigation utilities
│   └── repositories/
│       └── trip_repository.dart     # Firestore operations
├── cubit/
│   ├── auth_cubit.dart              # Authentication state
│   ├── navigation_cubit.dart        # Navigation state
│   └── trip_cubit.dart              # Trip state management
├── screens/
│   ├── role_selection_screen.dart   # User/Admin selection
│   └── splash_screen.dart           # App splash screen
├── user/
│   ├── home_screen.dart             # User main interface
│   ├── sign_in_screen.dart          # User authentication
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
- `cupertino_icons`: iOS-style icons

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions, please contact the development team or create an issue in the repository.