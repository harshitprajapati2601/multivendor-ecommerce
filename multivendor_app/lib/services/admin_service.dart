import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/order.dart';
import '../models/paginated_response.dart';
import '../models/seller.dart';

class AdminService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<SellerModel>> getPendingSellers() async {
    try {
      final response = await _dio.get('/admin/sellers/pending');
      return (response.data as List).map((e) => SellerModel.fromJson(e)).toList();
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<List<SellerModel>> getApprovedSellers() async {
    try {
      final response = await _dio.get('/admin/sellers/approved');
      return (response.data as List).map((e) => SellerModel.fromJson(e)).toList();
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<SellerModel> approveSeller(int sellerId) async {
    try {
      final response = await _dio.patch('/admin/sellers/$sellerId/approve');
      return SellerModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<void> rejectSeller(int sellerId) async {
    try {
      await _dio.delete('/admin/sellers/$sellerId');
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }


  /// Browses every order in the system — the only way an admin can
  /// discover an order's id, since GET /api/orders is customer-only.
  Future<PaginatedResponse<OrderModel>> getAllOrders({
    OrderStatus? status,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get('/admin/orders', queryParameters: {
        if (status != null) 'status': status.name.toUpperCase(),
        'page': page,
        'size': size,
      });
      return PaginatedResponse.fromJson(response.data, OrderModel.fromJson);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
