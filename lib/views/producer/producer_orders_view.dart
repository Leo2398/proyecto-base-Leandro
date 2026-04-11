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
import 'producer_dashboard_view.dart';
import 'producer_products_view.dart';
import 'producer_profile_view.dart';

class ProducerOrdersView extends StatefulWidget {
  const ProducerOrdersView({super.key});

  @override
  State<ProducerOrdersView> createState() => _ProducerOrdersViewState();
}

class _ProducerOrdersViewState extends State<ProducerOrdersView> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'Todos';
  DateTime? _lastSyncedAt;
  bool _isRefreshing = false;

  final List<String> _filters = const [
    'Todos',
    'Pendientes',
    'Aceptados',
    'Entregados',
    'Cancelados',
  ];

  static const Color _bgTop = Color(0xFFF8F2EA);
  static const Color _bgMid = Color(0xFFF3E9DD);
  static const Color _bgBottom = Color(0xFFE8D6C1);

  static const Color _primary = Color(0xFFC89B5D);
  static const Color _primaryDark = Color(0xFF8B6847);
  static const Color _gold = Color(0xFFE5BB7A);
  static const Color _green = Color(0xFF467C5E);
  static const Color _orange = Color(0xFFD67B35);
  static const Color _red = Color(0xFFB95C40);
  static const Color _blue = Color(0xFF5E7FA3);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF8F1E8);

  static const Color _textDark = Color(0xFF4A3428);
  static const Color _textSoft = Color(0xFF8A7360);
  static const Color _border = Color(0xFFEADACA);
  static const Color _divider = Color(0xFFE8DCCD);

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

  List<OrderModel> _getFilteredOrders(List<OrderModel> orders) {
    final query = _searchController.text.toLowerCase().trim();

    final filtered = orders.where((order) {
      final matchesSearch =
          query.isEmpty ||
              (order.id?.toString().contains(query) ?? false) ||
              order.clientID.toString().contains(query) ||
              order.pickupLocationID.toString().contains(query) ||
              _getStateText(order.state).toLowerCase().contains(query) ||
              _formatCurrency(order.amount).toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'Pendientes' => order.state == 0,
        'Aceptados' => order.state == 1,
        'Entregados' => order.state == 2,
        'Cancelados' => order.state == 3,
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

  String _getStateText(int state) {
    switch (state) {
      case 0:
        return 'Pendiente';
      case 1:
        return 'Aceptado';
      case 2:
        return 'Entregado';
      case 3:
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  String _getStateDescription(int state) {
    switch (state) {
      case 0:
        return 'Pedido recién recibido';
      case 1:
        return 'En preparación o confirmado';
      case 2:
        return 'Pedido finalizado correctamente';
      case 3:
        return 'Pedido anulado';
      default:
        return 'Estado no identificado';
    }
  }

  Color _getStateColor(int state) {
    switch (state) {
      case 0:
        return _orange;
      case 1:
        return _blue;
      case 2:
        return _green;
      case 3:
        return _red;
      default:
        return _textSoft;
    }
  }

  IconData _getStateIcon(int state) {
    switch (state) {
      case 0:
        return Icons.schedule_rounded;
      case 1:
        return Icons.inventory_2_rounded;
      case 2:
        return Icons.check_circle_rounded;
      case 3:
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  List<int> _getAvailableNextStates(OrderModel order) {
    switch (order.state) {
      case 0:
        return [1, 3];
      case 1:
        return [2, 3];
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

  String _formatLastSync(DateTime? date) {
    if (date == null) return 'Sin sincronizar';
    return 'Act. ${_formatTime(date)} · ${_formatShortDate(date)}';
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

  int _totalOrders(List<OrderModel> orders) => orders.length;

  int _pendingOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == 0).length;

  int _acceptedOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == 1).length;

  int _deliveredOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == 2).length;

  int _cancelledOrders(List<OrderModel> orders) =>
      orders.where((o) => o.state == 3).length;

  double _managedAmount(List<OrderModel> orders) {
    return orders
        .where((o) => o.state != 3)
        .fold(0.0, (sum, order) => sum + order.amount);
  }

  double _deliveredAmount(List<OrderModel> orders) {
    return orders
        .where((o) => o.state == 2)
        .fold(0.0, (sum, order) => sum + order.amount);
  }

  double _averageTicket(List<OrderModel> orders) {
    if (orders.isEmpty) return 0.0;
    final total = orders.fold(0.0, (sum, order) => sum + order.amount);
    return total / orders.length;
  }

  EdgeInsets _responsivePadding(double width) {
    if (width >= 1200) {
      return const EdgeInsets.fromLTRB(28, 16, 28, 190);
    }
    if (width >= 800) {
      return const EdgeInsets.fromLTRB(20, 14, 20, 190);
    }
    return const EdgeInsets.fromLTRB(16, 12, 16, 190);
  }

  double _maxContentWidth(double width) {
    if (width >= 1600) return 1380;
    if (width >= 1300) return 1180;
    if (width >= 1000) return 980;
    return width;
  }

  int _statsCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 760) return 2;
    return 2;
  }

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

  Future<void> _onBottomNavigationTap(int index) async {
    switch (index) {
      case 0:
        await _goToDashboard();
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
      builder: (_) {
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
                  'Selecciona el siguiente estado para este pedido.',
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
                      onTap: () => Navigator.pop(context, state),
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
        ),
      );
    } else {
      final message =
          orderController.errorMessage ?? 'No se pudo actualizar el pedido.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildBackgroundBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.18),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required String producerName,
    required List<OrderModel> orders,
  }) {
    final pending = _pendingOrders(orders);
    final accepted = _acceptedOrders(orders);
    final delivered = _deliveredOrders(orders);
    final cancelled = _cancelledOrders(orders);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            _primaryDark,
            const Color(0xFF9A7553),
            _primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _goToDashboard,
                child: Ink(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sync_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatLastSync(_lastSyncedAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Historial y control de pedidos',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Administra, revisa y sigue cada pedido de $producerName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Visualiza pedidos recibidos, detecta pendientes rápido y mantén el control del flujo de ventas desde una sola pantalla.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 13.6,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickBadge(
                icon: Icons.schedule_rounded,
                label: '$pending pendientes',
              ),
              _QuickBadge(
                icon: Icons.inventory_2_rounded,
                label: '$accepted aceptados',
              ),
              _QuickBadge(
                icon: Icons.check_circle_rounded,
                label: '$delivered entregados',
              ),
              _QuickBadge(
                icon: Icons.cancel_rounded,
                label: '$cancelled cancelados',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(List<OrderModel> orders, double width) {
    final items = [
      _SummaryCardData(
        title: 'Pedidos',
        value: _totalOrders(orders).toString(),
        subtitle: 'Total recibidos',
        icon: Icons.shopping_bag_rounded,
        color: _primaryDark,
      ),
      _SummaryCardData(
        title: 'Pendientes',
        value: _pendingOrders(orders).toString(),
        subtitle: 'Requieren atención',
        icon: Icons.pending_actions_rounded,
        color: _orange,
      ),
      _SummaryCardData(
        title: 'Entregados',
        value: _deliveredOrders(orders).toString(),
        subtitle: 'Completados',
        icon: Icons.verified_rounded,
        color: _green,
      ),
      _SummaryCardData(
        title: 'Monto activo',
        value: _formatCurrency(_managedAmount(orders)),
        subtitle: 'Sin cancelados',
        icon: Icons.payments_rounded,
        color: _blue,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _statsCrossAxisCount(width),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: width >= 1000 ? 1.62 : 1.32,
      ),
      itemBuilder: (_, index) => _SummaryCard(item: items[index]),
    );
  }

  Widget _buildControlsCard({
    required List<OrderModel> orders,
    required int filteredCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.93),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: _primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Filtra y encuentra pedidos rápido',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  '$filteredCount / ${orders.length}',
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            cursorColor: _primaryDark,
            style: const TextStyle(
              color: _textDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Busca por # pedido, cliente, estado o ubicación',
              hintStyle: const TextStyle(
                color: _textSoft,
                fontSize: 13.5,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _primaryDark.withOpacity(0.8),
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
                color: _textSoft,
              ),
              filled: true,
              fillColor: _surfaceSoft,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _primary.withOpacity(0.55)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filters.map((filter) {
                final selected = _selectedFilter == filter;
                return InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _primary.withOpacity(0.18)
                          : _surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? _primary.withOpacity(0.55)
                            : _border,
                      ),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: selected ? _primaryDark : _textSoft,
                        fontSize: 12.5,
                        fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightPanel(List<OrderModel> orders) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
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
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniInsightCard(
                  title: 'Ticket promedio',
                  value: _formatCurrency(_averageTicket(orders)),
                  subtitle: 'Promedio por pedido',
                  icon: Icons.receipt_long_rounded,
                  color: _gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniInsightCard(
                  title: 'Cobrado',
                  value: _formatCurrency(_deliveredAmount(orders)),
                  subtitle: 'Solo entregados',
                  icon: Icons.savings_rounded,
                  color: _green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniInsightCard(
                  title: 'Aceptados',
                  value: _acceptedOrders(orders).toString(),
                  subtitle: 'En preparación',
                  icon: Icons.local_shipping_rounded,
                  color: _blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniInsightCard(
                  title: 'Cancelados',
                  value: _cancelledOrders(orders).toString(),
                  subtitle: 'Pedidos anulados',
                  icon: Icons.remove_shopping_cart_rounded,
                  color: _red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _red,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hubo un problema al cargar',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 12.6,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final stateColor = _getStateColor(order.state);
    final canUpdate = _getAvailableNextStates(order).isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              gradient: LinearGradient(
                colors: [
                  stateColor.withOpacity(0.14),
                  _surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_rounded,
                            size: 18,
                            color: _primaryDark,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '#${order.id ?? '--'}',
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: stateColor.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStateIcon(order.state),
                            size: 15,
                            color: stateColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStateText(order.state),
                            style: TextStyle(
                              color: stateColor,
                              fontSize: 12.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Pedido recibido ${_getRelativeDate(order.registerDate)}',
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(order.amount),
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Monto total',
                          style: TextStyle(
                            color: _textSoft,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoPill(
                      icon: Icons.person_rounded,
                      label: 'Cliente',
                      value: 'ID ${order.clientID}',
                      iconColor: _primaryDark,
                    ),
                    _InfoPill(
                      icon: Icons.location_on_rounded,
                      label: 'Entrega',
                      value: order.pickupLocationID > 0
                          ? 'Ubicación ${order.pickupLocationID}'
                          : 'Sin ubicación',
                      iconColor: _red,
                    ),
                    _InfoPill(
                      icon: Icons.calendar_today_rounded,
                      label: 'Fecha',
                      value: _formatDate(order.registerDate),
                      iconColor: _blue,
                    ),
                    _InfoPill(
                      icon: Icons.access_time_filled_rounded,
                      label: 'Hora',
                      value: _formatTime(order.registerDate),
                      iconColor: _orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              children: [
                _OrderProgressStepper(
                  state: order.state,
                  acceptedColor: _blue,
                  pendingColor: _orange,
                  deliveredColor: _green,
                  cancelledColor: _red,
                  dividerColor: _divider,
                  softText: _textSoft,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showOrderDetails(order),
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Ver detalle'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryDark,
                          side: BorderSide(color: _border),
                          backgroundColor: _surfaceSoft,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                        canUpdate ? () => _showUpdateStateSheet(order) : null,
                        icon: Icon(
                          canUpdate
                              ? Icons.sync_alt_rounded
                              : Icons.check_circle_rounded,
                        ),
                        label: Text(
                          canUpdate ? 'Actualizar' : 'Cerrado',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                          canUpdate ? _primary : _green.withOpacity(0.92),
                          disabledBackgroundColor: order.state == 3
                              ? _red.withOpacity(0.84)
                              : _green.withOpacity(0.88),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
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
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              _SkeletonBox(width: 92, height: 40, radius: 16),
              Spacer(),
              _SkeletonBox(width: 112, height: 34, radius: 999),
            ],
          ),
          const SizedBox(height: 16),
          const _SkeletonBox(width: double.infinity, height: 24, radius: 12),
          const SizedBox(height: 10),
          const _SkeletonBox(width: 220, height: 15, radius: 12),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _SkeletonBox(width: 110, height: 56, radius: 16),
              _SkeletonBox(width: 125, height: 56, radius: 16),
              _SkeletonBox(width: 112, height: 56, radius: 16),
              _SkeletonBox(width: 115, height: 56, radius: 16),
            ],
          ),
          const SizedBox(height: 18),
          const _SkeletonBox(width: double.infinity, height: 56, radius: 18),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: _SkeletonBox(
                  width: double.infinity,
                  height: 48,
                  radius: 16,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _SkeletonBox(
                  width: double.infinity,
                  height: 48,
                  radius: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.93),
        borderRadius: BorderRadius.circular(30),
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
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _primary.withOpacity(0.20),
                  _gold.withOpacity(0.10),
                ],
              ),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 36,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No hay coincidencias' : 'No hay pedidos para mostrar',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Prueba con otro texto de búsqueda o cambia el filtro actual.'
                : 'Cuando empieces a recibir pedidos desde la plataforma, aparecerán aquí organizados por estado y fecha.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 13.8,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isRefreshing ? null : _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar pedidos'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
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
                    child: _buildBottomNavItem(items[0], selected: false),
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
      backgroundColor: _bgTop,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton.extended(
          backgroundColor: _primary,
          elevation: 12,
          onPressed: _isRefreshing ? null : _loadOrders,
          icon: _isRefreshing
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.refresh_rounded, color: Colors.white),
          label: Text(
            _isRefreshing ? 'Actualizando' : 'Actualizar',
            style: const TextStyle(
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
              top: -90,
              left: -70,
              child: _buildBackgroundBubble(
                220,
                _primary.withOpacity(0.10),
              ),
            ),
            Positioned(
              top: 180,
              right: -70,
              child: _buildBackgroundBubble(
                170,
                _blue.withOpacity(0.08),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -30,
              child: _buildBackgroundBubble(
                200,
                _green.withOpacity(0.07),
              ),
            ),
            Positioned(
              bottom: 250,
              right: -20,
              child: _buildBackgroundBubble(
                120,
                _gold.withOpacity(0.08),
              ),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: _primaryDark,
                onRefresh: _loadOrders,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: maxWidth,
                        ),
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            SliverPadding(
                              padding: _responsivePadding(screenWidth),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate(
                                  [
                                    _buildHeaderCard(
                                      producerName: user?.name ?? 'tu negocio',
                                      orders: orders,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildSummaryGrid(orders, screenWidth),
                                    const SizedBox(height: 14),
                                    _buildControlsCard(
                                      orders: orders,
                                      filteredCount: filteredOrders.length,
                                    ),
                                    const SizedBox(height: 14),
                                    _buildHighlightPanel(orders),
                                    if (errorMessage != null &&
                                        errorMessage.trim().isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      _buildErrorBanner(errorMessage),
                                    ],
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Historial de pedidos',
                                                style: TextStyle(
                                                  color: _textDark,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Tus pedidos más recientes, filtrados y listos para gestionar.',
                                                style: TextStyle(
                                                  color: _textSoft,
                                                  fontSize: 12.6,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _surface.withOpacity(0.88),
                                            borderRadius:
                                            BorderRadius.circular(14),
                                            border: Border.all(color: _border),
                                          ),
                                          child: Text(
                                            '${filteredOrders.length} visibles',
                                            style: const TextStyle(
                                              color: _textSoft,
                                              fontSize: 12.2,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (isInitialLoading) ...[
                                      _buildLoadingCard(),
                                      const SizedBox(height: 12),
                                      _buildLoadingCard(),
                                      const SizedBox(height: 12),
                                      _buildLoadingCard(),
                                    ] else if (filteredOrders.isEmpty) ...[
                                      _buildEmptyState(),
                                    ] else ...[
                                      ...List.generate(filteredOrders.length,
                                              (index) {
                                            final order = filteredOrders[index];
                                            return Padding(
                                              padding: EdgeInsets.only(
                                                bottom:
                                                index == filteredOrders.length - 1
                                                    ? 0
                                                    : 12,
                                              ),
                                              child: _buildOrderCard(order),
                                            );
                                          }),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    const surface = Colors.white;
    const surfaceSoft = Color(0xFFFFFCF8);
    const border = Color(0xFFEADACA);
    const textDark = Color(0xFF4A3428);
    const textSoft = Color(0xFF8A7360);
    const primaryDark = Color(0xFF8B6847);
    const primary = Color(0xFFC89B5D);
    const divider = Color(0xFFE8DCCD);

    final height = MediaQuery.of(context).size.height * 0.84;

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
                          child: Icon(
                            stateIcon,
                            color: stateColor,
                          ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                            title: 'Entrega',
                            value: order.pickupLocationID > 0
                                ? 'Ubicación ${order.pickupLocationID}'
                                : 'Sin ubicación',
                            subtitle: 'Punto de entrega',
                            icon: Icons.location_on_rounded,
                            color: const Color(0xFFB95C40),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
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
            ),
            const SizedBox(height: 12),
            Expanded(
              child: details.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stateColor.withOpacity(0.10),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 34,
                          color: stateColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No se encontraron productos en este pedido',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Verifica si el detalle fue registrado correctamente en la base de datos o si todavía falta cargar la información completa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSoft,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                itemCount: details.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final detail = details[index];
                  final product = productsById[detail.productID];
                  final subtotal = detail.quantity * detail.unitPrice;

                  return Container(
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
                          child: product?.picture != null &&
                              product!.picture!.trim().isNotEmpty
                              ? Image.network(
                            product.picture!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return const Icon(
                                Icons.eco_rounded,
                                color: primaryDark,
                              );
                            },
                          )
                              : const Icon(
                            Icons.eco_rounded,
                            color: primaryDark,
                          ),
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
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: divider),
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
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
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

class _SummaryCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _SummaryCard extends StatelessWidget {
  final _SummaryCardData item;

  const _SummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEADACA)),
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              item.icon,
              color: item.color,
            ),
          ),
          const Spacer(),
          Text(
            item.title,
            style: const TextStyle(
              color: Color(0xFF8A7360),
              fontSize: 12.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4A3428),
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.subtitle,
            style: const TextStyle(
              color: Color(0xFF8A7360),
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInsightCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MiniInsightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADACA)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
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
                    color: Color(0xFF8A7360),
                    fontSize: 12.1,
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
                    fontSize: 15.2,
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
                    fontSize: 11.8,
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADACA)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8A7360),
                    fontSize: 11.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A3428),
                    fontSize: 12.8,
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
}

class _QuickBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderProgressStepper extends StatelessWidget {
  final int state;
  final Color acceptedColor;
  final Color pendingColor;
  final Color deliveredColor;
  final Color cancelledColor;
  final Color dividerColor;
  final Color softText;

  const _OrderProgressStepper({
    required this.state,
    required this.acceptedColor,
    required this.pendingColor,
    required this.deliveredColor,
    required this.cancelledColor,
    required this.dividerColor,
    required this.softText,
  });

  bool _isStepActive(int index) {
    if (state == 3) {
      return index == 3;
    }
    if (state == 0) return index == 0;
    if (state == 1) return index <= 1;
    if (state == 2) return index <= 2;
    return false;
  }

  Color _stepColor(int index) {
    if (state == 3 && index == 3) return cancelledColor;

    switch (index) {
      case 0:
        return pendingColor;
      case 1:
        return acceptedColor;
      case 2:
        return deliveredColor;
      case 3:
        return cancelledColor;
      default:
        return softText;
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Pendiente',
      'Aceptado',
      'Entregado',
      'Cancelado',
    ];

    const icons = [
      Icons.schedule_rounded,
      Icons.inventory_2_rounded,
      Icons.check_circle_rounded,
      Icons.cancel_rounded,
    ];

    return Column(
      children: [
        Row(
          children: List.generate(labels.length * 2 - 1, (i) {
            if (i.isOdd) {
              final leftStep = i ~/ 2;
              final activeLine =
                  (state != 3 && _isStepActive(leftStep + 1)) ||
                      (state == 3 && leftStep == 2);
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: activeLine
                        ? _stepColor(leftStep + 1).withOpacity(0.45)
                        : dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }

            final step = i ~/ 2;
            final active = _isStepActive(step);
            final color = _stepColor(step);

            return Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? color.withOpacity(0.14)
                        : dividerColor.withOpacity(0.7),
                    border: Border.all(
                      color: active ? color : dividerColor,
                    ),
                  ),
                  child: Icon(
                    icons[step],
                    size: 18,
                    color: active ? color : softText.withOpacity(0.65),
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: labels.map((label) {
            final index = labels.indexOf(label);
            final active = _isStepActive(index);
            final color = _stepColor(index);

            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? color : softText,
                  fontSize: 11.2,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADACA)),
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
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8A7360),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4A3428),
              fontSize: 15.4,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8A7360),
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
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
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF1E7DA),
            Color(0xFFF8F1E7),
            Color(0xFFF1E7DA),
          ],
        ),
      ),
    );
  }
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
