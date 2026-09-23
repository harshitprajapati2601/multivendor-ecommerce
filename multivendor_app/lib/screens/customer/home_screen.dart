import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/state_views.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
      context.read<ProductProvider>().loadFirstPage();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        context.read<ProductProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openFilters() {
    final productProvider = context.read<ProductProvider>();
    final minController = TextEditingController(text: productProvider.minPrice?.toStringAsFixed(0) ?? '');
    final maxController = TextEditingController(text: productProvider.maxPrice?.toStringAsFixed(0) ?? '');
    double? selectedRating = productProvider.minRating;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter products', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Min price'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Max price'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Minimum rating', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [4, 3, 2, 1].map((r) {
                    final selected = selectedRating == r.toDouble();
                    return ChoiceChip(
                      label: Text('$r+ ★'),
                      selected: selected,
                      onSelected: (_) => setSheetState(() => selectedRating = selected ? null : r.toDouble()),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          productProvider.clearFilters();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear all'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          productProvider.applyFilters(
                            minPrice: double.tryParse(minController.text),
                            maxPrice: double.tryParse(maxController.text),
                            minRating: selectedRating,
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSort() {
    final provider = context.read<ProductProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Widget tile(String label, String by, String dir) => ListTile(
              title: Text(label),
              trailing: (provider.sortBy == by && provider.sortDir == dir)
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                provider.setSort(by, dir);
                Navigator.pop(ctx);
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text('Sort by', style: Theme.of(ctx).textTheme.titleMedium),
              tile('Newest first', 'createdAt', 'desc'),
              tile('Price: low to high', 'price', 'asc'),
              tile('Price: high to low', 'price', 'desc'),
              tile('Highest rated', 'averageRating', 'desc'),
              tile('Name: A to Z', 'name', 'asc'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final productProvider = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(icon: const Icon(Icons.sort_rounded), onPressed: _openSort),
          IconButton(icon: const Icon(Icons.tune_rounded), onPressed: _openFilters),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => productProvider.loadFirstPage(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              productProvider.setKeyword('');
                            },
                          )
                        : null,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => productProvider.setKeyword(v.trim()),
                ),
              ),
            ),
            if (categoryProvider.categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All'),
                          selected: productProvider.categoryId == null,
                          onSelected: (_) => productProvider.setCategory(null),
                        ),
                      ),
                      ...categoryProvider.categories.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.name),
                            selected: productProvider.categoryId == c.id,
                            onSelected: (_) => productProvider.setCategory(c.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (productProvider.isLoading)
              const SliverFillRemaining(child: LoadingView())
            else if (productProvider.errorMessage != null && productProvider.products.isEmpty)
              SliverFillRemaining(
                child: ErrorStateView(
                  message: productProvider.errorMessage!,
                  onRetry: () => productProvider.loadFirstPage(),
                ),
              )
            else if (productProvider.products.isEmpty)
              SliverFillRemaining(
                child: EmptyStateView(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products found',
                  subtitle: 'Try a different search or clear your filters.',
                  actionLabel: productProvider.hasActiveFilters ? 'Clear filters' : null,
                  onAction: productProvider.hasActiveFilters ? () => productProvider.clearFilters() : null,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = productProvider.products[index];
                      return ProductCard(
                        product: product,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id)),
                        ),
                      );
                    },
                    childCount: productProvider.products.length,
                  ),
                ),
              ),
            if (productProvider.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}
