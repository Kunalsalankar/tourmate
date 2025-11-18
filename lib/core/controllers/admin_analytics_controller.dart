import 'package:flutter/foundation.dart';

import '../models/admin_analytics_model.dart';
import '../services/admin_analytics_service.dart';

enum AnalyticsRangePreset {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

class AdminAnalyticsController extends ChangeNotifier {
  final AdminAnalyticsService _service;

  AnalyticsRangePreset _preset = AnalyticsRangePreset.thisWeek;
  DateTime _fromDate = _startOfToday();
  DateTime _toDate = _endOfToday();
  String _mode = 'all';

  bool _isLoading = false;
  String? _error;
  AdminAnalytics _analytics = AdminAnalytics.empty();
  bool _hasLoadedOnce = false;

  AdminAnalyticsController(this._service) {
    applyPreset(_preset, notify: false);
    _reload();
  }

  AnalyticsRangePreset get preset => _preset;
  DateTime get fromDate => _fromDate;
  DateTime get toDate => _toDate;
  String get mode => _mode;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AdminAnalytics get analytics => _analytics;
  bool get hasLoadedOnce => _hasLoadedOnce;

  void applyPreset(AnalyticsRangePreset preset, {bool notify = true}) {
    _preset = preset;
    final now = DateTime.now();

    switch (preset) {
      case AnalyticsRangePreset.today:
        _fromDate = _startOfDay(now);
        _toDate = _endOfDay(now);
        break;
      case AnalyticsRangePreset.thisWeek:
        final weekday = now.weekday; // 1 (Mon) .. 7 (Sun)
        final start = now.subtract(Duration(days: weekday - 1));
        _fromDate = _startOfDay(start);
        _toDate = _endOfDay(start.add(const Duration(days: 6)));
        break;
      case AnalyticsRangePreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        _fromDate = _startOfDay(start);
        _toDate = _endOfDay(end);
        break;
      case AnalyticsRangePreset.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        _fromDate = _startOfDay(start);
        _toDate = _endOfDay(end);
        break;
      case AnalyticsRangePreset.custom:
        break;
    }

    if (notify) {
      notifyListeners();
      _reload();
    }
  }

  void setCustomFrom(DateTime date) {
    _preset = AnalyticsRangePreset.custom;
    _fromDate = _startOfDay(date);
    if (_fromDate.isAfter(_toDate)) {
      _toDate = _endOfDay(date);
    }
    notifyListeners();
    _reload();
  }

  void setCustomTo(DateTime date) {
    _preset = AnalyticsRangePreset.custom;
    _toDate = _endOfDay(date);
    if (_toDate.isBefore(_fromDate)) {
      _fromDate = _startOfDay(date);
    }
    notifyListeners();
    _reload();
  }

  void setMode(String mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    _reload();
  }

  Future<void> _reload() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final raw = await _service.fetchAnalytics(
        startDate: _fromDate,
        endDate: _toDate,
        travelMode: _mode,
      );

      final tripsByMode = (raw['tripsByMode'] as Map<dynamic, dynamic>?)
              ?.map((key, value) => MapEntry(key.toString(), (value ?? 0) as int)) ??
          <String, int>{};

      int _m(String key) => tripsByMode[key] ?? 0;

      _analytics = AdminAnalytics(
        totalTrips: (raw['totalTrips'] as num? ?? 0).toInt(),
        carTrips: _m('car'),
        bikeTrips: _m('bike'),
        busTrips: _m('bus'),
        walkTrips: _m('walk'),
        totalDistance: (raw['totalDistanceKm'] as num? ?? 0).toDouble(),
        totalUsers: (raw['totalUsers'] as num? ?? 0).toInt(),
        avgTripDuration: (raw['avgTripDurationMinutes'] as num? ?? 0).toDouble(),
      );
      _hasLoadedOnce = true;
    } catch (e) {
      _error = e.toString();
      _analytics = AdminAnalytics.empty();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static DateTime _startOfToday() => _startOfDay(DateTime.now());
  static DateTime _endOfToday() => _endOfDay(DateTime.now());

  static DateTime _startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static DateTime _endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
}

