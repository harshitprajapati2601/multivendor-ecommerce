import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/inventory.dart';

class InventoryService {
  final Dio _dio = ApiClient.instance.dio;

  Future<InventoryModel> getStock(int productId) async {
    try {
      final response = await _dio.get('/products/$productId/inventory');
      return InventoryModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<InventoryModel> restock(int productId, int quantity) async {
    try {
      final response =
          await _dio.patch('/products/$productId/inventory/restock', data: {'quantity': quantity});
      return InventoryModel.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
