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
  print('\n\n========================================');
  print('🚀 MAIN FUNCTION STARTED - VERSION 2.0');
  print('========================================\n');
  
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize timezone data for scheduled notifications
  tz.initializeTimeZones();
  
  // Initialize notification service (don't request permissions yet - will be done in splash screen)
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Initialize trip notification scheduler
  final tripNotificationScheduler = TripNotificationScheduler(
    notificationService: notificationService,
  );
  await tripNotificationScheduler.initialize();
  
  print('\n🔧 [MAIN] Notification scheduler created: ${tripNotificationScheduler != null}');
  print('🔧 [MAIN] Starting app with scheduler...\n');
  
  runApp(
    OverlaySupport.global(
      child: MyApp(tripNotificationScheduler: tripNotificationScheduler),
    ),
  );
}