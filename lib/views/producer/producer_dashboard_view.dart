import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/coin_movement_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/product_model.dart';
import '../auth/login_view.dart';
import 'producer_coins_view.dart';
import 'producer_create_product_view.dart';
import 'producer_products_view.dart';
import 'producer_profile_view.dart';

class ProducerDashboardView extends StatefulWidget {
  const ProducerDashboardView({super.key});

  @override
  State<ProducerDashboardView> createState() => _ProducerDashboardViewState();
}

class _ProducerDashboardViewState extends State<ProducerDashboardView> {
  static const Color _bgTop = Color(0xFFF7F2EA);
  static const Color _bgBottom = Color(0xFFE9DDCE);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF8F2E9);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8A6848);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF43795C);
  static const Color _orange = Color(0xFFD97A33);
  static const Color _red = Color(0xFFBC5F39);

  static const Color _textDark = Color(0xFF4B3427);
  static const Color _textSoft = Color(0xFF857261);
  static const Color _border = Color(0xFFEEE3D5);
  static const Color _divider = Color(0xFFE7DACA);

  DateTime? _lastSyncedAt;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      final userController = context.read<UserController>();
      final productController = context.read<ProductController>();
      final coinController = context.read<CoinMovementController>();

      final currentUser = userController.currentUser;
      if (currentUser == null || currentUser.id == null) return;

      await Future.wait([
        productController.getProductsByProducer(currentUser.id!),
        coinController.loadCoinData(currentUser.id!),
      ]);

      if (!mounted) return;
      setState(() {
        _lastSyncedAt = DateTime.now();
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  List<ProductModel> _recentProducts(List<ProductModel> products) {
    final copy = [...products];
    copy.sort((a, b) {
      final aDate = a.harvestDate ?? DateTime(2000);
      final bDate = b.harvestDate ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return copy.take(4).toList();
  }

  List<ProductModel> _lowStockProducts(List<ProductModel> products) {
    return products.where((p) => p.state == 1 && p.stock > 0 && p.stock <= 3).toList();
  }

  List<ProductModel> _soldOutProducts(List<ProductModel> products) {
    return products.where((p) => p.stock == 0).toList();
  }

  int _activeProducts(List<ProductModel> products) {
    return products.where((p) => p.state == 1).length;
  }

  int _pausedProducts(List<ProductModel> products) {
    return products.where((p) => p.state == 0).length;
  }

  int _totalUnits(List<ProductModel> products) {
    return products.fold(0, (sum, p) => sum + p.stock);
  }

  double _inventoryValue(List<ProductModel> products) {
    return products.fold(0.0, (sum, p) => sum + (p.price * p.stock));
  }

  double _averagePrice(List<ProductModel> products) {
    if (products.isEmpty) return 0;
    final total = products.fold(0.0, (sum, p) => sum + p.price);
    return total / products.length;
  }

  double _availabilityPercent(List<ProductModel> products) {
    if (products.isEmpty) return 0;
    return _activeProducts(products) / products.length;
  }

  double _dashboardCoinBalance(
      UserController userController,
      CoinMovementController coinController,
      ) {
    if (coinController.isLoading) {
      return userController.currentUser?.balance ?? 0;
    }
    return coinController.balance;
  }

  double _dashboardMoneyReference(
      UserController userController,
      CoinMovementController coinController,
      ) {
    if (coinController.isLoading) {
      return (userController.currentUser?.balance ?? 0) * 100;
    }
    return coinController.balanceInMoney;
  }

  String _money(double value) {
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  String _coins(double value) {
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatHour(DateTime? date) {
    if (date == null) return 'Sin sincronizar';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

  String _productStatusText(ProductModel product) {
    if (product.state == 0) return 'Pausado';
    if (product.stock == 0) return 'Agotado';
    if (product.stock <= 3) return 'Stock bajo';
    return 'Activo';
  }

  Color _productStatusColor(ProductModel product) {
    if (product.state == 0) return const Color(0xFF8F8F8F);
    if (product.stock == 0) return _red;
    if (product.stock <= 3) return _orange;
    return _green;
  }

  String _stockHealthLabel(List<ProductModel> products) {
    if (products.isEmpty) return 'Sin catálogo';
    if (_soldOutProducts(products).isNotEmpty) return 'Atención requerida';
    if (_lowStockProducts(products).isNotEmpty) return 'Revisar stock';
    return 'Todo en orden';
  }

  Color _stockHealthColor(List<ProductModel> products) {
    if (products.isEmpty) return _primaryDark;
    if (_soldOutProducts(products).isNotEmpty) return _red;
    if (_lowStockProducts(products).isNotEmpty) return _orange;
    return _green;
  }

  EdgeInsets _pagePadding(double width) {
    if (width >= 1000) {
      return const EdgeInsets.fromLTRB(24, 18, 24, 180);
    }
    return const EdgeInsets.fromLTRB(16, 14, 16, 180);
  }

  double _maxWidth(double width) {
    if (width >= 1500) return 1320;
    if (width >= 1200) return 1100;
    if (width >= 1000) return 920;
    return width;
  }

  int _summaryCrossAxisCount(double width) {
    if (width >= 1000) return 4;
    if (width >= 700) return 2;
    return 2;
  }

  int _quickActionsCrossAxisCount(double width) {
    if (width >= 1100) return 4;
    if (width >= 700) return 2;
    return 2;
  }

  Future<void> _goToProducts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerProductsView(),
      ),
    );

    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _goToCreateProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerCreateProductView(),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      await _loadDashboardData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto publicado correctamente'),
        ),
      );
    }
  }

  Future<void> _goToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerProfileView(),
      ),
    );

    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _goToCoins() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerCoinsView(),
      ),
    );

    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _replenishProduct(ProductModel product) async {
    if (product.id == null) return;

    final productController = context.read<ProductController>();
    final newStock = product.stock + 10;

    final success = await productController.updateStock(product.id!, newStock);

    if (!mounted) return;

    if (success) {
      await _loadDashboardData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock actualizado para ${product.name}'),
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

  Future<void> _logout() async {
    final controller = context.read<UserController>();
    await controller.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
    );
  }

  Future<void> _onBottomNavigationTap(int index) async {
    switch (index) {
      case 0:
        await _loadDashboardData();
        break;
      case 1:
        await _goToProducts();
        break;
      case 2:
        await _goToCoins();
        break;
      case 3:
        await _goToProfile();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final productController = context.watch<ProductController>();
    final coinController = context.watch<CoinMovementController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final isVerySmall = screenWidth < 360;

    final products = productController.products;
    final recentProducts = _recentProducts(products).take(isMobile ? 3 : 4).toList();
    final lowStockProducts = _lowStockProducts(products);
    final soldOutProducts = _soldOutProducts(products);

    final coinBalance = _dashboardCoinBalance(userController, coinController);
    final moneyReference = _dashboardMoneyReference(userController, coinController);

    final isLoading = productController.isLoading || coinController.isLoading;
    final isInitialLoading = isLoading && products.isEmpty && _lastSyncedAt == null;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6EFE6),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton.extended(
          backgroundColor: _primary,
          elevation: 12,
          onPressed: _goToCreateProduct,
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
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: _buildBackgroundBubble(
                190,
                _primary.withOpacity(0.12),
              ),
            ),
            Positioned(
              top: 150,
              right: -65,
              child: _buildBackgroundBubble(
                150,
                _green.withOpacity(0.08),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -25,
              child: _buildBackgroundBubble(
                170,
                _primaryDark.withOpacity(0.06),
              ),
            ),
            Positioned(
              bottom: 210,
              right: -25,
              child: _buildBackgroundBubble(
                95,
                _gold.withOpacity(0.10),
              ),
            ),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: _primary,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.zero,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _maxWidth(screenWidth),
                        ),
                        child: Padding(
                          padding: _pagePadding(screenWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopBar(
                                userController: userController,
                                coinBalance: coinBalance,
                                isLoading: isLoading || _isRefreshing,
                                screenWidth: screenWidth,
                                products: products,
                              ),
                              const SizedBox(height: 18),
                              if (isInitialLoading)
                                _buildLoadingCard()
                              else ...[
                                _buildHeroCard(
                                  userController: userController,
                                  products: products,
                                  coinBalance: coinBalance,
                                  moneyReference: moneyReference,
                                  isLoading: isLoading || _isRefreshing,
                                  isMobile: isMobile,
                                  isVerySmall: isVerySmall,
                                ),
                                const SizedBox(height: 18),
                                _buildSectionContainer(
                                  title: 'Resumen operativo',
                                  subtitle: 'Vista rápida del estado real de tu catálogo.',
                                  child: Column(
                                    children: [
                                      _buildSummaryGrid(
                                        screenWidth: screenWidth,
                                        items: [
                                          _SummaryCardData(
                                            icon: Icons.inventory_2_outlined,
                                            title: 'Productos',
                                            value: products.length.toString(),
                                            accent: _primary,
                                          ),
                                          _SummaryCardData(
                                            icon: Icons.check_circle_outline,
                                            title: 'Activos',
                                            value: _activeProducts(products).toString(),
                                            accent: _green,
                                          ),
                                          _SummaryCardData(
                                            icon: Icons.grid_view_rounded,
                                            title: 'Unidades',
                                            value: _totalUnits(products).toString(),
                                            accent: _primaryDark,
                                          ),
                                          _SummaryCardData(
                                            icon: Icons.payments_outlined,
                                            title: 'Promedio',
                                            value: '${_money(_averagePrice(products))} mon.',
                                            accent: _orange,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _buildStatusBanner(
                                        label: 'Estado general',
                                        value: _stockHealthLabel(products),
                                        color: _stockHealthColor(products),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildAvailabilityCard(
                                        availability: _availabilityPercent(products),
                                        active: _activeProducts(products),
                                        total: products.length,
                                        moneyReference: moneyReference,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildSectionContainer(
                                  title: 'Alertas del catálogo',
                                  subtitle: 'Solo muestra información real según el stock actual.',
                                  actionLabel: lowStockProducts.isNotEmpty || soldOutProducts.isNotEmpty
                                      ? 'Ver catálogo'
                                      : null,
                                  onActionTap: lowStockProducts.isNotEmpty || soldOutProducts.isNotEmpty
                                      ? _goToProducts
                                      : null,
                                  child: _buildAlertsContent(
                                    lowStockProducts: lowStockProducts,
                                    soldOutProducts: soldOutProducts,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildSectionContainer(
                                  title: 'Accesos rápidos',
                                  subtitle: 'Entradas directas a las acciones que más usas.',
                                  child: _buildQuickActionsGrid(
                                    screenWidth: screenWidth,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildSectionContainer(
                                  title: 'Productos recientes',
                                  subtitle: 'Tus publicaciones más actuales con datos reales.',
                                  actionLabel: 'Ver productos',
                                  onActionTap: _goToProducts,
                                  child: recentProducts.isEmpty
                                      ? _buildEmptyCard(
                                    icon: Icons.inventory_2_outlined,
                                    title: 'Aún no tienes productos publicados',
                                    subtitle:
                                    'Cuando publiques productos, aquí aparecerán tus registros más recientes.',
                                  )
                                      : Column(
                                    children: recentProducts.map(_buildRecentProductCard).toList(),
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

  Widget _buildTopBar({
    required UserController userController,
    required double coinBalance,
    required bool isLoading,
    required double screenWidth,
    required List<ProductModel> products,
  }) {
    final user = userController.currentUser;
    final hasName = (user?.name.isNotEmpty ?? false);
    final initial = hasName ? user!.name[0].toUpperCase() : 'P';
    final isMobile = screenWidth < 700;
    final statusColor = _stockHealthColor(products);
    final statusText = _stockHealthLabel(products);

    final titleArea = Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFFB9854A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0C5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
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
                    icon: Icons.dashboard_customize_outlined,
                    label: 'Dashboard',
                    color: _primaryDark,
                    background: const Color(0xFFFFF7EC),
                  ),
                  _buildHeaderChip(
                    icon: Icons.verified_outlined,
                    label: 'Datos reales',
                    color: _green,
                    background: const Color(0xFFF2FAF5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                userController.currentUser?.name ?? 'Productor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  color: _textDark,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _lastSyncedAt == null
                    ? 'Sincronización pendiente'
                    : 'Actualizado ${_formatHour(_lastSyncedAt)} · ${_formatDate(_lastSyncedAt)}',
                style: TextStyle(
                  fontSize: 11.8,
                  color: isLoading ? _primaryDark : _textSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildBalancePill(
              isLoading: isLoading,
              value: '${_coins(coinBalance)} mon.',
            ),
            _buildTopIconButton(
              icon: Icons.refresh_rounded,
              color: _primary,
              onTap: _loadDashboardData,
            ),
            _buildMenuButton(),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: statusColor.withOpacity(0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insights_outlined, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleArea,
          const SizedBox(height: 14),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleArea),
        const SizedBox(width: 12),
        SizedBox(
          width: 280,
          child: actions,
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

  Widget _buildBalancePill({
    required bool isLoading,
    required String value,
  }) {
    return InkWell(
      onTap: _goToCoins,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.98),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLoading ? Icons.hourglass_top_rounded : Icons.monetization_on_outlined,
              color: _primary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onTap(),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildMenuButton() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_horiz_rounded,
          color: _textDark,
          size: 20,
        ),
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        onSelected: (value) {
          if (value == 'logout') {
            _logout();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 18),
                SizedBox(width: 10),
                Text('Cerrar sesión'),
              ],
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
            'Cargando dashboard...',
            style: TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos trayendo tus productos y tus monedas.',
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

  Widget _buildHeroCard({
    required UserController userController,
    required List<ProductModel> products,
    required double coinBalance,
    required double moneyReference,
    required bool isLoading,
    required bool isMobile,
    required bool isVerySmall,
  }) {
    final userName = userController.currentUser?.name ?? 'Productor';
    final stockValue = _inventoryValue(products);

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
            top: -40,
            right: -10,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -22,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            top: 28,
            right: 24,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.store_mall_directory_outlined,
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
                      icon: Icons.sync_rounded,
                      text: isLoading ? 'Actualizando' : 'Sincronizado',
                    ),
                    _buildHeroTag(
                      icon: Icons.storefront_outlined,
                      text: '${products.length} productos',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Hola, $userName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.02,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Un panel más limpio, más visual y mucho más cómodo para usar en móvil.',
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
                        child: _buildHeroTopMetric(
                          icon: Icons.savings_outlined,
                          title: 'Inventario',
                          value: '${_money(stockValue)} mon.',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withOpacity(0.10),
                      ),
                      Expanded(
                        child: _buildHeroTopMetric(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Saldo',
                          value: '${_coins(coinBalance)} mon.',
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
                  childAspectRatio: isMobile ? 1.45 : 1.7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildHeroStat(
                      label: 'Activos',
                      value: _activeProducts(products).toString(),
                    ),
                    _buildHeroStat(
                      label: 'Pausados',
                      value: _pausedProducts(products).toString(),
                    ),
                    _buildHeroStat(
                      label: 'Stock bajo',
                      value: _lowStockProducts(products).length.toString(),
                    ),
                    _buildHeroStat(
                      label: 'Agotados',
                      value: _soldOutProducts(products).length.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: isVerySmall
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroBottomInfo(
                        title: 'Referencia',
                        value: _money(moneyReference),
                      ),
                      const SizedBox(height: 10),
                      _buildHeroBottomInfo(
                        title: 'Disponibilidad',
                        value: '${(_availabilityPercent(products) * 100).round()}%',
                      ),
                      const SizedBox(height: 10),
                      _buildHeroBottomInfo(
                        title: 'Última carga',
                        value: _formatHour(_lastSyncedAt),
                      ),
                    ],
                  )
                      : Row(
                    children: [
                      Expanded(
                        child: _buildHeroBottomInfo(
                          title: 'Referencia',
                          value: _money(moneyReference),
                        ),
                      ),
                      Expanded(
                        child: _buildHeroBottomInfo(
                          title: 'Disponibilidad',
                          value: '${(_availabilityPercent(products) * 100).round()}%',
                        ),
                      ),
                      Expanded(
                        child: _buildHeroBottomInfo(
                          title: 'Última carga',
                          value: _formatHour(_lastSyncedAt),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isVerySmall)
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _goToProducts,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.storefront_rounded, size: 18),
                          label: const Text('Ver catálogo'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _goToCoins,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _textDark,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 18,
                          ),
                          label: const Text('Ir a monedas'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _goToProducts,
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.storefront_rounded, size: 18),
                          label: const Text('Ver catálogo'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _goToCoins,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _textDark,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 18,
                          ),
                          label: const Text('Ir a monedas'),
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

  Widget _buildHeroTopMetric({
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

  Widget _buildHeroBottomInfo({
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required Widget child,
    String? actionLabel,
    Future<void> Function()? onActionTap,
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
              if (actionLabel != null && onActionTap != null) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => onActionTap(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
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
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryGrid({
    required double screenWidth,
    required List<_SummaryCardData> items,
  }) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _summaryCrossAxisCount(screenWidth),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: screenWidth < 400 ? 1.18 : 1.35,
      ),
      itemBuilder: (_, index) => _buildSummaryCard(items[index]),
    );
  }

  Widget _buildSummaryCard(_SummaryCardData item) {
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

  Widget _buildStatusBanner({
    required String label,
    required String value,
    required Color color,
  }) {
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
              label,
              style: const TextStyle(
                color: _textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
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

  Widget _buildAvailabilityCard({
    required double availability,
    required int active,
    required int total,
    required double moneyReference,
  }) {
    final safePercent = availability.clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Disponibilidad del catálogo',
            style: TextStyle(
              color: _textDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LinearProgressIndicator(
              value: safePercent,
              minHeight: 11,
              backgroundColor: const Color(0xFFE8DCCB),
              valueColor: const AlwaysStoppedAnimation(_primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$active activos',
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(safePercent * 100).round()}%',
                style: const TextStyle(
                  color: _primaryDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total total',
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_money_rounded,
                  color: _primaryDark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Referencia del saldo: ${_money(moneyReference)}',
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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

  Widget _buildAlertsContent({
    required List<ProductModel> lowStockProducts,
    required List<ProductModel> soldOutProducts,
  }) {
    if (lowStockProducts.isEmpty && soldOutProducts.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.check_circle_outline_rounded,
        title: 'Todo se ve en orden',
        subtitle: 'No hay productos con stock bajo ni agotados en este momento.',
      );
    }

    return Column(
      children: [
        if (soldOutProducts.isNotEmpty)
          ...soldOutProducts.take(2).map(
                (product) => _buildAlertCard(
              product: product,
              title: 'Producto agotado',
              subtitle: 'Este producto ya no tiene stock disponible.',
              accent: _red,
              icon: Icons.remove_shopping_cart_outlined,
              buttonText: 'Ver catálogo',
              onTap: _goToProducts,
            ),
          ),
        if (lowStockProducts.isNotEmpty)
          ...lowStockProducts.take(3).map(
                (product) => _buildAlertCard(
              product: product,
              title: 'Stock bajo',
              subtitle: 'Solo quedan ${product.stock} unidades disponibles.',
              accent: _orange,
              icon: Icons.warning_amber_rounded,
              buttonText: 'Reponer',
              onTap: () => _replenishProduct(product),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertCard({
    required ProductModel product,
    required String title,
    required String subtitle,
    required Color accent,
    required IconData icon,
    required String buttonText,
    required Future<void> Function() onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildStatusBadge(_productStatusText(product), accent),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textDark,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: const TextStyle(
                color: _textSoft,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSoftInfoChip(
                icon: Icons.payments_outlined,
                text: '${_money(product.price)} mon. / ${product.unit ?? 'unidad'}',
              ),
              _buildSoftInfoChip(
                icon: Icons.event_outlined,
                text: _formatDate(product.harvestDate),
              ),
              _buildSoftInfoChip(
                icon: Icons.inventory_2_outlined,
                text: 'Stock ${product.stock}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => onTap(),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid({
    required double screenWidth,
  }) {
    final actions = [
      _QuickActionData(
        icon: Icons.add_box_outlined,
        title: 'Publicar',
        subtitle: 'Crear producto',
        accent: _primary,
        onTap: _goToCreateProduct,
      ),
      _QuickActionData(
        icon: Icons.storefront_outlined,
        title: 'Productos',
        subtitle: 'Gestionar catálogo',
        accent: _primaryDark,
        onTap: _goToProducts,
      ),
      _QuickActionData(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Monedas',
        subtitle: 'Saldo e historial',
        accent: const Color(0xFFC68A28),
        onTap: _goToCoins,
      ),
      _QuickActionData(
        icon: Icons.person_outline_rounded,
        title: 'Perfil',
        subtitle: 'Editar datos',
        accent: _green,
        onTap: _goToProfile,
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _quickActionsCrossAxisCount(screenWidth),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: screenWidth < 400 ? 1.05 : 1.2,
      ),
      itemBuilder: (_, index) => _buildQuickActionCard(actions[index]),
    );
  }

  Widget _buildQuickActionCard(_QuickActionData action) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => action.onTap(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFCF8), Color(0xFFF8F2E8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _divider),
          boxShadow: [
            BoxShadow(
              color: action.accent.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: action.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(action.icon, color: action.accent, size: 22),
            ),
            const Spacer(),
            Text(
              action.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textDark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              action.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textSoft,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProductCard(ProductModel product) {
    final statusColor = _productStatusColor(product);
    final statusText = _productStatusText(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF4ECE0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: product.picture != null && product.picture!.isNotEmpty
                ? ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                product.picture!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    color: _primary,
                    size: 28,
                  );
                },
              ),
            )
                : const Icon(
              Icons.inventory_2_outlined,
              color: _primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(statusText, statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  product.description ?? 'Sin descripción disponible.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSoftInfoChip(
                      icon: Icons.payments_outlined,
                      text: '${_money(product.price)} mon. / ${product.unit ?? 'unidad'}',
                    ),
                    _buildSoftInfoChip(
                      icon: Icons.inventory_2_outlined,
                      text: 'Stock ${product.stock}',
                    ),
                    _buildSoftInfoChip(
                      icon: Icons.calendar_month_outlined,
                      text: _harvestLabel(product.harvestDate),
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

  Widget _buildSoftInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryDark),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: _primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textDark,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
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
                    child: _buildBottomNavItem(items[0], selected: true),
                  ),
                  Expanded(
                    child: _buildBottomNavItem(items[1], selected: false),
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

class _SummaryCardData {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  const _SummaryCardData({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });
}

class _QuickActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Future<void> Function() onTap;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
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