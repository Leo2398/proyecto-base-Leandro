/// Modelo de ítem en el carrito de compras (en memoria, sesión actual)
class CartItem {
  final int productId;
  final int producerID;
  final String nombre;
  final String producerName;
  final double precio;
  final String unidad;
  final String? picture;
  int quantity;

  CartItem({
    required this.productId,
    required this.producerID,
    required this.nombre,
    required this.producerName,
    required this.precio,
    required this.unidad,
    this.picture,
    this.quantity = 1,
  });

  double get subtotal => precio * quantity;

  CartItem copyWith({
    int? productId,
    int? producerID,
    String? nombre,
    String? producerName,
    double? precio,
    String? unidad,
    String? picture,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      producerID: producerID ?? this.producerID,
      nombre: nombre ?? this.nombre,
      producerName: producerName ?? this.producerName,
      precio: precio ?? this.precio,
      unidad: unidad ?? this.unidad,
      picture: picture ?? this.picture,
      quantity: quantity ?? this.quantity,
    );
  }
}