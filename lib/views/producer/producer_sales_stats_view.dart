import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/order_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import 'producer_coins_view.dart';
import 'producer_create_product_view.dart';
import 'producer_dashboard_view.dart';
import 'producer_orders_view.dart';
import 'producer_products_view.dart';
import 'producer_profile_view.dart';
import 'producer_sales_history_view.dart';

class ProducerSalesStatsView extends StatefulWidget {
  const ProducerSalesStatsView({super.key});

  @override
  State<ProducerSalesStatsView> createState() => _ProducerSalesStatsViewState();
}

class _ProducerSalesStatsViewState extends State<ProducerSalesStatsView> {
  // ─── Paleta visual consistente con productor ───────────────────────────────
  static const Color _bgTop = Color(0xFFF8F2EA);
  static const Color _bgMiddle = Color(0xFFF3E8D8);
  static const Color _bgBottom = Color(0xFFE6D6C3);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF7EFE5);
  static const Color _surfaceWarm = Color(0xFFFFF7EC);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8A6848);
  static const Color _coffee = Color(0xFF4B3427);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF43795C);
  static const Color _orange = Color(0xFFD97A33);
  static const Color _red = Color(0xFFBC5F39);
  static const Color _blue = Color(0xFF5E7FA3);
  static const Color _purple = Color(0xFF7A67A8);

  static const Color _textDark = Color(0xFF4B3427);
  static const Color _textSoft = Color(0xFF857261);
  static const Color _textMuted = Color(0xFFA19182);
  static const Color _border = Color(0xFFEEE3D5);
  static const Color _divider = Color(0xFFE7DACA);

  // ─── Estados de pedido ─────────────────────────────────────────────────────
  static const int _statePending = 0;
  static const int _statePreparing = 1;
  static const int _stateShipped = 2;
  static const int _stateCompleted = 3;
  static const int _stateCancelled = 4;

  DateTime? _lastSyncedAt;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadStats();
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CARGA DE DATOS
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _loadStats() async {
    if (!mounted) return;

    setState(() => _isRefreshing = true);

    try {
      final userController = context.read<UserController>();
      final orderController = context.read<OrderController>();
      final productController = context.read<ProductController>();

      final currentUser = userController.currentUser;
      if (currentUser == null || currentUser.id == null || currentUser.id! <= 0) {
        return;
      }

      await Future.wait([
        orderController.loadOrdersByProducer(currentUser.id!),
        productController.getProductsByProducer(currentUser.id!),
      ]);

      if (!mounted) return;
      setState(() => _lastSyncedAt = DateTime.now());
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HELPERS DE FORMATO
  // ────────────────────────────────────────────────────────────────────────────
  String _formatMoney(double value) {
    if (value == value.truncateToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _formatCurrency(double value) => '${_formatMoney(value)} mon.';

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _formatShortDate(DateTime? date) {
    if (date == null) return '--/--';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '--:--';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${_formatDate(date)} • ${_formatTime(date)}';
  }

  String _formatLastSync(DateTime? date) {
    if (date == null) return 'Sin sincronizar';
    return 'Act. ${_formatTime(date)} · ${_formatShortDate(date)}';
  }

  String _relativeDate(DateTime? date) {
    if (date == null) return 'sin fecha';

    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'hace instantes';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'hace 1 día';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return _formatDate(date);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HELPERS DE NEGOCIO
  // ────────────────────────────────────────────────────────────────────────────
  List<OrderModel> _recentOrders(List<OrderModel> orders) {
    final copy = [...orders];
    copy.sort((a, b) {
      final aDate = a.registerDate ?? DateTime(2000);
      final bDate = b.registerDate ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return copy.take(5).toList();
  }

  List<ProductModel> _topProducts(List<ProductModel> products) {
    final copy = [...products];
    copy.sort((a, b) {
      final aValue = a.price * a.stock;
      final bValue = b.price * b.stock;
      return bValue.compareTo(aValue);
    });
    return copy.take(5).toList();
  }

  int _totalOrders(List<OrderModel> orders) => orders.length;

  int _pendingOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == _statePending).length;

  int _preparingOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == _statePreparing).length;

  int _shippedOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == _stateShipped).length;

  int _completedOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == _stateCompleted).length;

  int _cancelledOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == _stateCancelled).length;

  double _managedAmount(List<OrderModel> orders) {
    return orders
        .where((o) => o.state != _stateCancelled)
        .fold(0.0, (sum, order) => sum + order.amount);
  }

  double _completedAmount(List<OrderModel> orders) {
    return orders
        .where((o) => o.state == _stateCompleted)
        .fold(0.0, (sum, order) => sum + order.amount);
  }

  double _averageTicket(List<OrderModel> orders) {
    if (orders.isEmpty) return 0.0;
    final total = orders.fold(0.0, (sum, order) => sum + order.amount);
    return total / orders.length;
  }

  double _completionPercent(List<OrderModel> orders) {
    if (orders.isEmpty) return 0;
    return _completedOrders(orders) / orders.length;
  }

  double _activePipelineAmount(List<OrderModel> orders) {
    return orders
        .where(
          (o) =>
      o.state == _statePending ||
          o.state == _statePreparing ||
          o.state == _stateShipped,
    )
        .fold(0.0, (sum, order) => sum + order.amount);
  }

  int _activeProducts(List<ProductModel> products) {
    return products.where((p) => p.state == 1 && p.stock > 0).length;
  }

  int _pausedProducts(List<ProductModel> products) {
    return products.where((p) => p.state == 0).length;
  }

  int _lowStockProducts(List<ProductModel> products) {
    return products.where((p) => p.state == 1 && p.stock > 0 && p.stock <= 3).length;
  }

  int _soldOutProducts(List<ProductModel> products) {
    return products.where((p) => p.stock == 0).length;
  }

  int _totalStock(List<ProductModel> products) {
    return products.fold(0, (sum, product) => sum + product.stock);
  }

  double _inventoryValue(List<ProductModel> products) {
    return products.fold(
      0.0,
          (sum, product) => sum + (product.price * product.stock),
    );
  }

  double _availabilityPercent(List<ProductModel> products) {
    if (products.isEmpty) return 0;
    return _activeProducts(products) / products.length;
  }

  int _alertsCount(List<OrderModel> orders, List<ProductModel> products) {
    return _pendingOrders(orders) +
        _lowStockProducts(products) +
        _soldOutProducts(products);
  }

  String _mainAdvice(List<OrderModel> orders, List<ProductModel> products) {
    if (_pendingOrders(orders) > 0) {
      return 'Tienes ${_pendingOrders(orders)} pedido${_pendingOrders(orders) == 1 ? '' : 's'} pendiente${_pendingOrders(orders) == 1 ? '' : 's'} por atender.';
    }
    if (_soldOutProducts(products) > 0) {
      return 'Hay ${_soldOutProducts(products)} producto${_soldOutProducts(products) == 1 ? '' : 's'} sin stock. Repón los más importantes.';
    }
    if (_lowStockProducts(products) > 0) {
      return 'Tu catálogo está bien, pero ${_lowStockProducts(products)} producto${_lowStockProducts(products) == 1 ? '' : 's'} ya tiene${_lowStockProducts(products) == 1 ? '' : 'n'} stock bajo.';
    }
    if (orders.isEmpty && products.isEmpty) {
      return 'Publica tus primeros productos para empezar a recibir pedidos.';
    }
    return 'Tu operación se ve estable. Mantén tu catálogo actualizado y revisa pedidos con frecuencia.';
  }

  String _ordersHealthLabel(List<OrderModel> orders) {
    if (orders.isEmpty) return 'Sin ventas';
    if (_pendingOrders(orders) > 0) return 'Atención requerida';
    if (_preparingOrders(orders) > 0 || _shippedOrders(orders) > 0) {
      return 'En movimiento';
    }
    return 'Todo en orden';
  }

  Color _ordersHealthColor(List<OrderModel> orders) {
    if (orders.isEmpty) return _primaryDark;
    if (_pendingOrders(orders) > 0) return _orange;
    if (_preparingOrders(orders) > 0) return _blue;
    if (_shippedOrders(orders) > 0) return _purple;
    return _green;
  }

  String _catalogHealthLabel(List<ProductModel> products) {
    if (products.isEmpty) return 'Sin catálogo';
    if (_soldOutProducts(products) > 0) return 'Reponer stock';
    if (_lowStockProducts(products) > 0) return 'Stock bajo';
    return 'Catálogo activo';
  }

  Color _catalogHealthColor(List<ProductModel> products) {
    if (products.isEmpty) return _primaryDark;
    if (_soldOutProducts(products) > 0) return _red;
    if (_lowStockProducts(products) > 0) return _orange;
    return _green;
  }

  String _productStatusText(ProductModel product) {
    if (product.state == 0) return 'Pausado';
    if (product.stock == 0) return 'Sin stock';
    if (product.stock <= 3) return 'Stock bajo';
    return 'Activo';
  }

  Color _productStatusColor(ProductModel product) {
    if (product.state == 0) return const Color(0xFF8F8F8F);
    if (product.stock == 0) return _red;
    if (product.stock <= 3) return _orange;
    return _green;
  }

  String _orderStateText(int state) {
    switch (state) {
      case _statePending:
        return 'Pendiente';
      case _statePreparing:
        return 'En preparación';
      case _stateShipped:
        return 'Enviado';
      case _stateCompleted:
        return 'Completado';
      case _stateCancelled:
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  Color _orderStateColor(int state) {
    switch (state) {
      case _statePending:
        return _orange;
      case _statePreparing:
        return _blue;
      case _stateShipped:
        return _purple;
      case _stateCompleted:
        return _green;
      case _stateCancelled:
        return _red;
      default:
        return _textSoft;
    }
  }

  IconData _orderStateIcon(int state) {
    switch (state) {
      case _statePending:
        return Icons.schedule_rounded;
      case _statePreparing:
        return Icons.inventory_2_rounded;
      case _stateShipped:
        return Icons.local_shipping_rounded;
      case _stateCompleted:
        return Icons.check_circle_rounded;
      case _stateCancelled:
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HELPERS VISUALES
  // ────────────────────────────────────────────────────────────────────────────
  EdgeInsets _responsivePadding(double width) {
    if (width >= 1200) return const EdgeInsets.fromLTRB(28, 16, 28, 132);
    if (width >= 800) return const EdgeInsets.fromLTRB(20, 14, 20, 132);
    return const EdgeInsets.fromLTRB(16, 12, 16, 132);
  }

  double _maxContentWidth(double width) {
    if (width >= 1600) return 1380;
    if (width >= 1300) return 1180;
    if (width >= 1000) return 980;
    return width;
  }

  int _overviewCrossAxisCount(double width) {
    if (width >= 1100) return 4;
    return 2;
  }

  Widget _buildDecorBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Uint8List? _decodeBase64Image(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final raw = value.trim();
      final normalized = raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkImage(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') || normalized.startsWith('https://');
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NAVEGACIÓN
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _goToDashboard() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerDashboardView()),
    );
  }

  Future<void> _goToProducts() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerProductsView()),
    );
  }

  Future<void> _goToOrders() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerOrdersView()),
    );
  }

  Future<void> _goToCoins() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerCoinsView()),
    );
  }

  Future<void> _goToProfile() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerProfileView()),
    );
  }

  Future<void> _goToSalesHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProducerSalesHistoryView()),
    );
  }

  Future<void> _openCreateProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProducerCreateProductView()),
    );

    if (created == true) {
      await _loadStats();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Producto publicado correctamente'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final orderController = context.watch<OrderController>();
    final productController = context.watch<ProductController>();

    final user = userController.currentUser;
    final orders = orderController.producerOrders;
    final products = productController.products;
    final recentOrders = _recentOrders(orders);
    final topProducts = _topProducts(products);
    final errorMessage = orderController.errorMessage ?? productController.errorMessage;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = _maxContentWidth(screenWidth);

    final isInitialLoading =
        (orderController.isLoading || productController.isLoading) &&
            orders.isEmpty &&
            products.isEmpty &&
            _lastSyncedAt == null;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6EFE6),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgMiddle, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -60,
              child: _buildDecorBubble(190, _primary.withOpacity(0.10)),
            ),
            Positioned(
              top: 110,
              right: -60,
              child: _buildDecorBubble(180, _gold.withOpacity(0.14)),
            ),
            Positioned(
              bottom: 120,
              left: -70,
              child: _buildDecorBubble(190, _green.withOpacity(0.07)),
            ),
            Positioned(
              bottom: -80,
              right: -70,
              child: _buildDecorBubble(180, _primaryDark.withOpacity(0.07)),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: _primary,
                onRefresh: _loadStats,
                child: errorMessage != null &&
                    orders.isEmpty &&
                    products.isEmpty &&
                    !orderController.isLoading &&
                    !productController.isLoading
                    ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 132),
                  children: [_buildErrorState(errorMessage)],
                )
                    : ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.zero,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Padding(
                          padding: _responsivePadding(screenWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAppBar(
                                userName: user?.name ?? 'Productor',
                                userImage: user?.image,
                                orders: orders,
                              ),
                              const SizedBox(height: 18),
                              if (isInitialLoading)
                                _buildLoadingCard()
                              else ...[
                                _buildHeroCard(orders: orders, products: products),
                                const SizedBox(height: 18),
                                _buildQuickActionsSection(),
                                const SizedBox(height: 18),
                                _buildAdviceCard(orders: orders, products: products),
                                const SizedBox(height: 18),
                                _buildOverviewSection(
                                  orders: orders,
                                  products: products,
                                  screenWidth: screenWidth,
                                ),
                                const SizedBox(height: 18),
                                _buildOrderDistributionSection(orders),
                                const SizedBox(height: 18),
                                _buildBusinessInsightsSection(
                                  products: products,
                                  orders: orders,
                                ),
                                const SizedBox(height: 18),
                                _buildRecentOrdersSection(recentOrders: recentOrders),
                                const SizedBox(height: 18),
                                _buildTopProductsSection(topProducts: topProducts),
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

  // ────────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildAppBar({
    required String userName,
    required String? userImage,
    required List<OrderModel> orders,
  }) {
    final firstName = userName.split(' ').first;
    final healthColor = _ordersHealthColor(orders);
    final healthLabel = _ordersHealthLabel(orders);

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showMoreMenu,
          child: _buildUserAvatar(
            name: userName,
            image: userImage,
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
                'Estadísticas de $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildTinyStatusChip(healthLabel, healthColor),
                  Text(
                    _isRefreshing ? 'Actualizando...' : _formatLastSync(_lastSyncedAt),
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
        _buildAppBarButton(
          icon: _isRefreshing ? Icons.sync_rounded : Icons.refresh_rounded,
          color: _primary,
          onTap: _loadStats,
        ),
        const SizedBox(width: 8),
        _buildAppBarButton(
          icon: Icons.menu_rounded,
          color: _primaryDark,
          onTap: _showMoreMenu,
        ),
      ],
    );
  }

  Widget _buildAppBarButton({
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HERO
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildHeroCard({
    required List<OrderModel> orders,
    required List<ProductModel> products,
  }) {
    final completedAmount = _completedAmount(orders);
    final completion = _completionPercent(orders);
    final avgTicket = _averageTicket(orders);
    final activePipeline = _activePipelineAmount(orders);
    final alerts = _alertsCount(orders, products);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF604E43), Color(0xFF493B35), Color(0xFF2E2624)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -38,
            right: -34,
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withOpacity(0.11),
              ),
            ),
          ),
          Positioned(
            bottom: -45,
            left: -25,
            child: Container(
              width: 110,
              height: 110,
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
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _gold.withOpacity(0.20)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_graph_rounded, size: 15, color: _gold),
                          SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Centro de rendimiento',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _gold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _formatCurrency(completedAmount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Ingresos completados · ${_totalOrders(orders)} pedidos · ${products.length} productos publicados',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.76),
                  fontSize: 12.8,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Ticket prom.',
                      value: _formatCurrency(avgTicket),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'En proceso',
                      value: _formatCurrency(activePipeline),
                      icon: Icons.route_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Cumplimiento',
                      value: '${(completion * 100).round()}%',
                      icon: Icons.track_changes_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Alertas',
                      value: alerts.toString(),
                      icon: Icons.notifications_active_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: completion.clamp(0.0, 1.0),
                  minHeight: 9,
                  backgroundColor: Colors.white.withOpacity(0.13),
                  valueColor: const AlwaysStoppedAnimation(_gold),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '${(completion * 100).round()}% de pedidos completados correctamente',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildHeroMiniTag(
                    label: '${_completedOrders(orders)} completados',
                    color: const Color(0xFFCDE8D9),
                  ),
                  _buildHeroMiniTag(
                    label: '${_pendingOrders(orders)} pendientes',
                    color: _pendingOrders(orders) > 0
                        ? const Color(0xFFFFD6A8)
                        : Colors.white70,
                  ),
                  _buildHeroMiniTag(
                    label: '${_lowStockProducts(products)} stock bajo',
                    color: _lowStockProducts(products) > 0
                        ? const Color(0xFFFFD6A8)
                        : Colors.white70,
                  ),
                  _buildHeroMiniTag(
                    label: '${_activeProducts(products)} activos',
                    color: const Color(0xFFCFE3FF),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _goToSalesHistory,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('Historial'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _goToOrders,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _textDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Pedidos'),
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
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 17.5,
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

  Widget _buildHeroMiniTag({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ACCIONES RÁPIDAS / RECOMENDACIÓN
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildQuickActionsSection() {
    final actions = <_QuickActionData>[
      _QuickActionData(
        icon: Icons.add_box_rounded,
        title: 'Publicar',
        subtitle: 'Nuevo producto',
        badge: 'Crear',
        color: _primary,
        onTap: _openCreateProduct,
      ),
      _QuickActionData(
        icon: Icons.inventory_2_outlined,
        title: 'Catálogo',
        subtitle: 'Stock y precios',
        badge: 'Gestionar',
        color: _blue,
        onTap: _goToProducts,
      ),
      _QuickActionData(
        icon: Icons.history_rounded,
        title: 'Historial',
        subtitle: 'Ventas cerradas',
        badge: 'Revisar',
        color: _purple,
        onTap: _goToSalesHistory,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final hideLongBadge = constraints.maxWidth < 390;

              return Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primary.withOpacity(0.20),
                          _gold.withOpacity(0.11),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: _primaryDark,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Accesos rápidos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Lo más usado para manejar tu negocio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _surfaceWarm,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app_rounded,
                          color: _primaryDark,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hideLongBadge ? '3' : '3 acciones',
                          style: const TextStyle(
                            color: _primaryDark,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final verySmall = constraints.maxWidth < 345;
              final useHorizontalList = constraints.maxWidth < 430;

              if (verySmall) {
                return Column(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      _buildQuickActionCard(
                        icon: actions[i].icon,
                        title: actions[i].title,
                        subtitle: actions[i].subtitle,
                        badge: actions[i].badge,
                        color: actions[i].color,
                        compact: true,
                        onTap: actions[i].onTap,
                      ),
                      if (i != actions.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              if (useHorizontalList) {
                return SizedBox(
                  height: 154,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: actions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      return SizedBox(
                        width: 146,
                        child: _buildQuickActionCard(
                          icon: actions[index].icon,
                          title: actions[index].title,
                          subtitle: actions[index].subtitle,
                          badge: actions[index].badge,
                          color: actions[index].color,
                          compact: false,
                          onTap: actions[index].onTap,
                        ),
                      );
                    },
                  ),
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    Expanded(
                      child: _buildQuickActionCard(
                        icon: actions[i].icon,
                        title: actions[i].title,
                        subtitle: actions[i].subtitle,
                        badge: actions[i].badge,
                        color: actions[i].color,
                        compact: false,
                        onTap: actions[i].onTap,
                      ),
                    ),
                    if (i != actions.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required bool compact,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          await onTap();
        },
        child: Ink(
          height: compact ? 86 : 154,
          padding: EdgeInsets.all(compact ? 12 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.16),
                _surfaceSoft,
                _surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -18,
                bottom: -18,
                child: Icon(
                  icon,
                  size: compact ? 58 : 70,
                  color: color.withOpacity(0.055),
                ),
              ),
              if (compact)
                Row(
                  children: [
                    _buildQuickActionIcon(icon: icon, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSoft,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionArrow(color),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildQuickActionIcon(icon: icon, color: color),
                        const Spacer(),
                        _buildQuickActionArrow(color),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
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

  Widget _buildQuickActionIcon({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  Widget _buildQuickActionArrow(Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: color,
        size: 16,
      ),
    );
  }

  Widget _buildAdviceCard({
    required List<OrderModel> orders,
    required List<ProductModel> products,
  }) {
    final alerts = _alertsCount(orders, products);
    final color = alerts > 0 ? _orange : _green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              alerts > 0 ? Icons.tips_and_updates_rounded : Icons.verified_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerts > 0 ? 'Prioridad de hoy' : 'Operación saludable',
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _mainAdvice(orders, products),
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 12.5,
                    height: 1.42,
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

  // ────────────────────────────────────────────────────────────────────────────
  // RESUMEN GENERAL
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewSection({
    required List<OrderModel> orders,
    required List<ProductModel> products,
    required double screenWidth,
  }) {
    final completion = _completionPercent(orders);
    final availability = _availabilityPercent(products);

    final items = [
      _OverviewItem(
        label: 'Pedidos',
        value: _totalOrders(orders).toString(),
        subtitle: '${_pendingOrders(orders)} pendientes',
        icon: Icons.receipt_long_rounded,
        color: _primary,
      ),
      _OverviewItem(
        label: 'Ingresos',
        value: _formatCurrency(_completedAmount(orders)),
        subtitle: 'completados',
        icon: Icons.savings_rounded,
        color: _green,
      ),
      _OverviewItem(
        label: 'Productos',
        value: products.length.toString(),
        subtitle: '${_activeProducts(products)} activos',
        icon: Icons.storefront_outlined,
        color: _blue,
      ),
      _OverviewItem(
        label: 'Inventario',
        value: _formatCurrency(_inventoryValue(products)),
        subtitle: '${_totalStock(products)} unidades',
        icon: Icons.warehouse_outlined,
        color: _gold,
      ),
    ];

    return _buildSectionShell(
      icon: Icons.dashboard_customize_rounded,
      iconColor: _primary,
      title: 'Resumen ejecutivo',
      trailing: _buildTinyStatusChip(
        '${_alertsCount(orders, products)} alertas',
        _alertsCount(orders, products) > 0 ? _orange : _green,
      ),
      child: Column(
        children: [
          GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _overviewCrossAxisCount(screenWidth),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 124,
            ),
            itemBuilder: (_, index) => _buildOverviewStatCard(items[index]),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildProgressInfoCard(
                  title: 'Cumplimiento',
                  value: completion,
                  label: '${(completion * 100).round()}%',
                  subtitle: '${_completedOrders(orders)} de ${_totalOrders(orders)} pedidos completados',
                  color: _green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProgressInfoCard(
                  title: 'Disponibilidad',
                  value: availability,
                  label: '${(availability * 100).round()}%',
                  subtitle: '${_activeProducts(products)} de ${products.length} productos activos',
                  color: _primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStatCard(_OverviewItem item) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 17),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up_rounded,
                color: item.color.withOpacity(0.65),
                size: 17,
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textDark,
              fontSize: 19.5,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textDark,
              fontSize: 11.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressInfoCard({
    required String title,
    required double value,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 12.6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor: const Color(0xFFE8DCCB),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 10.8,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // DISTRIBUCIÓN DE PEDIDOS
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildOrderDistributionSection(List<OrderModel> orders) {
    final total = orders.isEmpty ? 1 : orders.length;
    final items = [
      _DistributionItem('Pendientes', _pendingOrders(orders), _orange, Icons.schedule_rounded),
      _DistributionItem('Preparación', _preparingOrders(orders), _blue, Icons.inventory_2_rounded),
      _DistributionItem('Enviados', _shippedOrders(orders), _purple, Icons.local_shipping_rounded),
      _DistributionItem('Completados', _completedOrders(orders), _green, Icons.check_circle_rounded),
      _DistributionItem('Cancelados', _cancelledOrders(orders), _red, Icons.cancel_rounded),
    ];

    return _buildSectionShell(
      icon: Icons.bar_chart_rounded,
      iconColor: _purple,
      title: 'Distribución de pedidos',
      trailing: TextButton.icon(
        onPressed: _goToOrders,
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: const Text(
          'Ver pedidos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
      ),
      child: Column(
        children: items.map((item) {
          final percent = orders.isEmpty ? 0.0 : item.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildDistributionBar(item: item, percent: percent),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDistributionBar({
    required _DistributionItem item,
    required double percent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${item.value}',
                style: TextStyle(
                  color: item.color,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '(${(percent * 100).round()}%)',
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE8DCCB),
              valueColor: AlwaysStoppedAnimation(item.color),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // INSIGHTS DEL NEGOCIO
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildBusinessInsightsSection({
    required List<ProductModel> products,
    required List<OrderModel> orders,
  }) {
    final catalogColor = _catalogHealthColor(products);
    final catalogLabel = _catalogHealthLabel(products);

    return _buildSectionShell(
      icon: Icons.insights_rounded,
      iconColor: catalogColor,
      title: 'Salud del negocio',
      trailing: _buildTinyStatusChip(catalogLabel, catalogColor),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMiniInsightCard(
                  title: 'Gestionado',
                  value: _formatCurrency(_managedAmount(orders)),
                  subtitle: 'sin cancelados',
                  icon: Icons.account_balance_wallet_rounded,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniInsightCard(
                  title: 'Inventario',
                  value: _formatCurrency(_inventoryValue(products)),
                  subtitle: 'valor estimado',
                  icon: Icons.inventory_2_outlined,
                  color: _gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMiniInsightCard(
                  title: 'Activos',
                  value: _activeProducts(products).toString(),
                  subtitle: '${_pausedProducts(products)} pausados',
                  icon: Icons.storefront_outlined,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniInsightCard(
                  title: 'Stock total',
                  value: _totalStock(products).toString(),
                  subtitle: '${_lowStockProducts(products)} con alerta',
                  icon: Icons.warehouse_outlined,
                  color: _orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInsightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
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
                    color: _textSoft,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 10.8,
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

  // ────────────────────────────────────────────────────────────────────────────
  // PEDIDOS RECIENTES
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildRecentOrdersSection({required List<OrderModel> recentOrders}) {
    return _buildSectionShell(
      icon: Icons.receipt_long_rounded,
      iconColor: _blue,
      title: 'Pedidos recientes',
      trailing: TextButton.icon(
        onPressed: _goToOrders,
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: const Text(
          'Ver todos',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
      ),
      child: recentOrders.isEmpty
          ? _buildSectionEmptyState(
        icon: Icons.inbox_rounded,
        title: 'Aún no hay pedidos',
        subtitle:
        'Cuando empieces a recibir órdenes, aparecerán aquí con monto, fecha y estado.',
      )
          : Column(children: recentOrders.map(_buildOrderTile).toList()),
    );
  }

  Widget _buildOrderTile(OrderModel order) {
    final stateColor = _orderStateColor(order.state);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _goToOrders,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_orderStateIcon(order.state), color: stateColor, size: 22),
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
                            'Pedido #${order.id ?? '--'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 14.8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _buildInlinePill(text: _orderStateText(order.state), color: stateColor),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatDateTime(order.registerDate),
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, color: _textMuted, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Cliente ID ${order.clientID}',
                          style: const TextStyle(
                            color: _textSoft,
                            fontSize: 11.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.access_time_rounded, color: _textMuted, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _relativeDate(order.registerDate),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSoft,
                              fontSize: 11.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(order.amount),
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'monto',
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
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

  // ────────────────────────────────────────────────────────────────────────────
  // PRODUCTOS DESTACADOS
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildTopProductsSection({required List<ProductModel> topProducts}) {
    return _buildSectionShell(
      icon: Icons.workspace_premium_rounded,
      iconColor: _gold,
      title: 'Catálogo destacado',
      trailing: TextButton.icon(
        onPressed: _goToProducts,
        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
        label: const Text(
          'Ir al catálogo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
      ),
      child: topProducts.isEmpty
          ? _buildSectionEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Sin productos publicados',
        subtitle:
        'Publica productos para ver aquí los más importantes por valor de inventario.',
      )
          : Column(children: topProducts.map(_buildProductTile).toList()),
    );
  }

  Widget _buildProductTile(ProductModel product) {
    final statusColor = _productStatusColor(product);
    final potential = product.price * product.stock;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _goToProducts,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildProductImage(product, statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInlinePill(text: _productStatusText(product), color: statusColor),
                        _buildInlinePill(text: 'Stock ${product.stock}', color: _blue),
                        _buildInlinePill(
                          text: '${_formatMoney(product.price)} mon.',
                          color: _primaryDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(potential),
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 15.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'valor stock',
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
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

  Widget _buildProductImage(ProductModel product, Color statusColor) {
    final bytes = _decodeBase64Image(product.picture);

    Widget child;
    if (_isNetworkImage(product.picture)) {
      child = Image.network(
        product.picture!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, color: statusColor),
      );
    } else if (bytes != null) {
      child = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, color: statusColor),
      );
    } else {
      child = Icon(Icons.eco_rounded, color: statusColor, size: 24);
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.13),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: statusColor.withOpacity(0.14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ESTADOS DE CARGA / ERROR / VACÍO
  // ────────────────────────────────────────────────────────────────────────────
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
            'Cargando estadísticas...',
            style: TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos sincronizando pedidos, montos y productos para mostrarte un panel claro.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
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
            child: const Icon(Icons.error_outline_rounded, color: _red, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'No se pudieron cargar las estadísticas',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: _textDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: _textSoft, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loadStats,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
            child: Icon(icon, size: 32, color: _primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // COMPONENTES COMUNES
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildSectionShell({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 15,
            offset: const Offset(0, 6),
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
                  color: iconColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
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
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildInlinePill({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildUserAvatar({
    required String name,
    required String? image,
    double size = 58,
    double radius = 20,
    double fontSize = 22,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final bytes = _decodeBase64Image(image);

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
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: content),
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
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // FAB
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildFloatingActionButton() {
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

  // ────────────────────────────────────────────────────────────────────────────
  // BOTTOM NAV
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNavigationBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            border: Border(top: BorderSide(color: _border.withOpacity(0.85))),
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
                  selected: false,
                  onTap: _goToProducts,
                ),
                const SizedBox(width: 56),
                _buildNavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Estadíst.',
                  selected: true,
                  onTap: _loadStats,
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
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // MENÚ INFERIOR
  // ────────────────────────────────────────────────────────────────────────────
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.035),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
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
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                email.isEmpty ? 'Panel de productor' : email,
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
                      borderRadius: BorderRadius.circular(24),
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
                          icon: Icons.storefront_outlined,
                          color: _primaryDark,
                          title: 'Productos',
                          subtitle: 'Gestiona catálogo y stock',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToProducts();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.receipt_long_rounded,
                          color: _blue,
                          title: 'Pedidos',
                          subtitle: 'Atiende tus órdenes activas',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToOrders();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.history_rounded,
                          color: _purple,
                          title: 'Historial de ventas',
                          subtitle: 'Revisa ventas y registros',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToSalesHistory();
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
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                    ),
                    child: _buildMenuAction(
                      icon: Icons.refresh_rounded,
                      color: _primaryDark,
                      title: 'Actualizar estadísticas',
                      subtitle: 'Sincroniza pedidos y productos',
                      onTap: () {
                        Navigator.pop(ctx);
                        _loadStats();
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
                      fontWeight: FontWeight.w900,
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
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _textSoft),
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
}

class _QuickActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final Future<void> Function() onTap;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.onTap,
  });
}

class _OverviewItem {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _OverviewItem({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _DistributionItem {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _DistributionItem(this.label, this.value, this.color, this.icon);
}