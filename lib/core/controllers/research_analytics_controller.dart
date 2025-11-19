import 'package:flutter/foundation.dart';

import '../models/research_analytics_model.dart';
import '../services/research_analytics_service.dart';

enum ResearchPreset {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

class ResearchAnalyticsController extends ChangeNotifier {
  final ResearchAnalyticsService _service;

  ResearchPreset _preset = ResearchPreset.thisMonth;
  DateTime _from = _startOfDay(DateTime.now().subtract(const Duration(days: 29)));
  DateTime _to = _endOfDay(DateTime.now());
  String _mode = 'all';

  bool _loading = false;
  String? _error;
  ResearchAnalytics _data = ResearchAnalytics.empty();

  ResearchAnalyticsController(this._service) {
    applyPreset(_preset, notify: false);
    _reload();
  }

  ResearchPreset get preset => _preset;
  DateTime get from => _from;
  DateTime get to => _to;
  String get mode => _mode;
  bool get loading => _loading;
  String? get error => _error;
  ResearchAnalytics get data => _data;

  void applyPreset(ResearchPreset preset, {bool notify = true}) {
    _preset = preset;
    final now = DateTime.now();
    switch (preset) {
      case ResearchPreset.today:
        _from = _startOfDay(now);
        _to = _endOfDay(now);
        break;
      case ResearchPreset.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        _from = _startOfDay(start);
        _to = _endOfDay(start.add(const Duration(days: 6)));
        break;
      case ResearchPreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        _from = _startOfDay(start);
        _to = _endOfDay(end);
        break;
      case ResearchPreset.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31);
        _from = _startOfDay(start);
        _to = _endOfDay(end);
        break;
      case ResearchPreset.custom:
        break;
    }
    if (notify) {
      notifyListeners();
      _reload();
    }
  }

  void setFrom(DateTime date) {
    _preset = ResearchPreset.custom;
    _from = _startOfDay(date);
    if (_from.isAfter(_to)) _to = _endOfDay(date);
    notifyListeners();
    _reload();
  }

  void setTo(DateTime date) {
    _preset = ResearchPreset.custom;
    _to = _endOfDay(date);
    if (_to.isBefore(_from)) _from = _startOfDay(date);
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
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _service.fetch(from: _from, to: _to, mode: _mode);
    } catch (e) {
      _error = e.toString();
      _data = ResearchAnalytics.empty();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  static DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static DateTime _endOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
}
