import '../core/db_connection.dart';
import '../models/delivery_mode_model.dart';
import 'interfaces/i_delivery_mode_service.dart';

/// Implementación del servicio de modalidades de entrega
/// Principio S de SOLID: solo maneja operaciones de BD para delivery modes
class DeliveryModeService implements IDeliveryModeService {
  /// Instancia de la conexión a la BD
  final DBConnection _db = DBConnection.instance;

  /// Obtiene todas las modalidades de entrega
  @override
  Future<List<DeliveryModeModel>> getAll() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute('SELECT * FROM DeliveryMode');

      return result.rows
          .map((row) => DeliveryModeModel.fromMap(row.assoc()))
          .toList();
    } catch (e) {
      print('Error en DeliveryModeService.getAll: $e');
      return [];
    }
  }
}