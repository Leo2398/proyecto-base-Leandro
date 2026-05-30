import 'package:flutter/material.dart';

import '../models/review_model.dart';
import '../services/interfaces/i_review_service.dart';
import '../services/review_service.dart';

class ReviewController extends ChangeNotifier {
  final IReviewService _reviewService;

  ReviewController({
    IReviewService? reviewService,
  }) : _reviewService = reviewService ?? ReviewService();

  bool _isLoading = false;
  String? _errorMessage;
  ReviewModel? _currentReview;
  final Map<int, bool> _reviewStatusByOrder = {};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ReviewModel? get currentReview => _currentReview;

  bool hasReviewCached(int orderId) {
    return _reviewStatusByOrder[orderId] ?? false;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearCurrentReview() {
    _currentReview = null;
    notifyListeners();
  }

  Future<ReviewModel?> loadReviewByOrderId(int orderId) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final review = await _reviewService.getReviewByOrderId(orderId);
      _currentReview = review;
      _reviewStatusByOrder[orderId] = review != null;

      return review;
    } catch (e) {
      _errorMessage = 'No se pudo cargar la calificación del pedido.';
      debugPrint('Error en loadReviewByOrderId: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> checkIfOrderHasReview(int orderId) async {
    try {
      _errorMessage = null;

      final hasReview = await _reviewService.hasReviewForOrder(orderId);
      _reviewStatusByOrder[orderId] = hasReview;
      notifyListeners();

      return hasReview;
    } catch (e) {
      _errorMessage = 'No se pudo verificar la calificación del pedido.';
      debugPrint('Error en checkIfOrderHasReview: $e');
      notifyListeners();
      return false;
    }
  }

  Future<ReviewModel?> createReview({
    required int orderId,
    required int userId,
    required int value,
    String? comment,
  }) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final review = ReviewModel(
        value: value,
        comment: comment,
        orderId: orderId,
        userId: userId,
      );

      if (!review.isValidValue) {
        throw Exception('La calificación debe estar entre 1 y 5 estrellas.');
      }

      final createdReview = await _reviewService.createReview(review);

      _currentReview = createdReview;
      _reviewStatusByOrder[orderId] = true;

      notifyListeners();
      return createdReview;
    } catch (e) {
      _errorMessage = _mapCreateReviewError(e);
      debugPrint('Error en createReview: $e');
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<ReviewModel>> getReviewsByUserId(int userId) async {
    try {
      _errorMessage = null;
      return await _reviewService.getReviewsByUserId(userId);
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las calificaciones del usuario.';
      debugPrint('Error en getReviewsByUserId: $e');
      notifyListeners();
      return [];
    }
  }

  Future<List<ReviewModel>> getReviewsByOrderId(int orderId) async {
    try {
      _errorMessage = null;
      return await _reviewService.getReviewsByOrderId(orderId);
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las calificaciones del pedido.';
      debugPrint('Error en getReviewsByOrderId: $e');
      notifyListeners();
      return [];
    }
  }

  Future<bool> deleteReview(int reviewId, {int? orderId}) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final deleted = await _reviewService.deleteReview(reviewId);

      if (deleted) {
        _currentReview = null;
        if (orderId != null) {
          _reviewStatusByOrder[orderId] = false;
        }
      }

      notifyListeners();
      return deleted;
    } catch (e) {
      _errorMessage = 'No se pudo eliminar la calificación.';
      debugPrint('Error en deleteReview: $e');
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  String _mapCreateReviewError(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('ya fue calificado')) {
      return 'Este pedido ya fue calificado.';
    }
    if (message.contains('solo se pueden calificar pedidos completados')) {
      return 'Solo puedes calificar pedidos completados.';
    }
    if (message.contains('solo el cliente dueño del pedido puede calificarlo')) {
      return 'Solo el cliente dueño del pedido puede calificarlo.';
    }
    if (message.contains('pedido no existe')) {
      return 'El pedido no existe.';
    }
    if (message.contains('inválidos')) {
      return 'Los datos de la calificación no son válidos.';
    }

    return 'No se pudo guardar la calificación.';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}