import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/report_models.dart';
import '../../services/product_service.dart';

/// Vista de productos más vendidos para el cliente
/// Principio S de SOLID: solo maneja la UI de más vendidos
class ClientBestSellersView extends StatefulWidget {
  const ClientBestSellersView({super.key});

  @override
  State<ClientBestSellersView> createState() => _ClientBestSellersViewState();
}

class _ClientBestSellersViewState extends State<ClientBestSellersView> {
  static const _green = Color(0xFF5A8A5A);
  static const _background = Color(0xFFF5F0E8);

  final ProductService _service = ProductService();
  List<TopProductItem> _products = [];
  bool _loading = true;

  /// Registros de ejemplo para mostrar mientras no haya datos en BD
  static const List<TopProductItem> _placeholders = [
    TopProductItem(
      id: -1,
      nombre: 'Tomate Cherry Orgánico',
      producerName: 'FreshFarm Co.',
      precio: 2.0,
      stock: 500,
      unidad: 'kg',
      picture: null,
    ),
    TopProductItem(
      id: -2,
      nombre: 'Lechuga Hidropónica',
      producerName: 'Verde Vital',
      precio: 4.0,
      stock: 300,
      unidad: '100g',
      picture: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _service.getTopSellingProducts();
    if (mounted) {
      setState(() {
        _products = result;
        _loading = false;
      });
    }
  }

  List<TopProductItem> get _displayItems =>
      _products.isNotEmpty ? _products : _placeholders;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF2D2D2D), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Más Vendidos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _green),
            )
          : RefreshIndicator(
              color: _green,
              onRefresh: _load,
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _displayItems.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeader();
                  }
                  final item = _displayItems[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BestSellerCard(item: item, rank: index),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: const [
                Icon(Icons.trending_up, color: _green, size: 16),
                SizedBox(width: 4),
                Text(
                  'Top productos del mercado',
                  style: TextStyle(
                    fontSize: 12,
                    color: _green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BestSellerCard extends StatelessWidget {
  final TopProductItem item;
  final int rank;

  const _BestSellerCard({required this.item, required this.rank});

  static const _cardColors = [
    Color(0xFFE8F5E8),
    Color(0xFFE8F0F8),
    Color(0xFFFFF3E0),
    Color(0xFFF3E8F5),
    Color(0xFFE8F5F0),
  ];

  ImageProvider? _imageProvider(String? pic) {
    if (pic == null || pic.isEmpty) return null;
    if (pic.startsWith('http')) return NetworkImage(pic);
    final f = File(pic);
    return f.existsSync() ? FileImage(f) : null;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _cardColors[(rank - 1) % _cardColors.length];
    final imgProvider = _imageProvider(item.picture);

    return Container(
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
      child: Row(
        children: [
          /// Imagen del producto
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: Container(
              width: 110,
              height: 110,
              color: bgColor,
              child: imgProvider != null
                  ? Image(image: imgProvider, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(
                        Icons.eco_outlined,
                        size: 44,
                        color: Color(0xFF5A8A5A),
                      ),
                    ),
            ),
          ),

          /// Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Ranking badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A8A5A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#$rank más vendido',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    item.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  Text(
                    item.producerName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// Precio
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on_outlined,
                            size: 14,
                            color: Color(0xFFB8860B),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${item.precio.toStringAsFixed(item.precio % 1 == 0 ? 0 : 2)}/${item.unidad}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                        ],
                      ),

                      /// Stock
                      Text(
                        'Stock: ${item.stock}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
