import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../models/auth_models.dart';
import '../models/user_profile.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final AccountService _accountService = AccountService();

  AuthStatus status = AuthStatus.unknown;
  UserRole? role;
  String? email;
  String? fullName;
  int? userId;
  String? profileImageUrl;
  UserProfile? userProfile;
  bool isUploadingPhoto = false;

  bool isLoading = false;
  String? errorMessage;

  AuthProvider() {
    ApiClient.instance.onSessionExpired = _handleSessionExpired;
  }

  Future<void> restoreSession() async {
    errorMessage = null;
    final hasSession = await SecureStorage.instance.hasSession();
    if (!hasSession) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    role = UserRoleX.fromApi(await SecureStorage.instance.getRole());
    email = await SecureStorage.instance.getEmail();
    fullName = await SecureStorage.instance.getFullName();
    final idStr = await SecureStorage.instance.getUserId();
    userId = idStr != null ? int.tryParse(idStr) : null;
    status = AuthStatus.authenticated;
    notifyListeners();
    loadProfile();
  }

  /// Refreshes name/profile picture/seller info from the backend (source of truth),
  /// falling back silently to whatever was cached locally on failure.
  Future<void> loadProfile() async {
    try {
      final profile = await _accountService.getMyProfile();
      userProfile = profile;
      fullName = profile.fullName;
      profileImageUrl = profile.profileImageUrl;
      notifyListeners();
    } catch (_) {
      // Non-fatal - keep showing cached name/initials.
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? shopName,
    String? shopDescription,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final profile = await _accountService.updateProfile(
        fullName: fullName,
        phoneNumber: phoneNumber,
        shopName: shopName,
        shopDescription: shopDescription,
      );
      userProfile = profile;
      this.fullName = profile.fullName;
      profileImageUrl = profile.profileImageUrl;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadProfilePicture(XFile image) async {
    isUploadingPhoto = true;
    notifyListeners();
    try {
      final profile = await _accountService.uploadProfilePicture(image);
      userProfile = profile;
      profileImageUrl = profile.profileImageUrl;
      isUploadingPhoto = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      isUploadingPhoto = false;
      notifyListeners();
      return false;
    }
  }

  void _handleSessionExpired() {
    status = AuthStatus.unauthenticated;
    role = null;
    email = null;
    fullName = null;
    profileImageUrl = null;
    userProfile = null;
    userId = null;
    errorMessage = null;
    SecureStorage.instance.clear();
    notifyListeners();
  }


  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? shopName,
    String? shopDescription,
  }) {
    return _run(() async {
      await _authService.register(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        shopName: shopName,
        shopDescription: shopDescription,
      );
      this.fullName = fullName;
      this.email = email;
    });
  }

  Future<bool> verifyEmail({required String email, required String otp}) {
    return _run(() async {
      await _authService.verifyEmail(email: email, otp: otp);
    });
  }

  Future<bool> resendVerification(String email) {
    return _run(() async {
      await _authService.resendEmailVerification(email);
    });
  }

  Future<bool> login({required String email, required String password}) {
    return _run(() async {
      final auth = await _authService.login(email: email, password: password);
      await _persistSession(auth);
    });
  }

  Future<bool> requestLoginOtp(String email) {
    return _run(() async {
      await _authService.requestLoginOtp(email);
    });
  }

  Future<bool> verifyLoginOtp({required String email, required String otp}) {
    return _run(() async {
      final auth = await _authService.verifyLoginOtp(email: email, otp: otp);
      await _persistSession(auth);
    });
  }

  Future<bool> requestPasswordReset(String email) {
    return _run(() async {
      await _authService.requestPasswordReset(email);
    });
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _run(() async {
      await _authService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );
    });
  }

  Future<bool> signInWithGoogle() {
    return _run(() async {
      final auth = await _authService.signInWithGoogleSDK();
      if (auth != null) {
        await _persistSession(auth);
      }
    });
  }

  Future<bool> googleLogin({
    required String idToken,
    String? email,
    String? name,
    String? googleId,
  }) {
    return _run(() async {
      final auth = await _authService.googleLogin(
        idToken: idToken,
        email: email,
        name: name,
        googleId: googleId,
      );
      await _persistSession(auth);
    });
  }

  Future<void> _persistSession(AuthResponseModel auth) async {
    try {
      await SecureStorage.instance.saveSession(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
        userId: auth.userId,
        email: auth.email,
        role: auth.role.apiValue,
        fullName: fullName ?? auth.email.split('@').first,
      );
    } catch (e, st) {
      // The server already authenticated us and issued tokens — a local
      // storage failure here must never be reported as "invalid OTP".
      debugPrint('SecureStorage.saveSession failed after successful login: $e\n$st');
      throw ApiException(
        message: 'Signed in, but could not save your session locally. '
            'Please try logging in again. ($e)',
      );
    }
    role = auth.role;
    email = auth.email;
    userId = auth.userId;
    errorMessage = null;
    status = AuthStatus.authenticated;
    await loadProfile();
  }

  Future<void> logout() async {
    isLoading = true;
    notifyListeners();
    await _authService.logout();
    await SecureStorage.instance.clear();
    status = AuthStatus.unauthenticated;
    role = null;
    email = null;
    fullName = null;
    profileImageUrl = null;
    userProfile = null;
    userId = null;
    isLoading = false;
    notifyListeners();
  }


  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
