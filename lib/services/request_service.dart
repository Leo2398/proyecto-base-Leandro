import '../core/db_connection.dart';
import '../models/request_model.dart';
import '../models/app_config_model.dart';

/// Principio S de SOLID: solo maneja operaciones de BD para Request y AppConfig
class RequestService {
  final DBConnection _db = DBConnection.instance;

  // ── AppConfig ──────────────────────────────────────────────────────────────

  /// Amplía la columna configValue a LONGTEXT si aún es TEXT (una sola vez)
  Future<void> migrateAppConfig() async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        'ALTER TABLE appconfig MODIFY COLUMN configValue LONGTEXT',
      );
    } catch (_) {
      // Ignora si ya es LONGTEXT u otro error menor
    }
  }

  /// Obtiene la configuración (bsPerCoin y qrImage) desde la tabla clave-valor
  Future<AppConfigModel> getAppConfig() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        "SELECT configKey, configValue FROM appconfig WHERE configKey IN ('bsPerCoin','qrImage')",
      );
      final rows = result.rows.map((r) => r.assoc()).toList();
      return AppConfigModel.fromRows(rows);
    } catch (e) {
      print('Error en getAppConfig: $e');
      return AppConfigModel.defaults;
    }
  }

  /// Guarda o actualiza un valor de configuración en AppConfig
  Future<bool> _setConfig(String key, String value) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''
        INSERT INTO appconfig (configKey, configValue)
        VALUES (:key, :val)
        ON DUPLICATE KEY UPDATE configValue = VALUES(configValue)
        ''',
        {'key': key, 'val': value},
      );
      return true;
    } catch (e) {
      print('Error en _setConfig($key): $e');
      return false;
    }
  }

  /// Actualiza el precio en Bs por moneda
  Future<bool> updateBsPerCoin(double bsPerCoin) =>
      _setConfig('bsPerCoin', bsPerCoin.toStringAsFixed(2));

  /// Actualiza la imagen QR (base64 o URL)
  Future<bool> updateQrImage(String imageData) =>
      _setConfig('qrImage', imageData);

  // ── Request ────────────────────────────────────────────────────────────────

  /// Crea un nuevo request de recarga
  Future<bool> createRequest(RequestModel request) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''
        INSERT INTO request (value, amount, image, state, userID)
        VALUES (:value, :amount, :image, 0, :userID)
        ''',
        {
          'value': request.value,
          'amount': request.amount,
          'image': request.image,
          'userID': request.userID,
        },
      );
      return true;
    } catch (e) {
      print('Error en createRequest: $e');
      return false;
    }
  }

  /// Obtiene todos los requests de un usuario ordenados por fecha desc
  Future<List<RequestModel>> getRequestsByUser(int userID) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT * FROM request
        WHERE userID = :userID
        ORDER BY registerDate DESC
        ''',
        {'userID': userID},
      );
      return result.rows.map((r) => RequestModel.fromMap(r.assoc())).toList();
    } catch (e) {
      print('Error en getRequestsByUser: $e');
      return [];
    }
  }

  /// Obtiene el request pendiente más reciente de un usuario
  Future<RequestModel?> getLatestPendingRequest(int userID) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT * FROM request
        WHERE userID = :userID AND state = 0
        ORDER BY registerDate DESC
        LIMIT 1
        ''',
        {'userID': userID},
      );
      if (result.rows.isEmpty) return null;
      return RequestModel.fromMap(result.rows.first.assoc());
    } catch (e) {
      print('Error en getLatestPendingRequest: $e');
      return null;
    }
  }

  /// Obtiene un request por su ID
  Future<RequestModel?> getRequestById(int id) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        'SELECT * FROM request WHERE ID = :id',
        {'id': id},
      );
      if (result.rows.isEmpty) return null;
      return RequestModel.fromMap(result.rows.first.assoc());
    } catch (e) {
      print('Error en getRequestById: $e');
      return null;
    }
  }

  /// Obtiene todos los requests pendientes con datos del usuario (para el admin)
  Future<List<RequestModel>> getAllPendingRequests() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT
          r.*,
          u.name AS userName,
          u.email AS userEmail,
          u.image AS userImage
        FROM request r
        INNER JOIN user u ON r.userID = u.ID
        WHERE r.state = 0
        ORDER BY r.registerDate ASC
        ''',
      );
      return result.rows.map((r) => RequestModel.fromMap(r.assoc())).toList();
    } catch (e) {
      print('Error en getAllPendingRequests: $e');
      return [];
    }
  }

  /// Obtiene todos los requests (pendientes + historial) con datos del usuario
  Future<List<RequestModel>> getAllRequests() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT
          r.*,
          u.name AS userName,
          u.email AS userEmail,
          u.image AS userImage
        FROM request r
        INNER JOIN user u ON r.userID = u.ID
        ORDER BY r.registerDate DESC
        ''',
      );
      return result.rows.map((r) => RequestModel.fromMap(r.assoc())).toList();
    } catch (e) {
      print('Error en getAllRequests: $e');
      return [];
    }
  }

  /// Aprueba un request pendiente:
  /// - valida que exista
  /// - valida que siga pendiente (state = 0)
  /// - bloquea el registro durante el proceso
  /// - marca el request como aprobado
  /// - suma las monedas al balance del usuario
  /// Todo dentro de transacción
  Future<bool> approveRequest({
    required int requestID,
    required int adminID,
  }) async {
    final conn = await _db.getConnection();

    try {
      await conn.execute('START TRANSACTION');

      final requestResult = await conn.execute(
        '''
        SELECT ID, value, userID, state
        FROM request
        WHERE ID = :id
        FOR UPDATE
        ''',
        {'id': requestID},
      );

      if (requestResult.rows.isEmpty) {
        await conn.execute('ROLLBACK');
        return false;
      }

      final row = requestResult.rows.first.assoc();

      final state = int.tryParse(row['state']?.toString() ?? '-1') ?? -1;
      if (state != 0) {
        await conn.execute('ROLLBACK');
        return false;
      }

      final coins = double.tryParse(row['value']?.toString() ?? '0') ?? 0;
      final userID = int.tryParse(row['userID']?.toString() ?? '0') ?? 0;

      if (userID <= 0 || coins <= 0) {
        await conn.execute('ROLLBACK');
        return false;
      }

      await conn.execute(
        '''
        UPDATE request
        SET state = 1,
            processedDate = NOW(),
            adminID = :adminID
        WHERE ID = :id AND state = 0
        ''',
        {
          'adminID': adminID,
          'id': requestID,
        },
      );

      await conn.execute(
        '''
        UPDATE user
        SET balance = balance + :coins
        WHERE ID = :userID
        ''',
        {
          'coins': coins,
          'userID': userID,
        },
      );

      await conn.execute('COMMIT');
      return true;
    } catch (e) {
      try {
        await conn.execute('ROLLBACK');
      } catch (_) {}
      print('Error en approveRequest: $e');
      return false;
    }
  }

  /// Rechaza un request pendiente:
  /// - valida que exista
  /// - valida que siga pendiente
  /// - evita volver a rechazar o tocar requests ya aprobados/rechazados
  Future<bool> rejectRequest({
    required int requestID,
    required int adminID,
  }) async {
    final conn = await _db.getConnection();

    try {
      await conn.execute('START TRANSACTION');

      final requestResult = await conn.execute(
        '''
        SELECT ID, state
        FROM request
        WHERE ID = :id
        FOR UPDATE
        ''',
        {'id': requestID},
      );

      if (requestResult.rows.isEmpty) {
        await conn.execute('ROLLBACK');
        return false;
      }

      final row = requestResult.rows.first.assoc();
      final state = int.tryParse(row['state']?.toString() ?? '-1') ?? -1;

      if (state != 0) {
        await conn.execute('ROLLBACK');
        return false;
      }

      await conn.execute(
        '''
        UPDATE request
        SET state = 2,
            processedDate = NOW(),
            adminID = :adminID
        WHERE ID = :id AND state = 0
        ''',
        {
          'adminID': adminID,
          'id': requestID,
        },
      );

      await conn.execute('COMMIT');
      return true;
    } catch (e) {
      try {
        await conn.execute('ROLLBACK');
      } catch (_) {}
      print('Error en rejectRequest: $e');
      return false;
    }
  }
}