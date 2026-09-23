import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/cart.dart';
import '../services/cart_service.dart';

class CartProvider extends ChangeNotifier {
  final CartService _service = CartService();

  CartModel cart = CartModel.empty();
  bool isLoading = false;
  String? errorMessage;
  int updatingProductId = 0; // 0 = none; used to show a spinner on one row

  Future<void> loadCart() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      cart = await _service.getMyCart();
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> addItem(int productId, int quantity) async {
    errorMessage = null;
    try {
      cart = await _service.addItem(productId: productId, quantity: quantity);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> updateQuantity(int productId, int quantity) async {
    updatingProductId = productId;
    notifyListeners();
    try {
      cart = await _service.updateItem(productId: productId, quantity: quantity);
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    updatingProductId = 0;
    notifyListeners();
  }

  Future<void> removeItem(int productId) async {
    updatingProductId = productId;
    notifyListeners();
    try {
      cart = await _service.removeItem(productId);
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    updatingProductId = 0;
    notifyListeners();
  }

  Future<void> clearCart() async {
    isLoading = true;
    notifyListeners();
    try {
      await _service.clearCart();
      cart = CartModel.empty();
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  void reset() {
    cart = CartModel.empty();
    notifyListeners();
  }
}
