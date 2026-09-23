import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../models/user_profile.dart';

class AccountService {
  final Dio _dio = ApiClient.instance.dio;

  Future<UserProfile> getMyProfile() async {
    try {
      final response = await _dio.get('/account/me');
      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<UserProfile> uploadProfilePicture(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: image.name),
      });
      final response = await _dio.post('/account/profile-picture', data: formData);
      return UserProfile.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? shopName,
    String? shopDescription,
  }) async {
    final payload = {
      if (fullName != null) 'fullName': fullName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (shopName != null) 'shopName': shopName,
      if (shopDescription != null) 'shopDescription': shopDescription,
    };
    try {
      final response = await _dio.put('/account/me', data: payload);
      return UserProfile.fromJson(response.data);
    } catch (e) {
      final apiErr = ApiClient.instance.mapError(e);
      if (apiErr.statusCode == 405) {
        try {
          final response = await _dio.post('/account/me', data: payload);
          return UserProfile.fromJson(response.data);
        } catch (inner) {
          throw ApiClient.instance.mapError(inner);
        }
      }
      throw apiErr;
    }
  }
}


