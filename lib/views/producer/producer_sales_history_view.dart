import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/order_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order_detail_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';

class ProducerSalesHistoryView extends StatefulWidget {
  const ProducerSalesHistoryView({super.key});

  @override
  State<ProducerSalesHistoryView> createState() =>
      _ProducerSalesHistoryViewState();
}

class _ProducerSalesHistoryViewState extends State<ProducerSalesHistoryView> {
  final TextEditingController _searchController = TextEditingController();

  static const int _stateCompleted = 3;

  static const Color _bgTop = Color(0xFFF8F2EA);
  static const Color _bgMid = Color(0xFFF3E9DD);
  static const Color _bgBottom = Color(0xFFE8D7C4);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF8F1E8);

  static const Color _primary = Color(0xFFC89B5D);
  static const Color _primaryDark = Color(0xFF8B6847);
  static const Color _gold = Color(0xFFE5BB7A);
  static const Color _green = Color(0xFF4B7D63);
  static const Color _orange = Color(0xFFD37A34);
  static const Color _red = Color(0xFFBE6041);
  static const Color _blue = Color(0xFF5E7FA3);
  static const Color _purple = Color(0xFF7A6CCF);
  static const Color _rose = Color(0xFFC76C7E);

  static const Color _textDark = Color(0xFF4A3428);
  static const Color _textSoft = Color(0xFF8A7360);
  static const Color _border = Color(0xFFEADACA);
  static const Color _divider = Color(0xFFE8DCCD);

  DateTime? _lastSyncedAt;
  bool _isRefreshing = false;
  bool _productsLoaded = false;
  String _selectedFilter = 'Todos';

  final List<String> _filters = const [
    'Todos',
    'Hoy',
    '7 días',
    '30 días',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadHistory();
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

  Future<void> _loadHistory() async {
    if (!mounted || _isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final userController = context.read<UserController>();
      final orderController = context.read<OrderController>();
      final productController = context.read<ProductController>();

      final user = userController.currentUser;
      if (user == null || user.id == null || user.id! <= 0) return;

      await Future.wait([
        orderController.loadOrdersByProducer(user.id!),
        if (!_productsLoaded) productController.getProductsByProducer(user.id!),
      ]);

      if (!mounted) return;

      setState(() {
        _lastSyncedAt = DateTime.now();
        _productsLoaded = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  List<OrderModel> _completedOrders(List<OrderModel> orders) {
    final completed = orders
        .where((order) => order.state == _stateCompleted)
        .toList();

    completed.sort((a, b) {
      final aDate = a.registerDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.registerDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return completed;
  }

  bool _matchesDateFilter(OrderModel order) {
    if (_selectedFilter == 'Todos') return true;

    final date = order.registerDate;
    if (date == null) return false;

    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'Hoy':
        return now.year == date.year &&
            now.month == date.month &&
            now.day == date.day;
      case '7 días':
        return now.difference(date).inDays <= 7;
      case '30 días':
        return now.difference(date).inDays <= 30;
      default:
        return true;
    }
  }

  List<OrderModel> _filteredOrders(List<OrderModel> orders) {
    final query = _searchController.text.trim().toLowerCase();

    return orders.where((order) {
      final address = (order.pickupLocationAddress ?? '').toLowerCase();
      final notes = (order.notes ?? '').toLowerCase();

      final matchesSearch =
          query.isEmpty ||
              (order.id?.toString().contains(query) ?? false) ||
              order.clientID.toString().contains(query) ||
              address.contains(query) ||
              notes.contains(query) ||
              _formatCurrency(order.amount).toLowerCase().contains(query);

      return matchesSearch && _matchesDateFilter(order);
    }).toList();
  }

  double _totalRevenue(List<OrderModel> orders) {
    return orders.fold(0.0, (sum, order) => sum + order.amount);
  }

  double _averageTicket(List<OrderModel> orders) {
    if (orders.isEmpty) return 0.0;
    return _totalRevenue(orders) / orders.length;
  }

  String _money(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatCurrency(double value) => 'Bs ${_money(value)}';

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

  String _safeAddress(OrderModel order) {
    final address = order.pickupLocationAddress?.trim();
    if (address != null && address.isNotEmpty) return address;
    if (order.pickupLocationID > 0) return 'Ubicación ${order.pickupLocationID}';
    return 'Sin dirección registrada';
  }

  String _notesPreview(OrderModel order) {
    final notes = order.notes?.trim();
    if (notes == null || notes.isEmpty) {
      return 'Sin observaciones registradas en este pedido.';
    }

    if (notes.length <= 110) return notes;
    return '${notes.substring(0, 110)}...';
  }

  bool _hasNotes(OrderModel order) {
    final notes = order.notes?.trim();
    return notes != null && notes.isNotEmpty;
  }

  bool _hasActiveFilters() {
    return _selectedFilter != 'Todos' || _searchController.text.trim().isNotEmpty;
  }

  OrderModel? _highestOrder(List<OrderModel> orders) {
    if (orders.isEmpty) return null;
    OrderModel best = orders.first;
    for (final order in orders) {
      if (order.amount > best.amount) {
        best = order;
      }
    }
    return best;
  }

  OrderModel? _latestOrder(List<OrderModel> orders) {
    if (orders.isEmpty) return null;
    return orders.first;
  }

  EdgeInsets _pagePadding(double width) {
    if (width >= 1200) {
      return const EdgeInsets.fromLTRB(28, 16, 28, 24);
    }
    if (width >= 800) {
      return const EdgeInsets.fromLTRB(20, 14, 20, 24);
    }
    return const EdgeInsets.fromLTRB(16, 12, 16, 24);
  }

  double _maxWidth(double width) {
    if (width >= 1600) return 1380;
    if (width >= 1300) return 1180;
    if (width >= 1000) return 980;
    return width;
  }

  int _summaryCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 760) return 2;
    return 2;
  }

  double _summaryCardExtent(double width) {
    if (width >= 1200) return 165;
    if (width >= 900) return 160;
    if (width >= 760) return 156;
    if (width >= 360) return 168;
    return 176;
  }

  int _highlightCrossAxisCount(double width) {
    if (width >= 1180) return 4;
    if (width >= 760) return 2;
    return 1;
  }

  double _highlightExtent(double width) {
    if (width >= 1180) return 128;
    if (width >= 760) return 132;
    return 118;
  }

  Widget _buildBubble(double size, Color color) {
    return IgnorePointer(
      child: Container(
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
      ),
    );
  }

  Future<void> _openOrderDetails(OrderModel order) async {
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
      builder: (_) => _SalesHistoryDetailsSheet(
        order: order,
        details: details,
        productsById: productsById,
        formatCurrency: _formatCurrency,
        formatDateTime: _formatDateTime,
      ),
    );
  }

  Widget _buildHeader({
    required String producerName,
    required List<OrderModel> completedOrders,
    required List<OrderModel> filteredOrders,
  }) {
    final revenue = _totalRevenue(completedOrders);
    final average = _averageTicket(completedOrders);
    final visibleRevenue = _totalRevenue(filteredOrders);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5A483F),
            Color(0xFF7A5F47),
            Color(0xFFC89B5D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GlassActionButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              _GlassInfoTag(
                icon: Icons.sync_rounded,
                label: _formatLastSync(_lastSyncedAt),
              ),
              const SizedBox(width: 8),
              _GlassActionButton(
                icon: Icons.refresh_rounded,
                onTap: _isRefreshing ? null : _loadHistory,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Text(
              'Historial premium de ventas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.25,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Transacciones de $producerName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Consulta pedidos completados, revisa ingresos, detecta tickets altos y entra al detalle de cada venta desde una pantalla más elegante, más cómoda y más clara.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontSize: 13.6,
              height: 1.44,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderTag(
                icon: Icons.check_circle_rounded,
                label: '${completedOrders.length} completadas',
              ),
              _HeaderTag(
                icon: Icons.savings_rounded,
                label: _formatCurrency(revenue),
              ),
              _HeaderTag(
                icon: Icons.receipt_long_rounded,
                label: _formatCurrency(average),
              ),
              _HeaderTag(
                icon: Icons.visibility_rounded,
                label: _formatCurrency(visibleRevenue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsPanel({
    required List<OrderModel> completedOrders,
    required List<OrderModel> filteredOrders,
    required double width,
  }) {
    final topOrder = _highestOrder(filteredOrders);
    final latestOrder = _latestOrder(filteredOrders);
    final visibleRevenue = _totalRevenue(filteredOrders);
    final averageVisible = _averageTicket(filteredOrders);

    final items = [
      _HighlightCardData(
        title: 'Ventas visibles',
        value: '${filteredOrders.length}',
        subtitle: 'Resultados del filtro actual',
        icon: Icons.visibility_rounded,
        color: _purple,
      ),
      _HighlightCardData(
        title: 'Ingreso visible',
        value: _formatCurrency(visibleRevenue),
        subtitle: 'Monto de lo que estás viendo',
        icon: Icons.payments_rounded,
        color: _gold,
      ),
      _HighlightCardData(
        title: 'Mayor venta',
        value: topOrder == null ? '--' : _formatCurrency(topOrder.amount),
        subtitle: topOrder == null
            ? 'Sin registros'
            : 'Pedido #${topOrder.id ?? '--'}',
        icon: Icons.local_fire_department_rounded,
        color: _rose,
      ),
      _HighlightCardData(
        title: 'Última venta',
        value: latestOrder == null
            ? '--/--'
            : _formatShortDate(latestOrder.registerDate),
        subtitle: latestOrder == null
            ? 'Sin movimiento'
            : '${_formatTime(latestOrder.registerDate)} · ${_formatCurrency(averageVisible)} prom.',
        icon: Icons.history_rounded,
        color: _blue,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _highlightCrossAxisCount(width),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: _highlightExtent(width),
      ),
      itemBuilder: (_, index) => _HighlightCard(item: items[index]),
    );
  }

  Widget _buildSummaryGrid(List<OrderModel> orders, double width) {
    final latestDate = orders.isNotEmpty ? orders.first.registerDate : null;

    final items = [
      _SummaryCardData(
        title: 'Ventas',
        value: '${orders.length}',
        subtitle: 'Pedidos completados',
        icon: Icons.verified_rounded,
        color: _green,
      ),
      _SummaryCardData(
        title: 'Ingresos',
        value: _formatCurrency(_totalRevenue(orders)),
        subtitle: 'Monto cobrado',
        icon: Icons.payments_rounded,
        color: _gold,
      ),
      _SummaryCardData(
        title: 'Ticket prom.',
        value: _formatCurrency(_averageTicket(orders)),
        subtitle: 'Promedio por venta',
        icon: Icons.receipt_long_rounded,
        color: _blue,
      ),
      _SummaryCardData(
        title: 'Última venta',
        value: latestDate == null ? '--/--' : _formatShortDate(latestDate),
        subtitle: latestDate == null ? 'Sin registros' : _formatTime(latestDate),
        icon: Icons.history_toggle_off_rounded,
        color: _purple,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _summaryCrossAxisCount(width),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: _summaryCardExtent(width),
      ),
      itemBuilder: (_, index) => _SummaryCard(item: items[index]),
    );
  }

  Widget _buildControls({
    required int totalCount,
    required int filteredCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primary.withOpacity(0.22),
                      _gold.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: _primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Filtra y explora tu historial',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16.8,
                    fontWeight: FontWeight.w900,
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
                  '$filteredCount / $totalCount',
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Busca por pedido, cliente, dirección, notas o monto. También puedes combinarlo con filtros de fecha.',
              style: TextStyle(
                color: _textSoft,
                fontSize: 12.8,
                height: 1.35,
              ),
            ),
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
              hintText: 'Busca por # pedido, cliente, monto o dirección',
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
                vertical: 15,
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
                  onTap: () => setState(() => _selectedFilter = filter),
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
                      boxShadow: selected
                          ? [
                        BoxShadow(
                          color: _primary.withOpacity(0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                          : null,
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
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.filter_alt_rounded,
                          color: _primaryDark,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hay filtros activos en esta vista',
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 12.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedFilter = 'Todos';
                    });
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Limpiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryDark,
                    side: BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
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
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool hasSearch}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _primary.withOpacity(0.22),
                  _gold.withOpacity(0.10),
                ],
              ),
            ),
            child: Icon(
              Icons.history_toggle_off_rounded,
              size: 40,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? 'No hay coincidencias en el historial'
                : 'Todavía no hay ventas completadas',
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
                ? 'Prueba con otro texto, limpia los filtros o cambia el rango de tiempo para encontrar tus transacciones.'
                : 'Cuando cierres pedidos completados, aquí verás un historial más visual con ventas recientes, montos cobrados y acceso al detalle de cada transacción.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 13.8,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isRefreshing ? null : _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar historial'),
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

  Widget _buildSectionHeader({
    required int visibleCount,
    required double visibleRevenue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ventas recientes',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Registro cronológico de pedidos completados, montos cobrados y resumen rápido de cada transacción.',
                style: TextStyle(
                  color: _textSoft,
                  fontSize: 12.8,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: _surface.withOpacity(0.88),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Text(
                '$visibleCount visibles',
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(visibleRevenue),
              style: const TextStyle(
                color: _textDark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaleCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 20,
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
                top: Radius.circular(32),
              ),
              gradient: LinearGradient(
                colors: [
                  _green.withOpacity(0.16),
                  _gold.withOpacity(0.04),
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
                            Icons.receipt_long_rounded,
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
                        color: _green.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _green.withOpacity(0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: _green,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Completado',
                            style: TextStyle(
                              color: _green,
                              fontSize: 12.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Venta registrada ${_relativeDate(order.registerDate)}',
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDateTime(order.registerDate),
                            style: const TextStyle(
                              color: _textSoft,
                              fontSize: 12.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
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
                            'Monto cobrado',
                            style: TextStyle(
                              color: _textSoft,
                              fontSize: 12.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
                      value: _safeAddress(order),
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
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  decoration: BoxDecoration(
                    color: _surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (_hasNotes(order) ? _purple : _textSoft)
                              .withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _hasNotes(order)
                              ? Icons.sticky_note_2_rounded
                              : Icons.notes_rounded,
                          color: _hasNotes(order) ? _purple : _textSoft,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasNotes(order)
                                  ? 'Notas del pedido'
                                  : 'Sin notas registradas',
                              style: TextStyle(
                                color: _hasNotes(order) ? _textDark : _textSoft,
                                fontSize: 12.8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _notesPreview(order),
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
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openOrderDetails(order),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border:
                          Border.all(color: _green.withOpacity(0.18)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payments_rounded,
                              size: 18,
                              color: _green,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Venta cerrada',
                              style: TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
        children: const [
          Row(
            children: [
              _SkeletonBox(width: 100, height: 40, radius: 16),
              Spacer(),
              _SkeletonBox(width: 112, height: 34, radius: 999),
            ],
          ),
          SizedBox(height: 16),
          _SkeletonBox(width: double.infinity, height: 24, radius: 12),
          SizedBox(height: 10),
          _SkeletonBox(width: 220, height: 15, radius: 12),
          SizedBox(height: 16),
          _SkeletonBox(width: double.infinity, height: 92, radius: 20),
          SizedBox(height: 14),
          Row(
            children: [
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

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final orderController = context.watch<OrderController>();

    final currentUser = userController.currentUser;
    final allOrders = orderController.producerOrders;
    final completedOrders = _completedOrders(allOrders);
    final filteredOrders = _filteredOrders(completedOrders);

    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = _maxWidth(screenWidth);

    final isInitialLoading =
        orderController.isLoading &&
            allOrders.isEmpty &&
            _lastSyncedAt == null;

    return Scaffold(
      backgroundColor: _bgTop,
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
              top: -95,
              left: -65,
              child: _buildBubble(220, _primary.withOpacity(0.10)),
            ),
            Positioned(
              top: 180,
              right: -55,
              child: _buildBubble(170, _blue.withOpacity(0.08)),
            ),
            Positioned(
              bottom: 160,
              left: -40,
              child: _buildBubble(200, _green.withOpacity(0.07)),
            ),
            Positioned(
              bottom: -40,
              right: -10,
              child: _buildBubble(150, _gold.withOpacity(0.08)),
            ),
            Positioned(
              top: 320,
              left: -35,
              child: _buildBubble(120, _rose.withOpacity(0.06)),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: _primaryDark,
                onRefresh: _loadHistory,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: _pagePadding(screenWidth),
                      children: [
                        _buildHeader(
                          producerName: currentUser?.name ?? 'Tu tienda',
                          completedOrders: completedOrders,
                          filteredOrders: filteredOrders,
                        ),
                        const SizedBox(height: 14),
                        _buildHighlightsPanel(
                          completedOrders: completedOrders,
                          filteredOrders: filteredOrders,
                          width: screenWidth,
                        ),
                        const SizedBox(height: 14),
                        _buildSummaryGrid(completedOrders, screenWidth),
                        const SizedBox(height: 14),
                        _buildControls(
                          totalCount: completedOrders.length,
                          filteredCount: filteredOrders.length,
                        ),
                        const SizedBox(height: 14),
                        _buildSectionHeader(
                          visibleCount: filteredOrders.length,
                          visibleRevenue: _totalRevenue(filteredOrders),
                        ),
                        const SizedBox(height: 12),
                        if (currentUser == null || currentUser.id == null)
                          _buildEmptyState(hasSearch: false)
                        else if (isInitialLoading) ...[
                          _buildLoadingCard(),
                          const SizedBox(height: 12),
                          _buildLoadingCard(),
                        ] else if (filteredOrders.isEmpty)
                          _buildEmptyState(
                            hasSearch: _searchController.text.trim().isNotEmpty,
                          )
                        else
                          ...List.generate(filteredOrders.length, (index) {
                            final order = filteredOrders[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == filteredOrders.length - 1
                                    ? 0
                                    : 12,
                              ),
                              child: _buildSaleCard(order),
                            );
                          }),
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
  }
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GlassActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.14),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _GlassInfoTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassInfoTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

class _HighlightCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _HighlightCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _HighlightCard extends StatelessWidget {
  final _HighlightCardData item;

  const _HighlightCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFEADACA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A7360),
                    fontSize: 12.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A3428),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8A7360),
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
    return LayoutBuilder(
      builder: (_, constraints) {
        final compact = constraints.maxHeight < 160;

        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 16,
            compact ? 14 : 16,
            compact ? 14 : 16,
            compact ? 14 : 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
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
              Row(
                children: [
                  Container(
                    width: compact ? 42 : 46,
                    height: compact ? 42 : 46,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      item.icon,
                      color: item.color,
                      size: compact ? 20 : 22,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF8A7360),
                  fontSize: compact ? 12.2 : 12.6,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              SizedBox(height: compact ? 5 : 6),
              Text(
                item.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF4A3428),
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const Spacer(),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF8A7360),
                  fontSize: compact ? 11.4 : 12.0,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
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

class _SalesHistoryDetailsSheet extends StatelessWidget {
  final OrderModel order;
  final List<OrderDetailModel> details;
  final Map<int, ProductModel> productsById;
  final String Function(double value) formatCurrency;
  final String Function(DateTime? date) formatDateTime;

  const _SalesHistoryDetailsSheet({
    required this.order,
    required this.details,
    required this.productsById,
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
    if (address != null && address.isNotEmpty) return address;
    if (order.pickupLocationID > 0) return 'Ubicación ${order.pickupLocationID}';
    return 'Sin dirección registrada';
  }

  String get _orderNotes {
    final notes = order.notes?.trim();
    if (notes != null && notes.isNotEmpty) return notes;
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
    const green = Color(0xFF4B7D63);
    const blue = Color(0xFF5E7FA3);
    const divider = Color(0xFFE8DCCD);

    final height = MediaQuery.of(context).size.height * 0.90;

    return SafeArea(
      top: false,
      child: Container(
        height: height,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(34),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF5A483F),
                            Color(0xFF7A5F47),
                            Color(0xFFC89B5D),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Venta #${order.id ?? '--'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatDateTime(order.registerDate),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.85),
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
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _HeroDetailMetric(
                                  title: 'Monto',
                                  value: formatCurrency(order.amount),
                                  icon: Icons.payments_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _HeroDetailMetric(
                                  title: 'Unidades',
                                  value: '$_totalUnits',
                                  icon: Icons.inventory_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _HeroDetailMetric(
                                  title: 'Ítems',
                                  value: '${details.length}',
                                  icon: Icons.receipt_long_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
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
                                  value: 'Completado',
                                  subtitle: 'Transacción cerrada',
                                  icon: Icons.check_circle_rounded,
                                  color: green,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DetailStat(
                                  title: 'Cliente',
                                  value: 'ID ${order.clientID}',
                                  subtitle: 'Comprador',
                                  icon: Icons.person_rounded,
                                  color: primaryDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _DetailStat(
                                  title: 'Dirección',
                                  value: _deliveryAddress,
                                  subtitle: 'Punto de entrega',
                                  icon: Icons.location_on_rounded,
                                  color: const Color(0xFFBE6041),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DetailStat(
                                  title: 'Hora',
                                  value: formatDateTime(order.registerDate),
                                  subtitle: 'Registro de la venta',
                                  icon: Icons.schedule_rounded,
                                  color: blue,
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: surfaceSoft,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B6847).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.sticky_note_2_rounded,
                                  color: Color(0xFF8B6847),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Notas del pedido',
                                  style: TextStyle(
                                    color: textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                                fontStyle:
                                _hasNotes ? FontStyle.normal : FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Productos vendidos',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 18.5,
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
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: green.withOpacity(0.10),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 34,
                                  color: green,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No se encontraron productos en esta venta',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(details.length, (index) {
                        final detail = details[index];
                        final product = productsById[detail.productID];
                        final subtotal = detail.quantity * detail.unitPrice;

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
                                  width: 56,
                                  height: 56,
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
                          ),
                        );
                      }),
                  ],
                ),
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

class _HeroDetailMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _HeroDetailMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.8,
                    fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
            child: Icon(icon, color: color, size: 22),
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
                    fontSize: 11.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4A3428),
                    fontSize: 14.6,
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
                    fontSize: 11.2,
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
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.6,
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
        color: const Color(0xFFF1E6DA),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}