import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/product.dart';
import '../services/product_service.dart';

class ProductProvider extends ChangeNotifier {
  final ProductService _service = ProductService();

  List<Product> products = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;

  // filters
  int? categoryId;
  double? minPrice;
  double? maxPrice;
  double? minRating;
  String keyword = '';
  String sortBy = 'createdAt';
  String sortDir = 'desc';

  int _page = 0;
  bool _last = true;
  int totalElements = 0;

  bool get hasMore => !_last;
  bool get hasActiveFilters =>
      categoryId != null || minPrice != null || maxPrice != null || minRating != null || keyword.isNotEmpty;

  Future<void> loadFirstPage() async {
    isLoading = true;
    errorMessage = null;
    _page = 0;
    notifyListeners();
    try {
      final result = await _fetch(0);
      products = result.content;
      _last = result.last;
      totalElements = result.totalElements;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_last || isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      final next = _page + 1;
      final result = await _fetch(next);
      products = [...products, ...result.content];
      _page = next;
      _last = result.last;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoadingMore = false;
    notifyListeners();
  }

  Future<dynamic> _fetch(int page) {
    return _service.browse(
      categoryId: categoryId,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minRating: minRating,
      keyword: keyword.isEmpty ? null : keyword,
      page: page,
      size: 20,
      sortBy: sortBy,
      sortDir: sortDir,
    );
  }

  void setKeyword(String value) {
    keyword = value;
    loadFirstPage();
  }

  void setCategory(int? id) {
    categoryId = id;
    loadFirstPage();
  }

  void applyFilters({double? minPrice, double? maxPrice, double? minRating}) {
    this.minPrice = minPrice;
    this.maxPrice = maxPrice;
    this.minRating = minRating;
    loadFirstPage();
  }

  void setSort(String by, String dir) {
    sortBy = by;
    sortDir = dir;
    loadFirstPage();
  }

  void clearFilters() {
    categoryId = null;
    minPrice = null;
    maxPrice = null;
    minRating = null;
    keyword = '';
    sortBy = 'createdAt';
    sortDir = 'desc';
    loadFirstPage();
  }
}
