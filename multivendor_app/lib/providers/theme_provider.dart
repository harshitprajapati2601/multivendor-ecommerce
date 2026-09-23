import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider with ChangeNotifier {
  static const String _baseStorageKey = 'app_theme_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ThemeMode _themeMode = ThemeMode.light;
  String? _currentAccountKey;

  ThemeMode get themeMode => _themeMode;
  String? get currentAccountKey => _currentAccountKey;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider();

  String _getKeyForAccount(String? accountKey) {
    if (accountKey == null || accountKey.isEmpty) {
      return _baseStorageKey;
    }
    return '${_baseStorageKey}_$accountKey';
  }

  /// Synchronizes theme mode for the given logged-in [accountKey] (e.g. userId or email).
  /// If [accountKey] is null or empty (logged out), theme resets to ThemeMode.light.
  Future<void> updateAccountKey(String? accountKey) async {
    if (_currentAccountKey == accountKey && accountKey != null) return;
    _currentAccountKey = accountKey;

    if (accountKey == null || accountKey.isEmpty) {
      _themeMode = ThemeMode.light;
      notifyListeners();
      return;
    }

    final key = _getKeyForAccount(accountKey);
    try {
      final saved = await _storage.read(key: key);
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    } catch (_) {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    if (_currentAccountKey != null && _currentAccountKey!.isNotEmpty) {
      final key = _getKeyForAccount(_currentAccountKey);
      try {
        final val = mode == ThemeMode.dark ? 'dark' : 'light';
        await _storage.write(key: key, value: val);
      } catch (_) {}
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
