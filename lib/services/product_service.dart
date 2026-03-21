import '../core/db_connection.dart';
import '../models/product_model.dart';
import 'interfaces/i_product_service.dart';

/// Implementación del servicio de productos
/// Principio S de SOLID: solo maneja operaciones de BD para productos
class ProductService implements IProductService {
  final DBConnection _db = DBConnection.instance;

  /// Obtener productos por productor
  @override
  Future<List<ProductModel>> getProductsByProducer(int producerID) async {
    try {
      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT *
        FROM Product
        WHERE UserID = :producerID
        ORDER BY ID DESC
        ''',
        {'producerID': producerID},
      );

      final products = result.rows.map((row) {
        final data = row.assoc();
        return ProductModel.fromMap(data);
      }).toList();

      print('✓ Productos cargados: ${products.length}');
      return products;
    } catch (e) {
      print('Error en getProductsByProducer: $e');
      return [];
    }
  }

  /// Crear producto
  @override
  Future<bool> createProduct(ProductModel product) async {
    try {
      final conn = await _db.getConnection();

      await conn.execute(
        '''
        INSERT INTO Product
        (name, picture, description, price, unit, stock, state, HarvestDate, UserID)
        VALUES
        (:name, :picture, :description, :price, :unit, :stock, :state, :harvestDate, :userID)
        ''',
        {
          'name': product.name.trim(),
          'picture': _normalizeText(product.picture),
          'description': _normalizeText(product.description),
          'price': product.price,
          'unit': _normalizeText(product.unit),
          'stock': product.stock,
          'state': product.state,
          'harvestDate': _formatDateTimeForSql(product.harvestDate),
          'userID': product.userID,
        },
      );

      print('✓ Producto creado correctamente');
      return true;
    } catch (e) {
      print('Error en createProduct: $e');
      return false;
    }
  }

  /// Actualizar stock
  @override
  Future<bool> updateStock(int productID, int newStock) async {
    try {
      final conn = await _db.getConnection();

      await conn.execute(
        '''
        UPDATE Product
        SET stock = :stock
        WHERE ID = :id
        ''',
        {
          'stock': newStock,
          'id': productID,
        },
      );

      print('✓ Stock actualizado correctamente');
      return true;
    } catch (e) {
      print('Error en updateStock: $e');
      return false;
    }
  }

  /// Actualizar producto completo
  @override
  Future<bool> updateProduct(ProductModel product) async {
    try {
      if (product.id == null) {
        print('Error en updateProduct: el producto no tiene ID');
        return false;
      }

      final conn = await _db.getConnection();

      await conn.execute(
        '''
        UPDATE Product SET
          name = :name,
          picture = :picture,
          description = :description,
          price = :price,
          unit = :unit,
          stock = :stock,
          state = :state,
          HarvestDate = :harvestDate
        WHERE ID = :id
        ''',
        {
          'name': product.name.trim(),
          'picture': _normalizeText(product.picture),
          'description': _normalizeText(product.description),
          'price': product.price,
          'unit': _normalizeText(product.unit),
          'stock': product.stock,
          'state': product.state,
          'harvestDate': _formatDateTimeForSql(product.harvestDate),
          'id': product.id,
        },
      );

      print('✓ Producto actualizado correctamente');
      return true;
    } catch (e) {
      print('Error en updateProduct: $e');
      return false;
    }
  }

  String? _normalizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _formatDateTimeForSql(DateTime? dateTime) {
    if (dateTime == null) return null;

    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute:$second';
  }
}