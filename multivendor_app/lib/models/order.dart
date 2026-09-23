enum OrderStatus { placed, shipped, delivered, cancelled, unknown }
enum PaymentStatusModel { pending, success, failed, refunded, unknown }

OrderStatus orderStatusFromApi(String? v) {
  switch (v) {
    case 'PLACED':
      return OrderStatus.placed;
    case 'SHIPPED':
      return OrderStatus.shipped;
    case 'DELIVERED':
      return OrderStatus.delivered;
    case 'CANCELLED':
      return OrderStatus.cancelled;
    default:
      return OrderStatus.unknown;
  }
}

PaymentStatusModel paymentStatusFromApi(String? v) {
  switch (v) {
    case 'PENDING':
      return PaymentStatusModel.pending;
    case 'SUCCESS':
      return PaymentStatusModel.success;
    case 'FAILED':
      return PaymentStatusModel.failed;
    case 'REFUNDED':
      return PaymentStatusModel.refunded;
    default:
      return PaymentStatusModel.unknown;
  }
}

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'Placed';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.unknown:
        return 'Unknown';
    }
  }
}

extension PaymentStatusX on PaymentStatusModel {
  String get label {
    switch (this) {
      case PaymentStatusModel.pending:
        return 'Pending';
      case PaymentStatusModel.success:
        return 'Paid';
      case PaymentStatusModel.failed:
        return 'Failed';
      case PaymentStatusModel.refunded:
        return 'Refunded';
      case PaymentStatusModel.unknown:
        return '—';
    }
  }
}

class OrderItemModel {
  final int productId;
  final String productName;
  final int quantity;
  final double priceAtPurchase;
  final double subtotal;

  OrderItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.priceAtPurchase,
    required this.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: json['productId'],
      productName: json['productName'] ?? '',
      quantity: json['quantity'] ?? 0,
      priceAtPurchase: (json['priceAtPurchase'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderModel {
  final int id;
  final int customerId;
  final String? customerName;
  final String? customerEmail;
  final OrderStatus status;
  final double totalAmount;
  final List<OrderItemModel> items;
  final PaymentStatusModel paymentStatus;
  final String? paymentTransactionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderModel({
    required this.id,
    required this.customerId,
    this.customerName,
    this.customerEmail,
    required this.status,
    required this.totalAmount,
    required this.items,
    required this.paymentStatus,
    this.paymentTransactionId,
    this.createdAt,
    this.updatedAt,
  });

  bool get canCancel => status == OrderStatus.placed;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      customerId: json['customerId'] ?? 0,
      customerName: json['customerName'],
      customerEmail: json['customerEmail'],
      status: orderStatusFromApi(json['status']),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      items: ((json['items'] as List?) ?? [])
          .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      paymentStatus: paymentStatusFromApi(json['paymentStatus']),
      paymentTransactionId: json['paymentTransactionId'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }
}
