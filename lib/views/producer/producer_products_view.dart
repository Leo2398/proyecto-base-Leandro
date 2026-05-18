import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/coin_movement_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/product_model.dart';
import 'producer_coins_view.dart';
import 'producer_create_product_view.dart';
import 'producer_dashboard_view.dart';
import 'producer_edit_product_view.dart';
import 'producer_orders_view.dart';
import 'producer_profile_view.dart';
import 'producer_sales_stats_view.dart';

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

  // ─── Paleta alineada al dashboard ──────────────────────────────────────────
  static const Color _bgTop = Color(0xFFF7F2EA);
  static const Color _bgBottom = Color(0xFFE8DAC9);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF7EFE5);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8A6848);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF43795C);
  static const Color _orange = Color(0xFFD97A33);
  static const Color _red = Color(0xFFBC5F39);
  static const Color _blue = Color(0xFF5E7FA3);
  static const Color _purple = Color(0xFF7A67A8);

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
      await _loadCoinData();
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

  // ─── Carga de datos ────────────────────────────────────────────────────────
  Future<void> _loadCoinData() async {
    final userController = context.read<UserController>();
    final coinController = context.read<CoinMovementController>();
    final currentUser = userController.currentUser;

    if (currentUser == null || currentUser.id == null || currentUser.id! <= 0) {
      return;
    }

    await coinController.loadCoinData(currentUser.id!);
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

  Future<void> _reloadAll() async {
    await Future.wait([
      _loadProducts(),
      _loadCoinData(),
    ]);
  }

  // ─── Helpers de negocio ────────────────────────────────────────────────────
  int _safeStock(ProductModel product) => product.stock < 0 ? 0 : product.stock;

  bool _isPaused(ProductModel product) => product.state == 0;

  bool _isSoldOut(ProductModel product) => _safeStock(product) == 0;

  bool _isLowStock(ProductModel product) =>
      !_isPaused(product) && _safeStock(product) > 0 && _safeStock(product) <= 3;

  bool _isActiveForCatalog(ProductModel product) =>
      !_isPaused(product) && _safeStock(product) > 0;

  bool _hasActiveSearchOrFilter() {
    return _searchController.text.trim().isNotEmpty ||
        _selectedFilter != 'Todos';
  }

  void _clearSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _selectedFilter = 'Todos';
    });
  }

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

  int _soldOutCount(List<ProductModel> products) =>
      products.where(_isSoldOut).length;

  int _pausedProductsCount(List<ProductModel> products) =>
      products.where(_isPaused).length;

  int _totalStock(List<ProductModel> products) =>
      products.fold(0, (sum, product) => sum + _safeStock(product));

  double _estimatedBalance(List<ProductModel> products) {
    return products.fold(
      0.0,
          (sum, product) => sum + (product.price * _safeStock(product)),
    );
  }

  double _availabilityPercent(List<ProductModel> products) {
    if (products.isEmpty) return 0;
    return _activeProductsCount(products) / products.length;
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

  // ─── Helpers visuales y formato ────────────────────────────────────────────
  double _getMaxContentWidth(double screenWidth) {
    if (screenWidth >= 1600) return 1380;
    if (screenWidth >= 1300) return 1180;
    if (screenWidth >= 1000) return 980;
    return screenWidth;
  }

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (screenWidth >= 1200) return const EdgeInsets.fromLTRB(28, 16, 28, 130);
    if (screenWidth >= 800) return const EdgeInsets.fromLTRB(20, 14, 20, 130);
    return const EdgeInsets.fromLTRB(16, 12, 16, 130);
  }

  int _overviewCrossAxisCount(double width) {
    if (width >= 1100) return 4;
    return 2;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _formatHour(DateTime? date) {
    if (date == null) return '--:--';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Uint8List? _decodeImageBytes(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    try {
      final raw = value.trim();
      final normalized =
      raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkImage(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  // ─── Acciones ──────────────────────────────────────────────────────────────
  Future<void> _increaseStock(ProductModel product) async {
    if (product.id == null) return;

    final productController = context.read<ProductController>();
    final increment = _isLowStock(product) || _isSoldOut(product) ? 10 : 1;
    final newStock = _safeStock(product) + increment;

    final success = await productController.updateStock(product.id!, newStock);

    if (!mounted) return;

    if (success) {
      await _reloadAll();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            increment == 10
                ? 'Stock repuesto correctamente (+10)'
                : 'Stock actualizado correctamente (+1)',
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productController.errorMessage ?? 'Error al actualizar stock',
          ),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
      await _reloadAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Producto publicado correctamente'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
      await _reloadAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Producto actualizado correctamente'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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

  Future<void> _goToOrders() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerOrdersView(),
      ),
    );
  }

  Future<void> _goToSalesStats() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerSalesStatsView(),
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

  // ─── Build principal ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final productController = context.watch<ProductController>();
    final userController = context.watch<UserController>();
    final coinController = context.watch<CoinMovementController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = _getMaxContentWidth(screenWidth);

    final products = productController.products;
    final filteredProducts = _getFilteredProducts(products);

    final coinBalance = coinController.isLoading
        ? (userController.currentUser?.balance ?? 0.0)
        : coinController.balance;

    final isInitialLoading =
        productController.isLoading && products.isEmpty && _lastSyncedAt == null;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6EFE6),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFloatingPublishButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -50,
              child: _buildDecorBubble(180, _primary.withOpacity(0.10)),
            ),
            Positioned(
              top: 130,
              right: -55,
              child: _buildDecorBubble(170, _gold.withOpacity(0.13)),
            ),
            Positioned(
              bottom: 140,
              left: -65,
              child: _buildDecorBubble(180, _green.withOpacity(0.07)),
            ),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _reloadAll,
                color: _primary,
                child: productController.errorMessage != null &&
                    products.isEmpty &&
                    !productController.isLoading
                    ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 130),
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
                        constraints:
                        BoxConstraints(maxWidth: maxContentWidth),
                        child: Padding(
                          padding: _getResponsivePadding(screenWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAppBar(
                                userController: userController,
                                coinBalance: coinBalance,
                                products: products,
                              ),
                              const SizedBox(height: 18),
                              if (isInitialLoading)
                                _buildLoadingCard()
                              else ...[
                                _buildHeroCard(
                                  coinBalance: coinBalance,
                                  products: products,
                                ),
                                const SizedBox(height: 20),
                                _buildOverviewSection(
                                  products: products,
                                  screenWidth: screenWidth,
                                ),
                                const SizedBox(height: 20),
                                _buildSearchFilterSection(
                                  filteredProducts: filteredProducts,
                                ),
                                const SizedBox(height: 20),
                                _buildProductsSection(
                                  allProducts: products,
                                  filteredProducts: filteredProducts,
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

  // ─── App bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar({
    required UserController userController,
    required double coinBalance,
    required List<ProductModel> products,
  }) {
    final user = userController.currentUser;
    final name = user?.name ?? 'Productor';
    final firstName = name.split(' ').first;
    final image = user?.image;
    final statusColor = _catalogStatusColor(products);
    final statusText = _catalogStatus(products);

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showMoreMenu,
          child: _buildUserAvatar(
            name: name,
            image: image,
            size: 54,
            radius: 18,
            fontSize: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Catálogo de $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildTinyStatusChip(statusText, statusColor),
                  Text(
                    '${_formatPrice(coinBalance)} mon.',
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildAppBarActionButton(
          icon: _isRefreshing ? Icons.sync_rounded : Icons.refresh_rounded,
          color: _primary,
          onTap: _reloadAll,
        ),
        const SizedBox(width: 8),
        _buildAppBarActionButton(
          icon: Icons.menu_rounded,
          color: _primaryDark,
          onTap: _showMoreMenu,
        ),
      ],
    );
  }

  Widget _buildAppBarActionButton({
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onTap(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ─── Hero principal ────────────────────────────────────────────────────────
  Widget _buildHeroCard({
    required double coinBalance,
    required List<ProductModel> products,
  }) {
    final lowStock = _lowStockCount(products);
    final soldOut = _soldOutCount(products);
    final paused = _pausedProductsCount(products);
    final active = _activeProductsCount(products);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A4A41), Color(0xFF443832), Color(0xFF302826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined,
                            size: 14, color: _gold),
                        SizedBox(width: 6),
                        Text(
                          'Mi catálogo',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white54,
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    products.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'productos',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Administra tu stock, edita tus publicaciones y mantén tu catálogo listo para vender.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Activos',
                      value: active.toString(),
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Valor stock',
                      value: _formatPrice(_estimatedBalance(products)),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Alertas',
                      value: (lowStock + soldOut).toString(),
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Monedas',
                      value: _formatPrice(coinBalance),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildHeroMiniTag(
                    label: '$paused pausados',
                    color: Colors.white70,
                  ),
                  _buildHeroMiniTag(
                    label: '$soldOut sin stock',
                    color: soldOut > 0 ? const Color(0xFFFFC4B5) : Colors.white70,
                  ),
                  _buildHeroMiniTag(
                    label: '$lowStock stock bajo',
                    color: lowStock > 0 ? const Color(0xFFFFD6A8) : Colors.white70,
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                      onPressed: _goToCoins,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _textDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                      ),
                      label: const Text('Monedas'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10.5,
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

  Widget _buildHeroMiniTag({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── Resumen general ───────────────────────────────────────────────────────
  Widget _buildOverviewSection({
    required List<ProductModel> products,
    required double screenWidth,
  }) {
    final statusColor = _catalogStatusColor(products);
    final statusText = _catalogStatus(products);
    final availability = _availabilityPercent(products);

    final items = [
      _OverviewItem(
        label: 'Activos',
        value: _activeProductsCount(products).toString(),
        icon: Icons.check_circle_outline_rounded,
        color: _green,
      ),
      _OverviewItem(
        label: 'Pausados',
        value: _pausedProductsCount(products).toString(),
        icon: Icons.pause_circle_outline_rounded,
        color: _purple,
      ),
      _OverviewItem(
        label: 'Stock bajo',
        value: _lowStockCount(products).toString(),
        icon: Icons.warning_amber_rounded,
        color: _orange,
      ),
      _OverviewItem(
        label: 'Sin stock',
        value: _soldOutCount(products).toString(),
        icon: Icons.remove_shopping_cart_outlined,
        color: _red,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insights_rounded, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Estado del catálogo',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildTinyStatusChip(statusText, statusColor),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _overviewCrossAxisCount(screenWidth),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 110,
            ),
            itemBuilder: (_, index) => _buildOverviewStatCard(items[index]),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Disponibilidad del catálogo',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${(availability * 100).round()}%',
                      style: const TextStyle(
                        color: _primaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: availability.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE8DCCB),
                    valueColor: const AlwaysStoppedAnimation(_primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${products.length} productos · ${_totalStock(products)} unidades · ${_formatPrice(_estimatedBalance(products))} monedas estimadas',
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 11.5,
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

  Widget _buildOverviewStatCard(_OverviewItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 16),
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Búsqueda y filtros ────────────────────────────────────────────────────
  Widget _buildSearchFilterSection({
    required List<ProductModel> filteredProducts,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded,
                    color: _primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Buscar y filtrar',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildTinyStatusChip(
                '${filteredProducts.length} resultado${filteredProducts.length == 1 ? '' : 's'}',
                _primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSearchBar(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filters.map(_buildFilterChip).toList(),
          ),
          if (_hasActiveSearchOrFilter()) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _clearSearchAndFilters,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text(
                  'Limpiar búsqueda y filtros',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _primaryDark,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: _textDark,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar producto por nombre o descripción...',
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          prefixIcon: const Icon(Icons.search_rounded, color: _textSoft),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            onPressed: _searchController.clear,
            icon: const Icon(Icons.close_rounded, color: _textSoft),
          )
              : const Icon(Icons.tune_rounded, color: _primary),
          filled: true,
          fillColor: _surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final isSelected = _selectedFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primary : _surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _divider,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: _primary.withOpacity(0.18),
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
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ─── Sección productos ─────────────────────────────────────────────────────
  Widget _buildProductsSection({
    required List<ProductModel> allProducts,
    required List<ProductModel> filteredProducts,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: _blue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Catálogo publicado',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _openCreateProduct,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Nuevo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (allProducts.isEmpty)
            _buildEmptyState(hasProducts: false)
          else if (filteredProducts.isEmpty)
            _buildEmptyState(hasProducts: true)
          else
            Column(
              children:
              filteredProducts.map((product) => _buildProductCard(product)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool hasProducts}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              hasProducts
                  ? Icons.search_off_rounded
                  : Icons.add_business_outlined,
              size: 32,
              color: _primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasProducts ? 'No se encontraron productos' : '¡Empieza a vender!',
            style: const TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasProducts
                ? 'Prueba con otro nombre o cambia el filtro seleccionado.'
                : 'Publica tu primer producto y empieza a llenar tu catálogo.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasProducts ? _clearSearchAndFilters : _openCreateProduct,
              icon: Icon(
                hasProducts ? Icons.restart_alt_rounded : Icons.add_rounded,
                size: 18,
              ),
              label: Text(
                hasProducts ? 'Limpiar filtros' : 'Publicar producto',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
    final unitText = (product.unit == null || product.unit!.trim().isEmpty)
        ? 'unidad'
        : product.unit!;
    final description = (product.description == null ||
        product.description!.trim().isEmpty)
        ? 'Sin descripción disponible.'
        : product.description!;
    final isAlertStock = !_isPaused(product) &&
        (_isLowStock(product) || _isSoldOut(product));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isAlertStock ? stateColor.withOpacity(0.28) : _divider,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openEditProduct(product),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductImage(product, unitText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusBadge(stateText, stateColor),
                            _buildProductInfoPill(
                              icon: Icons.monetization_on_outlined,
                              text: '${_formatPrice(product.price)} mon.',
                              color: _primaryDark,
                            ),
                            _buildProductInfoPill(
                              icon: Icons.inventory_2_outlined,
                              text: 'Stock $stock',
                              color: isAlertStock ? stateColor : _green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textSoft,
                            fontSize: 12.2,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildProductInfoPill(
                              icon: Icons.eco_outlined,
                              text: unitText,
                              color: _green,
                            ),
                            _buildProductInfoPill(
                              icon: Icons.calendar_month_outlined,
                              text: _getHarvestLabel(product.harvestDate),
                              color: _blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProductAlertBanner(product),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openEditProduct(product),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryDark,
                        side: const BorderSide(color: _divider),
                        backgroundColor: _surface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                      product.id == null ? null : () => _increaseStock(product),
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
                      style: FilledButton.styleFrom(
                        backgroundColor:
                        (_isLowStock(product) || _isSoldOut(product))
                            ? _orange
                            : _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(ProductModel product, String unitText) {
    final bytes = _decodeImageBytes(product.picture);

    Widget imageChild;
    if (_isNetworkImage(product.picture)) {
      imageChild = Image.network(
        product.picture!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildProductImagePlaceholder(),
      );
    } else if (bytes != null) {
      imageChild = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildProductImagePlaceholder(),
      );
    } else {
      imageChild = _buildProductImagePlaceholder();
    }

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: imageChild,
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unitText,
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
    );
  }

  Widget _buildProductImagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6EEE2), Color(0xFFE9DBC7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 40,
          color: _primaryDark,
        ),
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
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildProductInfoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductAlertBanner(ProductModel product) {
    final isAlertStock = !_isPaused(product) &&
        (_isLowStock(product) || _isSoldOut(product));
    final color = isAlertStock
        ? (_isSoldOut(product) ? _red : _orange)
        : _primaryDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAlertStock ? color.withOpacity(0.08) : _surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlertStock ? color.withOpacity(0.16) : _divider,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAlertStock
                ? Icons.warning_amber_rounded
                : Icons.calendar_month_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAlertStock
                  ? _getStockLabel(product)
                  : 'Cosecha: ${_formatHarvestDate(product.harvestDate)} · ${_getHarvestLabel(product.harvestDate)}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom sheet menú ─────────────────────────────────────────────────────
  Future<void> _showMoreMenu() async {
    final user = context.read<UserController>().currentUser;
    final name = user?.name ?? 'Productor';
    final email = user?.email ?? '';
    final image = user?.image;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F2EA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6C6B3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        _buildUserAvatar(
                          name: name,
                          image: image,
                          size: 54,
                          radius: 18,
                          fontSize: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textDark,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                email.isEmpty ? 'Productor verificado' : email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        _buildMenuAction(
                          icon: Icons.dashboard_rounded,
                          color: _primary,
                          title: 'Dashboard',
                          subtitle: 'Volver a la vista principal',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToDashboard();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.receipt_long_rounded,
                          color: _blue,
                          title: 'Pedidos',
                          subtitle: 'Gestiona tus órdenes',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToOrders();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.bar_chart_rounded,
                          color: _purple,
                          title: 'Estadísticas',
                          subtitle: 'Métricas y rendimiento',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToSalesStats();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.account_balance_wallet_outlined,
                          color: _gold,
                          title: 'Monedas',
                          subtitle: 'Saldo, recargas e historial',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToCoins();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.person_outline_rounded,
                          color: _green,
                          title: 'Perfil',
                          subtitle: 'Datos, ubicación y horarios',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToProfile();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _border),
                    ),
                    child: _buildMenuAction(
                      icon: Icons.refresh_rounded,
                      color: _primaryDark,
                      title: 'Actualizar catálogo',
                      subtitle: 'Sincroniza productos y monedas',
                      onTap: () {
                        Navigator.pop(ctx);
                        _reloadAll();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuAction({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _textSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Divider(height: 1, thickness: 1, color: _divider),
    );
  }

  // ─── Estados comunes ───────────────────────────────────────────────────────
  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 18),
          Text(
            'Cargando catálogo...',
            style: TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos sincronizando tus productos y su stock real.',
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
        color: _surface,
        borderRadius: BorderRadius.circular(26),
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
              onPressed: _reloadAll,
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

  // ─── Avatar ────────────────────────────────────────────────────────────────
  Widget _buildUserAvatar({
    required String name,
    required String? image,
    double size = 58,
    double radius = 20,
    double fontSize = 22,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final bytes = _decodeImageBytes(image);

    Widget content;
    if (_isNetworkImage(image)) {
      content = Image.network(
        image!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialAvatar(
          initial: initial,
          size: size,
          radius: radius,
          fontSize: fontSize,
        ),
      );
    } else if (bytes != null) {
      content = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialAvatar(
          initial: initial,
          size: size,
          radius: radius,
          fontSize: fontSize,
        ),
      );
    } else {
      return _buildInitialAvatar(
        initial: initial,
        size: size,
        radius: radius,
        fontSize: fontSize,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }

  Widget _buildInitialAvatar({
    required String initial,
    required double size,
    required double radius,
    required double fontSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFFB9854A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ─── Helpers visuales comunes ──────────────────────────────────────────────
  Widget _buildDecorBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildTinyStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ─── FAB ───────────────────────────────────────────────────────────────────
  Widget _buildFloatingPublishButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.40),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: _primary,
          elevation: 0,
          shape: const CircleBorder(),
          onPressed: _openCreateProduct,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  // ─── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNavigationBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            border: Border(
              top: BorderSide(color: _border.withOpacity(0.85)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Inicio',
                  selected: false,
                  onTap: _goToDashboard,
                ),
                _buildNavItem(
                  icon: Icons.storefront_outlined,
                  label: 'Productos',
                  selected: true,
                  onTap: _reloadAll,
                ),
                const SizedBox(width: 56),
                _buildNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Pedidos',
                  selected: false,
                  onTap: _goToOrders,
                ),
                _buildNavItem(
                  icon: Icons.menu_rounded,
                  label: 'Más',
                  selected: false,
                  onTap: _showMoreMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required Future<void> Function() onTap,
  }) {
    final color = selected ? _primary : _textSoft;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight:
                  selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}