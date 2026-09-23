enum UserRole { customer, seller, admin }

extension UserRoleX on UserRole {
  String get apiValue {
    switch (this) {
      case UserRole.customer:
        return 'CUSTOMER';
      case UserRole.seller:
        return 'SELLER';
      case UserRole.admin:
        return 'ADMIN';
    }
  }

  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.seller:
        return 'Seller';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromApi(String? value) {
    switch (value) {
      case 'SELLER':
        return UserRole.seller;
      case 'ADMIN':
        return UserRole.admin;
      case 'CUSTOMER':
      default:
        return UserRole.customer;
    }
  }
}

class AuthResponseModel {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int userId;
  final String email;
  final UserRole role;

  AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.userId,
    required this.email,
    required this.role,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      tokenType: json['tokenType'] ?? 'Bearer',
      userId: json['userId'] ?? 0,
      email: json['email'] ?? '',
      role: UserRoleX.fromApi(json['role']),
    );
  }
}
