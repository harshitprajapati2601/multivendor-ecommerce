import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/constants.dart';
import '../../models/product.dart';
import '../../providers/category_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product; // null = create mode
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  int? _categoryId;
  bool _isSaving = false;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _currentImageUrl;
  bool _isUploadingPhoto = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _stockController = TextEditingController(text: p != null ? '' : '0');
    _categoryId = p?.categoryId;
    _currentImageUrl = p?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
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

    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = image;
      _pickedImageBytes = bytes;
    });

    // In edit mode the product already exists, so upload immediately.
    // In create mode we hold onto the file and upload right after creation.
    if (_isEdit) {
      setState(() => _isUploadingPhoto = true);
      final provider = context.read<SellerProductProvider>();

      final ok = await provider.uploadImage(widget.product!.id, image);
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
        if (ok) _currentImageUrl = provider.products.firstWhere((p) => p.id == widget.product!.id).imageUrl;
      });
      if (!ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Could not upload photo')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a category')));
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<SellerProductProvider>();
    final request = ProductRequestModel(
      name: _nameController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      categoryId: _categoryId!,
      initialStock: _isEdit ? null : (int.tryParse(_stockController.text.trim()) ?? 0),
    );

    final ok = _isEdit
        ? await provider.updateProduct(widget.product!.id, request)
        : await provider.createProduct(request);

    if (!mounted) return;

    if (ok && !_isEdit && _pickedImage != null) {
      // The newly created product is prepended to the list by the provider.
      final created = provider.products.first;
      await provider.uploadImage(created.id, _pickedImage!);
      if (!mounted) return;
    }

    setState(() => _isSaving = false);

    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Could not save product')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'New product')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _PhotoPicker(
                  bytes: _pickedImageBytes,
                  imageUrl: _currentImageUrl,
                  isUploading: _isUploadingPhoto,
                  onTap: _pickPhoto,
                )),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nameController,
                  label: 'Product name',
                  prefixIcon: Icons.label_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _descController,
                  label: 'Description (optional)',
                  prefixIcon: Icons.description_outlined,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _priceController,
                  label: 'Price',
                  prefixIcon: Icons.currency_rupee_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final value = double.tryParse(v ?? '');
                    if (value == null || value <= 0) return 'Enter a valid price';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text('Category', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categoryProvider.categories.map((c) {
                    return ChoiceChip(
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    );
                  }).toList(),
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _stockController,
                    label: 'Initial stock',
                    prefixIcon: Icons.inventory_2_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter a valid quantity' : null,
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    'To change stock, use "Restock" from the product list.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 28),
                PrimaryButton(
                  label: _isEdit ? 'Save changes' : 'Create product',
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final Uint8List? bytes;
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onTap;

  const _PhotoPicker({
    required this.bytes,
    required this.imageUrl,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = AppConfig.resolveImageUrl(imageUrl);

    return InkWell(
      onTap: isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover)
            else if (resolvedUrl != null)
              Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const _PhotoPlaceholder(),
              )
            else
              const _PhotoPlaceholder(),
            if (isUploading)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  ),
                ),
              )
            else
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      child: const Center(
        child: Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.textSecondary),
      ),
    );
  }

}
