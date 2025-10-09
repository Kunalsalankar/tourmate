// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'firebase_options.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/trip_notification_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize timezone data for scheduled notifications
  tz.initializeTimeZones();
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  
  // Initialize trip notification scheduler
  final tripNotificationScheduler = TripNotificationScheduler(
    notificationService: notificationService,
  );
  await tripNotificationScheduler.initialize();
  
  runApp(
    OverlaySupport.global(
      child: MyApp(tripNotificationScheduler: tripNotificationScheduler),
    ),
  );
}