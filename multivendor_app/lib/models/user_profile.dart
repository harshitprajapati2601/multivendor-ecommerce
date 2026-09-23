import 'auth_models.dart';

class UserProfile {
  final int id;
  final String fullName;
  final String email;
  final UserRole role;
  final String? phoneNumber;
  final bool phoneVerified;
  final String? profileImageUrl;
  final String? shopName;
  final String? shopDescription;
  final bool? sellerApproved;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phoneNumber,
    required this.phoneVerified,
    this.profileImageUrl,
    this.shopName,
    this.shopDescription,
    this.sellerApproved,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: UserRoleX.fromApi(json['role']),
      phoneNumber: json['phoneNumber'],
      phoneVerified: json['phoneVerified'] ?? false,
      profileImageUrl: json['profileImageUrl'],
      shopName: json['shopName'],
      shopDescription: json['shopDescription'],
      sellerApproved: json['sellerApproved'],
    );
  }
}

