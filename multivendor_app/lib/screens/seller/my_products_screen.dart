import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/product_image.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/state_views.dart';
import 'product_form_screen.dart';

final _currency = NumberFormat.currency(symbol: '₹');

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  String _searchQuery = '';
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
      context.read<SellerProductProvider>().loadMyProducts();
    });
  }

  void _openRestockSheet(Product product) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
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
            Text('Restock "${product.name}"', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Current stock: ${product.stockQuantity}', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity to add'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Consumer<SellerProductProvider>(
              builder: (context, provider, _) => PrimaryButton(
                label: 'Add stock',
                onPressed: () async {
                  final qty = int.tryParse(controller.text);
                  if (qty == null || qty <= 0) return;
                  final ok = await provider.restock(product.id, qty);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Stock updated' : (provider.errorMessage ?? 'Restock failed'))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePhoto(Product product) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (image == null || !mounted) return;

    final provider = context.read<SellerProductProvider>();
    final ok = await provider.uploadImage(product.id, image);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Could not upload photo')));
    }
  }

  Future<void> _toggleActive(Product product) async {
    final provider = context.read<SellerProductProvider>();
    final newActiveState = !product.active;
    final ok = await provider.toggleProductActive(product);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (newActiveState ? '"${product.name}" activated' : '"${product.name}" deactivated')
              : (provider.errorMessage ?? 'Could not update product status'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to completely delete "${product.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final provider = context.read<SellerProductProvider>();
    final ok = await provider.deleteProduct(product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '"${product.name}" deleted' : (provider.errorMessage ?? 'Could not delete product')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SellerProductProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final theme = Theme.of(context);

    final filteredProducts = provider.products.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesCategory = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();


    return Scaffold(
      appBar: AppBar(title: const Text('My Products')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProductFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New product'),
      ),
      body: Column(
        children: [
          // Search & Filter Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Category Filter Chips
          if (categoryProvider.categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categoryProvider.categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final selected = _selectedCategoryId == null;
                    return FilterChip(
                      label: const Text('All Categories'),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : theme.textTheme.bodyMedium?.color,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => setState(() => _selectedCategoryId = null),
                    );
                  }
                  final cat = categoryProvider.categories[index - 1];
                  final selected = _selectedCategoryId == cat.id;
                  return FilterChip(
                    label: Text(cat.name),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary : theme.textTheme.bodyMedium?.color,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),

          // Product List Body
          Expanded(
            child: provider.isLoading
                ? const LoadingView()
                : provider.errorMessage != null && provider.products.isEmpty
                    ? ErrorStateView(message: provider.errorMessage!, onRetry: provider.loadMyProducts)
                    : provider.products.isEmpty
                        ? EmptyStateView(
                            icon: Icons.inventory_2_outlined,
                            title: 'No products yet',
                            subtitle: 'Tap "New product" to list your first item.\n'
                                'Note: your shop needs admin approval before products go live.',
                            actionLabel: 'Add a product',
                            onAction: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                            ),
                          )
                        : filteredProducts.isEmpty
                            ? const EmptyStateView(
                                icon: Icons.search_off_rounded,
                                title: 'No matching products',
                                subtitle: 'Try clearing your search or category filter.',
                              )
                            : RefreshIndicator(
                                onRefresh: provider.loadMyProducts,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                                  itemCount: filteredProducts.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final product = filteredProducts[index];
                                    return Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: theme.cardTheme.color,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: theme.dividerColor),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _ProductThumbnail(
                                            product: product,
                                            onTap: () => _changePhoto(product),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        product.name,
                                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    InkWell(
                                                      onTap: () => _toggleActive(product),
                                                      borderRadius: BorderRadius.circular(20),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: (product.active ? AppColors.success : AppColors.textSecondary)
                                                              .withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(
                                                            color: (product.active ? AppColors.success : AppColors.textSecondary)
                                                                .withValues(alpha: 0.3),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              width: 7,
                                                              height: 7,
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: product.active
                                                                    ? AppColors.success
                                                                    : AppColors.textSecondary,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 5),
                                                            Text(
                                                              product.active ? 'Active' : 'Inactive',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w700,
                                                                color: product.active
                                                                    ? AppColors.success
                                                                    : AppColors.textSecondary,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 3),
                                                            Icon(
                                                              product.active
                                                                  ? Icons.toggle_on_rounded
                                                                  : Icons.toggle_off_rounded,
                                                              size: 18,
                                                              color: product.active
                                                                  ? AppColors.success
                                                                  : AppColors.textSecondary,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  categoryProvider.nameFor(product.categoryId),
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Text(
                                                      _currency.format(product.price),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    RatingStars(rating: product.averageRating, size: 13),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Stock: ${product.stockQuantity}',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: product.stockQuantity > 0
                                                        ? AppColors.textSecondary
                                                        : AppColors.danger,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const Divider(height: 20),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: () => Navigator.of(context).push(
                                                          MaterialPageRoute(
                                                            builder: (_) => ProductFormScreen(product: product),
                                                          ),
                                                        ),
                                                        icon: const Icon(Icons.edit_outlined, size: 15),
                                                        label: const Text(
                                                          'Edit',
                                                          style: TextStyle(fontSize: 12.5),
                                                        ),
                                                        style: OutlinedButton.styleFrom(
                                                          minimumSize: const Size.fromHeight(36),
                                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: () => _openRestockSheet(product),
                                                        icon: const Icon(Icons.add_box_outlined, size: 15),
                                                        label: const Text(
                                                          'Restock',
                                                          style: TextStyle(fontSize: 12.5),
                                                        ),
                                                        style: OutlinedButton.styleFrom(
                                                          minimumSize: const Size.fromHeight(36),
                                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    IconButton(
                                                      tooltip: 'Delete Product',
                                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                                      onPressed: () => _deleteProduct(product),
                                                      style: IconButton.styleFrom(
                                                        backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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

class _ProductThumbnail extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductThumbnail({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: ProductImage(
                id: product.id,
                name: product.name,
                imageUrl: product.imageUrl,
                letterSize: 24,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1.5)),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
