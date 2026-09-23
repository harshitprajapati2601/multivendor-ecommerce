import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../models/product.dart';
import '../services/inventory_service.dart';
import '../services/product_service.dart';

class SellerProductProvider extends ChangeNotifier {
  final ProductService _productService = ProductService();
  final InventoryService _inventoryService = InventoryService();

  List<Product> products = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadMyProducts() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _productService.getMyProducts(size: 100);
      products = result.content;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> createProduct(ProductRequestModel request) async {
    try {
      final created = await _productService.create(request);
      products = [created, ...products];
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(int id, ProductRequestModel request) async {
    try {
      final updated = await _productService.update(id, request);
      products = products.map((p) => p.id == id ? updated : p).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deactivateProduct(int id) async {
    try {
      await _productService.deactivate(id);
      products = products.map((p) {
        if (p.id != id) return p;
        return Product(
          id: p.id,
          name: p.name,
          description: p.description,
          price: p.price,
          categoryId: p.categoryId,
          categoryName: p.categoryName,
          sellerId: p.sellerId,
          sellerShopName: p.sellerShopName,
          averageRating: p.averageRating,
          stockQuantity: p.stockQuantity,
          active: false,
          imageUrl: p.imageUrl,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
        );
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await _productService.deactivate(id);
      products.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }


  Future<bool> activateProduct(int id) async {
    try {
      final updated = await _productService.activate(id);
      products = products.map((p) => p.id == id ? updated : p).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleProductActive(Product product) async {
    if (product.active) {
      return await deactivateProduct(product.id);
    } else {
      return await activateProduct(product.id);
    }
  }

  Future<bool> uploadImage(int productId, XFile image) async {
    try {
      final updated = await _productService.uploadImage(productId, image);
      products = products.map((p) => p.id == productId ? updated : p).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> restock(int productId, int quantity) async {
    try {
      final inv = await _inventoryService.restock(productId, quantity);
      products = products.map((p) {
        if (p.id != productId) return p;
        return Product(
          id: p.id,
          name: p.name,
          description: p.description,
          price: p.price,
          categoryId: p.categoryId,
          categoryName: p.categoryName,
          sellerId: p.sellerId,
          sellerShopName: p.sellerShopName,
          averageRating: p.averageRating,
          stockQuantity: inv.stockQuantity,
          active: p.active,
          imageUrl: p.imageUrl,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
        );
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
