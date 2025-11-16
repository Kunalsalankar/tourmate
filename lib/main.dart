// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/firebase_messaging_background.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/location_comment_notifier_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase (guard against duplicate init)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } else {
      // Access existing default app to ensure core is ready
      Firebase.app();
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
    // Safe to ignore duplicate-app: default already initialized by platform/plugins
  }
  
  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.initialize();
  if (!kIsWeb) {
    await notificationService.requestPermissions();
    // Android 13+ requires explicit POST_NOTIFICATIONS runtime permission
    await Permission.notification.request();
  }

  // Start Location Comment Notifier Service (for real-time comment notifications)
  if (!kIsWeb) {
    try {
      debugPrint('🔄 Starting location comment notifications...');
      final service = LocationCommentNotifierService();
      await service.start();
      debugPrint('✅ Location comment notifications started successfully');
      debugPrint('🔍 Service running: ${service.isRunning}');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Could not start location comment notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Register background handler for data-only FCM
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // Ensure foreground notifications show on iOS (no-op on Android)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
  
  // Optimize and configure Google Maps renderer on Android
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final GoogleMapsFlutterPlatform mapsImpl = GoogleMapsFlutterPlatform.instance;
    if (mapsImpl is GoogleMapsFlutterAndroid) {
      // Optional overrides from .env
      final rendererEnv = dotenv.env['MAPS_ANDROID_RENDERER']?.toLowerCase(); // latest | legacy
      final viewSurfaceEnv = dotenv.env['MAPS_ANDROID_VIEW_SURFACE']?.toLowerCase(); // true | false

      final bool useSurface = viewSurfaceEnv == null
          ? true
          : (viewSurfaceEnv == '1' || viewSurfaceEnv == 'true' || viewSurfaceEnv == 'yes');
      mapsImpl.useAndroidViewSurface = useSurface; // Hybrid composition surface when true

      AndroidMapRenderer target = AndroidMapRenderer.latest;
      if (rendererEnv == 'legacy') target = AndroidMapRenderer.legacy;

      try {
        await mapsImpl.initializeWithRenderer(target);
      } catch (_) {
        // Fallback to legacy on failures (helps with some Mali/older devices)
        try {
          await mapsImpl.initializeWithRenderer(AndroidMapRenderer.legacy);
        } catch (_) {}
      }
    }
  }
  
  runApp(
    OverlaySupport.global(
      child: const MyApp(),
    ),
  );
}