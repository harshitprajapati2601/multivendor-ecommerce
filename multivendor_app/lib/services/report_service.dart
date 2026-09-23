import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/report.dart';

class ReportService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<CategoryRevenue>> revenueByCategory() async {
    try {
      final response = await _dio.get('/reports/revenue-by-category');
      return (response.data as List).map((e) => CategoryRevenue.fromJson(e)).toList();
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<List<ProductSales>> topSellingProducts({int limit = 10}) async {
    try {
      final response =
          await _dio.get('/reports/top-selling-products', queryParameters: {'limit': limit});
      return (response.data as List).map((e) => ProductSales.fromJson(e)).toList();
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }

  Future<List<SellerSales>> topSellers({int limit = 10}) async {
    try {
      final response = await _dio.get('/reports/top-sellers', queryParameters: {'limit': limit});
      return (response.data as List).map((e) => SellerSales.fromJson(e)).toList();
    } catch (e) {
      throw ApiClient.instance.mapError(e);
    }
  }
}
