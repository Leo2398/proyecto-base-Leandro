import '../core/db_connection.dart';
import '../models/order_detail_model.dart';
import '../models/order_model.dart';
import 'interfaces/i_order_service.dart';

class OrderService implements IOrderService {
  final DBConnection _db = DBConnection.instance;

  /// Estados usados en APP-44:
  /// 0 = Pendiente
  /// 1 = En preparación
  /// 2 = Enviado
  /// 3 = Completado
  /// 4 = Cancelado
  static const int statePending = 0;
  static const int statePreparing = 1;
  static const int stateShipped = 2;
  static const int stateCompleted = 3;
  static const int stateCancelled = 4;

  @override
  Future<int?> createOrder(
      OrderModel order,
      List<OrderDetailModel> details,
      ) async {
    try {
      if (details.isEmpty) return null;

      if (!_isValidOrderState(order.state)) {
        return null;
      }

      final conn = await _db.getConnection();

      await conn.execute('START TRANSACTION');

      try {
        await conn.execute(
          '''
          INSERT INTO Orders (
            amount,
            state,
            pickupLocationID,
            ClientID,
            ProducerID
          ) VALUES (
            :amount,
            :state,
            :pickupLocationID,
            :clientID,
            :producerID
          )
          ''',
          {
            'amount': order.amount,
            'state': order.state,
            'pickupLocationID': order.pickupLocationID,
            'clientID': order.clientID,
            'producerID': order.producerID,
          },
        );

        final idResult = await conn.execute(
          'SELECT LAST_INSERT_ID() AS id',
        );

        if (idResult.rows.isEmpty) {
          await conn.execute('ROLLBACK');
          return null;
        }

        final newOrderId =
            int.tryParse(idResult.rows.first.assoc()['id'].toString()) ?? 0;

        if (newOrderId <= 0) {
          await conn.execute('ROLLBACK');
          return null;
        }

        for (final detail in details) {
          if (detail.productID <= 0 || detail.quantity <= 0) {
            await conn.execute('ROLLBACK');
            return null;
          }

          final stockResult = await conn.execute(
            '''
            UPDATE Product
            SET stock = stock - :quantity
            WHERE ID = :productID
              AND UserID = :producerID
              AND state = 1
              AND stock >= :quantity
            ''',
            {
              'productID': detail.productID,
              'producerID': order.producerID,
              'quantity': detail.quantity,
            },
          );

          if (stockResult.affectedRows.toInt() <= 0) {
            await conn.execute('ROLLBACK');
            print(
              'Error en createOrder: stock insuficiente o producto inválido '
                  'para ProductID=${detail.productID}',
            );
            return null;
          }

          await conn.execute(
            '''
            INSERT INTO OrderDetail (
              OrderID,
              ProductID,
              Quantity,
              unitPrice
            ) VALUES (
              :orderID,
              :productID,
              :quantity,
              :unitPrice
            )
            ''',
            {
              'orderID': newOrderId,
              'productID': detail.productID,
              'quantity': detail.quantity,
              'unitPrice': detail.unitPrice,
            },
          );
        }

        await conn.execute('COMMIT');
        return newOrderId;
      } catch (e) {
        await conn.execute('ROLLBACK');
        print('Error en createOrder (transaction): $e');
        return null;
      }
    } catch (e) {
      print('Error en createOrder: $e');
      return null;
    }
  }

  @override
  Future<List<OrderModel>> getOrdersByClient(int clientID) async {
    try {
      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT
          o.*,
          pl.address AS pickupLocationAddress,
          NULL AS notes
        FROM Orders o
        LEFT JOIN PickupLocation pl
          ON pl.LocationID = o.pickupLocationID
        WHERE o.ClientID = :clientID
        ORDER BY o.registerDate DESC, o.UniqueID DESC
        ''',
        {
          'clientID': clientID,
        },
      );

      return result.rows
          .map((row) => OrderModel.fromMap(row.assoc()))
          .toList();
    } catch (e) {
      print('Error en getOrdersByClient: $e');
      return [];
    }
  }

  @override
  Future<List<OrderModel>> getOrdersByProducer(int producerID) async {
    try {
      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT
          o.*,
          pl.address AS pickupLocationAddress,
          NULL AS notes
        FROM Orders o
        LEFT JOIN PickupLocation pl
          ON pl.LocationID = o.pickupLocationID
        WHERE o.ProducerID = :producerID
        ORDER BY o.registerDate DESC, o.UniqueID DESC
        ''',
        {
          'producerID': producerID,
        },
      );

      return result.rows
          .map((row) => OrderModel.fromMap(row.assoc()))
          .toList();
    } catch (e) {
      print('Error en getOrdersByProducer: $e');
      return [];
    }
  }

  @override
  Future<List<OrderDetailModel>> getOrderDetails(int orderID) async {
    try {
      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT *
        FROM OrderDetail
        WHERE OrderID = :orderID
        ''',
        {
          'orderID': orderID,
        },
      );

      return result.rows
          .map((row) => OrderDetailModel.fromMap(row.assoc()))
          .toList();
    } catch (e) {
      print('Error en getOrderDetails: $e');
      return [];
    }
  }

  @override
  Future<bool> updateOrderState(int orderID, int state) async {
    try {
      if (orderID <= 0) return false;
      if (!_isValidOrderState(state)) return false;

      final conn = await _db.getConnection();

      await conn.execute('START TRANSACTION');

      try {
        final currentStateResult = await conn.execute(
          '''
          SELECT state
          FROM Orders
          WHERE UniqueID = :orderID
          LIMIT 1
          ''',
          {
            'orderID': orderID,
          },
        );

        if (currentStateResult.rows.isEmpty) {
          await conn.execute('ROLLBACK');
          return false;
        }

        final currentState =
            int.tryParse(
              currentStateResult.rows.first.assoc()['state'].toString(),
            ) ??
                -1;

        if (!_isValidOrderState(currentState)) {
          await conn.execute('ROLLBACK');
          return false;
        }

        if (!_isTransitionAllowed(currentState, state)) {
          await conn.execute('ROLLBACK');
          print(
            'Transición inválida en updateOrderState: '
                '$currentState -> $state para OrderID=$orderID',
          );
          return false;
        }

        final result = await conn.execute(
          '''
          UPDATE Orders
          SET state = :state
          WHERE UniqueID = :orderID
          ''',
          {
            'state': state,
            'orderID': orderID,
          },
        );

        if (result.affectedRows.toInt() <= 0) {
          await conn.execute('ROLLBACK');
          return false;
        }

        await conn.execute('COMMIT');
        return true;
      } catch (e) {
        await conn.execute('ROLLBACK');
        print('Error en updateOrderState (transaction): $e');
        return false;
      }
    } catch (e) {
      print('Error en updateOrderState: $e');
      return false;
    }
  }

  bool _isValidOrderState(int state) {
    return state >= statePending && state <= stateCancelled;
  }

  bool _isTransitionAllowed(int currentState, int nextState) {
    if (currentState == nextState) return true;

    switch (currentState) {
      case statePending:
        return nextState == statePreparing || nextState == stateCancelled;

      case statePreparing:
        return nextState == stateShipped || nextState == stateCancelled;

      case stateShipped:
        return nextState == stateCompleted || nextState == stateCancelled;

      case stateCompleted:
      case stateCancelled:
        return false;

      default:
        return false;
    }
  }
}