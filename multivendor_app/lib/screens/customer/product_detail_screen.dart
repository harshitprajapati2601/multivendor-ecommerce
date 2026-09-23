import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/product.dart';
import '../../models/review.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/review_provider.dart';
import '../../services/product_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/product_image.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/state_views.dart';

final _currency = NumberFormat.currency(symbol: '₹');

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _productService = ProductService();
  Product? _product;
  bool _isLoading = true;
  String? _error;
  int _quantity = 1;
  bool _addingToCart = false;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReviewProvider>().loadReviews(widget.productId);
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final product = await _productService.getById(widget.productId);
      setState(() => _product = product);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _addToCart() async {
    setState(() => _addingToCart = true);
    final ok = await context.read<CartProvider>().addItem(widget.productId, _quantity);
    if (!mounted) return;
    setState(() => _addingToCart = false);
    final cartProvider = context.read<CartProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Added to cart' : (cartProvider.errorMessage ?? 'Could not add to cart'))),
    );
  }

  void _openReviewSheet() {
    int rating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
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
              Text('Write a review', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Center(
                child: RatingPicker(rating: rating, onChanged: (r) => setSheetState(() => rating = r)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Consumer<ReviewProvider>(
                builder: (context, reviewProvider, _) => PrimaryButton(
                  label: 'Submit review',
                  isLoading: reviewProvider.isSubmitting,
                  onPressed: () async {
                    final ok = await reviewProvider.submitReview(
                      productId: widget.productId,
                      rating: rating,
                      comment: commentController.text.trim().isEmpty ? null : commentController.text.trim(),
                    );
                    if (!ctx.mounted) return;
                    if (ok) {
                      Navigator.pop(ctx);
                      _load(); // refresh average rating
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(reviewProvider.errorMessage ?? 'Could not submit review')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewProvider = context.watch<ReviewProvider>();
    final userId = context.watch<AuthProvider>().userId;

    return Scaffold(
      appBar: AppBar(title: Text(_product?.name ?? 'Product')),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorStateView(message: _error!, onRetry: _load)
              : _buildContent(reviewProvider, userId),
      bottomNavigationBar: _product == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_rounded, size: 18),
                            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          ),
                          Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            onPressed: _quantity < _product!.stockQuantity
                                ? () => setState(() => _quantity++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: _product!.inStock ? 'Add to cart' : 'Out of stock',
                        icon: Icons.shopping_cart_outlined,
                        isLoading: _addingToCart,
                        onPressed: _product!.inStock ? _addToCart : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildContent(ReviewProvider reviewProvider, int? userId) {
    final product = _product!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AspectRatio(
            aspectRatio: 1.6,
            child: ProductImage(
              id: product.id,
              name: product.name,
              imageUrl: product.imageUrl,
              letterSize: 72,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.categoryName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                      label: Text(product.categoryName!),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      side: BorderSide.none,
                    ),
                  ),
                Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    RatingStars(rating: product.averageRating, size: 18),
                    const SizedBox(width: 10),
                    if (product.sellerShopName != null)
                      Expanded(
                        child: Text(
                          'Sold by ${product.sellerShopName}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _currency.format(product.price),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  product.inStock ? '${product.stockQuantity} in stock' : 'Currently out of stock',
                  style: TextStyle(
                    color: product.inStock ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (product.description != null && product.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Description', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(product.description!, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reviews (${reviewProvider.reviews.length})',
                        style: Theme.of(context).textTheme.titleMedium),
                    TextButton.icon(
                      onPressed: _openReviewSheet,
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: const Text('Write a review'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (reviewProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                else if (reviewProvider.reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No reviews yet — be the first!', style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ...reviewProvider.reviews.map((r) => _ReviewTile(
                        review: r,
                        canDelete: userId != null && userId == r.customerId,
                        onDelete: () async {
                          final ok = await reviewProvider.deleteReview(r.id);
                          if (ok) _load();
                        },
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Review review;
  final bool canDelete;
  final VoidCallback onDelete;

  const _ReviewTile({required this.review, required this.canDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  review.customerName.isNotEmpty ? review.customerName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(review.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              RatingStars(rating: review.rating.toDouble(), size: 13, showValue: false),
              if (canDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                  onPressed: onDelete,
                ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
