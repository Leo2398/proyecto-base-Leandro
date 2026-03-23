import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/report_models.dart';
import '../../models/user_model.dart';
import 'client_producer_products_view.dart';

/// Detalle de un producto más vendido
/// Muestra info del producto y del productor; permite agregar al carrito
class ClientProductDetailView extends StatelessWidget {
  final TopProductItem item;

  const ClientProductDetailView({super.key, required this.item});

  static const _green = Color(0xFF5A8A5A);
  static const _gold = Color(0xFFB8860B);
  static const _bg = Color(0xFFF5F0E8);
  static const _text = Color(0xFF2D2D2D);
  static const _textSub = Color(0xFF888888);

  ImageProvider? _imgProvider(String? pic) {
    if (pic == null || pic.isEmpty) return null;
    if (pic.startsWith('http')) return NetworkImage(pic);
    final f = File(pic);
    return f.existsSync() ? FileImage(f) : null;
  }

  void _addToCart(BuildContext context) {
    context.read<CartController>().addFromTopItem(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${item.nombre}" agregado al carrito'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goToProducer(BuildContext context) {
    if (item.producerId <= 0) return;
    final userCtrl = context.read<UserController>();
    // Busca el productor en la lista cargada; si no está, crea un stub con los datos disponibles
    UserModel? producer;
    try {
      producer = userCtrl.producers.firstWhere((p) => p.id == item.producerId);
    } catch (_) {
      producer = null;
    }
    producer ??= UserModel(
      id: item.producerId,
      name: item.producerName,
      email: '',
      password: '',
      role: 1,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProducerProductsView(producer: producer!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imgProvider = _imgProvider(item.picture);
    final precio = item.precio.toStringAsFixed(
        item.precio % 1 == 0 ? 0 : 2);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalle del Producto',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
        actions: [
          Consumer<CartController>(
            builder: (_, cart, __) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: _text),
                  onPressed: () {},
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: _green,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Imagen del producto ---
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: imgProvider != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image(
                          image: imgProvider, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Icon(Icons.eco_outlined,
                          size: 80, color: _green),
                    ),
            ),
            const SizedBox(height: 16),

            // --- Info del producto ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on_outlined,
                          size: 18, color: _gold),
                      const SizedBox(width: 4),
                      Text(
                        '$precio / ${item.unidad}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 16, color: _textSub),
                      const SizedBox(width: 4),
                      Text(
                        'Stock disponible: ${item.stock}',
                        style: const TextStyle(
                            fontSize: 13, color: _textSub),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Productor ---
            const Text(
              'Productor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _goToProducer(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0EDE0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar productor (tappable)
                    GestureDetector(
                      onTap: () => _goToProducer(context),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: _green.withOpacity(0.15),
                        child: Text(
                          item.producerName.isNotEmpty
                              ? item.producerName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _green,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre del productor (tappable)
                          GestureDetector(
                            onTap: () => _goToProducer(context),
                            child: Text(
                              item.producerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _green,
                                decoration: TextDecoration.underline,
                                decorationColor: _green,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Toca para ver todos sus productos',
                            style: TextStyle(
                                fontSize: 11, color: _textSub),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: _textSub, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Botón agregar al carrito ---
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: item.stock > 0
                    ? () => _addToCart(context)
                    : null,
                icon: const Icon(Icons.shopping_cart_outlined,
                    size: 20),
                label: Text(
                  item.stock > 0
                      ? 'Agregar al carrito'
                      : 'Sin stock disponible',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- Botón ver todos los productos del productor ---
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: item.producerId > 0
                    ? () => _goToProducer(context)
                    : null,
                icon: const Icon(Icons.store_outlined, size: 20),
                label: const Text(
                  'Ver productos del productor',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: _green),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
