import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/product_model.dart';
import 'producer_coins_view.dart';
import 'producer_create_product_view.dart';
import 'producer_dashboard_view.dart';
import 'producer_edit_product_view.dart';
import 'producer_profile_view.dart';

class ProducerProductsView extends StatefulWidget {
  const ProducerProductsView({super.key});

  @override
  State<ProducerProductsView> createState() => _ProducerProductsViewState();
}

class _ProducerProductsViewState extends State<ProducerProductsView> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'Todos';
  DateTime? _lastSyncedAt;
  bool _isRefreshing = false;

  final List<String> _filters = const [
    'Todos',
    'Activos',
    'Pausados',
    'Stock bajo',
    'Sin stock',
  ];

  static const Color _bgTop = Color(0xFFF8F2EA);
  static const Color _bgMid = Color(0xFFF4ECE1);
  static const Color _bgBottom = Color(0xFFEADCCA);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8A6848);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF43795C);
  static const Color _orange = Color(0xFFD97A33);
  static const Color _red = Color(0xFFBC5F39);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF8F2E9);

  static const Color _textDark = Color(0xFF4B3427);
  static const Color _textSoft = Color(0xFF857261);
  static const Color _border = Color(0xFFEEE3D5);
  static const Color _divider = Color(0xFFE7DACA);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProducts();
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
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    final userController = context.read<UserController>();
    final productController = context.read<ProductController>();

    final currentUser = userController.currentUser;

    if (currentUser == null || currentUser.id == null) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
      return;
    }

    await productController.getProductsByProducer(currentUser.id!);

    if (!mounted) return;
    setState(() {
      _lastSyncedAt = DateTime.now();
      _isRefreshing = false;
    });
  }

  int _safeStock(ProductModel product) {
    return product.stock < 0 ? 0 : product.stock;
  }

  bool _isPaused(ProductModel product) => product.state == 0;

  bool _isSoldOut(ProductModel product) => _safeStock(product) == 0;

  bool _isLowStock(ProductModel product) =>
      !_isPaused(product) && _safeStock(product) > 0 && _safeStock(product) <= 3;

  bool _isActiveForCatalog(ProductModel product) =>
      !_isPaused(product) && _safeStock(product) > 0;

  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    final query = _searchController.text.toLowerCase().trim();

    final filtered = products.where((product) {
      final name = product.name.toLowerCase();
      final description = (product.description ?? '').toLowerCase();

      final matchesSearch =
          query.isEmpty || name.contains(query) || description.contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'Activos' => _isActiveForCatalog(product),
        'Pausados' => _isPaused(product),
        'Stock bajo' => _isLowStock(product),
        'Sin stock' => _isSoldOut(product),
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();

    filtered.sort((a, b) {
      final aId = a.id ?? 0;
      final bId = b.id ?? 0;
      return bId.compareTo(aId);
    });

    return filtered;
  }

  String _getStateText(ProductModel product) {
    if (_isPaused(product)) return 'Pausado';
    if (_isSoldOut(product)) return 'Sin stock';
    if (_isLowStock(product)) return 'Stock bajo';
    return 'Activo';
  }

  Color _getStateColor(ProductModel product) {
    if (_isPaused(product)) return const Color(0xFF8F8F8F);
    if (_isSoldOut(product)) return _red;
    if (_isLowStock(product)) return _orange;
    return _green;
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

  String _formatPrice(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _getStockLabel(ProductModel product) {
    final stock = _safeStock(product);

    if (_isPaused(product)) {
      return stock == 0
          ? 'Producto pausado y sin stock'
          : 'Producto pausado con $stock unidad${stock == 1 ? '' : 'es'}';
    }

    if (stock == 0) return 'Sin stock disponible';
    if (stock <= 3) return 'Quedan $stock unidad${stock == 1 ? '' : 'es'}';
    if (stock <= 10) return 'Stock limitado';
    return 'Disponible para venta';
  }

  int _activeProductsCount(List<ProductModel> products) =>
      products.where(_isActiveForCatalog).length;

  int _lowStockCount(List<ProductModel> products) =>
      products.where(_isLowStock).length;

  int _totalStock(List<ProductModel> products) =>
      products.fold(0, (sum, product) => sum + _safeStock(product));

  int _pausedProductsCount(List<ProductModel> products) =>
      products.where(_isPaused).length;

  double _estimatedBalance(List<ProductModel> products) {
    return products.fold(
      0.0,
          (sum, product) => sum + (product.price * _safeStock(product)),
    );
  }

  int _soldOutCount(List<ProductModel> products) =>
      products.where(_isSoldOut).length;

  double _getMaxContentWidth(double screenWidth) {
    if (screenWidth >= 1500) return 1320;
    if (screenWidth >= 1200) return 1080;
    if (screenWidth >= 1000) return 920;
    return screenWidth;
  }

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (screenWidth >= 1000) {
      return const EdgeInsets.fromLTRB(24, 18, 24, 180);
    }
    return const EdgeInsets.fromLTRB(16, 14, 16, 180);
  }

  int _summaryCrossAxisCount(double width) {
    if (width >= 1000) return 4;
    if (width >= 700) return 2;
    return 2;
  }

  Future<void> _increaseStock(ProductModel product) async {
    if (product.id == null) return;

    final productController = context.read<ProductController>();

    final increment = _isLowStock(product) || _isSoldOut(product) ? 10 : 1;
    final currentStock = _safeStock(product);
    final newStock = currentStock + increment;

    final success = await productController.updateStock(product.id!, newStock);

    if (!mounted) return;

    if (success) {
      await _loadProducts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            increment == 10
                ? 'Stock repuesto correctamente (+10)'
                : 'Stock actualizado correctamente (+1)',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productController.errorMessage ?? 'Error al actualizar stock',
          ),
        ),
      );
    }
  }

  Future<void> _openCreateProduct() async {
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
  }

  Future<void> _openEditProduct(ProductModel product) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProducerEditProductView(product: product),
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
  }

  Future<void> _goToDashboard() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerDashboardView(),
      ),
    );
  }

  Future<void> _goToCoins() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerCoinsView(),
      ),
    );
  }

  Future<void> _goToProfile() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerProfileView(),
      ),
    );
  }

  Future<void> _onBottomNavigationTap(int index) async {
    switch (index) {
      case 0:
        await _goToDashboard();
        break;
      case 1:
        await _loadProducts();
        break;
      case 2:
        await _goToCoins();
        break;
      case 3:
        await _goToProfile();
        break;
    }
  }

  String _formatHour(DateTime? date) {
    if (date == null) return 'Sin sincronizar';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _catalogStatus(List<ProductModel> products) {
    if (products.isEmpty) return 'Sin catálogo';
    if (_soldOutCount(products) > 0) return 'Atención requerida';
    if (_lowStockCount(products) > 0) return 'Revisar stock';
    return 'Todo en orden';
  }

  Color _catalogStatusColor(List<ProductModel> products) {
    if (products.isEmpty) return _primaryDark;
    if (_soldOutCount(products) > 0) return _red;
    if (_lowStockCount(products) > 0) return _orange;
    return _green;
  }

  @override
  Widget build(BuildContext context) {
    final productController = context.watch<ProductController>();
    final userController = context.watch<UserController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = _getMaxContentWidth(screenWidth);
    final products = productController.products;
    final filteredProducts = _getFilteredProducts(products);

    final isInitialLoading =
        productController.isLoading && products.isEmpty && _lastSyncedAt == null;

    return Scaffold(
      extendBody: true,
      backgroundColor: _bgTop,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton.extended(
          backgroundColor: _primary,
          elevation: 12,
          onPressed: _openCreateProduct,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Publicar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgMid, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -85,
              left: -60,
              child: _buildBackgroundBubble(
                200,
                _primary.withOpacity(0.11),
              ),
            ),
            Positioned(
              top: 180,
              right: -65,
              child: _buildBackgroundBubble(
                150,
                _green.withOpacity(0.08),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -30,
              child: _buildBackgroundBubble(
                190,
                _primaryDark.withOpacity(0.06),
              ),
            ),
            Positioned(
              bottom: 250,
              right: -30,
              child: _buildBackgroundBubble(
                95,
                _gold.withOpacity(0.10),
              ),
            ),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadProducts,
                color: _primary,
                child: productController.errorMessage != null &&
                    products.isEmpty &&
                    !productController.isLoading
                    ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 180),
                  children: [
                    _buildErrorState(productController.errorMessage!),
                  ],
                )
                    : ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.zero,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Padding(
                          padding: _getResponsivePadding(screenWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopBar(userController, products),
                              const SizedBox(height: 18),
                              if (isInitialLoading)
                                _buildLoadingCard()
                              else ...[
                                _buildHeroCard(userController, products),
                                const SizedBox(height: 18),
                                _buildSectionContainer(
                                  title: 'Resumen del catálogo',
                                  subtitle:
                                  'Estado real de tus productos en una vista rápida.',
                                  child: Column(
                                    children: [
                                      _buildSummaryGrid(products, screenWidth),
                                      const SizedBox(height: 14),
                                      _buildStatusBanner(products),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildSectionContainer(
                                  title: 'Buscar y filtrar',
                                  subtitle:
                                  'Encuentra productos rápido y organiza mejor tu catálogo.',
                                  child: Column(
                                    children: [
                                      _buildSearchBar(),
                                      const SizedBox(height: 14),
                                      _buildFilters(),
                                      const SizedBox(height: 14),
                                      _buildToolsRow(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildSectionContainer(
                                  title: 'Catálogo publicado',
                                  subtitle:
                                  'Listado completo de tus productos con stock, estado y acciones.',
                                  actionLabel:
                                  '${filteredProducts.length} resultado${filteredProducts.length == 1 ? '' : 's'}',
                                  child: filteredProducts.isEmpty
                                      ? _buildEmptyState()
                                      : Column(
                                    children: filteredProducts
                                        .map((product) =>
                                        _buildProductCard(product))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTopBar(UserController userController, List<ProductModel> products) {
    final balance = userController.currentUser?.balance ?? 0.0;
    final statusColor = _catalogStatusColor(products);
    final statusText = _catalogStatus(products);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _goToDashboard,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _surface.withOpacity(0.98),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textDark,
              size: 18,
            ),
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
                children: [
                  _buildHeaderChip(
                    icon: Icons.storefront_outlined,
                    label: 'Mis productos',
                    color: _primaryDark,
                    background: const Color(0xFFFFF7EC),
                  ),
                  _buildHeaderChip(
                    icon: Icons.inventory_2_outlined,
                    label: '${products.length} total',
                    color: _green,
                    background: const Color(0xFFF2FAF5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Catálogo del productor',
                style: TextStyle(
                  fontSize: 24,
                  color: _textDark,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _lastSyncedAt == null
                    ? 'Sin actualización reciente'
                    : 'Actualizado ${_formatHour(_lastSyncedAt)} · ${_formatDate(_lastSyncedAt)}',
                style: const TextStyle(
                  fontSize: 11.8,
                  color: _textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _surface.withOpacity(0.98),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_outlined,
                    color: _primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatPrice(balance.toDouble()),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.09),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.18)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 16),
          Text(
            'Cargando catálogo...',
            style: TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos trayendo tus productos y su stock real.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _red,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No se pudo cargar el catálogo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: _textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: _textSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loadProducts,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(UserController userController, List<ProductModel> products) {
    final producerName = userController.currentUser?.name ?? 'Productor';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5B4A42),
            Color(0xFF433933),
            Color(0xFF2C2725),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -14,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -42,
            left: -18,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 22,
            right: 20,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.agriculture_outlined,
                color: Colors.white70,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroTag(
                      icon: Icons.verified_outlined,
                      text: 'Datos reales',
                    ),
                    _buildHeroTag(
                      icon: Icons.eco_outlined,
                      text: 'Catálogo agrícola',
                    ),
                    _buildHeroTag(
                      icon: Icons.sync_rounded,
                      text: _isRefreshing ? 'Actualizando' : 'Sincronizado',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  producerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.02,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Un catálogo más visual, más limpio y mucho mejor pensado para móvil.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildHeroMetric(
                          icon: Icons.inventory_2_outlined,
                          title: 'Productos',
                          value: products.length.toString(),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withOpacity(0.10),
                      ),
                      Expanded(
                        child: _buildHeroMetric(
                          icon: Icons.attach_money_rounded,
                          title: 'Valor stock',
                          value: _formatPrice(_estimatedBalance(products)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildHeroStat(
                      label: 'Activos',
                      value: _activeProductsCount(products).toString(),
                    ),
                    _buildHeroStat(
                      label: 'Pausados',
                      value: _pausedProductsCount(products).toString(),
                    ),
                    _buildHeroStat(
                      label: 'Stock bajo',
                      value: _lowStockCount(products).toString(),
                    ),
                    _buildHeroStat(
                      label: 'Sin stock',
                      value: _soldOutCount(products).toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openCreateProduct,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: const Text('Publicar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loadProducts,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _textDark,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Actualizar'),
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

  Widget _buildHeroTag({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStat({
    required String label,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
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

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required Widget child,
    String? actionLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _divider),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: _primaryDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(List<ProductModel> products, double width) {
    final items = [
      _SummaryItem(
        icon: Icons.check_circle_outline,
        title: 'Activos',
        value: _activeProductsCount(products).toString(),
        accent: _green,
      ),
      _SummaryItem(
        icon: Icons.warning_amber_rounded,
        title: 'Stock bajo',
        value: _lowStockCount(products).toString(),
        accent: _orange,
      ),
      _SummaryItem(
        icon: Icons.grid_view_rounded,
        title: 'Unidades',
        value: _totalStock(products).toString(),
        accent: _primaryDark,
      ),
      _SummaryItem(
        icon: Icons.attach_money_rounded,
        title: 'Valor stock',
        value: _formatPrice(_estimatedBalance(products)),
        accent: _primary,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _summaryCrossAxisCount(width),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: width < 400 ? 1.18 : 1.35,
      ),
      itemBuilder: (_, index) => _buildSummaryCard(items[index]),
    );
  }

  Widget _buildSummaryCard(_SummaryItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFCF8), Color(0xFFF8F1E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.accent, size: 20),
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(List<ProductModel> products) {
    final color = _catalogStatusColor(products);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_heart_outlined, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Estado general del catálogo',
              style: const TextStyle(
                color: _textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _catalogStatus(products),
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
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
          hintText: 'Buscar producto por nombre o descripción...',
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          prefixIcon: const Icon(Icons.search, color: _textSoft),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
            },
            icon: const Icon(
              Icons.close_rounded,
              color: _textSoft,
            ),
          )
              : const Icon(
            Icons.tune_rounded,
            color: _primary,
          ),
          filled: true,
          fillColor: _surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isSelected ? _primary : _surfaceMuted,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? _primary : _divider,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : [],
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : _textDark,
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
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: _primaryDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFFF5F0E8),
            child: Icon(
              Icons.search_off_rounded,
              size: 32,
              color: _primary,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'No se encontraron productos',
            style: TextStyle(
              fontSize: 16,
              color: _textDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Prueba con otro nombre o cambia el filtro seleccionado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _textSoft,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final stateColor = _getStateColor(product);
    final stateText = _getStateText(product);
    final stock = _safeStock(product);
    final isAlertStock = _isLowStock(product) || _isSoldOut(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isAlertStock && !_isPaused(product)
              ? const Color(0xFFF0C4A7)
              : _divider,
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
                          product.picture!.trim().isNotEmpty
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
                        color: _primary,
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
                          color: Colors.white.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (product.unit == null || product.unit!.trim().isEmpty)
                              ? 'unidad'
                              : product.unit!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _green,
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
                                fontWeight: FontWeight.w800,
                                color: _textDark,
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
                        (product.description == null ||
                            product.description!.trim().isEmpty)
                            ? 'Sin descripción disponible.'
                            : product.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _textSoft,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInlineInfo(
                        icon: Icons.monetization_on_outlined,
                        color: _primary,
                        text:
                        '${_formatPrice(product.price)} monedas / ${(product.unit == null || product.unit!.trim().isEmpty) ? 'unidad' : product.unit!}',
                      ),
                      const SizedBox(height: 6),
                      _buildInlineInfo(
                        icon: Icons.inventory_2_outlined,
                        color: _primaryDark,
                        text: 'Stock: $stock',
                      ),
                      const SizedBox(height: 6),
                      _buildInlineInfo(
                        icon: Icons.calendar_month_outlined,
                        color: _primaryDark,
                        text: _getHarvestLabel(product.harvestDate),
                      ),
                      const SizedBox(height: 6),
                      _buildInlineInfo(
                        icon: Icons.verified_outlined,
                        color: _green,
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
                          color: isAlertStock && !_isPaused(product)
                              ? const Color(0xFFFFF2E8)
                              : _surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isAlertStock && !_isPaused(product)
                                ? const Color(0xFFF4D0B6)
                                : _divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isAlertStock && !_isPaused(product)
                                  ? Icons.warning_amber_rounded
                                  : Icons.local_shipping_outlined,
                              size: 17,
                              color: isAlertStock && !_isPaused(product)
                                  ? _orange
                                  : _primaryDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getStockLabel(product),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isAlertStock && !_isPaused(product)
                                      ? _orange
                                      : _textSoft,
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
            color: _divider,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditProduct(product),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryDark,
                      side: const BorderSide(color: _divider),
                      backgroundColor: _surfaceMuted,
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
                    onPressed: product.id == null ? null : () => _increaseStock(product),
                    icon: Icon(
                      (_isLowStock(product) || _isSoldOut(product))
                          ? Icons.refresh_rounded
                          : Icons.add_rounded,
                      size: 18,
                    ),
                    label: Text(
                      (_isLowStock(product) || _isSoldOut(product))
                          ? 'Reponer +10'
                          : '+1 stock',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      (_isLowStock(product) || _isSoldOut(product))
                          ? _orange
                          : _primary,
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
              color: _textSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    final items = <_BottomNavData>[
      const _BottomNavData(
        icon: Icons.home_rounded,
        label: 'Inicio',
        index: 0,
      ),
      const _BottomNavData(
        icon: Icons.storefront_rounded,
        label: 'Productos',
        index: 1,
      ),
      const _BottomNavData(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Monedas',
        index: 2,
      ),
      const _BottomNavData(
        icon: Icons.person_rounded,
        label: 'Perfil',
        index: 3,
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 82,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.86),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.65)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBottomNavItem(items[0], selected: false),
                  ),
                  Expanded(
                    child: _buildBottomNavItem(items[1], selected: true),
                  ),
                  const SizedBox(width: 68),
                  Expanded(
                    child: _buildBottomNavItem(items[2], selected: false),
                  ),
                  Expanded(
                    child: _buildBottomNavItem(items[3], selected: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(_BottomNavData item, {required bool selected}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _onBottomNavigationTap(item.index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: selected ? _primaryDark : _textSoft,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _primaryDark : _textSoft,
                fontSize: 11.3,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });
}

class _BottomNavData {
  final IconData icon;
  final String label;
  final int index;

  const _BottomNavData({
    required this.icon,
    required this.label,
    required this.index,
  });
}