# 🔔 Trip Detection Notification Flow Diagram

## 📊 Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              USER DEVICE                                 │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                        TourMate App                             │    │
│  │                                                                 │    │
│  │  ┌──────────────────────────────────────────────────────┐     │    │
│  │  │              TripDetectionService                     │     │    │
│  │  │  • Monitors GPS location                             │     │    │
│  │  │  • Detects movement patterns                         │     │    │
│  │  │  • Fires trip events                                 │     │    │
│  │  └────────────────┬─────────────────────────────────────┘     │    │
│  │                   │                                            │    │
│  │                   │ Events (onTripStart, onTripEnd)           │    │
│  │                   ↓                                            │    │
│  │  ┌──────────────────────────────────────────────────────┐     │    │
│  │  │              TripDetectionCubit                       │     │    │
│  │  │  • Listens to trip events                            │     │    │
│  │  │  • Manages trip state                                │     │    │
│  │  │  • Triggers notifications                            │     │    │
│  │  │  • Performs reverse geocoding                        │     │    │
│  │  └────────────────┬─────────────────────────────────────┘     │    │
│  │                   │                                            │    │
│  │                   │ Notification Requests                     │    │
│  │                   ↓                                            │    │
│  │  ┌──────────────────────────────────────────────────────┐     │    │
│  │  │              NotificationService                      │     │    │
│  │  │  • Formats notification content                      │     │    │
│  │  │  • Manages notification channels                     │     │    │
│  │  │  • Shows notifications                               │     │    │
│  │  └────────────────┬─────────────────────────────────────┘     │    │
│  │                   │                                            │    │
│  └───────────────────┼────────────────────────────────────────────┘    │
│                      │                                                 │
│                      │ Platform Notification API                       │
│                      ↓                                                 │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │         Android/iOS Notification System                       │    │
│  │  • Displays notification                                      │    │
│  │  • Plays sound/vibration                                      │    │
│  │  • Shows on lock screen                                       │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 🚗 Trip Start Notification Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TRIP START SEQUENCE                              │
└─────────────────────────────────────────────────────────────────────────┘

1. USER STARTS MOVING
   │
   ├─→ GPS detects movement (speed > 2 m/s)
   │
   └─→ Movement continues for 1 minute
       │
       ▼

2. TRIP DETECTION SERVICE
   │
   ├─→ Creates AutoTripModel with origin
   │
   ├─→ Fires onTripStart event
   │
   └─→ Starts tracking route
       │
       ▼

3. TRIP DETECTION CUBIT
   │
   ├─→ Receives onTripStart event
   │
   ├─→ Emits TripDetectionActive state
   │
   ├─→ Calls _getLocationName() for origin
   │   │
   │   ├─→ Uses geocoding package
   │   │
   │   ├─→ Converts GPS to "Mumbai, Maharashtra"
   │   │
   │   └─→ Falls back to coordinates if fails
   │
   └─→ Calls NotificationService.showTripDetectedNotification()
       │
       ▼

4. NOTIFICATION SERVICE
   │
   ├─→ Formats notification content:
   │   • Title: "🚗 New Trip Detected!"
   │   • Body: "Started Car from Mumbai, Maharashtra..."
   │
   ├─→ Configures notification:
   │   • Channel: trip_detection_channel
   │   • Priority: High
   │   • Sound: Enabled
   │   • Vibration: Enabled
   │
   └─→ Shows notification via flutter_local_notifications
       │
       ▼

5. USER RECEIVES NOTIFICATION
   │
   ├─→ Notification appears on screen
   │
   ├─→ Sound plays 🔔
   │
   ├─→ Device vibrates 📳
   │
   └─→ Shows on lock screen 📱
```

---

## ✅ Trip End Notification Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          TRIP END SEQUENCE                               │
└─────────────────────────────────────────────────────────────────────────┘

1. USER STOPS MOVING
   │
   ├─→ GPS detects stationary (speed < 1 m/s)
   │
   └─→ Stationary for 5 minutes
       │
       ▼

2. TRIP DETECTION SERVICE
   │
   ├─→ Calculates trip statistics:
   │   • Distance: 145.23 km
   │   • Duration: 150 minutes
   │   • Average speed: 58 km/h
   │   • Max speed: 95 km/h
   │
   ├─→ Sets destination location
   │
   ├─→ Fires onTripEnd event
   │
   └─→ Stops tracking
       │
       ▼

3. TRIP DETECTION CUBIT
   │
   ├─→ Receives onTripEnd event
   │
   ├─→ Saves trip to Firestore
   │
   ├─→ Emits TripDetected state
   │
   ├─→ Calls _getLocationName() for destination
   │   │
   │   ├─→ Uses geocoding package
   │   │
   │   ├─→ Converts GPS to "Pune, Maharashtra"
   │   │
   │   └─→ Falls back to coordinates if fails
   │
   └─→ Calls NotificationService.showTripEndedNotification()
       │
       ▼

4. NOTIFICATION SERVICE
   │
   ├─→ Formats notification content:
   │   • Title: "✅ Trip Completed!"
   │   • Body: "Car trip ended at Pune. 145.23km in 2h 30min"
   │
   ├─→ Configures notification:
   │   • Channel: trip_detection_channel
   │   • Priority: High
   │   • Sound: Enabled
   │   • Vibration: Enabled
   │
   └─→ Shows notification via flutter_local_notifications
       │
       ▼

5. USER RECEIVES NOTIFICATION
   │
   ├─→ Notification appears on screen
   │
   ├─→ Sound plays 🔔
   │
   ├─→ Device vibrates 📳
   │
   ├─→ Shows trip summary
   │
   └─→ Shows on lock screen 📱
```

---

## 🔄 Ongoing Trip Update Flow (Optional)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      TRIP UPDATE SEQUENCE (Optional)                     │
└─────────────────────────────────────────────────────────────────────────┘

1. TRIP IN PROGRESS
   │
   ├─→ Every 15 minutes (configurable)
   │
   └─→ Trip still active
       │
       ▼

2. TRIP DETECTION CUBIT
   │
   ├─→ Gets current trip statistics
   │
   └─→ Calls NotificationService.showTripUpdateNotification()
       │
       ▼

3. NOTIFICATION SERVICE
   │
   ├─→ Formats notification content:
   │   • Title: "🚗 Trip in Progress"
   │   • Body: "Car • 45.5km • 1h 15min"
   │
   ├─→ Configures notification:
   │   • Channel: trip_updates_channel
   │   • Priority: Low
   │   • Sound: Disabled
   │   • Vibration: Disabled
   │   • Ongoing: True
   │
   └─→ Updates existing notification (ID: 0)
       │
       ▼

4. USER SEES UPDATE
   │
   └─→ Silent update in notification shade
```

---

## 🌐 Reverse Geocoding Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      REVERSE GEOCODING PROCESS                           │
└─────────────────────────────────────────────────────────────────────────┘

INPUT: GPS Coordinates (19.0760, 72.8777)
   │
   ▼

1. TRIP DETECTION CUBIT
   │
   └─→ Calls _getLocationName(lat, lng)
       │
       ▼

2. GEOCODING PACKAGE
   │
   ├─→ Sends request to geocoding service
   │
   ├─→ Receives placemark data:
   │   {
   │     locality: "Mumbai",
   │     subLocality: "Andheri",
   │     administrativeArea: "Maharashtra",
   │     country: "India"
   │   }
   │
   └─→ Returns placemark list
       │
       ▼

3. LOCATION NAME BUILDER
   │
   ├─→ Extracts relevant parts:
   │   • Locality: "Mumbai"
   │   • Administrative Area: "Maharashtra"
   │
   ├─→ Combines parts: "Mumbai, Maharashtra"
   │
   └─→ Returns formatted string
       │
       ▼

OUTPUT: "Mumbai, Maharashtra"

┌─────────────────────────────────────────────────────────────────────────┐
│                         FALLBACK SCENARIO                                │
└─────────────────────────────────────────────────────────────────────────┘

IF: No internet OR Geocoding fails
   │
   └─→ Returns coordinates: "19.0760, 72.8777"
```

---

## 📱 Platform-Specific Notification Flow

### **Android Flow**

```
NotificationService
   │
   ├─→ Creates AndroidNotificationDetails
   │   • Channel ID: trip_detection_channel
   │   • Importance: High
   │   • Priority: High
   │   • Sound: Default
   │   • Vibration: Pattern [0, 250, 250, 250]
   │   • Icon: @mipmap/ic_launcher
   │
   ├─→ Creates NotificationDetails
   │
   └─→ FlutterLocalNotificationsPlugin.show()
       │
       ▼
   Android Notification Manager
       │
       ├─→ Checks notification permission (Android 13+)
       │
       ├─→ Checks Do Not Disturb settings
       │
       ├─→ Checks notification channel settings
       │
       └─→ Displays notification
           │
           ├─→ Shows in notification shade
           ├─→ Shows on lock screen
           ├─→ Plays sound
           ├─→ Vibrates device
           └─→ Shows heads-up notification
```

### **iOS Flow**

```
NotificationService
   │
   ├─→ Creates DarwinNotificationDetails
   │   • presentAlert: true
   │   • presentBadge: true
   │   • presentSound: true
   │   • interruptionLevel: timeSensitive
   │
   ├─→ Creates NotificationDetails
   │
   └─→ FlutterLocalNotificationsPlugin.show()
       │
       ▼
   iOS User Notifications Framework
       │
       ├─→ Checks notification permission
       │
       ├─→ Checks Focus mode settings
       │
       ├─→ Checks notification settings
       │
       └─→ Displays notification
           │
           ├─→ Shows in notification center
           ├─→ Shows on lock screen
           ├─→ Plays sound
           ├─→ Shows banner
           └─→ Updates badge (optional)
```

---

## ⚡ Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ERROR HANDLING                                   │
└─────────────────────────────────────────────────────────────────────────┘

TRY: Show notification
   │
   ├─→ SUCCESS
   │   │
   │   ├─→ Log: "Trip start notification sent"
   │   │
   │   └─→ Continue normal flow
   │
   └─→ ERROR
       │
       ├─→ Catch exception
       │
       ├─→ Log error: "Error sending notification: $e"
       │
       ├─→ Don't crash app
       │
       └─→ Continue without notification
           │
           └─→ User can still see trip in app
```

---

## 🔐 Permission Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      PERMISSION REQUEST FLOW                             │
└─────────────────────────────────────────────────────────────────────────┘

APP STARTUP (main.dart)
   │
   ├─→ Initialize NotificationService
   │
   └─→ Request notification permissions
       │
       ▼

ANDROID (13+)
   │
   ├─→ Check if permission granted
   │
   ├─→ If not, show system dialog:
   │   "Allow TourMate to send notifications?"
   │   [ Don't allow ] [ Allow ]
   │
   └─→ Store permission result
       │
       ├─→ GRANTED: Notifications enabled ✅
       │
       └─→ DENIED: Notifications disabled ❌
           │
           └─→ User can enable later in Settings

iOS
   │
   ├─→ Check if permission granted
   │
   ├─→ If not, show system dialog:
   │   "TourMate Would Like to Send You Notifications"
   │   [ Don't Allow ] [ Allow ]
   │
   └─→ Store permission result
       │
       ├─→ GRANTED: Notifications enabled ✅
       │
       └─→ DENIED: Notifications disabled ❌
           │
           └─→ User can enable later in Settings
```

---

## 📊 State Management Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      CUBIT STATE TRANSITIONS                             │
└─────────────────────────────────────────────────────────────────────────┘

TripDetectionInitial
   │
   │ startDetection()
   ▼
TripDetectionLoading
   │
   │ Detection started successfully
   ▼
TripDetectionActive (currentTrip: null)
   │
   │ Trip detected (1 min movement)
   │ → NOTIFICATION: Trip Started 🚗
   ▼
TripDetectionActive (currentTrip: AutoTripModel)
   │
   │ Trip updates every 30 seconds
   ▼
TripDetectionActive (currentTrip: updated)
   │
   │ Trip ended (5 min stationary)
   │ → NOTIFICATION: Trip Completed ✅
   ▼
TripDetected (savedTrip)
   │
   │ After 2 seconds
   ▼
TripDetectionActive (currentTrip: null)
   │
   │ Ready for next trip
   └─→ Loop continues...
```

---

## 🎯 Complete User Journey

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      END-TO-END USER JOURNEY                             │
└─────────────────────────────────────────────────────────────────────────┘

1. USER OPENS APP
   │
   ├─→ App requests notification permission
   │
   └─→ User grants permission ✅

2. USER ENABLES TRIP DETECTION
   │
   └─→ App starts monitoring GPS

3. USER STARTS DRIVING
   │
   ├─→ 0:00 - User starts car
   ├─→ 0:30 - App detects movement
   ├─→ 1:00 - Movement confirmed
   │
   └─→ 📱 NOTIFICATION: "New Trip Detected!"

4. USER DRIVES
   │
   ├─→ App tracks route
   ├─→ Records GPS points
   └─→ Calculates statistics

5. USER ARRIVES AT DESTINATION
   │
   ├─→ 2:30:00 - User parks car
   ├─→ 2:30:30 - App detects stationary
   ├─→ 2:35:30 - Stationary confirmed
   │
   └─→ 📱 NOTIFICATION: "Trip Completed! 145km in 2h 30min"

6. USER VIEWS NOTIFICATION
   │
   ├─→ Sees trip summary
   ├─→ Can tap to open app (future)
   └─→ Trip saved in history

7. CYCLE REPEATS
   │
   └─→ Ready for next trip
```

---

**Last Updated**: October 14, 2025
**Diagram Version**: 1.0.0
