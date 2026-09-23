import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';
import 'order_detail_screen.dart';

final _currency = NumberFormat.currency(symbol: '₹');
final _date = DateFormat('MMM d, yyyy • h:mm a');

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadMyOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: orderProvider.isLoading
          ? const LoadingView()
          : orderProvider.errorMessage != null && orderProvider.orders.isEmpty
              ? ErrorStateView(message: orderProvider.errorMessage!, onRetry: orderProvider.loadMyOrders)
              : orderProvider.orders.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.receipt_long_outlined,
                      title: 'No orders yet',
                      subtitle: 'Orders you place will show up here.',
                    )
                  : RefreshIndicator(
                      onRefresh: orderProvider.loadMyOrders,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: orderProvider.orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = orderProvider.orders[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Order #${order.id}',
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          StatusBadge.orderStatus(order.status),
                                        ],
                                      ),
                                      if (order.createdAt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _date.format(order.createdAt!),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Text(
                                        order.items.map((i) => '${i.productName} ×${i.quantity}').join(', '),
                                        style: theme.textTheme.bodyMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${order.items.length} item(s)',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          StatusBadge.paymentStatus(order.paymentStatus),
                                          Text(
                                            _currency.format(order.totalAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
