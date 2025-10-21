// firebase_messaging_background.dart
// Handles data-only FCM in background to render rich notifications with images.

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';
import '../models/location_comment_model.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Ensure Firebase is initialized in this isolate
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    // Initialize notifications in this isolate too
    final notif = NotificationService();
    await notif.initialize();

    final data = message.data;

    // Expected keys (adjust to your backend payload):
    // type=nearby_comment, userName, comment, photoUrl(optional), commentId
    final type = data['type'] as String?;
    if (type == 'nearby_comment') {
      final userName = data['userName'] as String? ?? 'Someone';
      final commentText = data['comment'] as String? ?? '';
      final photoUrl = data['image'] as String? ?? data['photoUrl'] as String?; // support either key
      final commentId = data['commentId'] as String?;

      final model = LocationCommentModel(
        id: commentId,
        uid: 'unknown',
        userName: userName,
        comment: commentText,
        lat: 0,
        lng: 0,
        timestamp: DateTime.now(),
        photoUrl: photoUrl,
      );

      await notif.showLocationCommentNotification(model);
    }
  } catch (e) {
    if (kDebugMode) {
      print('FCM background handler error: $e');
    }
  }
}
