import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/cart.dart';

class CartService {
  final Dio _dio = ApiClient.instance.dio;

  Future<CartModel> getMyCart() async {
    try {
      final response = await _dio.get('/cart');
      return CartModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<CartModel> addItem({required int productId, required int quantity}) async {
    try {
      final response =
          await _dio.post('/cart/items', data: {'productId': productId, 'quantity': quantity});
      return CartModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<CartModel> updateItem({required int productId, required int quantity}) async {
    try {
      final response = await _dio.put('/cart/items/$productId', data: {'quantity': quantity});
      return CartModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<CartModel> removeItem(int productId) async {
    try {
      final response = await _dio.delete('/cart/items/$productId');
      return CartModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<void> clearCart() async {
    try {
      await _dio.delete('/cart');
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
