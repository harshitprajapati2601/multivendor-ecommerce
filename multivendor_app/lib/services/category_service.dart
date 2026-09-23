import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/category.dart';

class CategoryService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<Category>> getAll() async {
    try {
      final response = await _dio.get('/categories');
      return (response.data as List).map((e) => Category.fromJson(e)).toList();
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Category> getById(int id) async {
    try {
      final response = await _dio.get('/categories/$id');
      return Category.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Category> create({required String name, String? description}) async {
    try {
      final response = await _dio.post('/categories', data: {'name': name, 'description': description});
      return Category.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Category> update(int id, {required String name, String? description}) async {
    try {
      final response =
          await _dio.put('/categories/$id', data: {'name': name, 'description': description});
      return Category.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/categories/$id');
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
