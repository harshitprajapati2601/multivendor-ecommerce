class CategoryRevenue {
  final int categoryId;
  final String categoryName;
  final double totalRevenue;

  CategoryRevenue({required this.categoryId, required this.categoryName, required this.totalRevenue});

  factory CategoryRevenue.fromJson(Map<String, dynamic> json) => CategoryRevenue(
        categoryId: json['categoryId'],
        categoryName: json['categoryName'] ?? '',
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      );
}

class ProductSales {
  final int productId;
  final String productName;
  final int totalQuantitySold;

  ProductSales({required this.productId, required this.productName, required this.totalQuantitySold});

  factory ProductSales.fromJson(Map<String, dynamic> json) => ProductSales(
        productId: json['productId'],
        productName: json['productName'] ?? '',
        totalQuantitySold: (json['totalQuantitySold'] as num?)?.toInt() ?? 0,
      );
}

class SellerSales {
  final int sellerId;
  final String shopName;
  final double totalRevenue;
  final int orderCount;

  SellerSales({
    required this.sellerId,
    required this.shopName,
    required this.totalRevenue,
    required this.orderCount,
  });

  factory SellerSales.fromJson(Map<String, dynamic> json) => SellerSales(
        sellerId: json['sellerId'],
        shopName: json['shopName'] ?? '',
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      );
}
