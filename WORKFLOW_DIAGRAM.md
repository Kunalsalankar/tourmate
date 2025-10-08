# Automatic Trip Detection - Workflow Diagrams

## 🔄 Complete User Journey

```
┌─────────────────────────────────────────────────────────────┐
│                    USER OPENS APP                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Navigate to Trip Detection Screen               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                 Tap "Start Detection"                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│          Request Location Permissions                        │
│   ┌──────────────────────────────────────────────┐          │
│   │  • Fine Location                              │          │
│   │  • Coarse Location                            │          │
│   │  • Background Location (Android 10+)          │          │
│   └──────────────────────────────────────────────┘          │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
    GRANTED                   DENIED
        │                         │
        ▼                         ▼
┌───────────────────┐    ┌────────────────────┐
│ Start GPS         │    │ Show Error         │
│ Tracking          │    │ Message            │
└────────┬──────────┘    └────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              Detection Active - Monitoring GPS               │
│                                                              │
│  Status: "Detection Active"                                  │
│  Waiting for movement...                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                USER STARTS MOVING                            │
│  (e.g., leaves home for work)                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              App Detects Movement                            │
│                                                              │
│  Condition: Speed > 2 m/s                                    │
│  Timer: 0 seconds                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│            Sustained Movement Check                          │
│                                                              │
│  ⏱️  Waiting for 3 minutes of continuous movement...        │
│  📍 Tracking location updates                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              ✅ TRIP STARTED                                 │
│                                                              │
│  Origin: Recorded                                            │
│  Start Time: Recorded                                        │
│  Status: Tracking...                                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Active Trip Tracking                            │
│  ┌────────────────────────────────────────────────┐         │
│  │  📍 Recording GPS points every 30s/10m         │         │
│  │  📏 Calculating distance (Haversine)           │         │
│  │  ⏱️  Tracking duration                          │         │
│  │  🚀 Monitoring speed (avg & max)               │         │
│  │  🚗 Inferring mode of transport                │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  Live Display:                                               │
│  • Distance: 5.2 km                                          │
│  • Duration: 25 min                                          │
│  • Avg Speed: 12.5 km/h                                      │
│  • Detected Mode: Bus                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              USER ARRIVES AT DESTINATION                     │
│  (e.g., arrives at office)                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              App Detects Stop                                │
│                                                              │
│  Condition: Speed < 1 m/s                                    │
│  Timer: 0 seconds                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│            Stationary Duration Check                         │
│                                                              │
│  ⏱️  Waiting for 5 minutes stationary...                    │
│  📍 Monitoring for movement                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
   STILL STOPPED            MOVED AGAIN
        │                         │
        ▼                         ▼
┌───────────────────┐    ┌────────────────────┐
│ End Trip          │    │ Continue Trip      │
└────────┬──────────┘    └────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              ✅ TRIP ENDED                                   │
│                                                              │
│  Destination: Recorded                                       │
│  End Time: Recorded                                          │
│  Final Stats Calculated                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Validate Trip                                   │
│                                                              │
│  Check: Distance >= 300 meters?                              │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
       YES                       NO
        │                         │
        ▼                         ▼
┌───────────────────┐    ┌────────────────────┐
│ Save to           │    │ Discard Trip       │
│ Firestore         │    │ (Too Short)        │
└────────┬──────────┘    └────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              📱 NOTIFICATION                                 │
│                                                              │
│  "Trip Detected!"                                            │
│  8.2 km • 35 min • Bus                                       │
│  [Confirm] button                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              User Taps "Confirm"                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Trip Confirmation Screen                        │
│  ┌────────────────────────────────────────────────┐         │
│  │  📊 Trip Summary                               │         │
│  │  • Date: 08/10/2025                            │         │
│  │  • Time: 08:00 → 08:35                         │         │
│  │  • Distance: 8.2 km                            │         │
│  │  • Duration: 35 min                            │         │
│  │  • Avg Speed: 14.1 km/h                        │         │
│  │  • Detected Mode: Bus                          │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  🗺️  Map with Route                                         │
│                                                              │
│  📝 User Input:                                              │
│  • Purpose: [Work] [Shopping] [Other]...                    │
│  • Mode: [Bus ▼]                                            │
│  • Companions: [Optional]                                    │
│  • Cost: [Optional]                                          │
│  • Notes: [Optional]                                         │
│                                                              │
│  [Reject]  [Confirm Trip]                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
    CONFIRM                    REJECT
        │                         │
        ▼                         ▼
┌───────────────────┐    ┌────────────────────┐
│ Update Trip       │    │ Mark as Rejected   │
│ Status:           │    │ in Firestore       │
│ "confirmed"       │    └────────────────────┘
│                   │
│ Add user data:    │
│ • Purpose         │
│ • Confirmed mode  │
│ • Companions      │
│ • Cost            │
│ • Notes           │
└────────┬──────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              ✅ TRIP CONFIRMED                               │
│                                                              │
│  Data saved to Firestore                                     │
│  Available for analysis                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Return to Detection Screen                      │
│                                                              │
│  Status: "Detection Active"                                  │
│  Ready for next trip                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 Detection State Machine

```
┌─────────────────┐
│   INITIAL       │
│  (App Start)    │
└────────┬────────┘
         │
         │ startDetection()
         ▼
┌─────────────────┐
│   IDLE          │
│ (Not Detecting) │
└────────┬────────┘
         │
         │ startDetection()
         ▼
┌─────────────────────────────────────────┐
│   ACTIVE                                 │
│   (Detecting - No Current Trip)          │
│                                          │
│   • Monitoring GPS                       │
│   • Waiting for movement                 │
└────────┬────────────────────────────────┘
         │
         │ Movement detected (3 min)
         ▼
┌─────────────────────────────────────────┐
│   ACTIVE                                 │
│   (Detecting - Trip In Progress)         │
│                                          │
│   • Tracking route                       │
│   • Calculating stats                    │
│   • Inferring mode                       │
└────────┬────────────────────────────────┘
         │
         │ User stopped (5 min)
         ▼
┌─────────────────────────────────────────┐
│   DETECTED                               │
│   (Trip Ended - Awaiting Confirmation)   │
│                                          │
│   • Trip saved to Firestore              │
│   • Notification shown                   │
│   • Waiting for user action              │
└────────┬────────────────────────────────┘
         │
         │
    ┌────┴─────┐
    │          │
CONFIRM    REJECT
    │          │
    ▼          ▼
┌───────┐  ┌────────┐
│CONFIRM│  │ ACTIVE │
│  ED   │  │        │
└───┬───┘  └────────┘
    │
    │ Auto-return (1s)
    ▼
┌─────────────────┐
│   ACTIVE        │
│ (Ready for      │
│  next trip)     │
└─────────────────┘
```

---

## 🎯 Algorithm Flow

### Trip Start Detection

```
┌─────────────────────────────────────┐
│   GPS Location Update Received      │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Calculate Speed from GPS          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Is speed > 2.0 m/s?               │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
       YES           NO
        │             │
        ▼             ▼
┌───────────────┐  ┌──────────────┐
│ Start/Update  │  │ Reset        │
│ Movement      │  │ Movement     │
│ Timer         │  │ Timer        │
└───────┬───────┘  └──────────────┘
        │
        ▼
┌─────────────────────────────────────┐
│   Has movement lasted 3 minutes?    │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
       YES           NO
        │             │
        ▼             ▼
┌───────────────┐  ┌──────────────┐
│ START TRIP    │  │ Keep         │
│               │  │ Monitoring   │
│ • Record      │  └──────────────┘
│   origin      │
│ • Record      │
│   start time  │
│ • Initialize  │
│   tracking    │
└───────────────┘
```

### Trip End Detection

```
┌─────────────────────────────────────┐
│   GPS Location Update (Active Trip) │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Calculate Speed from GPS          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Is speed < 1.0 m/s?               │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
       YES           NO
        │             │
        ▼             ▼
┌───────────────┐  ┌──────────────┐
│ Start/Update  │  │ Reset        │
│ Stationary    │  │ Stationary   │
│ Timer         │  │ Timer        │
└───────┬───────┘  │              │
        │          │ Continue     │
        ▼          │ Tracking     │
┌───────────────┐  └──────────────┘
│ Has been      │
│ stationary    │
│ for 5 min?    │
└───────┬───────┘
        │
    ┌───┴────┐
    │        │
   YES      NO
    │        │
    ▼        ▼
┌───────┐ ┌──────┐
│ Check │ │ Keep │
│ Min   │ │ Wait │
│ Dist  │ └──────┘
└───┬───┘
    │
┌───┴────┐
│        │
>= 300m  < 300m
│        │
▼        ▼
┌────┐ ┌────────┐
│END │ │DISCARD │
│TRIP│ │ TRIP   │
└────┘ └────────┘
```

### Mode Detection

```
┌─────────────────────────────────────┐
│   Calculate Speed Statistics        │
│   • Average Speed                    │
│   • Maximum Speed                    │
│   • Speed Variance                   │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Max Speed <= 7 km/h?              │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
       YES           NO
        │             │
        ▼             ▼
    ┌───────┐   ┌─────────────────────┐
    │WALKING│   │ Max Speed <= 25?    │
    └───────┘   └──────────┬──────────┘
                           │
                    ┌──────┴──────┐
                   YES           NO
                    │             │
                    ▼             ▼
            ┌───────────────┐  ┌──────────────┐
            │ Avg < 12?     │  │ Max <= 60?   │
            └───────┬───────┘  └──────┬───────┘
                    │                 │
              ┌─────┴─────┐     ┌─────┴─────┐
             YES         NO    YES         NO
              │           │     │           │
              ▼           ▼     ▼           ▼
          ┌──────┐   ┌──────┐ ┌────┐  ┌──────────┐
          │CYCLE │   │E-BIKE│ │BIKE│  │ Max<=120?│
          └──────┘   └──────┘ └────┘  └────┬─────┘
                                            │
                                      ┌─────┴─────┐
                                     YES         NO
                                      │           │
                                      ▼           ▼
                              ┌───────────────┐ ┌───────┐
                              │ Variance > 15?│ │ TRAIN │
                              └───────┬───────┘ └───────┘
                                      │
                                ┌─────┴─────┐
                               YES         NO
                                │           │
                                ▼           ▼
                             ┌────┐     ┌─────┐
                             │BUS │     │ CAR │
                             └────┘     └─────┘
```

---

## 📊 Data Flow

```
┌──────────────┐
│   GPS        │
│   Sensor     │
└──────┬───────┘
       │
       │ Position Updates
       ▼
┌──────────────────────────────┐
│  TripDetectionService        │
│                              │
│  • Process GPS data          │
│  • Apply detection logic     │
│  • Calculate statistics      │
│  • Infer mode                │
└──────┬───────────────────────┘
       │
       │ Trip Events
       │ (start/update/end)
       ▼
┌──────────────────────────────┐
│  TripDetectionCubit          │
│                              │
│  • Manage state              │
│  • Handle events             │
│  • Coordinate UI updates     │
└──────┬───────────────────────┘
       │
       │ State Changes
       ▼
┌──────────────────────────────┐
│  UI Screens                  │
│                              │
│  • Detection Screen          │
│  • Confirmation Screen       │
└──────┬───────────────────────┘
       │
       │ User Actions
       │ (confirm/reject)
       ▼
┌──────────────────────────────┐
│  AutoTripRepository          │
│                              │
│  • Save to Firestore         │
│  • Update trip status        │
│  • Query trips               │
└──────┬───────────────────────┘
       │
       │ Firestore Operations
       ▼
┌──────────────────────────────┐
│  Firestore Database          │
│                              │
│  Collection: auto_trips      │
└──────────────────────────────┘
```

---

## 🔄 Background Processing

```
┌─────────────────────────────────────┐
│   App in Foreground                 │
└──────────────┬──────────────────────┘
               │
               │ User presses Home
               ▼
┌─────────────────────────────────────┐
│   App Moves to Background           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│   Foreground Service Starts         │
│   (Android)                          │
│                                      │
│   • Persistent notification          │
│   • GPS tracking continues           │
└──────────────┬──────────────────────┘
               │
               │ GPS Updates
               ▼
┌─────────────────────────────────────┐
│   TripDetectionService              │
│   (Running in Background)            │
│                                      │
│   • Processes location updates       │
│   • Detects trip start/end           │
│   • Saves data locally               │
└──────────────┬──────────────────────┘
               │
               │ Trip Detected
               ▼
┌─────────────────────────────────────┐
│   Local Notification                │
│                                      │
│   "Trip Detected!"                   │
│   Tap to confirm                     │
└──────────────┬──────────────────────┘
               │
               │ User taps notification
               ▼
┌─────────────────────────────────────┐
│   App Returns to Foreground         │
│   Opens Confirmation Screen          │
└─────────────────────────────────────┘
```

---

**Visual Guide Version**: 1.0.0  
**Last Updated**: 2025-10-08
