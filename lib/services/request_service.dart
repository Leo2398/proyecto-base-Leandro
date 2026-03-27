import '../core/db_connection.dart';
import '../models/request_model.dart';
import '../models/app_config_model.dart';

/// Principio S de SOLID: solo maneja operaciones de BD para Request y AppConfig
class RequestService {
  final DBConnection _db = DBConnection.instance;

  // ── AppConfig ──────────────────────────────────────────────────────────────

  /// Obtiene la configuración de la app (precio por moneda y QR)
  Future<AppConfigModel> getAppConfig() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute('SELECT * FROM AppConfig LIMIT 1');
      if (result.rows.isEmpty) return AppConfigModel.defaults;
      return AppConfigModel.fromMap(result.rows.first.assoc());
    } catch (e) {
      print('Error en getAppConfig: $e');
      return AppConfigModel.defaults;
    }
  }

  /// Actualiza precio por moneda y QR (solo admin)
  Future<bool> updateAppConfig({
    required double bsPerCoin,
    String? qrImage,
  }) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''UPDATE AppConfig SET bsPerCoin = :bsPerCoin,
           qrImage = :qrImage, updatedAt = NOW()
           WHERE id = 1''',
        {'bsPerCoin': bsPerCoin, 'qrImage': qrImage},
      );
      return true;
    } catch (e) {
      print('Error en updateAppConfig: $e');
      return false;
    }
  }

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
      print('✓ Request creado correctamente');
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
      return result.rows
          .map((r) => RequestModel.fromMap(r.assoc()))
          .toList();
    } catch (e) {
      print('Error en getRequestsByUser: $e');
      return [];
    }
  }

  /// Obtiene el request pendiente más reciente de un usuario (para polling)
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

  /// Consulta el estado actual de un request por ID (para polling)
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

  /// Obtiene todos los requests pendientes (para el admin)
  Future<List<RequestModel>> getAllPendingRequests() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''SELECT * FROM Request WHERE state = 0
           ORDER BY registerDate ASC''',
      );
      return result.rows
          .map((r) => RequestModel.fromMap(r.assoc()))
          .toList();
    } catch (e) {
      print('Error en getAllPendingRequests: $e');
      return [];
    }
  }

  /// Aprueba un request: cambia state=1, guarda processedDate y adminID
  Future<bool> approveRequest({
    required int requestID,
    required int adminID,
  }) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''UPDATE Request SET state = 1, processedDate = NOW(), adminID = :adminID
           WHERE ID = :id''',
        {'adminID': adminID, 'id': requestID},
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