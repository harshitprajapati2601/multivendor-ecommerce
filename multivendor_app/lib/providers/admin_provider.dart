import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/order.dart';
import '../models/report.dart';
import '../models/seller.dart';
import '../services/admin_service.dart';
import '../services/order_service.dart';
import '../services/report_service.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  final ReportService _reportService = ReportService();
  final OrderService _orderService = OrderService();

  List<SellerModel> pendingSellers = [];
  List<SellerModel> approvedSellers = [];
  bool isLoadingSellers = false;

  List<CategoryRevenue> revenueByCategory = [];
  List<ProductSales> topProducts = [];
  List<SellerSales> topSellers = [];
  bool isLoadingReports = false;

  // All-orders browsing (the only way an admin can discover an order id).
  List<OrderModel> orders = [];
  OrderStatus? orderStatusFilter;
  bool isLoadingOrders = false;
  bool isLoadingMoreOrders = false;
  int _ordersPage = 0;
  bool _ordersLast = true;
  bool get hasMoreOrders => !_ordersLast;

  String? errorMessage;

  Future<void> loadPendingSellers() async {
    await loadSellers();
  }

  Future<void> loadSellers() async {
    isLoadingSellers = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _adminService.getPendingSellers(),
        _adminService.getApprovedSellers(),
      ]);
      pendingSellers = results[0];
      approvedSellers = results[1];
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoadingSellers = false;
    notifyListeners();
  }

  Future<bool> approveSeller(int sellerId) async {
    try {
      final approved = await _adminService.approveSeller(sellerId);
      pendingSellers = pendingSellers.where((s) => s.id != sellerId).toList();
      approvedSellers = [approved, ...approvedSellers.where((s) => s.id != sellerId)];
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectSeller(int sellerId) async {
    try {
      await _adminService.rejectSeller(sellerId);
      pendingSellers = pendingSellers.where((s) => s.id != sellerId).toList();
      approvedSellers = approvedSellers.where((s) => s.id != sellerId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }


  Future<void> loadReports() async {
    isLoadingReports = true;
    errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _reportService.revenueByCategory(),
        _reportService.topSellingProducts(limit: 10),
        _reportService.topSellers(limit: 10),
      ]);
      revenueByCategory = results[0] as List<CategoryRevenue>;
      topProducts = results[1] as List<ProductSales>;
      topSellers = results[2] as List<SellerSales>;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoadingReports = false;
    notifyListeners();
  }

  Future<bool> shipOrder(int orderId) async {
    try {
      final updated = await _orderService.ship(orderId);
      orders = orders.map((o) => o.id == orderId ? updated : o).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deliverOrder(int orderId) async {
    try {
      final updated = await _orderService.deliver(orderId);
      orders = orders.map((o) => o.id == orderId ? updated : o).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  void setOrderStatusFilter(OrderStatus? status) {
    orderStatusFilter = status;
    loadOrders();
  }

  Future<void> loadOrders() async {
    isLoadingOrders = true;
    errorMessage = null;
    _ordersPage = 0;
    notifyListeners();
    try {
      final result = await _adminService.getAllOrders(status: orderStatusFilter, page: 0, size: 20);
      orders = result.content;
      _ordersLast = result.last;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoadingOrders = false;
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    if (_ordersLast || isLoadingMoreOrders) return;
    isLoadingMoreOrders = true;
    notifyListeners();
    try {
      final next = _ordersPage + 1;
      final result = await _adminService.getAllOrders(status: orderStatusFilter, page: next, size: 20);
      orders = [...orders, ...result.content];
      _ordersPage = next;
      _ordersLast = result.last;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoadingMoreOrders = false;
    notifyListeners();
  }
}
