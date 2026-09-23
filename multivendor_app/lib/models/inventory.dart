class InventoryModel {
  final int productId;
  final String productName;
  final int stockQuantity;

  InventoryModel({
    required this.productId,
    required this.productName,
    required this.stockQuantity,
  });

  factory InventoryModel.fromJson(Map<String, dynamic> json) {
    return InventoryModel(
      productId: json['productId'],
      productName: json['productName'] ?? '',
      stockQuantity: json['stockQuantity'] ?? 0,
    );
  }
}
