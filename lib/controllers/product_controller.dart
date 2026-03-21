import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/interfaces/i_product_service.dart';
import '../services/product_service.dart';

/// Controlador de Productos
/// Principio S de SOLID: solo maneja la lógica de negocio de productos
/// Principio D de SOLID: depende de la interfaz IProductService
/// Implementa ChangeNotifier para el patrón Observer
class ProductController extends ChangeNotifier {
  /// Dependencia de la interfaz, no de la implementación
  final IProductService _productService;

  /// Lista de productos cargados
  List<ProductModel> _products = [];

  /// Indica si hay una operación en progreso
  bool _isLoading = false;

  /// Mensaje de error de la última operación
  String? _errorMessage;

  /// Constructor con inyección de dependencias
  ProductController({IProductService? productService})
      : _productService = productService ?? ProductService();

  /// Getters para acceder al estado desde la UI
  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Obtiene los productos de un productor
  Future<List<ProductModel>> getProductsByProducer(int producerID) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _productService.getProductsByProducer(producerID);
      _products = result;

      return result;
    } catch (e) {
      _errorMessage = 'Error obteniendo productos: $e';
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea un nuevo producto
  Future<bool> createProduct(ProductModel product) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _productService.createProduct(product);

      if (!success) {
        _errorMessage = 'Error al crear producto';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error creando producto: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza el stock de un producto
  Future<bool> updateStock(int productID, int newStock) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (newStock < 0) {
        _errorMessage = 'El stock no puede ser negativo';
        return false;
      }

      final success = await _productService.updateStock(productID, newStock);

      if (!success) {
        _errorMessage = 'Error al actualizar stock';
        return false;
      }

      /// Actualiza también la lista local si el producto ya está cargado
      final index = _products.indexWhere((p) => p.id == productID);
      if (index != -1) {
        final currentProduct = _products[index];
        _products[index] = ProductModel(
          id: currentProduct.id,
          name: currentProduct.name,
          picture: currentProduct.picture,
          description: currentProduct.description,
          price: currentProduct.price,
          unit: currentProduct.unit,
          stock: newStock,
          state: currentProduct.state,
          harvestDate: currentProduct.harvestDate,
          userID: currentProduct.userID,
        );
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error actualizando stock: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza un producto completo
  Future<bool> updateProduct(ProductModel product) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _productService.updateProduct(product);

      if (!success) {
        _errorMessage = 'Error al actualizar producto';
        return false;
      }

      /// Actualiza también la lista local si el producto ya existe en memoria
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error actualizando producto: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpia los productos cargados
  void clearProducts() {
    _products = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpia el mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}