import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/order.dart';
import '../models/paginated_response.dart';

class OrderService {
  final Dio _dio = ApiClient.instance.dio;

  Future<OrderModel> placeOrder({String? paymentToken}) async {
    try {
      final response = await _dio.post(
        '/orders',
        data: paymentToken != null ? {'paymentToken': paymentToken} : {},
      );
      return OrderModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<PaginatedResponse<OrderModel>> getMyOrders({int page = 0, int size = 20}) async {
    try {
      final response = await _dio.get('/orders', queryParameters: {'page': page, 'size': size});
      return PaginatedResponse.fromJson(response.data, OrderModel.fromJson);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<OrderModel> getById(int id) async {
    try {
      final response = await _dio.get('/orders/$id');
      return OrderModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<OrderModel> cancel(int id) async {
    try {
      final response = await _dio.patch('/orders/$id/cancel');
      return OrderModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<OrderModel> ship(int id) async {
    try {
      final response = await _dio.patch('/orders/$id/ship');
      return OrderModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<OrderModel> deliver(int id) async {
    try {
      final response = await _dio.patch('/orders/$id/deliver');
      return OrderModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
