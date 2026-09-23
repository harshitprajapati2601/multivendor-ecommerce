import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';
import 'order_detail_screen.dart';

final _currency = NumberFormat.currency(symbol: '₹');

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _checkout(BuildContext context) async {
    final cartProvider = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm your order', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Total: ${_currency.format(cartProvider.cart.totalAmount)} for '
              '${cartProvider.cart.itemCount} item(s).',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Payment is processed through a payment gateway — no real charge will be made.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Place order'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final order = await orderProvider.placeOrder();
    if (!context.mounted) return;

    if (order != null) {
      await cartProvider.loadCart();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(orderProvider.errorMessage ?? 'Could not place order')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();
    final cart = cartProvider.cart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear cart',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear cart?'),
                    content: const Text('This removes every item from your cart.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (confirm == true) await cartProvider.clearCart();
              },
            ),
        ],
      ),
      body: cartProvider.isLoading
          ? const LoadingView()
          : cartProvider.errorMessage != null && cart.isEmpty
              ? ErrorStateView(message: cartProvider.errorMessage!, onRetry: cartProvider.loadCart)
              : cart.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Your cart is empty',
                      subtitle: 'Browse products and add something you like.',
                    )
                  : RefreshIndicator(
                      onRefresh: cartProvider.loadCart,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: cart.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          final isUpdating = cartProvider.updatingProductId == item.productId;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item.productName.isNotEmpty ? item.productName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_currency.format(item.unitPrice)} each',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isUpdating)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                                        onPressed: () {
                                          if (item.quantity > 1) {
                                            cartProvider.updateQuantity(item.productId, item.quantity - 1);
                                          } else {
                                            cartProvider.removeItem(item.productId);
                                          }
                                        },
                                      ),
                                      Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                                        onPressed: () =>
                                            cartProvider.updateQuantity(item.productId, item.quantity + 1),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Column(

                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          _currency.format(cart.totalAmount),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Checkout',
                      icon: Icons.lock_outline_rounded,
                      isLoading: context.watch<OrderProvider>().isPlacingOrder,
                      onPressed: () => _checkout(context),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
