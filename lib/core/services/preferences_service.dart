import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app preferences and first-time launch detection
class PreferencesService {
  // Singleton instance
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _keyFirstLaunch = 'is_first_launch';
  static const String _keyNotificationPermissionRequested = 'notification_permission_requested';

  /// Initialize the preferences service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if this is the first time the app is launched
  bool get isFirstLaunch {
    return _prefs?.getBool(_keyFirstLaunch) ?? true;
  }

  /// Mark that the app has been launched
  Future<void> setFirstLaunchComplete() async {
    await _prefs?.setBool(_keyFirstLaunch, false);
  }

  /// Check if notification permission has been requested
  bool get hasRequestedNotificationPermission {
    return _prefs?.getBool(_keyNotificationPermissionRequested) ?? false;
  }

  /// Mark that notification permission has been requested
  Future<void> setNotificationPermissionRequested() async {
    await _prefs?.setBool(_keyNotificationPermissionRequested, true);
  }

  /// Reset all preferences (for testing)
  Future<void> reset() async {
    await _prefs?.clear();
  }
}
