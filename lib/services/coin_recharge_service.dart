import '../core/db_connection.dart';
import '../models/coin_recharge_model.dart';

/// Servicio para gestión de solicitudes de recarga de monedas
class CoinRechargeService {
  final DBConnection _db = DBConnection.instance;

  /// Crea la tabla si no existe
  Future<void> initTable() async {
    try {
      final conn = await _db.getConnection();
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS coinrecharge (
          ID INT AUTO_INCREMENT PRIMARY KEY,
          userID INT NOT NULL,
          coinsRequested INT NOT NULL,
          amountPaid DECIMAL(10,2) NOT NULL,
          proofImage VARCHAR(500),
          status VARCHAR(20) DEFAULT 'pending',
          requestDate DATETIME DEFAULT CURRENT_TIMESTAMP,
          resolvedDate DATETIME NULL,
          adminID INT NULL
        )
      ''');
    } catch (e) {
      print('Error en CoinRechargeService.initTable: $e');
    }
  }

  /// El cliente envía una solicitud de recarga
  Future<bool> createRequest({
    required int userId,
    required int coinsRequested,
    required double amountPaid,
    String? proofImage,
  }) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''
        INSERT INTO coinrecharge (userID, coinsRequested, amountPaid, proofImage, status)
        VALUES (:userId, :coins, :amount, :proof, 'pending')
        ''',
        {
          'userId': userId,
          'coins': coinsRequested,
          'amount': amountPaid,
          'proof': proofImage,
        },
      );
      return true;
    } catch (e) {
      print('Error en createRequest: $e');
      return false;
    }
  }

  /// Todas las solicitudes pendientes (JOIN con user para datos del solicitante)
  Future<List<CoinRechargeModel>> getPendingRequests() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute('''
        SELECT cr.*, u.name AS userName, u.email AS userEmail, u.image AS userImage
        FROM coinrecharge cr
        JOIN user u ON u.ID = cr.userID
        WHERE cr.status = 'pending'
        ORDER BY cr.requestDate DESC
      ''');
      return result.rows
          .map((r) => CoinRechargeModel.fromMap(r.assoc()))
          .toList();
    } catch (e) {
      print('Error en getPendingRequests: $e');
      return [];
    }
  }

  /// Todas las solicitudes (historial completo)
  Future<List<CoinRechargeModel>> getAllRequests() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute('''
        SELECT cr.*, u.name AS userName, u.email AS userEmail, u.image AS userImage
        FROM coinrecharge cr
        JOIN user u ON u.ID = cr.userID
        ORDER BY cr.requestDate DESC
      ''');
      return result.rows
          .map((r) => CoinRechargeModel.fromMap(r.assoc()))
          .toList();
    } catch (e) {
      print('Error en getAllRequests: $e');
      return [];
    }
  }

  /// Solicitudes de un usuario específico
  Future<List<CoinRechargeModel>> getRequestsByUser(int userId) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT cr.*, u.name AS userName, u.email AS userEmail, u.image AS userImage
        FROM coinrecharge cr
        JOIN user u ON u.ID = cr.userID
        WHERE cr.userID = :userId
        ORDER BY cr.requestDate DESC
        ''',
        {
          'userId': userId,
        },
      );
      return result.rows
          .map((r) => CoinRechargeModel.fromMap(r.assoc()))
          .toList();
    } catch (e) {
      print('Error en getRequestsByUser: $e');
      return [];
    }
  }

  /// Aprueba la solicitud y acredita las monedas al usuario
  Future<bool> approveRequest(int requestId) async {
    try {
      final conn = await _db.getConnection();

      // 1. Obtener los datos de la solicitud
      final res = await conn.execute(
        'SELECT * FROM coinrecharge WHERE ID = :id',
        {'id': requestId},
      );
      if (res.rows.isEmpty) return false;

      final data = res.rows.first.assoc();
      final userId = int.tryParse(data['userID']?.toString() ?? '') ?? 0;
      final coins = int.tryParse(data['coinsRequested']?.toString() ?? '') ?? 0;

      if (userId <= 0 || coins <= 0) return false;

      // 2. Actualizar estado de la solicitud
      await conn.execute(
        '''
        UPDATE coinrecharge
        SET status = 'approved', resolvedDate = NOW()
        WHERE ID = :id
        ''',
        {'id': requestId},
      );

      // 3. Agregar monedas al balance del usuario
      await conn.execute(
        'UPDATE user SET balance = balance + :coins WHERE ID = :userId',
        {'coins': coins, 'userId': userId},
      );

      return true;
    } catch (e) {
      print('Error en approveRequest: $e');
      return false;
    }
  }

  /// Rechaza la solicitud (sin modificar el balance)
  Future<bool> rejectRequest(int requestId) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''
        UPDATE coinrecharge
        SET status = 'rejected', resolvedDate = NOW()
        WHERE ID = :id
        ''',
        {'id': requestId},
      );
      return true;
    } catch (e) {
      print('Error en rejectRequest: $e');
      return false;
    }
  }
}