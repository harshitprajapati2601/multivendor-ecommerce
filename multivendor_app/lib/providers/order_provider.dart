import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/order.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _service = OrderService();

  List<OrderModel> orders = [];
  bool isLoading = false;
  bool isPlacingOrder = false;
  String? errorMessage;

  Future<void> loadMyOrders() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _service.getMyOrders(size: 50);
      orders = result.content;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<OrderModel?> placeOrder({String? paymentToken}) async {
    isPlacingOrder = true;
    errorMessage = null;
    notifyListeners();
    OrderModel? order;
    try {
      order = await _service.placeOrder(paymentToken: paymentToken);
      orders = [order, ...orders];
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isPlacingOrder = false;
    notifyListeners();
    return order;
  }

  Future<bool> cancelOrder(int id) async {
    try {
      final updated = await _service.cancel(id);
      orders = orders.map((o) => o.id == id ? updated : o).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
