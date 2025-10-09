import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/trip_model.dart';
import 'notification_service.dart';

/// Service to manage scheduling notifications for trips
class TripNotificationScheduler {
  final NotificationService _notificationService;

  TripNotificationScheduler({required NotificationService notificationService})
      : _notificationService = notificationService;

  /// Initialize timezone data
  Future<void> initialize() async {
    // Timezone is already initialized in main.dart
    // Just set the local location
    final locationName = tz.local.name;
    tz.setLocalLocation(tz.getLocation(locationName));
  }

  /// Schedule notifications for a future trip
  /// This schedules both:
  /// 1. A notification at trip start time
  /// 2. A reminder notification 1 hour before (optional)
  Future<void> scheduleNotificationsForTrip(
    TripModel trip, {
    bool includeReminder = true,
  }) async {
    print('\n🔔 [SCHEDULER] scheduleNotificationsForTrip called');
    print('   Trip ID: ${trip.id}');
    print('   Trip Type: ${trip.tripType}');
    print('   Include Reminder: $includeReminder');
    
    if (trip.tripType != TripType.future || trip.id == null) {
      print('   ❌ Cannot schedule: tripType=${trip.tripType}, id=${trip.id}');
      return;
    }

    try {
      print('   📱 Scheduling trip start notification...');
      // Schedule notification at trip start time
      await _notificationService.scheduleTripNotification(trip);

      // Schedule reminder notification 1 hour before
      if (includeReminder) {
        print('   ⏰ Scheduling reminder notification...');
        await _notificationService.scheduleTripReminderNotification(
          trip,
          reminderBefore: const Duration(hours: 1),
        );
      }
      print('   ✅ All notifications scheduled successfully!');
    } catch (e) {
      // Log error but don't throw - notification scheduling shouldn't block trip creation
      print('   ❌ Error scheduling trip notifications: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  /// Cancel notifications for a trip
  Future<void> cancelNotificationsForTrip(String tripId) async {
    try {
      await _notificationService.cancelTripNotification(tripId);
    } catch (e) {
      print('Error canceling trip notifications: $e');
    }
  }

  /// Reschedule notifications for an updated trip
  Future<void> rescheduleNotificationsForTrip(
    TripModel trip, {
    bool includeReminder = true,
  }) async {
    if (trip.id == null) return;

    // Cancel existing notifications
    await cancelNotificationsForTrip(trip.id!);

    // Schedule new notifications if it's a future trip
    if (trip.tripType == TripType.future) {
      await scheduleNotificationsForTrip(trip, includeReminder: includeReminder);
    }
  }

  /// Get all pending notification requests
  Future<void> getPendingNotifications() async {
    final pending = await _notificationService.getPendingNotifications();
    print('Pending notifications: ${pending.length}');
    for (final notification in pending) {
      print('ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
  }
}
