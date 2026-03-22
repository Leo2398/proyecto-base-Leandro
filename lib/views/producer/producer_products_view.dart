import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/product_model.dart';
import 'producer_create_product_view.dart';
import 'producer_edit_product_view.dart';

class ProducerProductsView extends StatefulWidget {
  const ProducerProductsView({super.key});

  @override
  State<ProducerProductsView> createState() => _ProducerProductsViewState();
}

class _ProducerProductsViewState extends State<ProducerProductsView> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'Todos';

  final List<String> _filters = [
    'Todos',
    'Activos',
    'Pausados',
    'Stock bajo',
    'Sin stock',
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
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProducts() async {
    final userController = Provider.of<UserController>(context, listen: false);
    final productController =
    Provider.of<ProductController>(context, listen: false);

    final currentUser = userController.currentUser;

    if (currentUser == null || currentUser.id == null) {
      return;
    }

    await productController.getProductsByProducer(currentUser.id!);

    if (mounted) {
      setState(() {});
    }
  }

  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    final query = _searchController.text.toLowerCase().trim();

    return products.where((product) {
      final name = product.name.toLowerCase();
      final description = (product.description ?? '').toLowerCase();

      final matchesSearch =
          query.isEmpty || name.contains(query) || description.contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'Activos' => product.state == 1,
        'Pausados' => product.state == 0,
        'Stock bajo' => product.state == 1 && product.stock > 0 && product.stock <= 3,
        'Sin stock' => product.stock == 0,
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _getStateText(ProductModel product) {
    if (product.state == 0) return 'Pausado';
    if (product.stock == 0) return 'Sin stock';
    if (product.stock <= 3) return 'Stock bajo';
    return 'Activo';
  }

  Color _getStateColor(ProductModel product) {
    if (product.state == 0) return const Color(0xFF8F8F8F);
    if (product.stock == 0) return const Color(0xFFD96C2F);
    if (product.stock <= 3) return const Color(0xFFD96C2F);
    return const Color(0xFF2E8B57);
  }

  String _formatHarvestDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getHarvestLabel(DateTime? date) {
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

  String _getStockLabel(ProductModel product) {
    if (product.stock == 0) return 'Sin stock disponible';
    if (product.stock <= 3) return 'Quedan ${product.stock} unidades';
    if (product.stock <= 10) return 'Stock limitado';
    return 'Disponible para venta';
  }

  int _activeProductsCount(List<ProductModel> products) =>
      products.where((p) => p.state == 1).length;

  int _lowStockCount(List<ProductModel> products) => products
      .where((p) => p.state == 1 && p.stock > 0 && p.stock <= 3)
      .length;

  int _totalStock(List<ProductModel> products) =>
      products.fold(0, (sum, product) => sum + product.stock);

  int _pausedProductsCount(List<ProductModel> products) =>
      products.where((p) => p.state == 0).length;

  double _estimatedBalance(List<ProductModel> products) {
    return products.fold(
      0.0,
          (sum, product) => sum + (product.price * product.stock),
    );
  }

  int _soldOutCount(List<ProductModel> products) =>
      products.where((p) => p.stock == 0).length;

  double _getMaxContentWidth(double screenWidth) {
    if (screenWidth >= 1400) return 1120;
    if (screenWidth >= 1100) return 980;
    if (screenWidth >= 800) return 780;
    return screenWidth;
  }

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (screenWidth >= 1000) {
      return const EdgeInsets.fromLTRB(24, 22, 24, 120);
    }
    return const EdgeInsets.fromLTRB(16, 16, 16, 110);
  }

  @override
  Widget build(BuildContext context) {
    final productController = context.watch<ProductController>();
    final userController = context.watch<UserController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = _getMaxContentWidth(screenWidth);
    final products = productController.products;
    final filteredProducts = _getFilteredProducts(products);

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
            color: const Color(0xFFC69A5B),
            child: productController.isLoading
                ? ListView(
              children: const [
                SizedBox(height: 220),
                Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFC69A5B),
                  ),
                ),
              ],
            )
                : productController.errorMessage != null
                ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 100),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Text(
                      productController.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            )
                : ListView(
              padding: EdgeInsets.zero,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints:
                    BoxConstraints(maxWidth: maxContentWidth),
                    child: Padding(
                      padding: _getResponsivePadding(screenWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(userController),
                          const SizedBox(height: 18),
                          _buildProducerBanner(userController),
                          const SizedBox(height: 18),
                          _buildQuickStats(products),
                          const SizedBox(height: 18),
                          _buildHighlightsRow(products),
                          const SizedBox(height: 18),
                          _buildMainWhitePanel(
                            screenWidth,
                            products,
                            filteredProducts,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFC7942E),
        elevation: 8,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const ProducerCreateProductView(),
            ),
          );

          if (created == true) {
            await _loadProducts();

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Producto publicado correctamente'),
              ),
            );
          }
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Publicar producto',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(UserController userController) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF5A3E2B),
            size: 20,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(10),
            shadowColor: Colors.black12,
            elevation: 2,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mis productos',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E3426),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Gestiona tu catálogo agrícola',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8C7B6B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.monetization_on_outlined,
                color: Color(0xFFC7942E),
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '${userController.currentUser?.balance.toStringAsFixed(0) ?? '0'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E3426),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF4E3426),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProducerBanner(UserController userController) {
    final producerName = userController.currentUser?.name ?? 'Productor';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD6CCBE),
            Color(0xFFC8B9A7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -20,
            right: -10,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.black.withOpacity(0.03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.agriculture_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.26),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Proveedor verificado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFD36B),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '4.8',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  producerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Proveedor agrícola',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Gestiona tus productos, controla el stock y mantén tu catálogo listo para nuevos pedidos.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBannerChip(Icons.eco_outlined, 'Orgánico'),
                    _buildBannerChip(
                      Icons.local_shipping_outlined,
                      'Entrega activa',
                    ),
                    _buildBannerChip(
                      Icons.inventory_2_outlined,
                      'Catálogo visible',
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

  Widget _buildBannerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(List<ProductModel> products) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Activos',
            value: _activeProductsCount(products).toString(),
            subtitle: 'Disponibles en catálogo',
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF3F7D58),
            background: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Stock bajo',
            value: _lowStockCount(products).toString(),
            subtitle: 'Productos por reponer',
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFD96C2F),
            background: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Unidades',
            value: _totalStock(products).toString(),
            subtitle: 'Inventario total',
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF8A6A45),
            background: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0E8DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconColor.withOpacity(0.12),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E3426),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6D5B4C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9A8E80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsRow(List<ProductModel> products) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniInsightCard(
            icon: Icons.pause_circle_outline_rounded,
            title: 'Pausados',
            value: _pausedProductsCount(products).toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniInsightCard(
            icon: Icons.savings_outlined,
            title: 'Valor stock',
            value: _estimatedBalance(products).toStringAsFixed(0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniInsightCard(
            icon: Icons.remove_shopping_cart_outlined,
            title: 'Sin stock',
            value: _soldOutCount(products).toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniInsightCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DED1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF8A6A45), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E3426),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A7A6A),
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

  Widget _buildMainWhitePanel(
      double screenWidth,
      List<ProductModel> products,
      List<ProductModel> filteredProducts,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 14),
          _buildFilters(),
          const SizedBox(height: 18),
          _buildToolsRow(),
          const SizedBox(height: 22),
          _buildSectionHeader(),
          const SizedBox(height: 6),
          Text(
            '${filteredProducts.length} producto${filteredProducts.length == 1 ? '' : 's'} encontrados',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9C8F82),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (filteredProducts.isEmpty)
            _buildEmptyState()
          else
            ...filteredProducts
                .map((product) => _buildProductCard(product, screenWidth, products)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9E0D3),
        ),
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
          prefixIcon: const Icon(Icons.search, color: Color(0xFF9A8A7A)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
            },
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF9A8A7A),
            ),
          )
              : const Icon(
            Icons.tune_rounded,
            color: Color(0xFFC7942E),
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
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFC69A5B)
                    : const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFC69A5B)
                      : const Color(0xFFE6DDCF),
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: const Color(0xFFC69A5B).withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : [],
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color:
                  isSelected ? Colors.white : const Color(0xFF5A3E2B),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildToolButton(
            icon: Icons.inventory_2_outlined,
            label: 'Stock',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildToolButton(
            icon: Icons.pause_circle_outline_rounded,
            label: 'Estado',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildToolButton(
            icon: Icons.search_rounded,
            label: 'Buscar',
          ),
        ),
      ],
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DED0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF8A6A45)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B5441),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'Catálogo publicado',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E3426),
            ),
          ),
        ),
        Text(
          'Más recientes',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFC7942E),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E7DA)),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFF5F0E8),
            child: Icon(
              Icons.search_off_rounded,
              size: 32,
              color: Color(0xFFC69A5B),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'No se encontraron productos',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6C5A4B),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Prueba con otro nombre o cambia el filtro seleccionado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF958575),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
      ProductModel product,
      double screenWidth,
      List<ProductModel> products,
      ) {
    final stateColor = _getStateColor(product);
    final stateText = _getStateText(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: product.stock <= 3 && product.state == 1
              ? const Color(0xFFF0C4A7)
              : const Color(0xFFF0E8DC),
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: product.picture != null &&
                          product.picture!.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          product.picture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF888888),
                              size: 42,
                            );
                          },
                        ),
                      )
                          : const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFFC69A5B),
                        size: 42,
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product.unit ?? 'unidad',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E8B57),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4E3426),
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(stateText, stateColor),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description ?? 'Sin descripción disponible.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF8C7B6B),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInlineInfo(
                        icon: Icons.monetization_on_outlined,
                        color: const Color(0xFFC7942E),
                        text:
                        '${product.price.toStringAsFixed(0)} monedas / ${product.unit ?? 'unidad'}',
                      ),
                      const SizedBox(height: 6),
                      _buildInlineInfo(
                        icon: Icons.inventory_2_outlined,
                        color: const Color(0xFF9E9183),
                        text: 'Stock: ${product.stock}',
                      ),
                      const SizedBox(height: 6),
                      _buildInlineInfo(
                        icon: Icons.calendar_month_outlined,
                        color: const Color(0xFF9E9183),
                        text: _getHarvestLabel(product.harvestDate),
                      ),
                      const SizedBox(height: 6),
                      _buildInlineInfo(
                        icon: Icons.verified_outlined,
                        color: const Color(0xFF2E8B57),
                        text: _formatHarvestDate(product.harvestDate),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: product.stock <= 3 && product.state == 1
                              ? const Color(0xFFFFF2E8)
                              : const Color(0xFFFBF8F3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: product.stock <= 3 && product.state == 1
                                ? const Color(0xFFF4D0B6)
                                : const Color(0xFFF0E8DC),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              product.stock <= 3 && product.state == 1
                                  ? Icons.warning_amber_rounded
                                  : Icons.local_shipping_outlined,
                              size: 17,
                              color: product.stock <= 3 && product.state == 1
                                  ? const Color(0xFFD96C2F)
                                  : const Color(0xFF8A6A45),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getStockLabel(product),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: product.stock <= 3 &&
                                      product.state == 1
                                      ? const Color(0xFFD96C2F)
                                      : const Color(0xFF7A6D60),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 1,
            color: const Color(0xFFF1E8DC),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProducerEditProductView(product: product),
                        ),
                      );

                      if (updated == true) {
                        await _loadProducts();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Producto actualizado correctamente'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A6A45),
                      side: const BorderSide(color: Color(0xFFE1D5C5)),
                      backgroundColor: const Color(0xFFFBF8F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: product.id == null
                        ? null
                        : () async {
                      final productController = Provider.of<ProductController>(
                        context,
                        listen: false,
                      );

                      final newStock = product.stock <= 3
                          ? product.stock + 10
                          : product.stock + 1;

                      final success = await productController.updateStock(
                        product.id!,
                        newStock,
                      );

                      if (success) {
                        await _loadProducts();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Stock actualizado correctamente'),
                          ),
                        );
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              productController.errorMessage ??
                                  'Error al actualizar stock',
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      product.stock <= 3
                          ? Icons.refresh_rounded
                          : Icons.inventory_outlined,
                      size: 18,
                    ),
                    label: Text(product.stock <= 3 ? 'Reponer' : 'Stock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: product.stock <= 3
                          ? const Color(0xFFFF7A1A)
                          : const Color(0xFFC69A5B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInlineInfo({
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
              fontSize: 13,
              color: Color(0xFF7A6D60),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}