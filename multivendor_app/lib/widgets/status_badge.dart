import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/order.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color lightColor;
  final Color darkColor;

  const StatusBadge({
    super.key,
    required this.label,
    required Color color,
    Color? darkColor,
  })  : lightColor = color,
        darkColor = darkColor ?? color;

  factory StatusBadge.orderStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.placed:
        return const StatusBadge(
          label: 'Placed',
          color: AppColors.primary,
          darkColor: Color(0xFF818CF8),
        );
      case OrderStatus.shipped:
        return const StatusBadge(
          label: 'Shipped',
          color: Color(0xFF0891B2),
          darkColor: Color(0xFF22D3EE),
        );
      case OrderStatus.delivered:
        return const StatusBadge(
          label: 'Delivered',
          color: AppColors.success,
          darkColor: Color(0xFF34D399),
        );
      case OrderStatus.cancelled:
        return const StatusBadge(
          label: 'Cancelled',
          color: AppColors.danger,
          darkColor: Color(0xFFF87171),
        );
      case OrderStatus.unknown:
        return const StatusBadge(
          label: 'Unknown',
          color: AppColors.textSecondary,
          darkColor: Color(0xFF94A3B8),
        );
    }
  }

  factory StatusBadge.paymentStatus(PaymentStatusModel status) {
    switch (status) {
      case PaymentStatusModel.success:
        return const StatusBadge(
          label: 'Paid',
          color: AppColors.success,
          darkColor: Color(0xFF34D399),
        );
      case PaymentStatusModel.pending:
        return const StatusBadge(
          label: 'Pending',
          color: AppColors.warning,
          darkColor: Color(0xFFFBBF24),
        );
      case PaymentStatusModel.failed:
        return const StatusBadge(
          label: 'Failed',
          color: AppColors.danger,
          darkColor: Color(0xFFF87171),
        );
      case PaymentStatusModel.refunded:
        return const StatusBadge(
          label: 'Refunded',
          color: Color(0xFF7C3AED),
          darkColor: Color(0xFFA78BFA),
        );
      case PaymentStatusModel.unknown:
        return const StatusBadge(
          label: '—',
          color: AppColors.textSecondary,
          darkColor: Color(0xFF94A3B8),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = isDark ? darkColor : lightColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
