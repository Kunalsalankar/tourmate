# Trip Notifications Setup Guide

## Overview
This system provides real-time notifications for future trips when their start time arrives. Users will receive:
1. A notification **1 hour before** the trip starts (reminder)
2. A notification **at the exact trip start time**

## Implementation Details

### Components Added

#### 1. **NotificationService** (`lib/core/services/notification_service.dart`)
Enhanced with scheduled notification methods:
- `scheduleTripNotification()` - Schedules notification at trip start time
- `scheduleTripReminderNotification()` - Schedules reminder notification before trip
- `cancelTripNotification()` - Cancels scheduled notifications for a trip
- `getPendingNotifications()` - Lists all pending notifications

#### 2. **TripNotificationScheduler** (`lib/core/services/trip_notification_scheduler.dart`)
New service that manages trip notification scheduling:
- `initialize()` - Initializes timezone data
- `scheduleNotificationsForTrip()` - Schedules both notifications for a future trip
- `cancelNotificationsForTrip()` - Cancels notifications when trip is deleted
- `rescheduleNotificationsForTrip()` - Updates notifications when trip is modified

#### 3. **TripCubit** (`lib/cubit/trip_cubit.dart`)
Updated to integrate notification scheduling:
- `createTrip()` - Automatically schedules notifications for future trips
- `updateTrip()` - Reschedules notifications when trip details change
- `deleteTrip()` - Cancels notifications when trip is deleted

#### 4. **Main App** (`lib/main.dart` & `lib/app/app.dart`)
- Initializes timezone data
- Creates and initializes NotificationService
- Creates TripNotificationScheduler
- Passes scheduler to TripCubit

### Dependencies Added
- `timezone: ^0.9.2` - For scheduling notifications at specific times

## How It Works

### When a User Creates a Future Trip:
1. User fills out trip form with future date/time
2. Trip is saved to Firestore
3. System automatically schedules two notifications:
   - Reminder: 1 hour before trip start
   - Start notification: At exact trip start time
4. Notifications are stored locally on the device

### When Trip Start Time Arrives:
1. Device triggers the scheduled notification
2. User sees notification: "Trip Starting Now! 🚀"
3. Notification includes trip details (origin → destination)
4. User can tap notification to open the app

### When User Updates a Trip:
1. System cancels old notifications
2. If still a future trip, schedules new notifications with updated time

### When User Deletes a Trip:
1. System cancels all scheduled notifications for that trip

## Notification Channels

### Trip Reminders Channel
- **ID**: `trip_reminder_channel`
- **Name**: Trip Reminders
- **Importance**: High
- **Description**: Notifications for upcoming trip reminders

## Permissions Required

### Android
- `SCHEDULE_EXACT_ALARM` - For exact time notifications
- `POST_NOTIFICATIONS` - For showing notifications (Android 13+)

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
```

### iOS
- Notification permissions are requested automatically on first launch

## Testing

### To Test Notifications:
1. Create a future trip with start time 2-3 minutes from now
2. Wait for notifications to appear
3. Check notification content and timing

### To Debug:
```dart
// In your code, call this to see pending notifications:
final scheduler = TripNotificationScheduler(notificationService: NotificationService());
await scheduler.getPendingNotifications();
```

## Important Notes

1. **Timezone**: The system uses the device's local timezone
2. **Background**: Notifications work even when app is closed
3. **Battery**: Uses `exactAllowWhileIdle` mode to work in Doze mode
4. **Persistence**: Notifications survive app restarts
5. **Limits**: Only future trips get notifications (not active/past trips)

## Customization

### Change Reminder Time
Edit `trip_notification_scheduler.dart`:
```dart
await scheduleNotificationsForTrip(
  trip,
  includeReminder: true,
  reminderBefore: Duration(hours: 2), // Change from 1 to 2 hours
);
```

### Disable Reminders
Set `includeReminder: false` when calling `scheduleNotificationsForTrip()`

### Custom Notification Messages
Edit notification titles/bodies in `notification_service.dart`:
- Line 195-196: Trip start notification
- Line 252-253: Reminder notification

## Troubleshooting

### Notifications Not Appearing?
1. Check notification permissions are granted
2. Verify trip is marked as `TripType.future`
3. Ensure trip time is in the future
4. Check device battery optimization settings
5. Verify timezone is set correctly

### Notifications Appearing at Wrong Time?
1. Check device timezone settings
2. Verify trip time is saved correctly in Firestore
3. Check timezone initialization in `main.dart`

## Future Enhancements
- Multiple reminder options (24h, 12h, 1h before)
- Custom notification sounds
- Notification action buttons (View Trip, Start Navigation)
- Push notifications via Firebase Cloud Messaging
- Notification history/logs
