import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';

class ClientProducerProductsView extends StatefulWidget {
  final UserModel producer;

  const ClientProducerProductsView({
    super.key,
    required this.producer,
  });

  @override
  State<ClientProducerProductsView> createState() =>
      _ClientProducerProductsViewState();
}

class _ClientProducerProductsViewState
    extends State<ClientProducerProductsView> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'Todos';

  final List<String> _filters = const [
    'Todos',
    'Disponibles',
    'Stock bajo',
    'Agotados',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProducts() async {
    if (widget.producer.id == null) return;

    final productController =
    Provider.of<ProductController>(context, listen: false);

    await productController.getProductsByProducer(widget.producer.id!);

    if (mounted) {
      setState(() {});
    }
  }

  List<ProductModel> _visibleProducts(List<ProductModel> products) {
    final query = _searchController.text.toLowerCase().trim();

    return products.where((product) {
      if (product.state != 1) return false;

      final name = product.name.toLowerCase();
      final description = (product.description ?? '').toLowerCase();

      final matchesSearch =
          query.isEmpty || name.contains(query) || description.contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'Disponibles' => product.stock > 3,
        'Stock bajo' => product.stock > 0 && product.stock <= 3,
        'Agotados' => product.stock == 0,
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  int _availableCount(List<ProductModel> products) {
    return products.where((p) => p.state == 1 && p.stock > 0).length;
  }

  int _lowStockCount(List<ProductModel> products) {
    return products.where((p) => p.state == 1 && p.stock > 0 && p.stock <= 3).length;
  }

  double _averagePrice(List<ProductModel> products) {
    final visible = products.where((p) => p.state == 1).toList();
    if (visible.isEmpty) return 0;

    final total = visible.fold(0.0, (sum, p) => sum + p.price);
    return total / visible.length;
  }

  String _formatMoney(double value) {
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _harvestLabel(DateTime? date) {
    if (date == null) return 'Sin fecha de cosecha';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final harvest = DateTime(date.year, date.month, date.day);
    final diff = today.difference(harvest).inDays;

    if (diff < 0) return 'Cosecha programada';
    if (diff == 0) return 'Cosechado hoy';
    if (diff == 1) return 'Cosechado hace 1 día';
    return 'Cosechado hace $diff días';
  }

  String _stockText(ProductModel product) {
    if (product.stock == 0) return 'Agotado';
    if (product.stock <= 3) return 'Pocas unidades';
    return 'Disponible';
  }

  Color _stockColor(ProductModel product) {
    if (product.stock == 0) return const Color(0xFFD96C2F);
    if (product.stock <= 3) return const Color(0xFFD96C2F);
    return const Color(0xFF5A8A5A);
  }

  // Reemplaza SOLO el método _addToCart en client_producer_products_view.dart

  void _addToCart(ProductModel product) {
    final cart = context.read<CartController>();

    // Verifica si el producto es de otra empresa
    if (!cart.canAddFromProducer(widget.producer.name)) {
      // Muestra el aviso de empresa diferente
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D8CE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Color(0xFFD96C2F),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Solo una empresa por pedido',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu carrito ya tiene productos de "${cart.currentProducerName}". '
                'Vacía el carrito para agregar productos de otra empresa.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14, color: Color(0xFF888888), height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5A8A5A),
                        side: const BorderSide(color: Color(0xFF5A8A5A)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        cart.clearCart();
                        Navigator.pop(context);
                        // Reintenta agregar después de limpiar
                        cart.addFromProduct(
                          product,
                          producerName: widget.producer.name,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${product.name}" agregado al carrito'),
                            backgroundColor: const Color(0xFF5A8A5A),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD96C2F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Vaciar y agregar',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Agrega normalmente
    cart.addFromProduct(product, producerName: widget.producer.name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${product.name}" agregado al carrito'),
        backgroundColor: const Color(0xFF5A8A5A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productController = context.watch<ProductController>();
    final products = productController.products;
    final filteredProducts = _visibleProducts(products);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF5F0E8),
              Color(0xFFF7F2EA),
              Color(0xFFF2ECE2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadProducts,
            color: const Color(0xFF5A8A5A),
            child: productController.isLoading
                ? ListView(
              children: const [
                SizedBox(height: 220),
                Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF5A8A5A),
                  ),
                ),
              ],
            )
                : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildTopBar(),
                const SizedBox(height: 18),
                _buildHeroCard(products),
                const SizedBox(height: 18),
                _buildSearchBar(),
                const SizedBox(height: 14),
                _buildFilters(),
                const SizedBox(height: 18),
                _buildSectionHeader(filteredProducts.length),
                const SizedBox(height: 12),
                if (productController.errorMessage != null)
                  _buildErrorState(productController.errorMessage!)
                else if (filteredProducts.isEmpty)
                  _buildEmptyState()
                else
                  ...filteredProducts.map(_buildProductCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF2D2D2D),
            size: 20,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(10),
            elevation: 2,
            shadowColor: Colors.black12,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Productos de la productora',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(List<ProductModel> products) {
    final initial = widget.producer.name.isNotEmpty
        ? widget.producer.name[0].toUpperCase()
        : 'P';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5A8A5A),
            Color(0xFF4C774C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A8A5A).withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -16,
            right: -12,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -26,
            left: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Productora agrícola',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.producer.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.producer.description?.isNotEmpty == true
                      ? widget.producer.description!
                      : 'Explora el catálogo disponible de esta productora y revisa sus productos antes de comprar.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeroMiniCard(
                        label: 'Productos',
                        value: products.where((p) => p.state == 1).length.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHeroMiniCard(
                        label: 'Disponibles',
                        value: _availableCount(products).toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHeroMiniCard(
                        label: 'Promedio',
                        value: '${_formatMoney(_averagePrice(products))} mon.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMiniCard({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DED1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar producto...',
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF888888),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            onPressed: () => _searchController.clear(),
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF888888),
            ),
          )
              : const Icon(
            Icons.tune_rounded,
            color: Color(0xFF5A8A5A),
          ),
          filled: true,
          fillColor: const Color(0xFFF8F5EF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final selected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF5A8A5A)
                    : const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF5A8A5A)
                      : const Color(0xFFE7DED1),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF5B4A3C),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(int total) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Catálogo disponible',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ),
        Text(
          '$total producto${total == 1 ? '' : 's'}',
          style: const TextStyle(
            color: Color(0xFF5A8A5A),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final stockColor = _stockColor(product);
    final stockText = _stockText(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E8DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: product.picture != null && product.picture!.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      product.picture!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF5A8A5A),
                          size: 34,
                        );
                      },
                    ),
                  )
                      : const Icon(
                    Icons.eco_outlined,
                    color: Color(0xFF5A8A5A),
                    size: 34,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: stockColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: stockColor.withOpacity(0.18),
                              ),
                            ),
                            child: Text(
                              stockText,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: stockColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.description?.isNotEmpty == true
                            ? product.description!
                            : 'Producto fresco disponible en el catálogo.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF888888),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        icon: Icons.monetization_on_outlined,
                        color: const Color(0xFFB8860B),
                        text:
                        '${_formatMoney(product.price)} monedas / ${product.unit ?? 'unidad'}',
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.inventory_2_outlined,
                        color: const Color(0xFF6C757D),
                        text: 'Stock: ${product.stock}',
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.calendar_month_outlined,
                        color: const Color(0xFF6C757D),
                        text: _harvestLabel(product.harvestDate),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        icon: Icons.verified_outlined,
                        color: const Color(0xFF5A8A5A),
                        text: _formatDate(product.harvestDate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            height: 1,
            color: const Color(0xFFF1E8DC),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Consumer<CartController>(
                    builder: (_, cart, __) {
                      final inCart = cart.items.any(
                          (i) => i.productId == (product.id ?? -1));
                      return OutlinedButton.icon(
                        onPressed: product.stock == 0
                            ? null
                            : () => _addToCart(product),
                        icon: Icon(
                          inCart
                              ? Icons.check_circle_outline
                              : Icons.shopping_cart_outlined,
                          size: 18,
                        ),
                        label: Text(inCart
                            ? 'En carrito'
                            : 'Agregar al carrito'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5A8A5A),
                          side: const BorderSide(
                              color: Color(0xFFD7E4D7)),
                          backgroundColor: const Color(0xFFF8FCF8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E8DC)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD96C2F),
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadProducts,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A8A5A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E8DC)),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFE8F0E8),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: Color(0xFF5A8A5A),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'No se encontraron productos',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF2D2D2D),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Prueba con otra búsqueda o cambia el filtro seleccionado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF888888),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}