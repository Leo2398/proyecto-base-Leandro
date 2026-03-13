import '../../models/product_family_model.dart';

/// Interfaz del servicio de familias de productos
/// Principio I de SOLID: interfaz específica solo para familias de productos
abstract class IProductFamilyService {
  /// Obtiene todas las familias de productos
  Future<List<ProductFamilyModel>> getAll();

  /// Guarda las familias seleccionadas por un productor
  Future<bool> saveProducerFamilies(int producerID, List<int> familyIDs);
}