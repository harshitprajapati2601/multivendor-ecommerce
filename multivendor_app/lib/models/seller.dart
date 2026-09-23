class SellerModel {
  final int id;
  final int userId;
  final String fullName;
  final String email;
  final String shopName;
  final String? shopDescription;
  final bool approved;

  SellerModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.shopName,
    this.shopDescription,
    required this.approved,
  });

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['id'],
      userId: json['userId'] ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      shopName: json['shopName'] ?? '',
      shopDescription: json['shopDescription'],
      approved: json['approved'] ?? false,
    );
  }
}
