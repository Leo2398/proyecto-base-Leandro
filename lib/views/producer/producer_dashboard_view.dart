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
import 'producer_sales_history_view.dart';
import 'producer_sales_stats_view.dart';

class ProducerDashboardView extends StatefulWidget {
  const ProducerDashboardView({super.key});

  @override
  State<ProducerDashboardView> createState() => _ProducerDashboardViewState();
}

class _ProducerDashboardViewState extends State<ProducerDashboardView> {
  // ─── Paleta de colores (mantenida) ─────────────────────────────────────────
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

  // ─── Estados de pedidos ────────────────────────────────────────────────────
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

  @override
  void dispose() {
    final notificationController = context.read<NotificationController>();
    notificationController.onNewNotification = null;
    notificationController.stopPolling();
    super.dispose();
  }

  // ─── Inicialización ────────────────────────────────────────────────────────
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
          content: Row(
            children: [
              Icon(_notificationTypeIcon(notification.type),
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: _primaryDark,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    };

    await notificationController.startPolling(
      userId: currentUser.id!,
      interval: const Duration(seconds: 5),
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
      if (currentUser == null ||
          currentUser.id == null ||
          currentUser.id! <= 0) {
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

  // ─── Helpers de datos ──────────────────────────────────────────────────────
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
    return products
        .where((p) => p.state == 1 && p.stock > 0 && p.stock <= 3)
        .toList();
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
    final completed =
    orders.where((o) => o.state == _stateCompleted).toList();
    if (completed.isEmpty) return 0;
    final total = completed.fold(0.0, (sum, order) => sum + order.amount);
    return total / completed.length;
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

  // ─── Helpers de formato ────────────────────────────────────────────────────

  /// Formatea un valor de monedas
  String _coins(double value) {
    if (value == value.truncateToDouble()) {
      return '${value.toStringAsFixed(0)} mon.';
    }
    return '${value.toStringAsFixed(2)} mon.';
  }

  /// Formatea un valor de monedas SIN el sufijo (para títulos grandes)
  String _coinsNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
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

  // ─── Navegación ────────────────────────────────────────────────────────────
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
        SnackBar(
          content: const Text('Producto publicado correctamente'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Future<void> _goToSalesStats() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProducerSalesStatsView()),
    );
    if (!mounted) return;
    await _loadDashboardData();
  }

  Future<void> _goToSalesHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProducerSalesHistoryView()),
    );
    if (!mounted) return;
    await _loadDashboardData();
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _textDark),
        ),
        content: const Text(
          'Tendrás que volver a iniciar sesión para acceder a tu tienda.',
          style: TextStyle(color: _textSoft, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _textSoft)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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

  // ─── Sheet de notificaciones ───────────────────────────────────────────────
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
              initialChildSize: 0.78,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F2EA),
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
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
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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
                                  await notificationController
                                      .markAllAsRead(userId);
                                },
                                icon: const Icon(Icons.done_all_rounded,
                                    size: 18),
                                label: const Text('Marcar todas'),
                                style: TextButton.styleFrom(
                                    foregroundColor: _primary),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                        child: Row(
                          children: [
                            _buildTinyStatusChip(
                              '${notificationController.unreadCount} sin leer',
                              notificationController.unreadCount > 0
                                  ? _red
                                  : _green,
                            ),
                            const SizedBox(width: 8),
                            _buildTinyStatusChip(
                              '${notifications.length} en total',
                              _blue,
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                if (userId != null && userId > 0) {
                                  await notificationController.refresh(
                                      userId: userId);
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
                                child: const Icon(Icons.refresh_rounded,
                                    color: _primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: notificationController.isLoading &&
                            notifications.isEmpty
                            ? const Center(
                          child: CircularProgressIndicator(
                              color: _primary),
                        )
                            : notifications.isEmpty
                            ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(
                              20, 10, 20, 30),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(24),
                                border:
                                Border.all(color: _border),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 56,
                                    color: _textSoft,
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'Todo tranquilo por aquí',
                                    style: TextStyle(
                                      color: _textDark,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Cuando llegue un pedido nuevo o cambie algo importante, te avisaremos aquí.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _textSoft,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                            : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(
                              20, 8, 20, 30),
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

  // ─── Sheet del menú de perfil ──────────────────────────────────────────────
  Future<void> _showProfileMenu() async {
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
                  // Cabecera de usuario
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
                  // Lista de opciones del perfil
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        _profileMenuItem(
                          icon: Icons.person_outline_rounded,
                          color: _primary,
                          title: 'Mi perfil',
                          subtitle: 'Datos, ubicación y horarios',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToProfile();
                          },
                        ),
                        _profileDivider(),
                        _profileMenuItem(
                          icon: Icons.bar_chart_rounded,
                          color: _blue,
                          title: 'Estadísticas',
                          subtitle: 'Métricas y rendimiento de ventas',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToSalesStats();
                          },
                        ),
                        _profileDivider(),
                        _profileMenuItem(
                          icon: Icons.history_rounded,
                          color: _purple,
                          title: 'Historial de ventas',
                          subtitle: 'Registro completo de pedidos',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToSalesHistory();
                          },
                        ),
                        _profileDivider(),
                        _profileMenuItem(
                          icon: Icons.star_rounded,
                          color: _orange,
                          title: 'Reseñas',
                          subtitle: 'Lo que opinan tus clientes',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToReviews();
                          },
                        ),
                        _profileDivider(),
                        _profileMenuItem(
                          icon: Icons.account_balance_wallet_outlined,
                          color: _gold,
                          title: 'Mis monedas',
                          subtitle: 'Saldo, recargas e historial',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToCoins();
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
                    child: Column(
                      children: [
                        _profileMenuItem(
                          icon: Icons.refresh_rounded,
                          color: _green,
                          title: 'Actualizar dashboard',
                          subtitle: 'Sincroniza todo con la base de datos',
                          onTap: () {
                            Navigator.pop(ctx);
                            _loadDashboardData();
                          },
                        ),
                        _profileDivider(),
                        _profileMenuItem(
                          icon: Icons.logout_rounded,
                          color: _red,
                          title: 'Cerrar sesión',
                          subtitle: 'Salir de tu cuenta',
                          onTap: () {
                            Navigator.pop(ctx);
                            _logout();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _profileMenuItem({
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
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _textSoft),
          ],
        ),
      ),
    );
  }

  Widget _profileDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Divider(height: 1, thickness: 1, color: _divider),
    );
  }

  // ─── Acción rápida en producto ─────────────────────────────────────────────
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
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
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
              borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  // ─── Avatar del usuario ────────────────────────────────────────────────────
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

  // ─── Layout helpers ────────────────────────────────────────────────────────
  EdgeInsets _pagePadding(double width) {
    if (width >= 1200) return const EdgeInsets.fromLTRB(28, 16, 28, 130);
    if (width >= 800) return const EdgeInsets.fromLTRB(20, 14, 20, 130);
    return const EdgeInsets.fromLTRB(16, 12, 16, 130);
  }

  double _maxWidth(double width) {
    if (width >= 1600) return 1380;
    if (width >= 1300) return 1180;
    if (width >= 1000) return 980;
    return width;
  }

  int _quickActionsCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 760) return 4;
    return 4;
  }

  int _productGridCount(double width) {
    if (width >= 1300) return 3;
    if (width >= 850) return 2;
    return 1;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════
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

    final recentProducts =
    _recentProducts(products).take(isMobile ? 4 : 6).toList();
    final recentOrders = _recentOrders(orders).take(isMobile ? 3 : 5).toList();
    final recentNotifications =
    notifications.take(isMobile ? 3 : 4).toList();

    final lowStockProducts = _lowStockProducts(products);
    final soldOutProducts = _soldOutProducts(products);

    final coinBalance = _dashboardCoinBalance(userController, coinController);

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
            // Burbujas decorativas
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
                        constraints:
                        BoxConstraints(maxWidth: _maxWidth(screenWidth)),
                        child: Padding(
                          padding: _pagePadding(screenWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header simple con avatar + saludo
                              _buildAppBar(
                                userController: userController,
                                unreadCount:
                                notificationController.unreadCount,
                                isLoading: isLoading,
                              ),
                              const SizedBox(height: 18),

                              if (isInitialLoading)
                                _buildLoadingCard()
                              else ...[
                                // Tarjeta principal de billetera
                                _buildWalletCard(
                                  coinBalance: coinBalance,
                                  pendingOrders: _pendingOrders(orders),
                                  totalOrders: orders.length,
                                ),
                                const SizedBox(height: 20),

                                // Accesos rápidos (2x2 / 4 cols)
                                _buildQuickActions(screenWidth),
                                const SizedBox(height: 20),

                                // Estado del negocio
                                _buildBusinessStatus(
                                  products: products,
                                  orders: orders,
                                  isDesktop: isDesktop,
                                ),
                                const SizedBox(height: 20),

                                // Pedidos recientes
                                _buildOrdersSection(
                                  orders: orders,
                                  recentOrders: recentOrders,
                                ),
                                const SizedBox(height: 20),

                                // Alertas de stock
                                if (lowStockProducts.isNotEmpty ||
                                    soldOutProducts.isNotEmpty) ...[
                                  _buildAlertsSection(
                                    lowStockProducts: lowStockProducts,
                                    soldOutProducts: soldOutProducts,
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Notificaciones recientes
                                _buildNotificationsPreview(
                                  unreadCount:
                                  notificationController.unreadCount,
                                  recentNotifications: recentNotifications,
                                ),
                                const SizedBox(height: 20),

                                // Productos recientes
                                _buildRecentProductsSection(
                                  screenWidth: screenWidth,
                                  recentProducts: recentProducts,
                                  totalProducts: products.length,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar({
    required UserController userController,
    required int unreadCount,
    required bool isLoading,
  }) {
    final user = userController.currentUser;
    final name = user?.name ?? 'Productor';
    final firstName = name.split(' ').first;
    final image = user?.image;

    return Row(
      children: [
        // Avatar tappable que abre menú de perfil
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showProfileMenu,
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
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        // Botón sincronización
        _buildAppBarIconButton(
          icon: isLoading ? Icons.sync_rounded : Icons.refresh_rounded,
          color: _primary,
          onTap: () => _loadDashboardData(),
        ),
        const SizedBox(width: 8),
        // Botón notificaciones con badge
        _buildAppBarNotificationButton(unreadCount),
        const SizedBox(width: 8),
        // Botón menú perfil
        _buildAppBarIconButton(
          icon: Icons.menu_rounded,
          color: _primaryDark,
          onTap: () => _showProfileMenu(),
        ),
      ],
    );
  }

  Widget _buildAppBarIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
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

  Widget _buildAppBarNotificationButton(int unreadCount) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _showNotificationsSheet,
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
                right: 6,
                top: 6,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: TARJETA DE BILLETERA (HERO)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWalletCard({
    required double coinBalance,
    required int pendingOrders,
    required int totalOrders,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: _goToCoins,
      child: Container(
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
            // Decoración circular
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
              right: 20,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_rounded,
                              size: 14, color: _gold),
                          SizedBox(width: 6),
                          Text(
                            'Mi billetera',
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
                      _coinsNumber(coinBalance),
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
                        'monedas',
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
                  'Saldo disponible para publicar productos',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _walletStatBox(
                        label: 'Pedidos pendientes',
                        value: pendingOrders.toString(),
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _walletStatBox(
                        label: 'Total pedidos',
                        value: totalOrders.toString(),
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletStatBox({
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: ACCESOS RÁPIDOS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickActions(double screenWidth) {
    final actions = [
      _ActionItem(
        title: 'Pedidos',
        icon: Icons.receipt_long_rounded,
        color: _blue,
        onTap: _goToOrders,
      ),
      _ActionItem(
        title: 'Productos',
        icon: Icons.storefront_outlined,
        color: _primaryDark,
        onTap: _goToProducts,
      ),
      _ActionItem(
        title: 'Estadísticas',
        icon: Icons.bar_chart_rounded,
        color: _green,
        onTap: _goToSalesStats,
      ),
      _ActionItem(
        title: 'Reseñas',
        icon: Icons.star_rounded,
        color: _orange,
        onTap: _goToReviews,
      ),
    ];

    final int crossAxisCount = screenWidth < 600 ? 2 : 4;
    final double cardHeight = screenWidth < 600 ? 118 : 110;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Accesos rápidos',
            style: TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (_, index) => _buildQuickActionCard(actions[index]),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(_ActionItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => item.onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _divider),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: ESTADO DEL NEGOCIO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBusinessStatus({
    required List<ProductModel> products,
    required List<OrderModel> orders,
    required bool isDesktop,
  }) {
    final stockColor = _stockHealthColor(products);
    final stockLabel = _stockHealthLabel(products);
    final availability = _availabilityPercent(products);

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
                  color: stockColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insights_rounded, color: stockColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Estado de tu negocio',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildTinyStatusChip(stockLabel, stockColor),
            ],
          ),
          const SizedBox(height: 16),
          // Métricas en fila
          Row(
            children: [
              Expanded(
                child: _statusMiniCard(
                  label: 'Productos',
                  value: products.length.toString(),
                  detail: '${_activeProducts(products)} activos',
                  icon: Icons.inventory_2_outlined,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusMiniCard(
                  label: 'Inventario',
                  value: _coinsNumber(_inventoryValue(products)),
                  detail: 'monedas en valor',
                  icon: Icons.payments_outlined,
                  color: _gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statusMiniCard(
                  label: 'Facturado',
                  value: _coinsNumber(_managedAmount(orders)),
                  detail: 'monedas gestionadas',
                  icon: Icons.auto_graph_rounded,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusMiniCard(
                  label: 'Completado',
                  value: _coinsNumber(_completedAmount(orders)),
                  detail: 'monedas cobradas',
                  icon: Icons.check_circle_outline_rounded,
                  color: _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barra de disponibilidad
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
                  '${_activeProducts(products)} activos · ${_pausedProducts(products)} pausados · ${products.length} total',
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

  Widget _statusMiniCard({
    required String label,
    required String value,
    required String detail,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
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
            detail,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: PEDIDOS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOrdersSection({
    required List<OrderModel> orders,
    required List<OrderModel> recentOrders,
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
                child: const Icon(Icons.receipt_long_rounded,
                    color: _blue, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pedidos recientes',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _goToOrders,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text(
                  'Ver todos',
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
          const SizedBox(height: 12),
          // Chips de estados
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _orderStateChip(
                  count: _pendingOrders(orders),
                  label: 'Pendientes',
                  color: _orange,
                ),
                const SizedBox(width: 8),
                _orderStateChip(
                  count: _preparingOrders(orders),
                  label: 'Preparando',
                  color: _blue,
                ),
                const SizedBox(width: 8),
                _orderStateChip(
                  count: _shippedOrders(orders),
                  label: 'Enviados',
                  color: _purple,
                ),
                const SizedBox(width: 8),
                _orderStateChip(
                  count: _completedOrders(orders),
                  label: 'Completados',
                  color: _green,
                ),
                const SizedBox(width: 8),
                _orderStateChip(
                  count: _cancelledOrders(orders),
                  label: 'Cancelados',
                  color: _red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Lista de recientes
          if (recentOrders.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _divider),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 44, color: _textSoft),
                  SizedBox(height: 10),
                  Text(
                    'Aún no hay pedidos',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Cuando un cliente te haga un pedido, aparecerá aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 12.3,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: recentOrders.map(_buildOrderTile).toList(),
            ),
          const SizedBox(height: 6),
          if (orders.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _goToSalesStats,
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    label: const Text('Ver estadísticas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryDark,
                      side: const BorderSide(color: _border),
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
                    onPressed: _goToOrders,
                    icon: const Icon(Icons.inbox_rounded, size: 18),
                    label: const Text('Gestionar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
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
    );
  }

  Widget _orderStateChip({
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(OrderModel order) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _goToOrders,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _orderStatusColor(order.state).withOpacity(0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _orderStatusIcon(order.state),
                color: _orderStatusColor(order.state),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Pedido #${order.id ?? '-'}',
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                          _orderStatusColor(order.state).withOpacity(0.13),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _orderStatusText(order.state),
                          style: TextStyle(
                            color: _orderStatusColor(order.state),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(order.registerDate),
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _coinsNumber(order.amount),
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'monedas',
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
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: ALERTAS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAlertsSection({
    required List<ProductModel> lowStockProducts,
    required List<ProductModel> soldOutProducts,
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
                  color: _orange.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: _orange, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Atención requerida',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildTinyStatusChip(
                '${lowStockProducts.length + soldOutProducts.length} alertas',
                _orange,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...soldOutProducts.take(2).map(
                (product) => _buildAlertCard(
              product: product,
              title: 'Producto agotado',
              subtitle: 'Sin stock disponible.',
              color: _red,
              icon: Icons.remove_shopping_cart_outlined,
              buttonText: 'Reponer stock',
              onTap: () => _replenishProduct(product),
            ),
          ),
          ...lowStockProducts.take(3).map(
                (product) => _buildAlertCard(
              product: product,
              title: 'Stock bajo',
              subtitle: 'Quedan ${product.stock} unidades.',
              color: _orange,
              icon: Icons.warning_amber_rounded,
              buttonText: 'Sumar 10 al stock',
              onTap: () => _replenishProduct(product),
            ),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(18),
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
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$title · $subtitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onTap(),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(buttonText),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: NOTIFICACIONES PREVIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNotificationsPreview({
    required int unreadCount,
    required List<NotificationModel> recentNotifications,
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
                  color: _purple.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_rounded,
                    color: _purple, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Notificaciones',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (unreadCount > 0)
                _buildTinyStatusChip('$unreadCount nuevas', _red),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _showNotificationsSheet,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text(
                  'Abrir',
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
          if (recentNotifications.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _divider),
              ),
              child: const Column(
                children: [
                  Icon(Icons.notifications_none_rounded,
                      size: 44, color: _textSoft),
                  SizedBox(height: 10),
                  Text(
                    'Sin notificaciones',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Aquí aparecerán los avisos del sistema y tus pedidos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 12.3,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children:
              recentNotifications.map(_buildNotificationPreviewCard).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreviewCard(NotificationModel item) {
    final color = _notificationTypeColor(item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isRead ? _surfaceSoft : color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isRead ? _divider : color.withOpacity(0.20),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          if (!item.isRead && item.id != null) {
            await context.read<NotificationController>().markAsRead(item.id!);
          }
          if (!mounted) return;
          await _showNotificationsSheet();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_notificationTypeIcon(item.type),
                    color: color, size: 20),
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
                              fontSize: 14,
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
                    const SizedBox(height: 3),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 11.8,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatDateTime(item.createdAt),
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
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: PRODUCTOS RECIENTES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRecentProductsSection({
    required double screenWidth,
    required List<ProductModel> recentProducts,
    required int totalProducts,
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
                child: const Icon(Icons.storefront_rounded,
                    color: _primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Mis productos',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (totalProducts > 0)
                _buildTinyStatusChip('$totalProducts en total', _primary),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _goToProducts,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text(
                  'Ver',
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
          if (recentProducts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
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
                    child: const Icon(
                      Icons.add_business_outlined,
                      size: 32,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '¡Empieza a vender!',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Publica tu primer producto y empieza a recibir pedidos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _goToCreateProduct,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Publicar producto'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
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
              itemBuilder: (_, index) =>
                  _buildProductCard(recentProducts[index]),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final statusColor = _productStatusColor(product);
    final bytes = _decodeImageBytes(product.picture);

    return Container(
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _goToProducts,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surfaceMuted,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22)),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22)),
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: _isNetworkImage(product.picture)
                            ? Image.network(
                          product.picture!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildProductImagePlaceholder(),
                        )
                            : bytes != null
                            ? Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildProductImagePlaceholder(),
                        )
                            : _buildProductImagePlaceholder(),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _productStatusText(product),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
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
                    _harvestLabel(product.harvestDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _coinsNumber(product.price),
                              style: const TextStyle(
                                color: _primaryDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'monedas / ${product.unit ?? "unidad"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textSoft,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 12, color: _textSoft),
                            const SizedBox(width: 4),
                            Text(
                              product.stock.toString(),
                              style: const TextStyle(
                                color: _textDark,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
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
          size: 46,
          color: _primaryDark,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: TILE DE NOTIFICACIONES (PARA EL SHEET)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNotificationTile(NotificationModel item) {
    final color = _notificationTypeColor(item.type);

    return Container(
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isRead ? _border : color.withOpacity(0.20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_notificationTypeIcon(item.type),
                  color: color, size: 21),
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
                            fontSize: 14.5,
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _notificationTypeLabel(item.type),
                          style: TextStyle(
                            color: color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        _formatDateTime(item.createdAt),
                        style: const TextStyle(
                          color: _textSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!item.isRead && item.id != null)
                        FilledButton.icon(
                          onPressed: () async {
                            await context
                                .read<NotificationController>()
                                .markAsRead(item.id!);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.done_rounded, size: 16),
                          label: const Text('Marcar leída',
                              style: TextStyle(fontSize: 12)),
                        ),
                      if (item.id != null)
                        OutlinedButton.icon(
                          onPressed: () async {
                            await context
                                .read<NotificationController>()
                                .deleteNotification(item.id!);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _red,
                            side: BorderSide(
                                color: _red.withOpacity(0.25)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16),
                          label: const Text('Eliminar',
                              style: TextStyle(fontSize: 12)),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: LOADING CARD
  // ═══════════════════════════════════════════════════════════════════════════
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
            'Cargando dashboard...',
            style: TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos sincronizando productos, pedidos y monedas.',
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

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTONES Y ELEMENTOS COMUNES
  // ═══════════════════════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════════════════════
  // FAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFloatingPublishButton(bool isMobile) {
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
          onPressed: _goToCreateProduct,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION BAR
  // ═══════════════════════════════════════════════════════════════════════════
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
                  selected: true,
                  onTap: () => _loadDashboardData(),
                ),
                _buildNavItem(
                  icon: Icons.storefront_outlined,
                  label: 'Productos',
                  onTap: _goToProducts,
                ),
                const SizedBox(width: 56), // espacio para el FAB
                _buildNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Pedidos',
                  onTap: _goToOrders,
                ),
                _buildNavItem(
                  icon: Icons.menu_rounded,
                  label: 'Más',
                  onTap: _showProfileMenu,
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

class _ActionItem {
  final String title;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  const _ActionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}