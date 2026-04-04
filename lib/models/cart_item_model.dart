/// Modelo de ítem en el carrito de compras (en memoria, sesión actual)
class CartItem {
  final int productId;
  final String nombre;
  final String producerName;
  final double precio;
  final String unidad;
  final String? picture;
  int quantity;

  CartItem({
    required this.productId,
    required this.nombre,
    required this.producerName,
    required this.precio,
    required this.unidad,
    this.picture,
    this.quantity = 1,
  });

  double get subtotal => precio * quantity;
}