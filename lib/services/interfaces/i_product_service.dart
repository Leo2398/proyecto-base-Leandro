import '../../models/product_model.dart';
import '../../models/report_models.dart';

abstract class IProductService {

  /// Top productos más vendidos (por valor de inventario)
  Future<List<TopProductItem>> getTopSellingProducts();

  /// Obtener todos los productos de un productor
  Future<List<ProductModel>> getProductsByProducer(int producerID);

  /// Crear un nuevo producto
  Future<bool> createProduct(ProductModel product);

  /// Actualizar stock de producto
  Future<bool> updateStock(int productID, int newStock);

  /// Actualizar información de producto
  Future<bool> updateProduct(ProductModel product);

}