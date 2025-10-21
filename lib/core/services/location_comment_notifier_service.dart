import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/location_comment_model.dart';
import '../repositories/location_comment_repository.dart';
import 'location_service.dart';
import 'notification_service.dart';

class LocationCommentNotifierService {
  static final LocationCommentNotifierService _instance = LocationCommentNotifierService._internal();
  factory LocationCommentNotifierService() => _instance;
  LocationCommentNotifierService._internal();

  final LocationService _locationService = LocationService();
  final LocationCommentRepository _commentRepository = LocationCommentRepository();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<Position>? _locationSub;
  bool _isRunning = false;
  DateTime? _lastCheck;
  final Duration _checkDebounce = const Duration(seconds: 20);
  final Map<String, DateTime> _notifiedAt = {};
  final Duration _notificationCooldown = const Duration(hours: 2);

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;
    final started = await _locationService.startTracking();
    if (!started) return;

    _locationSub = _locationService.locationStream.listen(_onLocation);
    // Immediate one-shot check without waiting for debounce
    final pos = _locationService.currentPosition ?? await _locationService.getCurrentPosition();
    if (pos != null) {
      await _onLocation(pos, force: true);
    }
    _isRunning = true;
  }

  void stop() {
    _locationSub?.cancel();
    _locationSub = null;
    _isRunning = false;
  }

  void dispose() {
    stop();
  }

  Future<void> _onLocation(Position position, {bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastCheck != null && now.difference(_lastCheck!) < _checkDebounce) {
      return;
    }
    _lastCheck = now;

    final nearby = await _commentRepository.getCommentsNearLocation(
      position.latitude,
      position.longitude,
      0.2,
    );

    // Debug: show how many comments were found nearby
    // ignore: avoid_print
    print('[LocationCommentNotifier] Nearby comments within 200m: ${nearby.length}');

    for (final LocationCommentModel c in nearby) {
      final last = _notifiedAt[c.id ?? '${c.uid}-${c.timestamp.millisecondsSinceEpoch}'];
      if (last != null && now.difference(last) < _notificationCooldown) {
        continue;
      }
      // ignore: avoid_print
      print('[LocationCommentNotifier] Notifying comment ${c.id ?? c.uid} by ${c.userName}');
      await _notificationService.showLocationCommentNotification(c);
      _notifiedAt[c.id ?? '${c.uid}-${c.timestamp.millisecondsSinceEpoch}'] = now;
    }
  }
}
