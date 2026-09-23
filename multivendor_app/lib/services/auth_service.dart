import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/api_client.dart';
import '../models/auth_models.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<AuthResponseModel?> signInWithGoogleSDK() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User pressed back / cancelled sign in prompt
        return null;
      }

      String? idToken;
      try {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        idToken = googleAuth.idToken;
      } catch (_) {
        // Best-effort ID Token extraction
      }

      return await googleLogin(
        idToken: idToken ?? '',
        email: googleUser.email,
        name: googleUser.displayName,
        googleId: googleUser.id,
      );
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<AuthResponseModel> googleLogin({
    required String idToken,
    String? email,
    String? name,
    String? googleId,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/google',
        data: {
          'idToken': idToken,
          if (email != null) 'email': email,
          if (name != null) 'name': name,
          if (googleId != null) 'googleId': googleId,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<String> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? shopName,
    String? shopDescription,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'fullName': fullName,
          'email': email,
          'password': password,
          'role': role.apiValue,
          if (shopName != null) 'shopName': shopName,
          if (shopDescription != null) 'shopDescription': shopDescription,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      return response.data['message'] ?? 'Registration successful.';
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<String> verifyEmail({required String email, required String otp}) async {
    try {
      final response = await _dio.post(
        '/auth/verify-email',
        data: {'email': email, 'otp': otp},
        options: Options(extra: {'skipAuth': true}),
      );
      return response.data['message'] ?? 'Email verified.';
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<String> resendEmailVerification(String email) async {
    try {
      final response = await _dio.post(
        '/auth/verify-email/resend',
        data: {'email': email},
        options: Options(extra: {'skipAuth': true}),
      );
      return response.data['message'] ?? 'Verification code resent.';
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<AuthResponseModel> login({required String email, required String password}) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: Options(extra: {'skipAuth': true}),
      );
      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<String> requestLoginOtp(String email) async {
    try {
      final response = await _dio.post(
        '/auth/otp/login/request',
        data: {'email': email},
        options: Options(extra: {'skipAuth': true}),
      );
      return response.data['message'] ?? 'OTP sent to your email.';
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<AuthResponseModel> verifyLoginOtp({required String email, required String otp}) async {
    try {
      final response = await _dio.post(
        '/auth/otp/login/verify',
        data: {'email': email, 'otp': otp},
        options: Options(extra: {'skipAuth': true}),
      );
      return AuthResponseModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<String> requestPasswordReset(String email) async {
    try {
      final response = await _dio.post(
        '/auth/password/reset-request',
        data: {'email': email},
        options: Options(extra: {'skipAuth': true}),
      );
      return response.data['message'] ?? 'Password reset code sent to your email.';
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/password/reset',
        data: {'email': email, 'otp': otp, 'newPassword': newPassword},
        options: Options(extra: {'skipAuth': true}),
      );
      return response.data['message'] ?? 'Password reset successfully.';
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Best-effort — local session is cleared regardless by the caller.
    }
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (_) {
      // Best-effort Google Sign-In session clearing
    }
  }

  Future<String> requestPhoneOtp(String phoneNumber) async {
    try {
      final response = await _dio.post('/account/phone/request-otp', data: {'phoneNumber': phoneNumber});
      return response.data['message'] ?? 'OTP sent to your phone.';
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<String> verifyPhoneOtp(String otp) async {
    try {
      final response = await _dio.post('/account/phone/verify-otp', data: {'otp': otp});
      return response.data['message'] ?? 'Phone verified.';
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
