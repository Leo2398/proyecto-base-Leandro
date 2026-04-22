import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/coin_movement_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/notification_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../auth/login_view.dart';
import 'producer_coins_view.dart';
import 'producer_create_product_view.dart';
import 'producer_orders_view.dart';
import 'producer_products_view.dart';
import 'producer_profile_view.dart';
import 'producer_reviews_view.dart';
import 'producer_sales_stats_view.dart';

class ProducerDashboardView extends StatefulWidget {
  const ProducerDashboardView({super.key});

  @override
  State<ProducerDashboardView> createState() => _ProducerDashboardViewState();
}

class _ProducerDashboardViewState extends State<ProducerDashboardView> {
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
      await _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    await _loadDashboardData();
    await _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final userController = context.read<UserController>();
    final notificationController = context.read<NotificationController>();

    final currentUser = userController.currentUser;
    if (currentUser == null || currentUser.id == null || currentUser.id! <= 0) {
      return;
    }

    notificationController.onNewNotification = (notification) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification.title),
          backgroundColor: _primaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    };

    await notificationController.startPolling(
      userId: currentUser.id!,
      interval: const Duration(seconds: 3),
      loadImmediately: true,
    );
  }

  Future<void> _loadDashboardData() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    try {
      final userController = context.read<UserController>();
      final productController = context.read<ProductController>();
      final coinController = context.read<CoinMovementController>();
      final orderController = context.read<OrderController>();
      final notificationController = context.read<NotificationController>();

      final currentUser = userController.currentUser;
      if (currentUser == null || currentUser.id == null || currentUser.id! <= 0) {
        return;
      }

      await Future.wait([
        productController.getProductsByProducer(currentUser.id!),
        coinController.loadCoinData(currentUser.id!),
        orderController.loadOrdersByProducer(currentUser.id!),
        notificationController.refresh(userId: currentUser.id!),
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
    return copy.take(6).toList();
  }

  List<OrderModel> _recentOrders(List<OrderModel> orders) {
    final copy = [...orders];
    copy.sort((a, b) {
      final aDate = a.registerDate ?? DateTime(2000);
      final bDate = b.registerDate ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });
    return copy.take(5).toList();
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

  int _pendingOrders(List<OrderModel> orders) {
    return orders.where((o) => o.state == _statePending).length;
  }

  int _preparingOrders(List<OrderModel> orders) {
    return orders.where((o) => o.state == _statePreparing).length;
  }

  int _shippedOrders(List<OrderModel> orders) {
    return orders.where((o) => o.state == _stateShipped).length;
  }

  int _completedOrders(List<OrderModel> orders) {
    return orders.where((o) => o.state == _stateCompleted).length;
  }

  int _cancelledOrders(List<OrderModel> orders) {
    return orders.where((o) => o.state == _stateCancelled).length;
  }

  double _managedAmount(List<OrderModel> orders) {
    return orders.fold(0.0, (sum, order) => sum + order.amount);
  }

  double _completedAmount(List<OrderModel> orders) {
    return orders
        .where((o) => o.state == _stateCompleted)
        .fold(0.0, (sum, order) => sum + order.amount);
  }

  double _averageTicket(List<OrderModel> orders) {
    if (orders.isEmpty) return 0;
    return _managedAmount(orders) / orders.length;
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

  String _bs(double value) {
    if (value == value.truncateToDouble()) {
      return 'Bs ${value.toStringAsFixed(0)}';
    }
    return 'Bs ${value.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatHour(DateTime? date) {
    if (date == null) return '--:--';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${_formatDate(date)} • ${_formatHour(date)}';
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

  String _orderStatusText(int state) {
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

  Color _orderStatusColor(int state) {
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

  IconData _orderStatusIcon(int state) {
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

  String _notificationTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return 'Pedido';
      case 'recharge':
        return 'Recarga';
      case 'stock':
        return 'Stock';
      case 'system':
        return 'Sistema';
      default:
        return 'General';
    }
  }

  IconData _notificationTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Icons.receipt_long_rounded;
      case 'recharge':
        return Icons.account_balance_wallet_rounded;
      case 'stock':
        return Icons.inventory_2_rounded;
      case 'system':
        return Icons.settings_suggest_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _notificationTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return _blue;
      case 'recharge':
        return _gold;
      case 'stock':
        return _orange;
      case 'system':
        return _purple;
      default:
        return _primary;
    }
  }

  EdgeInsets _pagePadding(double width) {
    if (width >= 1200) return const EdgeInsets.fromLTRB(28, 16, 28, 170);
    if (width >= 800) return const EdgeInsets.fromLTRB(20, 14, 20, 170);
    return const EdgeInsets.fromLTRB(16, 12, 16, 170);
  }

  double _maxWidth(double width) {
    if (width >= 1600) return 1380;
    if (width >= 1300) return 1180;
    if (width >= 1000) return 980;
    return width;
  }

  int _quickActionsCrossAxisCount(double width) {
    if (width >= 1200) return 6;
    if (width >= 760) return 3;
    return 2;
  }

  int _metricCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 850) return 2;
    return 2;
  }

  int _orderMetricCrossAxisCount(double width) {
    if (width >= 1200) return 6;
    if (width >= 850) return 3;
    return 2;
  }

  int _productGridCount(double width) {
    if (width >= 1300) return 3;
    if (width >= 850) return 2;
    return 1;
  }

  Future<void> _goToProducts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProducerProductsView()),
    );

    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _goToCreateProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProducerCreateProductView()),
    );

    if (!mounted) return;

    if (created == true) {
      await _loadDashboardData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto publicado correctamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _goToSalesStats() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerSalesStatsView()),
    );
  }

  Future<void> _goToOrders() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProducerOrdersView()),
    );

    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _goToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProducerProfileView()),
    );

    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _goToReviews() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProducerReviewsView()),
    );

    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _goToCoins() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProducerCoinsView()),
    );

    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _showNotificationsSheet() async {
    final notificationController = context.read<NotificationController>();
    final userId = context.read<UserController>().currentUser?.id;

    if (userId != null && userId > 0) {
      await notificationController.refresh(userId: userId);
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Consumer<NotificationController>(
          builder: (context, notificationController, child) {
            final notifications = notificationController.notifications;

            return DraggableScrollableSheet(
              initialChildSize: 0.76,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F2EA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6C6B3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Notificaciones',
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (notificationController.unreadCount > 0)
                              TextButton.icon(
                                onPressed: () async {
                                  await notificationController.markAllAsRead(userId);
                                },
                                icon: const Icon(Icons.done_all_rounded, size: 18),
                                label: const Text('Marcar todas'),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                        child: Row(
                          children: [
                            _buildTinyStatusChip(
                              '${notificationController.unreadCount} sin leer',
                              _primary,
                            ),
                            const SizedBox(width: 8),
                            _buildTinyStatusChip(
                              '${notifications.length} en lista',
                              _blue,
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                if (userId != null && userId > 0) {
                                  await notificationController.refresh(userId: userId);
                                }
                              },
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border),
                                ),
                                child: const Icon(
                                  Icons.refresh_rounded,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: notificationController.isLoading
                            ? const Center(
                          child: CircularProgressIndicator(color: _primary),
                        )
                            : notifications.isEmpty
                            ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 54,
                                    color: _textSoft,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No hay notificaciones todavía',
                                    style: TextStyle(
                                      color: _textDark,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Cuando haya pedidos, cambios o eventos nuevos, aparecerán aquí.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _textSoft,
                                      fontSize: 12.8,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                            : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final item = notifications[index];
                            return _buildNotificationTile(item);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productController.errorMessage ?? 'Error al actualizar stock',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final notificationController = context.read<NotificationController>();
    final controller = context.read<UserController>();

    notificationController.stopPolling();
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
        await _goToOrders();
        break;
      case 3:
        await _goToSalesStats();
        break;
      case 4:
        await _goToCoins();
        break;
      case 5:
        await _goToProfile();
        break;
    }
  }

  Uint8List? _decodeImageBytes(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    try {
      final raw = value.trim();
      final normalized = raw.contains(',')
          ? raw.substring(raw.indexOf(',') + 1)
          : raw;

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

  Widget _buildUserAvatar({
    required String name,
    required String? image,
    double size = 58,
    double radius = 20,
    double fontSize = 22,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final bytes = _decodeImageBytes(image);

    if (_isNetworkImage(image)) {
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
          child: Image.network(
            image!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(
              initial: initial,
              size: size,
              radius: radius,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }

    if (bytes != null) {
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
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialAvatar(
              initial: initial,
              size: size,
              radius: radius,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }

    return _buildInitialAvatar(
      initial: initial,
      size: size,
      radius: radius,
      fontSize: fontSize,
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

  @override
  void dispose() {
    final notificationController = context.read<NotificationController>();
    notificationController.onNewNotification = null;
    notificationController.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final productController = context.watch<ProductController>();
    final coinController = context.watch<CoinMovementController>();
    final orderController = context.watch<OrderController>();
    final notificationController = context.watch<NotificationController>();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final isDesktop = screenWidth >= 1000;

    final products = productController.products;
    final orders = orderController.producerOrders;
    final notifications = notificationController.notifications;

    final recentProducts = _recentProducts(products).take(isMobile ? 4 : 6).toList();
    final recentOrders = _recentOrders(orders).take(isMobile ? 3 : 5).toList();
    final recentNotifications =
    notifications.take(isMobile ? 3 : 4).toList();

    final lowStockProducts = _lowStockProducts(products);
    final soldOutProducts = _soldOutProducts(products);

    final coinBalance = _dashboardCoinBalance(userController, coinController);
    final moneyReference = _dashboardMoneyReference(userController, coinController);

    final isLoading = productController.isLoading ||
        coinController.isLoading ||
        orderController.isLoading ||
        notificationController.isLoading ||
        _isRefreshing;

    final isInitialLoading = isLoading &&
        products.isEmpty &&
        orders.isEmpty &&
        _lastSyncedAt == null;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6EFE6),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFloatingPublishButton(isMobile),
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
              top: 120,
              right: -55,
              child: _buildDecorBubble(170, _gold.withOpacity(0.13)),
            ),
            Positioned(
              bottom: 140,
              left: -65,
              child: _buildDecorBubble(180, _green.withOpacity(0.07)),
            ),
            Positioned(
              bottom: -50,
              right: -20,
              child: _buildDecorBubble(130, _primaryDark.withOpacity(0.06)),
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
                        constraints: BoxConstraints(maxWidth: _maxWidth(screenWidth)),
                        child: Padding(
                          padding: _pagePadding(screenWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopHeader(
                                userController: userController,
                                products: products,
                                orders: orders,
                                coinBalance: coinBalance,
                                unreadCount: notificationController.unreadCount,
                                isLoading: isLoading,
                                isMobile: isMobile,
                              ),
                              const SizedBox(height: 18),
                              if (isInitialLoading)
                                _buildLoadingCard()
                              else ...[
                                _buildStoreHero(
                                  userController: userController,
                                  products: products,
                                  orders: orders,
                                  coinBalance: coinBalance,
                                  moneyReference: moneyReference,
                                  unreadCount: notificationController.unreadCount,
                                  isLoading: isLoading,
                                  isMobile: isMobile,
                                ),
                                const SizedBox(height: 18),
                                _buildWalletSection(
                                  coinBalance: coinBalance,
                                  moneyReference: moneyReference,
                                  products: products,
                                  orders: orders,
                                  isDesktop: isDesktop,
                                ),
                                const SizedBox(height: 18),
                                _buildQuickActionsSection(screenWidth),
                                const SizedBox(height: 18),
                                _buildNotificationsPreviewSection(
                                  unreadCount: notificationController.unreadCount,
                                  recentNotifications: recentNotifications,
                                ),
                                const SizedBox(height: 18),
                                _buildOrdersOverviewSection(
                                  screenWidth: screenWidth,
                                  orders: orders,
                                  recentOrders: recentOrders,
                                ),
                                const SizedBox(height: 18),
                                _buildResponsiveMiddleSection(
                                  screenWidth: screenWidth,
                                  products: products,
                                  moneyReference: moneyReference,
                                  lowStockProducts: lowStockProducts,
                                  soldOutProducts: soldOutProducts,
                                ),
                                const SizedBox(height: 18),
                                _buildRecentProductsSection(
                                  screenWidth: screenWidth,
                                  recentProducts: recentProducts,
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

  Widget _buildFloatingPublishButton(bool isMobile) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          backgroundColor: _primary,
          elevation: 10,
          onPressed: _goToCreateProduct,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FloatingActionButton.extended(
        backgroundColor: _primary,
        elevation: 10,
        onPressed: _goToCreateProduct,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Publicar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildDecorBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildTopHeader({
    required UserController userController,
    required List<ProductModel> products,
    required List<OrderModel> orders,
    required double coinBalance,
    required int unreadCount,
    required bool isLoading,
    required bool isMobile,
  }) {
    final user = userController.currentUser;
    final name = user?.name ?? 'Productor';
    final image = user?.image;
    final stockColor = _stockHealthColor(products);
    final stockText = _stockHealthLabel(products);

    final left = Row(
      children: [
        _buildUserAvatar(
          name: name,
          image: image,
          size: 60,
          radius: 20,
          fontSize: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mi tienda',
                style: TextStyle(
                  color: _textSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: stockColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$stockText · ${orders.length} pedidos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: stockColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final right = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
      children: [
        _buildCoinChip('${_coins(coinBalance)} mon.'),
        _buildOrderChip('${orders.length} pedidos'),
        _buildNotificationButton(unreadCount),
        _buildHeaderIconButton(
          icon: Icons.refresh_rounded,
          color: _primary,
          onTap: _loadDashboardData,
        ),
        _buildMenuButton(),
      ],
    );

    final syncText = _lastSyncedAt == null
        ? 'Sincronización pendiente'
        : 'Actualizado ${_formatHour(_lastSyncedAt)} · ${_formatDate(_lastSyncedAt)}${isLoading ? ' · actualizando' : ''}';

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          const SizedBox(height: 12),
          right,
          const SizedBox(height: 8),
          Text(
            syncText,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            right,
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            syncText,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoinChip(String value) {
    return InkWell(
      onTap: _goToCoins,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_outlined, size: 18, color: _primary),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: _textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderChip(String value) {
    return InkWell(
      onTap: _goToOrders,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_rounded, size: 18, color: _blue),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: _textDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationButton(int unreadCount) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _showNotificationsSheet,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(
                Icons.notifications_none_rounded,
                color: _primaryDark,
                size: 21,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
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
          color: _surface.withOpacity(0.96),
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
        icon: const Icon(Icons.more_horiz_rounded, color: _textDark, size: 20),
        color: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onSelected: (value) {
          if (value == 'notifications') {
            _showNotificationsSheet();
          } else if (value == 'reviews') {
            _goToReviews();
          } else if (value == 'refresh') {
            _loadDashboardData();
          } else if (value == 'logout') {
            _logout();
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem<String>(
            value: 'notifications',
            child: Row(
              children: [
                Icon(Icons.notifications_none_rounded, size: 18),
                SizedBox(width: 10),
                Text('Ver notificaciones'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'reviews',
            child: Row(
              children: [
                Icon(Icons.star_rounded, size: 18),
                SizedBox(width: 10),
                Text('Ver reseñas'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: 10),
                Text('Actualizar dashboard'),
              ],
            ),
          ),
          PopupMenuDivider(),
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
            'Estamos trayendo productos, monedas, pedidos y notificaciones.',
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

  Widget _buildStoreHero({
    required UserController userController,
    required List<ProductModel> products,
    required List<OrderModel> orders,
    required double coinBalance,
    required double moneyReference,
    required int unreadCount,
    required bool isLoading,
    required bool isMobile,
  }) {
    final user = userController.currentUser;
    final userName = user?.name ?? 'Productor';
    final stockText = _stockHealthLabel(products);
    final stockColor = _stockHealthColor(products);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A4A41), Color(0xFF443832), Color(0xFF302826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroTag(
                icon: Icons.storefront_outlined,
                text: '${products.length} productos',
              ),
              _buildHeroTag(
                icon: Icons.receipt_long_rounded,
                text: '${orders.length} pedidos',
              ),
              _buildHeroTag(
                icon: Icons.auto_graph_rounded,
                text: stockText,
              ),
              _buildHeroTag(
                icon: Icons.notifications_active_outlined,
                text: unreadCount > 0
                    ? '$unreadCount nuevas'
                    : 'Sin alertas nuevas',
              ),
              _buildHeroTag(
                icon: Icons.sync_rounded,
                text: isLoading ? 'Actualizando' : 'Sincronizado',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserAvatar(
                name: userName,
                image: user?.image,
                size: 64,
                radius: 22,
                fontSize: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu tienda lista para vender y gestionar pedidos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.04,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hola, $userName. Desde aquí puedes revisar productos, pedidos, monedas, reseñas y notificaciones en tiempo real.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 12.8,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          isMobile
              ? Column(
            children: [
              _buildHeroHighlightCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Monedas disponibles',
                value: '${_coins(coinBalance)} mon.',
              ),
              const SizedBox(height: 10),
              _buildHeroHighlightCard(
                icon: Icons.receipt_long_rounded,
                title: 'Pedidos pendientes',
                value: _pendingOrders(orders).toString(),
              ),
            ],
          )
              : Row(
            children: [
              Expanded(
                child: _buildHeroHighlightCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Monedas disponibles',
                  value: '${_coins(coinBalance)} mon.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroHighlightCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Pedidos pendientes',
                  value: _pendingOrders(orders).toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroMiniCard(
                title: 'Activos',
                value: _activeProducts(products).toString(),
              ),
              _buildHeroMiniCard(
                title: 'Pedidos',
                value: orders.length.toString(),
              ),
              _buildHeroMiniCard(
                title: 'Completados',
                value: _completedOrders(orders).toString(),
              ),
              _buildHeroMiniCard(
                title: 'Referencia',
                value: _money(moneyReference),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: stockColor.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: stockColor.withOpacity(0.24)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, color: stockColor, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estado general: $stockText · ${_pendingOrders(orders)} pendientes · ${_preparingOrders(orders)} en preparación · $unreadCount notificaciones sin leer',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.96),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          isMobile
              ? Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _goToOrders,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Ver pedidos'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _goToReviews,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _textDark,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Reseñas y calificaciones'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showNotificationsSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: const Text('Ver notificaciones'),
                ),
              ),
            ],
          )
              : Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _goToOrders,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Ver pedidos'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _goToReviews,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _textDark,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Ver reseñas'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _showNotificationsSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: const Text('Notificaciones'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTag({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
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

  Widget _buildHeroHighlightCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
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
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
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
      ),
    );
  }

  Widget _buildHeroMiniCard({required String title, required String value}) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
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
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
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

  Widget _buildWalletSection({
    required double coinBalance,
    required double moneyReference,
    required List<ProductModel> products,
    required List<OrderModel> orders,
    required bool isDesktop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monedas y operación',
          style: TextStyle(color: _textDark, fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Saldo, inventario y resumen de la operación diaria en una sola franja.',
          style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildWalletPrimaryCard(
                  coinBalance: coinBalance,
                  moneyReference: moneyReference,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildWalletMiniCard(
                      title: 'Inventario',
                      value: '${_money(_inventoryValue(products))} mon.',
                      icon: Icons.inventory_2_outlined,
                      color: _primaryDark,
                    ),
                    const SizedBox(height: 12),
                    _buildWalletMiniCard(
                      title: 'Promedio',
                      value: '${_money(_averagePrice(products))} mon.',
                      icon: Icons.payments_outlined,
                      color: _orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildWalletMiniCard(
                      title: 'Pedidos',
                      value: orders.length.toString(),
                      icon: Icons.receipt_long_rounded,
                      color: _blue,
                    ),
                    const SizedBox(height: 12),
                    _buildWalletMiniCard(
                      title: 'Facturado',
                      value: _bs(_managedAmount(orders)),
                      icon: Icons.auto_graph_rounded,
                      color: _gold,
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildWalletPrimaryCard(
                coinBalance: coinBalance,
                moneyReference: moneyReference,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildWalletMiniCard(
                      title: 'Inventario',
                      value: '${_money(_inventoryValue(products))} mon.',
                      icon: Icons.inventory_2_outlined,
                      color: _primaryDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWalletMiniCard(
                      title: 'Promedio',
                      value: '${_money(_averagePrice(products))} mon.',
                      icon: Icons.payments_outlined,
                      color: _orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildWalletMiniCard(
                      title: 'Pedidos',
                      value: orders.length.toString(),
                      icon: Icons.receipt_long_rounded,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWalletMiniCard(
                      title: 'Facturado',
                      value: _bs(_managedAmount(orders)),
                      icon: Icons.auto_graph_rounded,
                      color: _gold,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildWalletPrimaryCard({
    required double coinBalance,
    required double moneyReference,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3B76F), Color(0xFFC99659), Color(0xFFB88549)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Monedas disponibles',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_coins(coinBalance)} mon.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Referencia: ${_money(moneyReference)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontSize: 12.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _goToCoins,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _textDark,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                label: const Text('Ir a monedas'),
              ),
              FilledButton.icon(
                onPressed: _goToOrders,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.18),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('Ver pedidos'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
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
                  style: const TextStyle(color: _textDark, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(color: _textSoft, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(double screenWidth) {
    final items = [
      _ActionItem(
        title: 'Publicar',
        subtitle: 'Nuevo producto',
        icon: Icons.add_box_outlined,
        color: _primary,
        onTap: _goToCreateProduct,
      ),
      _ActionItem(
        title: 'Productos',
        subtitle: 'Gestionar catálogo',
        icon: Icons.storefront_outlined,
        color: _primaryDark,
        onTap: _goToProducts,
      ),
      _ActionItem(
        title: 'Pedidos',
        subtitle: 'Gestionar órdenes',
        icon: Icons.receipt_long_rounded,
        color: _blue,
        onTap: _goToOrders,
      ),
      _ActionItem(
        title: 'Monedas',
        subtitle: 'Saldo e historial',
        icon: Icons.account_balance_wallet_outlined,
        color: _gold,
        onTap: _goToCoins,
      ),
      _ActionItem(
        title: 'Perfil',
        subtitle: 'Tus datos',
        icon: Icons.person_outline_rounded,
        color: _green,
        onTap: _goToProfile,
      ),
      _ActionItem(
        title: 'Reseñas',
        subtitle: 'Opiniones y calificaciones',
        icon: Icons.star_rounded,
        color: _orange,
        onTap: _goToReviews,
      ),
      _ActionItem(
        title: 'Avisos',
        subtitle: 'Ver notificaciones',
        icon: Icons.notifications_outlined,
        color: _purple,
        onTap: _showNotificationsSheet,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accesos rápidos',
          style: TextStyle(color: _textDark, fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Módulos directos al estilo de una app moderna de pedidos.',
          style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _quickActionsCrossAxisCount(screenWidth),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: screenWidth < 500 ? 1.10 : 1.35,
          ),
          itemBuilder: (_, index) => _buildActionCard(items[index]),
        ),
      ],
    );
  }

  Widget _buildActionCard(_ActionItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => item.onTap(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _divider),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
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
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const Spacer(),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textDark, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              item.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textSoft, fontSize: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsPreviewSection({
    required int unreadCount,
    required List<NotificationModel> recentNotifications,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notificaciones',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Avisos nuevos del sistema para revisarlos rápido.',
                      style: TextStyle(
                        color: _textSoft,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showNotificationsSheet,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Abrir'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTinyStatusChip('$unreadCount sin leer', unreadCount > 0 ? _red : _green),
              const SizedBox(width: 8),
              _buildTinyStatusChip('Tiempo real activo', _blue),
            ],
          ),
          const SizedBox(height: 14),
          if (recentNotifications.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surfaceSoft,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _divider),
              ),
              child: const Row(
                children: [
                  Icon(Icons.notifications_none_rounded, color: _textSoft),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Todavía no hay notificaciones para mostrar.',
                      style: TextStyle(
                        color: _textSoft,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...recentNotifications.map(_buildNotificationPreviewCard),
        ],
      ),
    );
  }

  Widget _buildNotificationPreviewCard(NotificationModel item) {
    final color = _notificationTypeColor(item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isRead ? _surfaceSoft : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isRead ? _divider : color.withOpacity(0.24),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (!item.isRead && item.id != null) {
            await context.read<NotificationController>().markAsRead(item.id!);
          }
          if (!mounted) return;
          await _showNotificationsSheet();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(_notificationTypeIcon(item.type), color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: _red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 12.2,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSoftInfoChip(
                          icon: _notificationTypeIcon(item.type),
                          text: _notificationTypeLabel(item.type),
                        ),
                        _buildSoftInfoChip(
                          icon: Icons.schedule_rounded,
                          text: _formatDateTime(item.createdAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersOverviewSection({
    required double screenWidth,
    required List<OrderModel> orders,
    required List<OrderModel> recentOrders,
  }) {
    final metrics = [
      _MetricItem(
        label: 'Pedidos',
        value: orders.length.toString(),
        icon: Icons.receipt_long_rounded,
        color: _blue,
      ),
      _MetricItem(
        label: 'Pendientes',
        value: _pendingOrders(orders).toString(),
        icon: Icons.schedule_rounded,
        color: _orange,
      ),
      _MetricItem(
        label: 'En preparación',
        value: _preparingOrders(orders).toString(),
        icon: Icons.inventory_2_rounded,
        color: _blue,
      ),
      _MetricItem(
        label: 'Enviados',
        value: _shippedOrders(orders).toString(),
        icon: Icons.local_shipping_rounded,
        color: _purple,
      ),
      _MetricItem(
        label: 'Completados',
        value: _completedOrders(orders).toString(),
        icon: Icons.check_circle_rounded,
        color: _green,
      ),
      _MetricItem(
        label: 'Cancelados',
        value: _cancelledOrders(orders).toString(),
        icon: Icons.cancel_rounded,
        color: _red,
      ),
      _MetricItem(
        label: 'Gestionado',
        value: _bs(_managedAmount(orders)),
        icon: Icons.payments_rounded,
        color: _gold,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedidos conectados al dashboard',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Resumen rápido de órdenes para saltar directo a la ventana de pedidos.',
                      style: TextStyle(
                        color: _textSoft,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _goToOrders,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Abrir pedidos'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: metrics.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _orderMetricCrossAxisCount(screenWidth),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: screenWidth < 500 ? 1.15 : 1.35,
            ),
            itemBuilder: (_, index) => _buildMetricCard(metrics[index]),
          ),
          const SizedBox(height: 14),
          if (screenWidth >= 950)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildOrdersHighlightCard(orders)),
                const SizedBox(width: 12),
                Expanded(child: _buildRecentOrdersCard(recentOrders)),
              ],
            )
          else
            Column(
              children: [
                _buildOrdersHighlightCard(orders),
                const SizedBox(height: 12),
                _buildRecentOrdersCard(recentOrders),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrdersHighlightCard(List<OrderModel> orders) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping_outlined, color: _primaryDark, size: 20),
              SizedBox(width: 8),
              Text(
                'Ritmo de pedidos',
                style: TextStyle(color: _textDark, fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMiniStatPanel(
                  title: 'Ticket prom.',
                  value: _bs(_averageTicket(orders)),
                  color: _gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatPanel(
                  title: 'Completado',
                  value: _bs(_completedAmount(orders)),
                  color: _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMiniStatPanel(
                  title: 'Cancelados',
                  value: _cancelledOrders(orders).toString(),
                  color: _red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStatPanel(
                  title: 'Por atender',
                  value: _pendingOrders(orders).toString(),
                  color: _orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _goToOrders,
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Gestionar pedidos'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatPanel({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: _textSoft, fontSize: 11.8, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersCard(List<OrderModel> recentOrders) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_send_rounded, color: _blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Pedidos recientes',
                style: TextStyle(color: _textDark, fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentOrders.isEmpty)
            const Text(
              'Aún no hay pedidos registrados para mostrar aquí.',
              style: TextStyle(color: _textSoft, fontSize: 12.8, height: 1.4),
            )
          else
            ...recentOrders.map(
                  (order) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _orderStatusColor(order.state).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _orderStatusIcon(order.state),
                        color: _orderStatusColor(order.state),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido #${order.id ?? '-'}',
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_orderStatusText(order.state)} · ${_bs(order.amount)}',
                            style: const TextStyle(
                              color: _textSoft,
                              fontSize: 12.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(order.registerDate),
                            style: const TextStyle(
                              color: _textSoft,
                              fontSize: 11.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _goToOrders,
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: _textSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResponsiveMiddleSection({
    required double screenWidth,
    required List<ProductModel> products,
    required double moneyReference,
    required List<ProductModel> lowStockProducts,
    required List<ProductModel> soldOutProducts,
  }) {
    final left = _buildOverviewPanel(
      screenWidth: screenWidth,
      products: products,
      moneyReference: moneyReference,
    );

    final right = _buildAlertsPanel(
      lowStockProducts: lowStockProducts,
      soldOutProducts: soldOutProducts,
    );

    if (screenWidth >= 1100) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: left),
          const SizedBox(width: 14),
          Expanded(flex: 5, child: right),
        ],
      );
    }

    return Column(
      children: [
        left,
        const SizedBox(height: 18),
        right,
      ],
    );
  }

  Widget _buildOverviewPanel({
    required double screenWidth,
    required List<ProductModel> products,
    required double moneyReference,
  }) {
    final metrics = [
      _MetricItem(
        label: 'Productos',
        value: products.length.toString(),
        icon: Icons.inventory_2_outlined,
        color: _primary,
      ),
      _MetricItem(
        label: 'Activos',
        value: _activeProducts(products).toString(),
        icon: Icons.check_circle_outline,
        color: _green,
      ),
      _MetricItem(
        label: 'Pausados',
        value: _pausedProducts(products).toString(),
        icon: Icons.pause_circle_outline_rounded,
        color: _purple,
      ),
      _MetricItem(
        label: 'Promedio',
        value: '${_money(_averagePrice(products))} mon.',
        icon: Icons.payments_outlined,
        color: _orange,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen operativo',
            style: TextStyle(color: _textDark, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Más visual, más legible y mejor adaptado a móvil y web.',
            style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: metrics.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _metricCrossAxisCount(screenWidth),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: screenWidth < 450 ? 1.15 : 1.35,
            ),
            itemBuilder: (_, index) => _buildMetricCard(metrics[index]),
          ),
          const SizedBox(height: 14),
          _buildAvailabilityCard(products, moneyReference),
        ],
      ),
    );
  }

  Widget _buildMetricCard(_MetricItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 20, color: item.color),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textDark, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: const TextStyle(color: _textSoft, fontSize: 11.8, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(List<ProductModel> products, double moneyReference) {
    final availability = _availabilityPercent(products).clamp(0.0, 1.0);
    final healthColor = _stockHealthColor(products);
    final healthLabel = _stockHealthLabel(products);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceMuted,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, color: healthColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estado general: $healthLabel',
                  style: TextStyle(color: healthColor, fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Disponibilidad del catálogo',
            style: TextStyle(color: _textDark, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: availability,
              minHeight: 12,
              backgroundColor: const Color(0xFFE8DCCB),
              valueColor: const AlwaysStoppedAnimation(_primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_activeProducts(products)} activos',
                  style: const TextStyle(color: _textSoft, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${(availability * 100).round()}%',
                style: const TextStyle(color: _primaryDark, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                '${products.length} total',
                style: const TextStyle(color: _textSoft, fontSize: 12, fontWeight: FontWeight.w600),
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
                const Icon(Icons.attach_money_rounded, color: _primaryDark, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Referencia del saldo: ${_money(moneyReference)}',
                    style: const TextStyle(color: _textSoft, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsPanel({
    required List<ProductModel> lowStockProducts,
    required List<ProductModel> soldOutProducts,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Atención inmediata',
            style: TextStyle(color: _textDark, fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lo urgente primero, como en una app operativa de verdad.',
            style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (lowStockProducts.isEmpty && soldOutProducts.isEmpty)
            _buildEmptyAlerts()
          else
            Column(
              children: [
                if (soldOutProducts.isNotEmpty)
                  ...soldOutProducts.take(2).map(
                        (product) => _buildAlertCard(
                      product: product,
                      title: 'Producto agotado',
                      subtitle: 'Ya no tienes stock disponible.',
                      color: _red,
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
                      subtitle: 'Solo quedan ${product.stock} unidades.',
                      color: _orange,
                      icon: Icons.warning_amber_rounded,
                      buttonText: 'Reponer',
                      onTap: () => _replenishProduct(product),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyAlerts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: _green,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Todo en orden',
            style: TextStyle(color: _textDark, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'No hay productos con stock bajo ni agotados en este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required ProductModel product,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required String buttonText,
    required Future<void> Function() onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              _buildStatusBadge(_productStatusText(product), color),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textDark, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: const TextStyle(color: _textSoft, fontSize: 12.5, height: 1.35),
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
                icon: Icons.event_outlined,
                text: _formatDate(product.harvestDate),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => onTap(),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(buttonText),
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
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

  Widget _buildSoftInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _textSoft),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildRecentProductsSection({
    required double screenWidth,
    required List<ProductModel> recentProducts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Productos recientes',
          style: TextStyle(color: _textDark, fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Una vista más linda y más cercana al estilo del dashboard del cliente.',
          style: TextStyle(color: _textSoft, fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (recentProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface.withOpacity(0.98),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _border),
            ),
            child: const Column(
              children: [
                Icon(Icons.storefront_outlined, size: 52, color: _textSoft),
                SizedBox(height: 12),
                Text(
                  'Todavía no publicaste productos',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Publica tu primer producto para verlo aquí con un diseño más visual.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSoft,
                    fontSize: 12.8,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            itemCount: recentProducts.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _productGridCount(screenWidth),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: screenWidth >= 850 ? 1.10 : 0.96,
            ),
            itemBuilder: (_, index) => _buildProductCard(recentProducts[index]),
          ),
      ],
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final statusColor = _productStatusColor(product);
    final bytes = _decodeImageBytes(product.picture);

    return Container(
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _goToProducts,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surfaceMuted,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: _isNetworkImage(product.picture)
                      ? Image.network(
                    product.picture!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildProductImagePlaceholder(),
                  )
                      : bytes != null
                      ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildProductImagePlaceholder(),
                  )
                      : _buildProductImagePlaceholder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                      _buildStatusBadge(_productStatusText(product), statusColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _harvestLabel(product.harvestDate),
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSoftInfoChip(
                        icon: Icons.payments_outlined,
                        text: '${_money(product.price)} mon.',
                      ),
                      _buildSoftInfoChip(
                        icon: Icons.scale_outlined,
                        text: product.unit ?? 'unidad',
                      ),
                      _buildSoftInfoChip(
                        icon: Icons.inventory_2_outlined,
                        text: 'Stock ${product.stock}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
          size: 52,
          color: _primaryDark,
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel item) {
    final color = _notificationTypeColor(item.type);

    return Container(
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: item.isRead ? _border : color.withOpacity(0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(_notificationTypeIcon(item.type), color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: _red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSoftInfoChip(
                        icon: _notificationTypeIcon(item.type),
                        text: _notificationTypeLabel(item.type),
                      ),
                      _buildSoftInfoChip(
                        icon: Icons.schedule_rounded,
                        text: _formatDateTime(item.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!item.isRead && item.id != null)
                        FilledButton.icon(
                          onPressed: () async {
                            await context.read<NotificationController>().markAsRead(item.id!);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.done_rounded, size: 18),
                          label: const Text('Marcar leída'),
                        ),
                      if (item.id != null)
                        OutlinedButton.icon(
                          onPressed: () async {
                            await context.read<NotificationController>().deleteNotification(item.id!);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: BorderSide(color: _red.withOpacity(0.25)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Eliminar'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            border: Border(
              top: BorderSide(color: _border.withOpacity(0.85)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_customize_outlined,
                  label: 'Inicio',
                  selected: true,
                  onTap: () => _onBottomNavigationTap(0),
                ),
                _buildNavItem(
                  icon: Icons.storefront_outlined,
                  label: 'Productos',
                  onTap: () => _onBottomNavigationTap(1),
                ),
                _buildNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Pedidos',
                  onTap: () => _onBottomNavigationTap(2),
                ),
                const SizedBox(width: 40),
                _buildNavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Ventas',
                  onTap: () => _onBottomNavigationTap(3),
                ),
                _buildNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Monedas',
                  onTap: () => _onBottomNavigationTap(4),
                ),
                _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Perfil',
                  onTap: () => _onBottomNavigationTap(5),
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
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final color = selected ? _primary : _textSoft;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.2,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _MetricItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}