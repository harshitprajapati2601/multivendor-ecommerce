import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

/// Thin wrapper around FlutterSecureStorage so the rest of the app never
/// touches the storage package directly.
class SecureStorage {
  SecureStorage._internal();
  static final SecureStorage instance = SecureStorage._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required int userId,
    required String email,
    required String role,
    required String fullName,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    await Future.wait([
      _storage.write(key: StorageKeys.accessToken, value: accessToken),
      _storage.write(key: StorageKeys.refreshToken, value: refreshToken),
      _storage.write(key: StorageKeys.userId, value: userId.toString()),
      _storage.write(key: StorageKeys.userEmail, value: email),
      _storage.write(key: StorageKeys.userRole, value: role),
      _storage.write(key: StorageKeys.userFullName, value: fullName),
    ]);
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    await Future.wait([
      _storage.write(key: StorageKeys.accessToken, value: accessToken),
      _storage.write(key: StorageKeys.refreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async {
    return _cachedAccessToken ??= await _storage.read(key: StorageKeys.accessToken);
  }

  Future<String?> getRefreshToken() async {
    return _cachedRefreshToken ??= await _storage.read(key: StorageKeys.refreshToken);
  }

  Future<String?> getRole() => _storage.read(key: StorageKeys.userRole);
  Future<String?> getEmail() => _storage.read(key: StorageKeys.userEmail);
  Future<String?> getFullName() => _storage.read(key: StorageKeys.userFullName);
  Future<String?> getUserId() => _storage.read(key: StorageKeys.userId);

  Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await _storage.deleteAll();
  }
}
