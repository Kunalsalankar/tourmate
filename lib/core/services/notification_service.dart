import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
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

  /// Request notification permissions (for both Android 13+ and iOS)
  Future<bool> requestPermissions() async {
    // Request permissions for Android 13+ (API level 33+)
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        debugPrint('Notification permission denied');
        return false;
      }
    }

    // Request permissions for iOS
    final bool? iosResult = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return iosResult ?? true; // Return true for Android if permission granted
  }

  /// Check if notification permissions are granted
  Future<bool> arePermissionsGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
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
    debugPrint('📅 [NOTIFICATION] Attempting to schedule trip notification');
    debugPrint('   Trip ID: ${trip.id ?? trip.tripNumber}');
    debugPrint('   Trip Type: ${trip.tripType}');
    debugPrint('   Trip Time: ${trip.time}');
    
    if (trip.tripType != TripType.future) {
      debugPrint('   ❌ Not a future trip, skipping notification');
      return; // Only schedule notifications for future trips
    }

    // Calculate notification time (at trip start time)
    final scheduledDate = tz.TZDateTime.from(trip.time, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    
    debugPrint('   Scheduled Date: $scheduledDate');
    debugPrint('   Current Time: $now');
    debugPrint('   Time Until Trip: ${scheduledDate.difference(now).inMinutes} minutes');
    
    // Don't schedule if the time has already passed
    if (scheduledDate.isBefore(now)) {
      debugPrint('   ❌ Trip time has passed, skipping notification');
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
    final notificationId = trip.id?.hashCode ?? trip.tripNumber.hashCode;
    debugPrint('   Notification ID: $notificationId');
    
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Trip Starting Now! 🚀',
        'Your trip from ${trip.origin} to ${trip.destination} is starting now. Have a safe journey!',
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: trip.id ?? trip.tripNumber,
      );
      debugPrint('   ✅ Trip notification scheduled successfully!');
    } catch (e) {
      debugPrint('   ❌ Error scheduling notification: $e');
      rethrow;
    }
  }

  /// Schedule a reminder notification before trip start (e.g., 1 hour before)
  Future<void> scheduleTripReminderNotification(
    TripModel trip, {
    Duration reminderBefore = const Duration(hours: 1),
  }) async {
    debugPrint('⏰ [NOTIFICATION] Attempting to schedule reminder notification');
    debugPrint('   Reminder Before: ${reminderBefore.inMinutes} minutes');
    
    if (trip.tripType != TripType.future) {
      debugPrint('   ❌ Not a future trip, skipping reminder');
      return;
    }

    // Calculate notification time (before trip start time)
    final reminderTime = trip.time.subtract(reminderBefore);
    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    
    debugPrint('   Reminder Time: $scheduledDate');
    debugPrint('   Current Time: $now');
    
    // Don't schedule if the time has already passed
    if (scheduledDate.isBefore(now)) {
      debugPrint('   ❌ Reminder time has passed, skipping');
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
    final notificationId = (trip.id?.hashCode ?? trip.tripNumber.hashCode) + 1;
    debugPrint('   Reminder Notification ID: $notificationId');
    
    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Upcoming Trip Reminder ⏰',
        'Your trip from ${trip.origin} to ${trip.destination} starts in ${reminderBefore.inHours} hour(s). Get ready!',
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: trip.id ?? trip.tripNumber,
      );
      debugPrint('   ✅ Reminder notification scheduled successfully!');
    } catch (e) {
      debugPrint('   ❌ Error scheduling reminder: $e');
      rethrow;
    }
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