import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';

final _currency = NumberFormat.currency(symbol: '₹');
final _date = DateFormat('MMM d, yyyy • h:mm a');

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final bool showAdminActions;

  const OrderDetailScreen({super.key, required this.orderId, this.showAdminActions = false});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _orderService = OrderService();
  OrderModel? _order;
  bool _isLoading = true;
  String? _error;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await _orderService.getById(widget.orderId);
      setState(() => _order = order);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel order')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _actionInProgress = true);
    try {
      final updated = await _orderService.cancel(widget.orderId);
      setState(() => _order = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Could not cancel order')));
      }
    }
    setState(() => _actionInProgress = false);
  }

  Future<void> _updateStatus(Future<OrderModel> Function(int) action, String successLabel) async {
    setState(() => _actionInProgress = true);
    try {
      final updated = await action(widget.orderId);
      setState(() => _order = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successLabel)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Action failed')));
      }
    }
    setState(() => _actionInProgress = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorStateView(message: _error!, onRetry: _load)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge.orderStatus(order.status),
              StatusBadge.paymentStatus(order.paymentStatus),
            ],
          ),
          const SizedBox(height: 12),
          if (order.createdAt != null)
            Text('Placed on ${_date.format(order.createdAt!)}', style: Theme.of(context).textTheme.bodySmall),
          if (order.paymentTransactionId != null) ...[
            const SizedBox(height: 4),
            Text('Transaction ID: ${order.paymentTransactionId}', style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),

              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity} × ${_currency.format(item.priceAtPurchase)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(_currency.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              Text(
                _currency.format(order.totalAmount),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (widget.showAdminActions) ...[
            if (order.status == OrderStatus.placed)
              PrimaryButton(
                label: 'Mark as shipped',
                icon: Icons.local_shipping_outlined,
                isLoading: _actionInProgress,
                onPressed: () => _updateStatus(_orderService.ship, 'Order marked as shipped'),
              ),
            if (order.status == OrderStatus.shipped) ...[
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Mark as delivered',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _actionInProgress,
                onPressed: () => _updateStatus(_orderService.deliver, 'Order marked as delivered'),
              ),
            ],
          ] else if (order.canCancel)
            PrimaryButton(
              label: 'Cancel order',
              icon: Icons.cancel_outlined,
              color: AppColors.danger,
              isLoading: _actionInProgress,
              onPressed: _cancelOrder,
            ),
        ],
      ),
    );
  }
}
