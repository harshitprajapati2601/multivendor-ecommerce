import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/state_views.dart';

class CategoriesManageScreen extends StatefulWidget {
  const CategoriesManageScreen({super.key});

  @override
  State<CategoriesManageScreen> createState() => _CategoriesManageScreenState();
}

class _CategoriesManageScreenState extends State<CategoriesManageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories(force: true);
    });
  }

  void _openForm({Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    final isEdit = category != null;

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
            Text(isEdit ? 'Edit category' : 'New category', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            AppTextField(controller: nameController, label: 'Name', prefixIcon: Icons.category_outlined),
            const SizedBox(height: 12),
            AppTextField(
              controller: descController,
              label: 'Description (optional)',
              prefixIcon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Consumer<CategoryProvider>(
              builder: (context, provider, _) => PrimaryButton(
                label: isEdit ? 'Save changes' : 'Create category',
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  final ok = isEdit
                      ? await provider.updateCategory(
                          category.id, nameController.text.trim(), descController.text.trim())
                      : await provider.createCategory(nameController.text.trim(), descController.text.trim());
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'Saved' : (provider.errorMessage ?? 'Could not save category'))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text('"${category.name}" will be removed. Products in it are unaffected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final provider = context.read<CategoryProvider>();
    final ok = await provider.deleteCategory(category.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Category deleted' : (provider.errorMessage ?? 'Could not delete category'))),
    );
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: provider.isLoading
          ? const LoadingView()
          : provider.errorMessage != null && provider.categories.isEmpty
              ? ErrorStateView(message: provider.errorMessage!, onRetry: () => provider.loadCategories(force: true))
              : provider.categories.isEmpty
                  ? const EmptyStateView(icon: Icons.category_outlined, title: 'No categories yet')
                  : RefreshIndicator(
                      onRefresh: () => provider.loadCategories(force: true),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        itemCount: provider.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final category = provider.categories[index];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),

                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      if (category.description != null && category.description!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(category.description!,
                                              style: Theme.of(context).textTheme.bodySmall),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _openForm(category: category),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                                  onPressed: () => _delete(category),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
