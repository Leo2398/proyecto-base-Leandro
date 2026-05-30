import '../core/db_connection.dart';
import '../models/delivery_mode_model.dart';
import 'interfaces/i_delivery_mode_service.dart';
import 'dart:developer' as developer;

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
      final result = await conn.execute('SELECT * FROM deliverymode');

      developer.log('deliverymode - Total rows: ${result.rows.length}');

      if (result.rows.isNotEmpty) {
        developer.log(
          'deliverymode - Primera fila: ${result.rows.first.assoc()}',
        );
      }

      final modes = result.rows
          .map((row) {
        try {
          return DeliveryModeModel.fromMap(row.assoc());
        } catch (e) {
          developer.log(
            'Error parseando deliverymode: $e, data: ${row.assoc()}',
          );
          rethrow;
        }
      })
          .toList();

      developer.log('✓ deliverymode cargadas exitosamente: ${modes.length}');
      return modes;
    } catch (e) {
      print('Error en getAll: $e');
      return [];
    }
  }
}