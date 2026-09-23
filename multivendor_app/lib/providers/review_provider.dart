import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/review.dart';
import '../services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewService _service = ReviewService();

  List<Review> reviews = [];
  bool isLoading = false;
  bool isSubmitting = false;
  String? errorMessage;

  Future<void> loadReviews(int productId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _service.getByProduct(productId, size: 50);
      reviews = result.content;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> submitReview({required int productId, required int rating, String? comment}) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      final review = await _service.create(productId: productId, rating: rating, comment: comment);
      reviews = [review, ...reviews];
      isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteReview(int id) async {
    try {
      await _service.delete(id);
      reviews = reviews.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
