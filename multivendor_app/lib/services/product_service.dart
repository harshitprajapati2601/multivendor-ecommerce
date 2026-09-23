import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../models/paginated_response.dart';
import '../models/product.dart';

class ProductService {
  final Dio _dio = ApiClient.instance.dio;

  Future<PaginatedResponse<Product>> browse({
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? keyword,
    int page = 0,
    int size = 20,
    String sortBy = 'createdAt',
    String sortDir = 'desc',
  }) async {
    try {
      final response = await _dio.get('/products', queryParameters: {
        if (categoryId != null) 'categoryId': categoryId,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (minRating != null) 'minRating': minRating,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'page': page,
        'size': size,
        'sortBy': sortBy,
        'sortDir': sortDir,
      });
      return PaginatedResponse.fromJson(response.data, Product.fromJson);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Product> getById(int id) async {
    try {
      final response = await _dio.get('/products/$id');
      return Product.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<PaginatedResponse<Product>> getMyProducts({int page = 0, int size = 20}) async {
    try {
      final response = await _dio.get('/products/my-products', queryParameters: {
        'page': page,
        'size': size,
      });
      return PaginatedResponse.fromJson(response.data, Product.fromJson);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Product> create(ProductRequestModel request) async {
    try {
      final response = await _dio.post('/products', data: request.toJson());
      return Product.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Product> update(int id, ProductRequestModel request) async {
    try {
      final response = await _dio.put('/products/$id', data: request.toJson());
      return Product.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Product> uploadImage(int id, XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: image.name),
      });
      final response = await _dio.post('/products/$id/image', data: formData);
      return Product.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<void> deactivate(int id) async {
    try {
      await _dio.delete('/products/$id');
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Product> activate(int id) async {
    try {
      final response = await _dio.patch('/products/$id/activate');
      return Product.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
