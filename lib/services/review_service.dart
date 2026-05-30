import '../core/db_connection.dart';
import '../models/review_model.dart';
import 'interfaces/i_review_service.dart';

class ReviewService implements IReviewService {
  final DBConnection _db = DBConnection.instance;

  static const int _completedOrderState = 3;

  @override
  Future<ReviewModel> createReview(ReviewModel review) async {
    try {
      if (!_isValidReview(review)) {
        throw Exception('Datos de review inválidos.');
      }

      final conn = await _db.getConnection();

      final orderValidation = await conn.execute(
        '''
        SELECT UniqueID, ClientID, state
        FROM orders
        WHERE UniqueID = :orderId
        LIMIT 1
        ''',
        {
          'orderId': review.orderId,
        },
      );

      if (orderValidation.rows.isEmpty) {
        throw Exception('El pedido no existe.');
      }

      final orderData = orderValidation.rows.first.assoc();
      final orderClientId = _toInt(orderData['ClientID']) ?? 0;
      final orderState = _toInt(orderData['state']) ?? -1;

      if (orderClientId != review.userId) {
        throw Exception('Solo el cliente dueño del pedido puede calificarlo.');
      }

      if (orderState != _completedOrderState) {
        throw Exception('Solo se pueden calificar pedidos completados.');
      }

      final existingReview = await conn.execute(
        '''
        SELECT ID
        FROM review
        WHERE OrderID = :orderId
        LIMIT 1
        ''',
        {
          'orderId': review.orderId,
        },
      );

      if (existingReview.rows.isNotEmpty) {
        throw Exception('Este pedido ya fue calificado.');
      }

      await conn.execute(
        '''
        INSERT INTO review (
          value,
          comment,
          OrderID,
          UserID
        ) VALUES (
          :value,
          :comment,
          :orderId,
          :userId
        )
        ''',
        {
          'value': review.value,
          'comment': _normalizeText(review.comment),
          'orderId': review.orderId,
          'userId': review.userId,
        },
      );

      final idResult = await conn.execute(
        'SELECT LAST_INSERT_ID() AS id',
      );

      final newId = idResult.rows.isNotEmpty
          ? (_toInt(idResult.rows.first.assoc()['id']) ?? 0)
          : 0;

      final createdReview = review.copyWith(id: newId > 0 ? newId : null);

      print('✓ Review creada correctamente. ID=${createdReview.id}');
      return createdReview;
    } catch (e) {
      print('Error en createReview: $e');
      rethrow;
    }
  }

  @override
  Future<ReviewModel?> getReviewByOrderId(int orderId) async {
    try {
      if (orderId <= 0) return null;

      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT
          ID,
          value,
          comment,
          OrderID,
          UserID
        FROM review
        WHERE OrderID = :orderId
        ORDER BY ID DESC
        LIMIT 1
        ''',
        {
          'orderId': orderId,
        },
      );

      if (result.rows.isEmpty) {
        return null;
      }

      final data = result.rows.first.assoc();
      return ReviewModel.fromMap(data);
    } catch (e) {
      print('Error en getReviewByOrderId: $e');
      return null;
    }
  }

  @override
  Future<bool> hasReviewForOrder(int orderId) async {
    try {
      if (orderId <= 0) return false;

      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT ID
        FROM review
        WHERE OrderID = :orderId
        LIMIT 1
        ''',
        {
          'orderId': orderId,
        },
      );

      return result.rows.isNotEmpty;
    } catch (e) {
      print('Error en hasReviewForOrder: $e');
      return false;
    }
  }

  @override
  Future<List<ReviewModel>> getReviewsByUserId(int userId) async {
    try {
      if (userId <= 0) return [];

      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT
          ID,
          value,
          comment,
          OrderID,
          UserID
        FROM review
        WHERE UserID = :userId
        ORDER BY ID DESC
        ''',
        {
          'userId': userId,
        },
      );

      return result.rows.map((row) {
        final data = row.assoc();
        return ReviewModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error en getReviewsByUserId: $e');
      return [];
    }
  }

  @override
  Future<List<ReviewModel>> getReviewsByOrderId(int orderId) async {
    try {
      if (orderId <= 0) return [];

      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT
          ID,
          value,
          comment,
          OrderID,
          UserID
        FROM review
        WHERE OrderID = :orderId
        ORDER BY ID DESC
        ''',
        {
          'orderId': orderId,
        },
      );

      return result.rows.map((row) {
        final data = row.assoc();
        return ReviewModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error en getReviewsByOrderId: $e');
      return [];
    }
  }

  @override
  Future<bool> deleteReview(int reviewId) async {
    try {
      if (reviewId <= 0) return false;

      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        DELETE FROM review
        WHERE ID = :reviewId
        ''',
        {
          'reviewId': reviewId,
        },
      );

      final deleted = result.affectedRows.toInt() > 0;

      if (deleted) {
        print('✓ Review eliminada correctamente. ID=$reviewId');
      }

      return deleted;
    } catch (e) {
      print('Error en deleteReview: $e');
      return false;
    }
  }

  bool _isValidReview(ReviewModel review) {
    return review.orderId > 0 &&
        review.userId > 0 &&
        review.value >= 1 &&
        review.value <= 5;
  }

  String? _normalizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}