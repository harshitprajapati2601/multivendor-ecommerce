import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/state_views.dart';

final _currency = NumberFormat.currency(symbol: '₹');

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: provider.isLoadingReports
          ? const LoadingView()
          : provider.errorMessage != null &&
                  provider.revenueByCategory.isEmpty &&
                  provider.topProducts.isEmpty &&
                  provider.topSellers.isEmpty
              ? ErrorStateView(message: provider.errorMessage!, onRetry: provider.loadReports)
              : RefreshIndicator(
                  onRefresh: provider.loadReports,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SectionCard(
                        title: 'Revenue by category',
                        icon: Icons.pie_chart_outline_rounded,
                        child: provider.revenueByCategory.isEmpty
                            ? const _EmptyRow()
                            : Column(
                                children: provider.revenueByCategory
                                    .map((r) => _StatRow(
                                          label: r.categoryName,
                                          value: _currency.format(r.totalRevenue),
                                        ))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Top selling products',
                        icon: Icons.trending_up_rounded,
                        child: provider.topProducts.isEmpty
                            ? const _EmptyRow()
                            : Column(
                                children: provider.topProducts
                                    .map((p) => _StatRow(
                                          label: p.productName,
                                          value: '${p.totalQuantitySold} sold',
                                        ))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Top sellers',
                        icon: Icons.emoji_events_outlined,
                        child: provider.topSellers.isEmpty
                            ? const _EmptyRow()
                            : Column(
                                children: provider.topSellers
                                    .map((s) => _StatRow(
                                          label: s.shopName,
                                          value: '${_currency.format(s.totalRevenue)} • ${s.orderCount} orders',
                                        ))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text('No data yet', style: TextStyle(color: AppColors.textSecondary)),
    );
  }
}
