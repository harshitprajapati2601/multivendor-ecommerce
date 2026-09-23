class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int categoryId;
  final String? categoryName;
  final int sellerId;
  final String? sellerShopName;
  final double averageRating;
  final int stockQuantity;
  final bool active;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.categoryId,
    this.categoryName,
    required this.sellerId,
    this.sellerShopName,
    required this.averageRating,
    required this.stockQuantity,
    required this.active,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get inStock => stockQuantity > 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId'] ?? 0,
      categoryName: json['categoryName'],
      sellerId: json['sellerId'] ?? 0,
      sellerShopName: json['sellerShopName'],
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: json['stockQuantity'] ?? 0,
      active: json['active'] ?? true,
      imageUrl: json['imageUrl'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }
}

/// Payload for creating/updating a product (ProductRequest on the backend).
class ProductRequestModel {
  final String name;
  final String? description;
  final double price;
  final int categoryId;
  final int? initialStock; // only used on create

  ProductRequestModel({
    required this.name,
    this.description,
    required this.price,
    required this.categoryId,
    this.initialStock,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'price': price,
        'categoryId': categoryId,
        if (initialStock != null) 'initialStock': initialStock,
      };
}
