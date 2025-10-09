import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/place_model.dart';
import '../models/trip_model.dart';

/// A service that handles local notifications
class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Flutter Local Notifications plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Notification IDs
  int _notificationId = 0;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize settings for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialize settings for all platforms
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    // Request permissions for iOS
    final bool? result = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return result ?? false;
  }

  /// Show a notification for a nearby place
  Future<void> showNearbyPlaceNotification(PlaceModel place, String s) async {
    // Android notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'nearby_places_channel',
      'Nearby Places',
      channelDescription: 'Notifications for nearby places of interest',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    // iOS notification details
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Notification details for all platforms
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Show the notification
    await _flutterLocalNotificationsPlugin.show(
      _getNextNotificationId(),
      'Nearby: ${place.name}',
      'You are near ${place.name}. ${place.address}',
      platformChannelSpecifics,
      payload: place.placeId,
    );
  }
  
  /// Show a notification for route deviation
  Future<void> showRouteDeviationNotification() async {
    // Android notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'route_deviation_channel',
      'Route Deviation',
      channelDescription: 'Notifications for route deviation alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    // iOS notification details
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Notification details for all platforms
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Show the notification
    await _flutterLocalNotificationsPlugin.show(
      _getNextNotificationId(),
      'Route Deviation',
      'You have deviated from the planned route. Tap to recalculate.',
      platformChannelSpecifics,
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    // This can be used to navigate to a place details screen
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Get the next notification ID
  int _getNextNotificationId() {
    return _notificationId++;
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Schedule a notification for a future trip
  Future<void> scheduleTripNotification(TripModel trip) async {
    if (trip.tripType != TripType.future) {
      return; // Only schedule notifications for future trips
    }

    // Calculate notification time (at trip start time)
    final scheduledDate = tz.TZDateTime.from(trip.time, tz.local);
    
    // Don't schedule if the time has already passed
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    // Android notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'trip_reminder_channel',
      'Trip Reminders',
      channelDescription: 'Notifications for upcoming trip reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    // iOS notification details
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Notification details for all platforms
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Schedule the notification
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      trip.id?.hashCode ?? trip.tripNumber.hashCode, // Use trip ID hash as notification ID
      'Trip Starting Now! 🚀',
      'Your trip from ${trip.origin} to ${trip.destination} is starting now. Have a safe journey!',
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: trip.id ?? trip.tripNumber,
    );
  }

  /// Schedule a reminder notification before trip start (e.g., 1 hour before)
  Future<void> scheduleTripReminderNotification(
    TripModel trip, {
    Duration reminderBefore = const Duration(hours: 1),
  }) async {
    if (trip.tripType != TripType.future) {
      return;
    }

    // Calculate notification time (before trip start time)
    final reminderTime = trip.time.subtract(reminderBefore);
    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
    
    // Don't schedule if the time has already passed
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    // Android notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'trip_reminder_channel',
      'Trip Reminders',
      channelDescription: 'Notifications for upcoming trip reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    // iOS notification details
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Notification details for all platforms
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Schedule the reminder notification
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      (trip.id?.hashCode ?? trip.tripNumber.hashCode) + 1, // Different ID for reminder
      'Upcoming Trip Reminder ⏰',
      'Your trip from ${trip.origin} to ${trip.destination} starts in ${reminderBefore.inHours} hour(s). Get ready!',
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: trip.id ?? trip.tripNumber,
    );
  }

  /// Cancel a scheduled trip notification
  Future<void> cancelTripNotification(String tripId) async {
    final notificationId = tripId.hashCode;
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
    await _flutterLocalNotificationsPlugin.cancel(notificationId + 1); // Cancel reminder too
  }

  /// Get all pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }
}