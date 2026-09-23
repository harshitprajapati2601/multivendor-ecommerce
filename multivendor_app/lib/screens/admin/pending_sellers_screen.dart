import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/seller.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';

class PendingSellersScreen extends StatefulWidget {
  const PendingSellersScreen({super.key});

  @override
  State<PendingSellersScreen> createState() => _PendingSellersScreenState();
}

class _PendingSellersScreenState extends State<PendingSellersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadSellers();
    });
  }

  Future<void> _handleRejectSeller(SellerModel seller) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application?'),
        content: Text('Are you sure you want to reject and cancel the seller application for "${seller.shopName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject & Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<AdminProvider>();
    final ok = await provider.rejectSeller(seller.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '${seller.shopName} application cancelled' : (provider.errorMessage ?? 'Could not reject application')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seller Management'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: theme.textTheme.bodySmall?.color,
            tabs: [
              Tab(text: 'Pending (${provider.pendingSellers.length})'),
              Tab(text: 'Active Sellers (${provider.approvedSellers.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Pending Applications
            provider.isLoadingSellers
                ? const LoadingView()
                : provider.errorMessage != null && provider.pendingSellers.isEmpty
                    ? ErrorStateView(message: provider.errorMessage!, onRetry: provider.loadSellers)
                    : provider.pendingSellers.isEmpty
                        ? const EmptyStateView(
                            icon: Icons.verified_user_outlined,
                            title: 'No pending sellers',
                            subtitle: 'New seller sign-ups awaiting approval will show up here.',
                          )
                        : RefreshIndicator(
                            onRefresh: provider.loadSellers,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: provider.pendingSellers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final seller = provider.pendingSellers[index];
                                return _PendingSellerCard(
                                  seller: seller,
                                  onApprove: () async {
                                    final ok = await provider.approveSeller(seller.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? '${seller.shopName} approved successfully!'
                                            : (provider.errorMessage ?? 'Could not approve seller')),
                                      ),
                                    );
                                  },
                                  onReject: () => _handleRejectSeller(seller),
                                );
                              },
                            ),
                          ),

            // Tab 2: Approved / Working Sellers
            provider.isLoadingSellers
                ? const LoadingView()
                : provider.errorMessage != null && provider.approvedSellers.isEmpty
                    ? ErrorStateView(message: provider.errorMessage!, onRetry: provider.loadSellers)
                    : provider.approvedSellers.isEmpty
                        ? const EmptyStateView(
                            icon: Icons.storefront_outlined,
                            title: 'No active sellers yet',
                            subtitle: 'Approved sellers will be listed here once applications are accepted.',
                          )
                        : RefreshIndicator(
                            onRefresh: provider.loadSellers,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: provider.approvedSellers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final seller = provider.approvedSellers[index];
                                return _ApprovedSellerCard(seller: seller);
                              },
                            ),
                          ),
          ],
        ),
      ),
    );
  }
}

class _PendingSellerCard extends StatelessWidget {
  final SellerModel seller;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingSellerCard({
    required this.seller,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  seller.shopName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${seller.fullName} • ${seller.email}',
            style: theme.textTheme.bodySmall,
          ),
          if (seller.shopDescription != null && seller.shopDescription!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(seller.shopDescription!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Approve shop',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: onApprove,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                  label: const Text('Cancel', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovedSellerCard extends StatelessWidget {
  final SellerModel seller;

  const _ApprovedSellerCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        seller.shopName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Owner: ${seller.fullName}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  seller.email,
                  style: theme.textTheme.bodySmall,
                ),
                if (seller.shopDescription != null && seller.shopDescription!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    seller.shopDescription!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
