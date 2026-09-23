import 'package:flutter/foundation.dart' hide Category;
import '../core/api_client.dart';
import '../models/category.dart';
import '../services/category_service.dart';

class CategoryProvider extends ChangeNotifier {
  final CategoryService _service = CategoryService();

  List<Category> categories = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadCategories({bool force = false}) async {
    if (categories.isNotEmpty && !force) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      categories = await _service.getAll();
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> createCategory(String name, String? description) async {
    try {
      final cat = await _service.create(name: name, description: description);
      categories = [...categories, cat];
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategory(int id, String name, String? description) async {
    try {
      final updated = await _service.update(id, name: name, description: description);
      categories = categories.map((c) => c.id == id ? updated : c).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      await _service.delete(id);
      categories = categories.where((c) => c.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  String nameFor(int? categoryId) {
    if (categoryId == null) return '';
    return categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(id: categoryId, name: '—'),
    ).name;
  }
}
