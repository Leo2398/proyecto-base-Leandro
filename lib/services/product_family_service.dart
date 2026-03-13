import '../core/db_connection.dart';
import '../models/product_family_model.dart';
import 'interfaces/i_product_family_service.dart';

/// Implementación del servicio de familias de productos
/// Principio S de SOLID: solo maneja operaciones de BD para familias
class ProductFamilyService implements IProductFamilyService {
  /// Instancia de la conexión a la BD
  final DBConnection _db = DBConnection.instance;

  /// Obtiene todas las familias de productos
  @override
  Future<List<ProductFamilyModel>> getAll() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute('SELECT * FROM ProductFamily');

      return result.rows
          .map((row) => ProductFamilyModel.fromMap(row.assoc()))
          .toList();
    } catch (e) {
      print('Error en ProductFamilyService.getAll: $e');
      return [];
    }
  }

  /// Guarda las familias seleccionadas por un productor
  @override
  Future<bool> saveProducerFamilies(
      int producerID, List<int> familyIDs) async {
    try {
      final conn = await _db.getConnection();

      /// Elimina las familias anteriores del productor
      await conn.execute(
        'DELETE FROM ProducerProductFamily WHERE ProducerID = :producerID',
        {'producerID': producerID},
      );

      /// Inserta las nuevas familias seleccionadas
      for (final familyID in familyIDs) {
        await conn.execute(
          '''INSERT INTO ProducerProductFamily (ProducerID, FamilyID) 
          VALUES (:producerID, :familyID)''',
          {'producerID': producerID, 'familyID': familyID},
        );
      }

      return true;
    } catch (e) {
      print('Error en saveProducerFamilies: $e');
      return false;
    }
  }
}