import '../core/db_connection.dart';
import '../models/coin_movement_model.dart';
import 'interfaces/i_coin_movement_service.dart';

/// Servicio de monedas adaptado 100% a la base de datos actual.
///
/// RESPETA LA BD EXISTENTE:
/// - saldo actual -> tabla User.balance
/// - solicitudes / historial de recarga -> tabla Request
/// - uso de monedas -> descuento directo en User.balance
///
/// IMPORTANTE:
/// Con la BD actual no existe una tabla separada para guardar el historial
/// de consumo de monedas. Por eso:
/// - getMovementsByUserId() devuelve historial de solicitudes de recarga
/// - registerUsage() solo descuenta saldo
class CoinMovementService implements ICoinMovementService {
  /// Instancia de conexión a la BD
  final DBConnection _db = DBConnection.instance;

  /// Regla del proyecto:
  /// 1 moneda = 100 de monto real
  static const double _moneyPerCoin = 100.0;

  /// Obtiene el saldo actual de monedas del usuario/productor
  @override
  Future<double> getUserCoinBalance(int userId) async {
    try {
      if (userId <= 0) return 0.0;

      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT balance
        FROM User
        WHERE ID = :userId
        LIMIT 1
        ''',
        {'userId': userId},
      );

      if (result.rows.isEmpty) return 0.0;

      final row = Map<String, dynamic>.from(result.rows.first.assoc());
      return _parseDouble(row['balance']) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Obtiene el historial de solicitudes de recarga del usuario/productor
  ///
  /// Como la BD actual no tiene una tabla de historial de consumo,
  /// este historial se construye desde la tabla Request.
  @override
  Future<List<CoinMovementModel>> getMovementsByUserId(int userId) async {
    try {
      if (userId <= 0) return [];

      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT
          ID,
          value,
          amount,
          image,
          state,
          registerDate,
          processedDate,
          userID,
          adminID
        FROM Request
        WHERE userID = :userId
        ORDER BY registerDate DESC, ID DESC
        ''',
        {'userId': userId},
      );

      return result.rows.map((row) {
        final data = Map<String, dynamic>.from(row.assoc());
        return _mapRequestToCoinMovement(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene una cantidad limitada de movimientos recientes
  @override
  Future<List<CoinMovementModel>> getRecentMovementsByUserId(
      int userId, {
        int limit = 20,
      }) async {
    try {
      if (userId <= 0) return [];

      final safeLimit = limit <= 0 ? 20 : limit;
      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT
          ID,
          value,
          amount,
          image,
          state,
          registerDate,
          processedDate,
          userID,
          adminID
        FROM Request
        WHERE userID = :userId
        ORDER BY registerDate DESC, ID DESC
        LIMIT $safeLimit
        ''',
        {'userId': userId},
      );

      return result.rows.map((row) {
        final data = Map<String, dynamic>.from(row.assoc());
        return _mapRequestToCoinMovement(data);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Crea un "movimiento" según el tipo recibido.
  ///
  /// - Si es recarga -> crea una solicitud en Request
  /// - Si es uso -> descuenta balance directamente
  ///
  /// Esto se adapta a la BD actual sin crear tablas nuevas.
  @override
  Future<bool> createMovement(CoinMovementModel movement) async {
    try {
      if (movement.userId <= 0) return false;
      if (movement.amount <= 0) return false;

      if (movement.isRecharge) {
        return await registerRecharge(
          userId: movement.userId,
          amount: movement.amount,
          description: movement.description,
        );
      }

      if (movement.isUsage) {
        return await registerUsage(
          userId: movement.userId,
          amount: movement.amount,
          description: movement.description,
        );
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Registra una solicitud de recarga de monedas.
  ///
  /// OJO:
  /// En esta BD, la recarga NO suma saldo inmediatamente.
  /// Primero crea una solicitud pendiente en Request y luego el admin
  /// deberá aprobarla para reflejar el saldo en User.balance.
  ///
  /// Como la interfaz actual no recibe imagen/comprobante,
  /// este método guarda image = ''.
  /// Luego, en la APP-49, conviene ajustar ese flujo para mandar
  /// el comprobante real.
  @override
  Future<bool> registerRecharge({
    required int userId,
    required double amount,
    String? description,
  }) async {
    try {
      if (userId <= 0) return false;
      if (amount <= 0) return false;

      /// En Request.value se guardan monedas enteras
      if (!_isWholeNumber(amount)) return false;

      final conn = await _db.getConnection();
      final coinValue = amount.toInt();
      final realAmount = amount * _moneyPerCoin;

      final result = await conn.execute(
        '''
        INSERT INTO Request (
          value,
          amount,
          image,
          state,
          registerDate,
          userID,
          adminID
        ) VALUES (
          :value,
          :amount,
          :image,
          :state,
          :registerDate,
          :userID,
          :adminID
        )
        ''',
        {
          'value': coinValue,
          'amount': realAmount,
          'image': '',
          'state': 0,
          'registerDate': _formatDateTimeForMySql(DateTime.now()),
          'userID': userId,
          'adminID': null,
        },
      );

      return result.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  /// Registra el uso de monedas descontando saldo directamente.
  ///
  /// IMPORTANTE:
  /// Como la BD actual no tiene tabla para guardar el historial
  /// de consumo, aquí solo se actualiza User.balance.
  @override
  Future<bool> registerUsage({
    required int userId,
    required double amount,
    String? description,
  }) async {
    try {
      if (userId <= 0) return false;
      if (amount <= 0) return false;

      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        UPDATE User
        SET balance = balance - :amount
        WHERE ID = :userId
          AND balance >= :amount
        ''',
        {
          'amount': amount,
          'userId': userId,
        },
      );

      return result.affectedRows.toInt() > 0;
    } catch (e) {
      return false;
    }
  }

  /// Convierte una fila de Request en CoinMovementModel
  ///
  /// Se usa CoinMovementModel solo como modelo visual/funcional
  /// para la pantalla de saldo e historial.
  CoinMovementModel _mapRequestToCoinMovement(Map<String, dynamic> row) {
    final int id = _parseInt(row['ID']) ?? 0;
    final int userId = _parseInt(row['userID']) ?? 0;
    final int coinValue = _parseInt(row['value']) ?? 0;
    final double paidAmount = _parseDouble(row['amount']) ?? 0.0;
    final int state = _parseInt(row['state']) ?? 0;
    final DateTime createdAt =
        _parseDateTime(row['registerDate']) ?? DateTime.now();
    final DateTime? processedDate = _parseDateTime(row['processedDate']);

    return CoinMovementModel(
      id: id,
      userId: userId,
      amount: coinValue.toDouble(),
      type: 'recarga',
      description: _buildRequestDescription(
        coinValue: coinValue,
        paidAmount: paidAmount,
        state: state,
        processedDate: processedDate,
      ),
      createdAt: createdAt,
    );
  }

  /// Construye una descripción bonita para mostrar en la interfaz
  String _buildRequestDescription({
    required int coinValue,
    required double paidAmount,
    required int state,
    DateTime? processedDate,
  }) {
    final stateText = _requestStateLabel(state);
    final processedText = processedDate != null
        ? ' | Procesado: ${_formatDate(processedDate)}'
        : '';

    return 'Solicitud de recarga de $coinValue monedas '
        '(Monto: ${paidAmount.toStringAsFixed(2)}) '
        '- Estado: $stateText$processedText';
  }

  /// Devuelve la etiqueta del estado de Request
  String _requestStateLabel(int state) {
    switch (state) {
      case 0:
        return 'Pendiente';
      case 1:
        return 'Aprobado';
      case 2:
        return 'Rechazado';
      default:
        return 'Desconocido';
    }
  }

  /// Verifica si el valor es entero, porque Request.value es INT
  bool _isWholeNumber(double value) {
    return value == value.toInt().toDouble();
  }

  /// Convierte cualquier valor a int
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  /// Convierte cualquier valor a double
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    final cleanValue = value.toString().replaceAll(',', '.');
    return double.tryParse(cleanValue);
  }

  /// Convierte cualquier valor a DateTime
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Formatea DateTime para MySQL DATETIME
  String _formatDateTimeForMySql(DateTime dateTime) {
    final local = dateTime.toLocal();

    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:$second';
  }

  /// Formato simple para mostrar fecha en texto
  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }
}