import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/paginated_response.dart';
import '../models/review.dart';

class ReviewService {
  final Dio _dio = ApiClient.instance.dio;

  Future<PaginatedResponse<Review>> getByProduct(int productId, {int page = 0, int size = 20}) async {
    try {
      final response = await _dio.get('/products/$productId/reviews', queryParameters: {
        'page': page,
        'size': size,
      });
      return PaginatedResponse.fromJson(response.data, Review.fromJson);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Review> create({required int productId, required int rating, String? comment}) async {
    try {
      final response = await _dio.post('/reviews', data: {
        'productId': productId,
        'rating': rating,
        'comment': comment,
      });
      return Review.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<Review> update(int id, {required int rating, String? comment}) async {
    try {
      final response = await _dio.put('/reviews/$id', data: {'rating': rating, 'comment': comment});
      return Review.fromJson(response.data);
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/reviews/$id');
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
