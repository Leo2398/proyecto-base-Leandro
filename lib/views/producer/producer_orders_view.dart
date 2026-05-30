import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/order_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order_detail_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import 'producer_coins_view.dart';
import 'producer_create_product_view.dart';
import 'producer_dashboard_view.dart';
import 'producer_products_view.dart';
import 'producer_profile_view.dart';
import 'producer_sales_stats_view.dart';

Uint8List? _decodeBase64Image(String? value) {
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

class ProducerOrdersView extends StatefulWidget {
  const ProducerOrdersView({super.key});

  @override
  State<ProducerOrdersView> createState() => _ProducerOrdersViewState();
}

class _ProducerOrdersViewState extends State<ProducerOrdersView> {
  final TextEditingController _searchController = TextEditingController();

  static const int _statePending = 0;
  static const int _statePreparing = 1;
  static const int _stateShipped = 2;
  static const int _stateCompleted = 3;
  static const int _stateCancelled = 4;

  String _selectedFilter = 'Todos';
  DateTime? _lastSyncedAt;
  bool _isRefreshing = false;

  final List<String> _filters = const [
    'Todos',
    'Pendientes',
    'En preparación',
    'Enviados',
    'Completados',
    'Cancelados',
  ];

  // ─── Paleta unificada con dashboard / productos ────────────────────────────
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
      await _loadOrders();
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
  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() => _isRefreshing = true);

    final userController = context.read<UserController>();
    final orderController = context.read<OrderController>();
    final productController = context.read<ProductController>();
    final user = userController.currentUser;

    if (user == null || user.id == null || user.id! <= 0) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
      return;
    }

    await Future.wait([
      orderController.loadOrdersByProducer(user.id!),
      productController.getProductsByProducer(user.id!),
    ]);

    if (!mounted) return;
    setState(() {
      _lastSyncedAt = DateTime.now();
      _isRefreshing = false;
    });
  }

  // ─── Helpers de negocio ────────────────────────────────────────────────────
  List<OrderModel> _getFilteredOrders(List<OrderModel> orders) {
    final query = _searchController.text.toLowerCase().trim();

    final filtered = orders.where((order) {
      final notes = (order.notes ?? '').toLowerCase();
      final pickupAddress = (order.pickupLocationAddress ?? '').toLowerCase();

      final matchesSearch = query.isEmpty ||
          (order.id?.toString().contains(query) ?? false) ||
          order.clientID.toString().contains(query) ||
          order.pickupLocationID.toString().contains(query) ||
          _getStateText(order.state).toLowerCase().contains(query) ||
          _formatCurrency(order.amount).toLowerCase().contains(query) ||
          notes.contains(query) ||
          pickupAddress.contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'Pendientes' => order.state == _statePending,
        'En preparación' => order.state == _statePreparing,
        'Enviados' => order.state == _stateShipped,
        'Completados' => order.state == _stateCompleted,
        'Cancelados' => order.state == _stateCancelled,
        _ => true,
      };

      return matchesSearch && matchesFilter;
    }).toList();

    filtered.sort((a, b) {
      final aDate = a.registerDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.registerDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

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

  String _getStateText(int state) {
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

  String _getStateDescription(int state) {
    switch (state) {
      case _statePending:
        return 'Pedido recién recibido, pendiente de atención';
      case _statePreparing:
        return 'Pedido confirmado y en preparación';
      case _stateShipped:
        return 'Pedido enviado al cliente';
      case _stateCompleted:
        return 'Pedido completado correctamente';
      case _stateCancelled:
        return 'Pedido anulado';
      default:
        return 'Estado no identificado';
    }
  }

  Color _getStateColor(int state) {
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

  IconData _getStateIcon(int state) {
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

  List<int> _getAvailableNextStates(OrderModel order) {
    switch (order.state) {
      case _statePending:
        return [_statePreparing, _stateCancelled];
      case _statePreparing:
        return [_stateShipped, _stateCancelled];
      case _stateShipped:
        return [_stateCompleted, _stateCancelled];
      default:
        return [];
    }
  }

  String _formatCurrency(double value) {
    if (value == value.truncateToDouble()) {
      return 'Bs ${value.toStringAsFixed(0)}';
    }
    return 'Bs ${value.toStringAsFixed(2)}';
  }

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

  String _getRelativeDate(DateTime? date) {
    if (date == null) return 'sin referencia';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'hace instantes';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'hace 1 día';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return _formatDate(date).toLowerCase();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
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

  String _ordersStatusLabel(List<OrderModel> orders) {
    if (orders.isEmpty) return 'Sin pedidos';
    if (_pendingOrders(orders) > 0) return 'Atención requerida';
    if (_preparingOrders(orders) > 0 || _shippedOrders(orders) > 0) {
      return 'En movimiento';
    }
    return 'Todo en orden';
  }

  Color _ordersStatusColor(List<OrderModel> orders) {
    if (orders.isEmpty) return _primaryDark;
    if (_pendingOrders(orders) > 0) return _orange;
    if (_preparingOrders(orders) > 0) return _blue;
    if (_shippedOrders(orders) > 0) return _purple;
    return _green;
  }

  // ─── Layout ────────────────────────────────────────────────────────────────
  EdgeInsets _responsivePadding(double width) {
    if (width >= 1200) return const EdgeInsets.fromLTRB(28, 16, 28, 130);
    if (width >= 800) return const EdgeInsets.fromLTRB(20, 14, 20, 130);
    return const EdgeInsets.fromLTRB(16, 12, 16, 130);
  }

  double _maxContentWidth(double width) {
    if (width >= 1600) return 1380;
    if (width >= 1300) return 1180;
    if (width >= 1000) return 980;
    return width;
  }

  int _statsCrossAxisCount(double width) {
    if (width >= 1100) return 4;
    return 2;
  }

  // ─── Navegación ────────────────────────────────────────────────────────────
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

  Future<void> _goToSalesStats() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerSalesStatsView()),
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

  Future<void> _openCreateProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProducerCreateProductView()),
    );

    if (created == true) {
      await _loadOrders();

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

  // ─── Acciones de pedido ────────────────────────────────────────────────────
  Future<void> _showOrderDetails(OrderModel order) async {
    if (order.id == null || order.id! <= 0) return;

    final orderController = context.read<OrderController>();
    final productController = context.read<ProductController>();

    await orderController.loadOrderDetails(order.id!);

    if (!mounted) return;

    final details = List<OrderDetailModel>.from(orderController.orderDetails);
    final products = List<ProductModel>.from(productController.products);

    final productsById = <int, ProductModel>{
      for (final product in products)
        if (product.id != null) product.id!: product,
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailsSheet(
        order: order,
        details: details,
        productsById: productsById,
        stateText: _getStateText(order.state),
        stateColor: _getStateColor(order.state),
        stateIcon: _getStateIcon(order.state),
        formatCurrency: _formatCurrency,
        formatDateTime: _formatDateTime,
      ),
    );
  }

  Future<void> _showUpdateStateSheet(OrderModel order) async {
    final nextStates = _getAvailableNextStates(order);
    if (nextStates.isEmpty || order.id == null) return;

    final selectedState = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: _primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Actualizar pedido #${order.id}',
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Selecciona el nuevo estado que deseas registrar para este pedido.',
                  style: TextStyle(
                    color: _textSoft.withOpacity(0.95),
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                ...nextStates.map(
                      (state) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.pop(sheetContext, state),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surfaceSoft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _getStateColor(state).withOpacity(0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _getStateIcon(state),
                                color: _getStateColor(state),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getStateText(state),
                                    style: const TextStyle(
                                      color: _textDark,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getStateDescription(state),
                                    style: const TextStyle(
                                      color: _textSoft,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: _textSoft.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedState == null || !mounted) return;

    final orderController = context.read<OrderController>();

    final success = await orderController.updateOrderState(
      order.id!,
      selectedState,
    );

    if (!mounted) return;

    if (success) {
      await _loadOrders();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido #${order.id} actualizado a ${_getStateText(selectedState)}',
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } else {
      final message =
          orderController.errorMessage ?? 'No se pudo actualizar el pedido.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  // ─── Menú inferior ─────────────────────────────────────────────────────────
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
                          icon: Icons.storefront_outlined,
                          color: _primaryDark,
                          title: 'Productos',
                          subtitle: 'Gestiona tu catálogo',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToProducts();
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
                      title: 'Actualizar pedidos',
                      subtitle: 'Sincroniza la información de órdenes',
                      onTap: () {
                        Navigator.pop(ctx);
                        _loadOrders();
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

  // ─── Build principal ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final orderController = context.watch<OrderController>();

    final user = userController.currentUser;
    final orders = orderController.producerOrders;
    final filteredOrders = _getFilteredOrders(orders);

    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = _maxContentWidth(screenWidth);

    final isInitialLoading =
        orderController.isLoading && orders.isEmpty && _lastSyncedAt == null;
    final errorMessage = orderController.errorMessage;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6EFE6),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFloatingActionButton(),
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
              top: 140,
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
                color: _primary,
                onRefresh: _loadOrders,
                child: errorMessage != null &&
                    orders.isEmpty &&
                    !orderController.isLoading
                    ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 130),
                  children: [
                    _buildErrorState(errorMessage),
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
                                _buildHeroCard(
                                  producerName:
                                  user?.name ?? 'tu negocio',
                                  orders: orders,
                                ),
                                const SizedBox(height: 20),
                                _buildOverviewSection(
                                  orders: orders,
                                  width: screenWidth,
                                ),
                                const SizedBox(height: 20),
                                _buildSearchFilterSection(
                                  orders: orders,
                                  filteredCount: filteredOrders.length,
                                ),
                                const SizedBox(height: 20),
                                _buildOrdersSection(
                                  filteredOrders: filteredOrders,
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
    required String userName,
    required String? userImage,
    required List<OrderModel> orders,
  }) {
    final firstName = userName.split(' ').first;
    final statusColor = _ordersStatusColor(orders);
    final statusText = _ordersStatusLabel(orders);

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
                'Pedidos de $firstName',
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
                children: [
                  _buildTinyStatusChip(statusText, statusColor),
                  Text(
                    _lastSyncedAt == null
                        ? 'Sin sincronizar'
                        : 'Act. ${_formatTime(_lastSyncedAt)} · ${_formatShortDate(_lastSyncedAt)}${_isRefreshing ? ' · actualizando' : ''}',
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
          onTap: _loadOrders,
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

  // ─── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHeroCard({
    required String producerName,
    required List<OrderModel> orders,
  }) {
    final pending = _pendingOrders(orders);
    final preparing = _preparingOrders(orders);
    final shipped = _shippedOrders(orders);
    final completed = _completedOrders(orders);
    final active = pending + preparing + shipped;
    final statusColor = _ordersStatusColor(orders);
    final completion = _completionPercent(orders);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B2D25).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF5E4638),
                Color(0xFF3F332C),
                Color(0xFF2D2522),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -58,
                right: -42,
                child: _buildDecorBubble(170, _gold.withOpacity(0.13)),
              ),
              Positioned(
                bottom: -64,
                left: -48,
                child: _buildDecorBubble(150, Colors.white.withOpacity(0.055)),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: Icon(
                  Icons.eco_rounded,
                  color: Colors.white.withOpacity(0.045),
                  size: 115,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.45),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _ordersStatusLabel(orders),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 14,
                                color: _gold,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Pedidos',
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Centro de pedidos',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      producerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      active > 0
                          ? 'Tienes $active pedido${active == 1 ? '' : 's'} activo${active == 1 ? '' : 's'} para revisar, preparar o entregar.'
                          : 'No tienes pedidos activos por ahora. Mantén tu catálogo actualizado para recibir nuevas órdenes.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 13.2,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatCurrency(_managedAmount(orders)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Monto total gestionado',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.62),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: _gold.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.payments_rounded,
                                  color: _gold,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: completion.clamp(0.0, 1.0),
                              minHeight: 9,
                              backgroundColor: Colors.white.withOpacity(0.12),
                              valueColor: const AlwaysStoppedAnimation(_gold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${(completion * 100).round()}% completado',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_completedOrders(orders)} de ${_totalOrders(orders)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHeroStatBox(
                            label: 'Pedidos',
                            value: _totalOrders(orders).toString(),
                            icon: Icons.shopping_bag_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildHeroStatBox(
                            label: 'Ticket prom.',
                            value: _formatCurrency(_averageTicket(orders)),
                            icon: Icons.receipt_long_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildHeroMiniTag(
                          label: '$pending pendientes',
                          color: pending > 0 ? const Color(0xFFFFD6A8) : Colors.white70,
                        ),
                        _buildHeroMiniTag(
                          label: '$preparing preparando',
                          color: preparing > 0 ? const Color(0xFFCFE3FF) : Colors.white70,
                        ),
                        _buildHeroMiniTag(
                          label: '$shipped enviados',
                          color: shipped > 0 ? const Color(0xFFE2D9FF) : Colors.white70,
                        ),
                        _buildHeroMiniTag(
                          label: '$completed completados',
                          color: completed > 0 ? const Color(0xFFCDE8D9) : Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loadOrders,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'Actualizar',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _goToProducts,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withOpacity(0.08),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.storefront_outlined, size: 18),
                            label: const Text(
                              'Catálogo',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
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

  // ─── Resumen ───────────────────────────────────────────────────────────────
  Widget _buildOverviewSection({
    required List<OrderModel> orders,
    required double width,
  }) {
    final statusColor = _ordersStatusColor(orders);
    final statusText = _ordersStatusLabel(orders);
    final completion = _completionPercent(orders);

    final items = [
      _OverviewItem(
        label: 'Pendientes',
        value: _pendingOrders(orders).toString(),
        icon: Icons.schedule_rounded,
        color: _orange,
      ),
      _OverviewItem(
        label: 'Preparación',
        value: _preparingOrders(orders).toString(),
        icon: Icons.inventory_2_rounded,
        color: _blue,
      ),
      _OverviewItem(
        label: 'Enviados',
        value: _shippedOrders(orders).toString(),
        icon: Icons.local_shipping_rounded,
        color: _purple,
      ),
      _OverviewItem(
        label: 'Completados',
        value: _completedOrders(orders).toString(),
        icon: Icons.check_circle_rounded,
        color: _green,
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
                  'Estado operativo',
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
              crossAxisCount: _statsCrossAxisCount(width),
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
                        'Porcentaje completado',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${(completion * 100).round()}%',
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
                    value: completion.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE8DCCB),
                    valueColor: const AlwaysStoppedAnimation(_primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_totalOrders(orders)} pedidos · ${_cancelledOrders(orders)} cancelados · ${_formatCurrency(_completedAmount(orders))} en pedidos completados',
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
    required List<OrderModel> orders,
    required int filteredCount,
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
                '$filteredCount resultado${filteredCount == 1 ? '' : 's'}',
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
          const SizedBox(height: 12),
          _buildSearchInsights(orders),
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
          hintText: 'Busca por # pedido, estado, cliente, monto o ubicación...',
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

  Widget _buildSearchInsights(List<OrderModel> orders) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniInsightCard(
            title: 'Ticket promedio',
            value: _formatCurrency(_averageTicket(orders)),
            subtitle: 'Promedio por pedido',
            icon: Icons.receipt_long_rounded,
            color: _gold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMiniInsightCard(
            title: 'Ingresos',
            value: _formatCurrency(_completedAmount(orders)),
            subtitle: 'Solo completados',
            icon: Icons.savings_rounded,
            color: _green,
          ),
        ),
      ],
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
                    fontSize: 11.5,
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

  // ─── Lista de pedidos ──────────────────────────────────────────────────────
  Widget _buildOrdersSection({
    required List<OrderModel> filteredOrders,
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
                  'Pedidos del productor',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Actualizar',
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
          if (filteredOrders.isEmpty)
            _buildEmptyState()
          else
            Column(
              children:
              filteredOrders.map((order) => _buildOrderCard(order)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final stateColor = _getStateColor(order.state);
    final canUpdate = _getAvailableNextStates(order).isNotEmpty;
    final isCancelled = order.state == _stateCancelled;
    final isCompleted = order.state == _stateCompleted;
    final address = order.pickupLocationAddress?.trim();
    final hasAddress = address != null && address.isNotEmpty;
    final notes = order.notes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: stateColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B4A37).withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: () => _showOrderDetails(order),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  color: stateColor,
                ),
              ),
              Positioned(
                top: -45,
                right: -45,
                child: _buildDecorBubble(120, stateColor.withOpacity(0.055)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 16, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: stateColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Icon(
                            _getStateIcon(order.state),
                            color: stateColor,
                            size: 24,
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
                                      'Pedido #${order.id ?? '--'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _textDark,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  _buildStatusBadge(
                                    _getStateText(order.state),
                                    stateColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${_formatDateTime(order.registerDate)} · ${_getRelativeDate(order.registerDate)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textSoft,
                                  fontSize: 11.6,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.075),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: stateColor.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.74),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getStateIcon(order.state),
                              size: 18,
                              color: stateColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getStateDescription(order.state),
                              style: TextStyle(
                                color: stateColor,
                                fontSize: 12.4,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildOrderMetricTile(
                            icon: Icons.payments_rounded,
                            title: 'Total',
                            value: _formatCurrency(order.amount),
                            color: _green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildOrderMetricTile(
                            icon: Icons.person_rounded,
                            title: 'Cliente',
                            value: 'ID ${order.clientID}',
                            color: _primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildOrderMetricTile(
                            icon: Icons.pin_drop_rounded,
                            title: 'Ubicación',
                            value: order.pickupLocationID > 0
                                ? 'ID ${order.pickupLocationID}'
                                : 'Sin dato',
                            color: _red,
                          ),
                        ),
                      ],
                    ),
                    if (hasAddress || hasNotes) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: _surfaceMuted,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _divider),
                        ),
                        child: Column(
                          children: [
                            if (hasAddress)
                              _buildOrderPreviewLine(
                                icon: Icons.location_on_rounded,
                                title: 'Entrega',
                                text: address!,
                                color: _red,
                              ),
                            if (hasAddress && hasNotes)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 9),
                                child: Divider(height: 1, color: _divider),
                              ),
                            if (hasNotes)
                              _buildOrderPreviewLine(
                                icon: Icons.sticky_note_2_rounded,
                                title: 'Nota',
                                text: notes!,
                                color: _gold,
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _OrderProgressStepper(
                      state: order.state,
                      pendingColor: _orange,
                      preparingColor: _blue,
                      shippedColor: _purple,
                      completedColor: _green,
                      cancelledColor: _red,
                      dividerColor: _divider,
                      softText: _textSoft,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showOrderDetails(order),
                            icon: const Icon(Icons.visibility_rounded, size: 18),
                            label: const Text(
                              'Detalle',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryDark,
                              side: const BorderSide(color: _divider),
                              backgroundColor: _surfaceSoft,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: canUpdate
                                ? () => _showUpdateStateSheet(order)
                                : null,
                            icon: Icon(
                              canUpdate
                                  ? Icons.sync_alt_rounded
                                  : isCancelled
                                  ? Icons.cancel_rounded
                                  : Icons.check_circle_rounded,
                              size: 18,
                            ),
                            label: Text(
                              canUpdate
                                  ? 'Cambiar'
                                  : isCancelled
                                  ? 'Cancelado'
                                  : isCompleted
                                  ? 'Finalizado'
                                  : 'Cerrado',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: canUpdate
                                  ? _primary
                                  : isCancelled
                                  ? _red.withOpacity(0.92)
                                  : _green.withOpacity(0.92),
                              disabledBackgroundColor: canUpdate
                                  ? _primary
                                  : isCancelled
                                  ? _red.withOpacity(0.84)
                                  : _green.withOpacity(0.88),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildOrderMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPreviewLine({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
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
            label,
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
            'Cargando pedidos...',
            style: TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos sincronizando tus órdenes y su estado actual.',
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
            'No se pudieron cargar los pedidos',
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
              onPressed: _loadOrders,
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

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;

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
              hasSearch ? Icons.search_off_rounded : Icons.inbox_outlined,
              size: 32,
              color: _primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasSearch ? 'No se encontraron pedidos' : 'Aún no hay pedidos',
            style: const TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Prueba con otro texto o cambia el filtro seleccionado.'
                : 'Cuando empieces a recibir pedidos aparecerán aquí con su estado y acciones rápidas.',
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
              onPressed: hasSearch ? _clearSearchAndFilters : _loadOrders,
              icon: Icon(
                hasSearch ? Icons.restart_alt_rounded : Icons.refresh_rounded,
                size: 18,
              ),
              label: Text(
                hasSearch ? 'Limpiar filtros' : 'Actualizar pedidos',
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

  // ─── Avatar ────────────────────────────────────────────────────────────────
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

  // ─── Sheet menu helpers ────────────────────────────────────────────────────
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
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _textSoft),
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
                  selected: false,
                  onTap: _goToProducts,
                ),
                const SizedBox(width: 56),
                _buildNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Pedidos',
                  selected: true,
                  onTap: _loadOrders,
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

class _OrderProgressStepper extends StatelessWidget {
  final int state;
  final Color pendingColor;
  final Color preparingColor;
  final Color shippedColor;
  final Color completedColor;
  final Color cancelledColor;
  final Color dividerColor;
  final Color softText;

  const _OrderProgressStepper({
    required this.state,
    required this.pendingColor,
    required this.preparingColor,
    required this.shippedColor,
    required this.completedColor,
    required this.cancelledColor,
    required this.dividerColor,
    required this.softText,
  });

  bool _isReached(int stepState) {
    if (state == 4) return false;
    return state >= stepState;
  }

  @override
  Widget build(BuildContext context) {
    if (state == 4) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cancelledColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cancelledColor.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: cancelledColor),
            const SizedBox(width: 8),
            Text(
              'Este pedido fue cancelado.',
              style: TextStyle(
                color: cancelledColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _ProgressNode(
            label: 'Pendiente',
            reached: _isReached(0),
            color: pendingColor,
            icon: Icons.schedule_rounded,
            softText: softText,
          ),
        ),
        _ProgressLine(
          active: _isReached(1),
          color: preparingColor,
          dividerColor: dividerColor,
        ),
        Expanded(
          child: _ProgressNode(
            label: 'Preparación',
            reached: _isReached(1),
            color: preparingColor,
            icon: Icons.inventory_2_rounded,
            softText: softText,
          ),
        ),
        _ProgressLine(
          active: _isReached(2),
          color: shippedColor,
          dividerColor: dividerColor,
        ),
        Expanded(
          child: _ProgressNode(
            label: 'Enviado',
            reached: _isReached(2),
            color: shippedColor,
            icon: Icons.local_shipping_rounded,
            softText: softText,
          ),
        ),
        _ProgressLine(
          active: _isReached(3),
          color: completedColor,
          dividerColor: dividerColor,
        ),
        Expanded(
          child: _ProgressNode(
            label: 'Completado',
            reached: _isReached(3),
            color: completedColor,
            icon: Icons.check_circle_rounded,
            softText: softText,
          ),
        ),
      ],
    );
  }
}

class _ProgressNode extends StatelessWidget {
  final String label;
  final bool reached;
  final Color color;
  final IconData icon;
  final Color softText;

  const _ProgressNode({
    required this.label,
    required this.reached,
    required this.color,
    required this.icon,
    required this.softText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: reached ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: reached ? color : const Color(0xFFE7DACA),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: reached ? Colors.white : softText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: reached ? const Color(0xFF4B3427) : softText,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final bool active;
  final Color color;
  final Color dividerColor;

  const _ProgressLine({
    required this.active,
    required this.color,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: active ? color : dividerColor,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final OrderModel order;
  final List<OrderDetailModel> details;
  final Map<int, ProductModel> productsById;
  final String stateText;
  final Color stateColor;
  final IconData stateIcon;
  final String Function(double value) formatCurrency;
  final String Function(DateTime? date) formatDateTime;

  const _OrderDetailsSheet({
    required this.order,
    required this.details,
    required this.productsById,
    required this.stateText,
    required this.stateColor,
    required this.stateIcon,
    required this.formatCurrency,
    required this.formatDateTime,
  });

  double get _detailTotal {
    return details.fold(
      0.0,
          (sum, item) => sum + (item.quantity * item.unitPrice),
    );
  }

  int get _totalUnits {
    return details.fold(0, (sum, item) => sum + item.quantity);
  }

  String get _deliveryAddress {
    final address = order.pickupLocationAddress?.trim();
    if (address != null && address.isNotEmpty) {
      return address;
    }

    if (order.pickupLocationID > 0) {
      return 'Ubicación ${order.pickupLocationID}';
    }

    return 'Sin dirección registrada';
  }

  String get _orderNotes {
    final notes = order.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return notes;
    }
    return 'Sin notas registradas';
  }

  bool get _hasNotes {
    final notes = order.notes?.trim();
    return notes != null && notes.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    const surface = Colors.white;
    const surfaceSoft = Color(0xFFFFFCF8);
    const border = Color(0xFFEADACA);
    const textDark = Color(0xFF4A3428);
    const textSoft = Color(0xFF8A7360);
    const primaryDark = Color(0xFF8B6847);
    const primary = Color(0xFFC89B5D);

    final height = MediaQuery.of(context).size.height * 0.88;

    return SafeArea(
      top: false,
      child: Container(
        height: height,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: stateColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(stateIcon, color: stateColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pedido #${order.id ?? '--'}',
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formatDateTime(order.registerDate),
                                style: const TextStyle(
                                  color: textSoft,
                                  fontSize: 12.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: textSoft,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceSoft,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _DetailStat(
                                  title: 'Estado',
                                  value: stateText,
                                  subtitle: 'Situación actual',
                                  icon: stateIcon,
                                  color: stateColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DetailStat(
                                  title: 'Monto',
                                  value: formatCurrency(order.amount),
                                  subtitle: 'Total del pedido',
                                  icon: Icons.payments_rounded,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _DetailStat(
                                  title: 'Cliente',
                                  value: 'ID ${order.clientID}',
                                  subtitle: 'Comprador',
                                  icon: Icons.person_rounded,
                                  color: primaryDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DetailStat(
                                  title: 'Productos',
                                  value: '${details.length}',
                                  subtitle: 'Ítems distintos',
                                  icon: Icons.shopping_bag_rounded,
                                  color: const Color(0xFF5E7FA3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _DetailStat(
                                  title: 'Unidades',
                                  value: '$_totalUnits',
                                  subtitle: 'Cantidad total',
                                  icon: Icons.inventory_rounded,
                                  color: const Color(0xFF467C5E),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DetailStat(
                                  title: 'Ubicación',
                                  value: order.pickupLocationID > 0
                                      ? 'ID ${order.pickupLocationID}'
                                      : 'Sin ubicación',
                                  subtitle: 'Referencia interna',
                                  icon: Icons.pin_drop_rounded,
                                  color: const Color(0xFFB95C40),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceSoft,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dirección de entrega',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              _deliveryAddress,
                              style: const TextStyle(
                                color: textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceSoft,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notas del restaurante',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              _orderNotes,
                              style: TextStyle(
                                color: _hasNotes ? textDark : textSoft,
                                fontSize: 14,
                                fontWeight:
                                _hasNotes ? FontWeight.w700 : FontWeight.w600,
                                height: 1.45,
                                fontStyle: _hasNotes
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Productos del pedido',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: surfaceSoft,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: border),
                          ),
                          child: Text(
                            '${details.length} ítem${details.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (details.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 30,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: border),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 34,
                              color: primaryDark,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No se encontraron productos en este pedido',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(details.length, (index) {
                        final detail = details[index];
                        final product = productsById[detail.productID];
                        final subtotal = detail.quantity * detail.unitPrice;
                        final bytes = _decodeBase64Image(product?.picture);

                        Widget imageChild;
                        if (_isNetworkImage(product?.picture)) {
                          imageChild = Image.network(
                            product!.picture!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.eco_rounded,
                              color: primaryDark,
                            ),
                          );
                        } else if (bytes != null) {
                          imageChild = Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.eco_rounded,
                              color: primaryDark,
                            ),
                          );
                        } else {
                          imageChild = const Icon(
                            Icons.eco_rounded,
                            color: primaryDark,
                          );
                        }

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == details.length - 1 ? 0 : 10,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: surfaceSoft,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: primary.withOpacity(0.12),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: imageChild,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product?.name.isNotEmpty == true
                                            ? product!.name
                                            : 'Producto ID ${detail.productID}',
                                        style: const TextStyle(
                                          color: textDark,
                                          fontSize: 15.2,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product?.unit != null &&
                                            product!.unit!.trim().isNotEmpty
                                            ? '${detail.quantity} ${product.unit}'
                                            : '${detail.quantity} unidad${detail.quantity == 1 ? '' : 'es'}',
                                        style: const TextStyle(
                                          color: textSoft,
                                          fontSize: 12.8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _SmallTag(
                                            text: 'ID ${detail.productID}',
                                            color: const Color(0xFF8B6847),
                                          ),
                                          _SmallTag(
                                            text: formatCurrency(detail.unitPrice),
                                            color: const Color(0xFF5E7FA3),
                                          ),
                                          _SmallTag(
                                            text:
                                            'Subtotal ${formatCurrency(subtotal)}',
                                            color: const Color(0xFF467C5E),
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
                      }),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total calculado',
                            style: TextStyle(
                              color: textSoft,
                              fontSize: 12.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(_detailTotal),
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Cerrar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _DetailStat({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADACA)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
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
                    color: Color(0xFF8A7360),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A3428),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A7360),
                    fontSize: 11,
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

class _SmallTag extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallTag({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}