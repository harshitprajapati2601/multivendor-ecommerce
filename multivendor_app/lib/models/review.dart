class Review {
  final int id;
  final int productId;
  final int customerId;
  final String customerName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  Review({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      productId: json['productId'],
      customerId: json['customerId'],
      customerName: json['customerName'] ?? 'Anonymous',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }
}
