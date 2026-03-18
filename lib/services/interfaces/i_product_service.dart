import '../../models/product_model.dart';

abstract class IProductService {

  /// Obtener todos los productos de un productor
  Future<List<ProductModel>> getProductsByProducer(int producerID);

  /// Crear un nuevo producto
  Future<bool> createProduct(ProductModel product);

  /// Actualizar stock de producto
  Future<bool> updateStock(int productID, int newStock);

  /// Actualizar información de producto
  Future<bool> updateProduct(ProductModel product);

}