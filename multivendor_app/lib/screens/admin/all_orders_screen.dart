import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/order.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';
import '../customer/order_detail_screen.dart';

final _currency = NumberFormat.currency(symbol: '₹');
final _date = DateFormat('MMM d, h:mm a');

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadOrders();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        context.read<AdminProvider>().loadMoreOrders();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: provider.orderStatusFilter == null,
                    onSelected: (_) => provider.setOrderStatusFilter(null),
                  ),
                ),
                ...OrderStatus.values.where((s) => s != OrderStatus.unknown).map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status.label),
                          selected: provider.orderStatusFilter == status,
                          onSelected: (_) => provider.setOrderStatusFilter(status),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: provider.isLoadingOrders
                ? const LoadingView()
                : provider.errorMessage != null && provider.orders.isEmpty
                    ? ErrorStateView(message: provider.errorMessage!, onRetry: provider.loadOrders)
                    : provider.orders.isEmpty
                        ? const EmptyStateView(
                            icon: Icons.receipt_long_outlined,
                            title: 'No orders found',
                            subtitle: 'Orders placed by customers will show up here.',
                          )
                        : RefreshIndicator(
                            onRefresh: provider.loadOrders,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: provider.orders.length + (provider.isLoadingMoreOrders ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                if (index >= provider.orders.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                                  );
                                }
                                final order = provider.orders[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => OrderDetailScreen(orderId: order.id, showAdminActions: true),
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardTheme.color,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Order #${order.id}',
                                                style: const TextStyle(fontWeight: FontWeight.w700)),
                                            StatusBadge.orderStatus(order.status),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          order.customerName ?? 'Customer #${order.customerId}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        if (order.customerEmail != null)
                                          Text(order.customerEmail!, style: Theme.of(context).textTheme.bodySmall),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            if (order.createdAt != null)
                                              Text(_date.format(order.createdAt!),
                                                  style: Theme.of(context).textTheme.bodySmall)
                                            else
                                              const SizedBox.shrink(),
                                            Text(
                                              _currency.format(order.totalAmount),
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
