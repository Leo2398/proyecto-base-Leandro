import '../core/db_connection.dart';
import '../models/request_model.dart';
import '../models/app_config_model.dart';

/// Principio S de SOLID: solo maneja operaciones de BD para Request y AppConfig
class RequestService {
  final DBConnection _db = DBConnection.instance;

  // ── AppConfig ──────────────────────────────────────────────────────────────

  /// Obtiene la configuración (bsPerCoin y qrImage) desde la tabla clave-valor
  Future<AppConfigModel> getAppConfig() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        "SELECT configKey, configValue FROM AppConfig WHERE configKey IN ('bsPerCoin','qrImage')",
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
        '''INSERT INTO AppConfig (configKey, configValue)
           VALUES (:key, :val)
           ON DUPLICATE KEY UPDATE configValue = VALUES(configValue)''',
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
        '''INSERT INTO Request (value, amount, image, state, userID)
           VALUES (:value, :amount, :image, 0, :userID)''',
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
        '''SELECT * FROM Request WHERE userID = :userID
           ORDER BY registerDate DESC''',
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
        '''SELECT * FROM Request
           WHERE userID = :userID AND state = 0
           ORDER BY registerDate DESC LIMIT 1''',
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
        'SELECT * FROM Request WHERE ID = :id',
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
        '''SELECT r.*, u.name AS userName, u.email AS userEmail, u.image AS userImage
           FROM Request r
           INNER JOIN User u ON r.userID = u.ID
           WHERE r.state = 0
           ORDER BY r.registerDate ASC''',
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
        '''SELECT r.*, u.name AS userName, u.email AS userEmail, u.image AS userImage
           FROM Request r
           INNER JOIN User u ON r.userID = u.ID
           ORDER BY r.registerDate DESC''',
      );
      return result.rows.map((r) => RequestModel.fromMap(r.assoc())).toList();
    } catch (e) {
      print('Error en getAllRequests: $e');
      return [];
    }
  }

  /// Aprueba un request: cambia state=1, guarda processedDate, adminID
  /// y suma las monedas al balance del usuario
  Future<bool> approveRequest({
    required int requestID,
    required int adminID,
  }) async {
    try {
      final conn = await _db.getConnection();

      // Obtener el request para saber cuántas monedas y a qué usuario
      final res = await conn.execute(
        'SELECT value, userID FROM Request WHERE ID = :id',
        {'id': requestID},
      );
      if (res.rows.isEmpty) return false;

      final row = res.rows.first.assoc();
      final coins = int.tryParse(row['value']?.toString() ?? '0') ?? 0;
      final userID = int.tryParse(row['userID']?.toString() ?? '0') ?? 0;

      // Marcar como aprobado
      await conn.execute(
        '''UPDATE Request SET state = 1, processedDate = NOW(), adminID = :adminID
           WHERE ID = :id''',
        {'adminID': adminID, 'id': requestID},
      );

      // Sumar monedas al balance del usuario
      await conn.execute(
        'UPDATE User SET balance = balance + :coins WHERE ID = :userID',
        {'coins': coins, 'userID': userID},
      );

      return true;
    } catch (e) {
      print('Error en approveRequest: $e');
      return false;
    }
  }

  /// Rechaza un request: cambia state=2
  Future<bool> rejectRequest({
    required int requestID,
    required int adminID,
  }) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''UPDATE Request SET state = 2, processedDate = NOW(), adminID = :adminID
           WHERE ID = :id''',
        {'adminID': adminID, 'id': requestID},
      );
      return true;
    } catch (e) {
      print('Error en rejectRequest: $e');
      return false;
    }
  }
}
