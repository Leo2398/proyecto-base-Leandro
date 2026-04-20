import '../core/db_connection.dart';
import '../models/order_detail_model.dart';
import '../models/order_model.dart';
import 'interfaces/i_order_service.dart';
import 'notification_service.dart';

class OrderService implements IOrderService {
  final DBConnection _db = DBConnection.instance;
  final NotificationService _notificationService = NotificationService();

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
      if (!_isValidOrderState(order.state)) return null;
      if (order.clientID <= 0 || order.producerID <= 0) return null;

      final conn = await _db.getConnection();
      await conn.execute('START TRANSACTION');

      try {
        /// 1) Bloquear saldo del cliente
        final balanceResult = await conn.execute(
          '''
          SELECT balance
          FROM User
          WHERE ID = :clientID
          FOR UPDATE
          ''',
          {
            'clientID': order.clientID,
          },
        );

        if (balanceResult.rows.isEmpty) {
          await conn.execute('ROLLBACK');
          print(
            'Error en createOrder: cliente no encontrado '
                'ClientID=${order.clientID}',
          );
          return null;
        }

        final currentBalance =
            double.tryParse(
              balanceResult.rows.first.assoc()['balance'].toString(),
            ) ??
                0.0;

        /// 2) Validar productos desde BD y recalcular total real
        final normalizedDetails = <Map<String, dynamic>>[];
        double computedTotal = 0.0;

        for (final detail in details) {
          if (detail.productID <= 0 || detail.quantity <= 0) {
            await conn.execute('ROLLBACK');
            return null;
          }

          final productResult = await conn.execute(
            '''
            SELECT
              ID,
              price,
              stock,
              state
            FROM Product
            WHERE ID = :productID
              AND UserID = :producerID
            LIMIT 1
            FOR UPDATE
            ''',
            {
              'productID': detail.productID,
              'producerID': order.producerID,
            },
          );

          if (productResult.rows.isEmpty) {
            await conn.execute('ROLLBACK');
            print(
              'Error en createOrder: producto no encontrado '
                  'o no pertenece al productor. ProductID=${detail.productID}',
            );
            return null;
          }

          final productRow = productResult.rows.first.assoc();

          final productState =
              int.tryParse(productRow['state'].toString()) ?? 0;
          final currentStock =
              int.tryParse(productRow['stock'].toString()) ?? 0;
          final realUnitPrice =
              double.tryParse(productRow['price'].toString()) ?? -1.0;

          if (productState != 1) {
            await conn.execute('ROLLBACK');
            print(
              'Error en createOrder: producto inactivo. '
                  'ProductID=${detail.productID}',
            );
            return null;
          }

          if (realUnitPrice < 0) {
            await conn.execute('ROLLBACK');
            print(
              'Error en createOrder: precio inválido '
                  'para ProductID=${detail.productID}',
            );
            return null;
          }

          if (currentStock < detail.quantity) {
            await conn.execute('ROLLBACK');
            print(
              'Error en createOrder: stock insuficiente '
                  'para ProductID=${detail.productID}',
            );
            return null;
          }

          normalizedDetails.add({
            'productID': detail.productID,
            'quantity': detail.quantity,
            'unitPrice': realUnitPrice,
          });

          computedTotal += realUnitPrice * detail.quantity;
        }

        if (computedTotal <= 0) {
          await conn.execute('ROLLBACK');
          print('Error en createOrder: total calculado inválido.');
          return null;
        }

        if (currentBalance < computedTotal) {
          await conn.execute('ROLLBACK');
          print(
            'Error en createOrder: saldo insuficiente '
                'ClientID=${order.clientID}, saldo=$currentBalance, '
                'monto=$computedTotal',
          );
          return null;
        }

        /// 3) Crear cabecera del pedido con total recalculado
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
            'amount': computedTotal,
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

        /// 4) Descontar stock e insertar detalles usando precios reales
        for (final detail in normalizedDetails) {
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
              'productID': detail['productID'],
              'producerID': order.producerID,
              'quantity': detail['quantity'],
            },
          );

          if (stockResult.affectedRows.toInt() <= 0) {
            await conn.execute('ROLLBACK');
            print(
              'Error en createOrder: stock insuficiente o producto inválido '
                  'para ProductID=${detail['productID']}',
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
              'productID': detail['productID'],
              'quantity': detail['quantity'],
              'unitPrice': detail['unitPrice'],
            },
          );
        }

        /// 5) Descontar saldo dentro de la misma transacción
        final balanceUpdateResult = await conn.execute(
          '''
          UPDATE User
          SET balance = balance - :amount
          WHERE ID = :clientID
            AND balance >= :amount
          ''',
          {
            'amount': computedTotal,
            'clientID': order.clientID,
          },
        );

        if (balanceUpdateResult.affectedRows.toInt() <= 0) {
          await conn.execute('ROLLBACK');
          print(
            'Error en createOrder: no se pudo descontar el saldo '
                'del cliente ClientID=${order.clientID}',
          );
          return null;
        }

        await conn.execute('COMMIT');

        await _notifyProducerNewOrder(
          producerID: order.producerID,
          orderID: newOrderId,
          amount: computedTotal,
        );

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
          SELECT
            state,
            amount,
            ClientID,
            ProducerID
          FROM Orders
          WHERE UniqueID = :orderID
          LIMIT 1
          FOR UPDATE
          ''',
          {
            'orderID': orderID,
          },
        );

        if (currentStateResult.rows.isEmpty) {
          await conn.execute('ROLLBACK');
          return false;
        }

        final row = currentStateResult.rows.first.assoc();

        final currentState = int.tryParse(row['state'].toString()) ?? -1;
        final clientID = int.tryParse(row['ClientID'].toString()) ?? 0;
        final producerID = int.tryParse(row['ProducerID'].toString()) ?? 0;
        final amount = double.tryParse(row['amount'].toString()) ?? 0.0;

        if (!_isValidOrderState(currentState)) {
          await conn.execute('ROLLBACK');
          return false;
        }

        if (currentState == state) {
          await conn.execute('COMMIT');
          return true;
        }

        if (!_isTransitionAllowed(currentState, state)) {
          await conn.execute('ROLLBACK');
          print(
            'Transición inválida en updateOrderState: '
                '$currentState -> $state para OrderID=$orderID',
          );
          return false;
        }

        /// Si se cancela, devolver stock y saldo dentro de la misma transacción
        if (state == stateCancelled) {
          final detailResult = await conn.execute(
            '''
            SELECT
              ProductID,
              Quantity
            FROM OrderDetail
            WHERE OrderID = :orderID
            ''',
            {
              'orderID': orderID,
            },
          );

          for (final detailRow in detailResult.rows) {
            final assoc = detailRow.assoc();
            final productID = int.tryParse(assoc['ProductID'].toString()) ?? 0;
            final quantity = int.tryParse(assoc['Quantity'].toString()) ?? 0;

            if (productID <= 0 || quantity <= 0) {
              await conn.execute('ROLLBACK');
              print(
                'Error en updateOrderState: detalle inválido '
                    'al cancelar pedido #$orderID',
              );
              return false;
            }

            final stockRestoreResult = await conn.execute(
              '''
              UPDATE Product
              SET stock = stock + :quantity
              WHERE ID = :productID
                AND UserID = :producerID
              ''',
              {
                'productID': productID,
                'producerID': producerID,
                'quantity': quantity,
              },
            );

            if (stockRestoreResult.affectedRows.toInt() <= 0) {
              await conn.execute('ROLLBACK');
              print(
                'Error en updateOrderState: no se pudo reponer stock '
                    'para ProductID=$productID en OrderID=$orderID',
              );
              return false;
            }
          }

          if (amount > 0 && clientID > 0) {
            final refundResult = await conn.execute(
              '''
              UPDATE User
              SET balance = balance + :amount
              WHERE ID = :clientID
              ''',
              {
                'amount': amount,
                'clientID': clientID,
              },
            );

            if (refundResult.affectedRows.toInt() <= 0) {
              await conn.execute('ROLLBACK');
              print(
                'Error en updateOrderState: no se pudo reembolsar '
                    'al cliente ClientID=$clientID para OrderID=$orderID',
              );
              return false;
            }
          }
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

        await _notifyClientOrderStateChanged(
          clientID: clientID,
          producerID: producerID,
          orderID: orderID,
          newState: state,
        );

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

  Future<void> _notifyProducerNewOrder({
    required int producerID,
    required int orderID,
    required double amount,
  }) async {
    if (producerID <= 0 || orderID <= 0) return;

    try {
      await _notificationService.createNotification(
        userId: producerID,
        title: 'Nuevo pedido recibido',
        message:
        'Tienes un nuevo pedido #$orderID pendiente de revisión por '
            '${_formatBs(amount)}.',
        type: 'order',
      );
    } catch (e) {
      print('Error notificando nuevo pedido al productor: $e');
    }
  }

  Future<void> _notifyClientOrderStateChanged({
    required int clientID,
    required int producerID,
    required int orderID,
    required int newState,
  }) async {
    if (clientID <= 0 || orderID <= 0) return;

    try {
      final title = _clientNotificationTitleForState(newState);
      final message = _clientNotificationMessageForState(orderID, newState);

      await _notificationService.createNotification(
        userId: clientID,
        title: title,
        message: message,
        type: 'order',
      );

      if (newState == stateCancelled && producerID > 0) {
        await _notificationService.createNotification(
          userId: producerID,
          title: 'Pedido cancelado',
          message: 'El pedido #$orderID fue marcado como cancelado.',
          type: 'order',
        );
      }
    } catch (e) {
      print('Error notificando cambio de estado del pedido: $e');
    }
  }

  String _clientNotificationTitleForState(int state) {
    switch (state) {
      case statePreparing:
        return 'Tu pedido está en preparación';
      case stateShipped:
        return 'Tu pedido fue enviado';
      case stateCompleted:
        return 'Tu pedido fue completado';
      case stateCancelled:
        return 'Tu pedido fue cancelado';
      case statePending:
      default:
        return 'Actualización de pedido';
    }
  }

  String _clientNotificationMessageForState(int orderID, int state) {
    switch (state) {
      case statePreparing:
        return 'El pedido #$orderID ya fue aceptado y está en preparación.';
      case stateShipped:
        return 'El pedido #$orderID ya fue enviado.';
      case stateCompleted:
        return 'El pedido #$orderID fue completado correctamente.';
      case stateCancelled:
        return 'El pedido #$orderID fue cancelado.';
      case statePending:
      default:
        return 'El pedido #$orderID tuvo una actualización.';
    }
  }

  String _formatBs(double value) {
    if (value == value.truncateToDouble()) {
      return 'Bs ${value.toStringAsFixed(0)}';
    }
    return 'Bs ${value.toStringAsFixed(2)}';
  }
}