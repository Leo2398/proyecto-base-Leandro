import '../../models/review_model.dart';

abstract class IReviewService {
  Future<ReviewModel> createReview(ReviewModel review);

  Future<ReviewModel?> getReviewByOrderId(int orderId);

  Future<bool> hasReviewForOrder(int orderId);

  Future<List<ReviewModel>> getReviewsByUserId(int userId);

  Future<List<ReviewModel>> getReviewsByOrderId(int orderId);

  Future<bool> deleteReview(int reviewId);
}