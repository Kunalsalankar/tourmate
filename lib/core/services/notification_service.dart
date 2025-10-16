import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/place_model.dart';

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
    try {
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
      final initialized = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      if (initialized == true) {
        debugPrint('✅ Notification service initialized successfully');
      } else {
        debugPrint('⚠️ Notification service initialization returned false');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
      rethrow;
    }
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
    try {
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
      debugPrint('✅ Nearby place notification shown: ${place.name}');
    } catch (e) {
      debugPrint('❌ Error showing nearby place notification: $e');
    }
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

  /// Show a notification when a new trip is detected
  Future<void> showTripDetectedNotification({
    required String mode,
    required String origin,
  }) async {
    try {
      // Android notification details with custom sound and vibration
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'trip_detection_channel',
        'Trip Detection',
        channelDescription: 'Notifications for automatic trip detection',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      // iOS notification details
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      // Notification details for all platforms
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Show the notification
      await _flutterLocalNotificationsPlugin.show(
        _getNextNotificationId(),
        '🚗 New Trip Detected!',
        'Started $mode from $origin. Tracking your journey...',
        platformChannelSpecifics,
        payload: 'trip_started',
      );
      debugPrint('✅ Trip detected notification shown: $mode from $origin');
    } catch (e) {
      debugPrint('❌ Error showing trip detected notification: $e');
    }
  }

  /// Show a notification when a trip ends
  Future<void> showTripEndedNotification({
    required String mode,
    required String destination,
    required double distanceKm,
    required int durationMinutes,
  }) async {
    try {
      // Format duration
      String durationText;
      if (durationMinutes < 60) {
        durationText = '$durationMinutes min';
      } else {
        final hours = durationMinutes ~/ 60;
        final mins = durationMinutes % 60;
        durationText = '${hours}h ${mins}min';
      }

      // Android notification details
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'trip_detection_channel',
        'Trip Detection',
        channelDescription: 'Notifications for automatic trip detection',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      // iOS notification details
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      // Notification details for all platforms
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Show the notification
      await _flutterLocalNotificationsPlugin.show(
        _getNextNotificationId(),
        '✅ Trip Completed!',
        '$mode trip ended at $destination. ${distanceKm.toStringAsFixed(2)}km in $durationText',
        platformChannelSpecifics,
        payload: 'trip_ended',
      );
      debugPrint('✅ Trip ended notification shown: $mode to $destination');
    } catch (e) {
      debugPrint('❌ Error showing trip ended notification: $e');
    }
  }

  /// Show a notification for trip update (optional, for long trips)
  Future<void> showTripUpdateNotification({
    required String mode,
    required double distanceKm,
    required int durationMinutes,
  }) async {
    // Format duration
    String durationText;
    if (durationMinutes < 60) {
      durationText = '$durationMinutes min';
    } else {
      final hours = durationMinutes ~/ 60;
      final mins = durationMinutes % 60;
      durationText = '${hours}h ${mins}min';
    }

    // Android notification details (low priority for updates)
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'trip_updates_channel',
      'Trip Updates',
      channelDescription: 'Ongoing trip progress updates',
      importance: Importance.low,
      priority: Priority.low,
      showWhen: true,
      enableVibration: false,
      playSound: false,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    // iOS notification details
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    // Notification details for all platforms
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Show the notification
    await _flutterLocalNotificationsPlugin.show(
      0, // Use fixed ID so it updates the same notification
      ' Trip in Progress',
      '$mode • ${distanceKm.toStringAsFixed(2)}km • $durationText',
      platformChannelSpecifics,
      payload: 'trip_update',
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
}