import 'package:flutter/foundation.dart';

/// Central place for configuration constants.
class AppConfig {
  AppConfig._();

  static String? customBaseUrl;

  static List<String> get candidateBaseUrls => [
    if (customBaseUrl != null) customBaseUrl!,
    const String.fromEnvironment('API_BASE_URL', defaultValue: ''),
    'http://localhost:8080/api',
    'http://10.0.2.2:8080/api',
    'http://127.0.0.1:8080/api',
  ].where((s) => s.isNotEmpty).toSet().toList();

  static String get _defaultBaseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }

    if (const String.fromEnvironment('API_BASE_URL').isNotEmpty) {
      return const String.fromEnvironment('API_BASE_URL');
    }

    if (kIsWeb) return 'http://localhost:8080/api';

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }

    return 'http://localhost:8080/api';
  }

  static String get apiBaseUrl => _defaultBaseUrl;

  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;

  static const String googleWebClientId =
      '984564758381-j3h58nipta62vt7eq32rk6dnqnqp5p2u.apps.googleusercontent.com';

  static const String appName = 'MultiMart';

  /// The backend serves uploaded photos (products, avatars) from the web
  /// root ("/uploads/..."), not under "/api" like every other endpoint.
  /// This strips a trailing "/api" off [apiBaseUrl] so image URLs resolve
  /// correctly regardless of which base URL was configured.
  static String get imageOrigin {
    if (apiBaseUrl.endsWith('/api')) {
      return apiBaseUrl.substring(0, apiBaseUrl.length - 4);
    }
    return apiBaseUrl;
  }

  /// Turns a relative path returned by the backend (e.g. "/uploads/products/x.jpg")
  /// into a fully-qualified URL the app can load. Returns null for null/empty input.
  static String? resolveImageUrl(String? relativeOrAbsolute) {
    if (relativeOrAbsolute == null || relativeOrAbsolute.isEmpty) return null;

    if (relativeOrAbsolute.startsWith('http://') ||
        relativeOrAbsolute.startsWith('https://')) {
      return relativeOrAbsolute;
    }

    return '$imageOrigin$relativeOrAbsolute';
  }
}

/// Keys used for secure token storage.
class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userRole = 'user_role';
  static const String userFullName = 'user_full_name';
}