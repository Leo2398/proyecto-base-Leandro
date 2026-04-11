import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../models/report_models.dart';

/// Principio S de SOLID: solo maneja el estado del carrito
/// Regla de negocio: no se pueden mezclar productos de diferentes empresas
class CartController extends ChangeNotifier {
  final List<CartItem> _items = [];

  /// Nombre de la empresa/productor actual en el carrito (null si está vacío)
  String? _currentProducerName;

  /// ID del productor actual en el carrito (null si está vacío)
  int? _currentProducerID;

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get total => _items.fold(0.0, (sum, i) => sum + i.subtotal);

  String? get currentProducerName => _currentProducerName;
  int? get currentProducerID => _currentProducerID;

  bool get isEmpty => _items.isEmpty;

  /// Verifica si se puede agregar un producto de una empresa distinta
  bool canAddFromProducer({
    required int producerID,
    required String producerName,
  }) {
    if (_items.isEmpty) return true;
    return _currentProducerID == producerID &&
        _currentProducerName == producerName;
  }

  /// Agrega desde ProductModel. Retorna false si es de otra empresa.
  bool addFromProduct(ProductModel product, {String producerName = ''}) {
    final int producerID = product.userID;

    if (!canAddFromProducer(
      producerID: producerID,
      producerName: producerName,
    )) {
      return false;
    }

    _currentProducerID = producerID;
    _currentProducerName = producerName;

    final idx = _items.indexWhere((i) => i.productId == (product.id ?? -1));

    if (idx >= 0) {
      _items[idx].quantity++;
    } else {
      _items.add(
        CartItem(
          productId: product.id ?? 0,
          producerID: producerID,
          nombre: product.name,
          producerName: producerName,
          precio: product.price,
          unidad: product.unit ?? 'unidad',
          picture: product.picture,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  /// Agrega desde TopProductItem. Retorna false si es de otra empresa.
  bool addFromTopItem(TopProductItem item) {
    if (!canAddFromProducer(
      producerID: item.producerId,
      producerName: item.producerName,
    )) {
      return false;
    }

    _currentProducerID = item.producerId;
    _currentProducerName = item.producerName;

    final idx = _items.indexWhere((i) => i.productId == item.id);

    if (idx >= 0) {
      _items[idx].quantity++;
    } else {
      _items.add(
        CartItem(
          productId: item.id,
          producerID: item.producerId,
          nombre: item.nombre,
          producerName: item.producerName,
          precio: item.precio,
          unidad: item.unidad,
          picture: item.picture,
        ),
      );
    }

    notifyListeners();
    return true;
  }

  /// Incrementa cantidad de un producto
  void increment(int productId) {
    final idx = _items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;

    _items[idx].quantity++;
    notifyListeners();
  }

  /// Decrementa cantidad. Si llega a 0 lo elimina.
  void decrement(int productId) {
    final idx = _items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;

    if (_items[idx].quantity <= 1) {
      _items.removeAt(idx);
    } else {
      _items[idx].quantity--;
    }

    if (_items.isEmpty) {
      _currentProducerName = null;
      _currentProducerID = null;
    }

    notifyListeners();
  }

  void removeItem(int productId) {
    _items.removeWhere((i) => i.productId == productId);

    if (_items.isEmpty) {
      _currentProducerName = null;
      _currentProducerID = null;
    }

    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _currentProducerName = null;
    _currentProducerID = null;
    notifyListeners();
  }
}