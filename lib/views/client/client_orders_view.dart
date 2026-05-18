import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/order_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import 'client_order_detail_view.dart';

class ClientOrdersView extends StatefulWidget {
  const ClientOrdersView({super.key});

  @override
  State<ClientOrdersView> createState() => _ClientOrdersViewState();
}

class _ClientOrdersViewState extends State<ClientOrdersView> {
  final TextEditingController _searchController = TextEditingController();

  _ClientOrdersFilter _selectedFilter = _ClientOrdersFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final userCtrl = context.read<UserController>();
    final orderCtrl = context.read<OrderController>();
    final client = userCtrl.currentUser;

    if (client?.id == null || client!.id! <= 0) {
      return;
    }

    await Future.wait([
      orderCtrl.loadOrdersByClient(client.id!),
      userCtrl.getAllProducers(),
    ]);
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _refresh() async {
    await _loadInitialData();
  }

  Future<void> _openOrderDetail(
      BuildContext context, {
        required OrderModel order,
        required UserModel? producer,
      }) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: ClientOrderDetailView(
            order: order,
            producer: producer,
          ),
        ),
      ),
    );

    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Consumer2<OrderController, UserController>(
          builder: (context, orderCtrl, userCtrl, _) {
            final client = userCtrl.currentUser;

            if (client == null || client.id == null || client.id! <= 0) {
              return _buildSessionErrorState(context);
            }

            final allOrders = orderCtrl.clientOrders;
            final filteredOrders = _applyFilters(
              orders: allOrders,
              producers: userCtrl.producers,
            );

            return RefreshIndicator(
              color: const Color(0xFF5A8A5A),
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildTopBar(context),
                        _buildHeroSection(
                          allOrders: allOrders,
                          filteredCount: filteredOrders.length,
                        ),
                        _buildSearchAndFilters(orders: allOrders),
                        if (orderCtrl.errorMessage != null &&
                            orderCtrl.errorMessage!.trim().isNotEmpty)
                          _buildInlineError(orderCtrl.errorMessage!),
                      ],
                    ),
                  ),
                  if (orderCtrl.isLoading && allOrders.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _OrdersLoadingState(),
                    )
                  else if (filteredOrders.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyOrdersState(
                        hasOrders: allOrders.isNotEmpty,
                        hasSearchOrFilter: _hasSearchOrFilterApplied,
                        onClearFilters: _clearFilters,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final order = filteredOrders[index];
                            final producer = _findProducer(
                              userCtrl.producers,
                              order.producerID,
                            );

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                index == filteredOrders.length - 1 ? 0 : 12,
                              ),
                              child: _OrderCard(
                                order: order,
                                producer: producer,
                                onTap: () => _openOrderDetail(
                                  context,
                                  order: order,
                                  producer: producer,
                                ),
                              ),
                            );
                          },
                          childCount: filteredOrders.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF2D2D2D),
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
              elevation: 2,
              shadowColor: Colors.black12,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mis pedidos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Consulta tus compras, estados y movimientos recientes',
                  style: TextStyle(
                    fontSize: 12.8,
                    color: Color(0xFF7A736B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7DED2)),
            ),
            child: IconButton(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF5A8A5A),
              ),
              tooltip: 'Actualizar',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection({
    required List<OrderModel> allOrders,
    required int filteredCount,
  }) {
    final activeCount = allOrders.where(_isActiveState).length;
    final completedCount = allOrders
        .where((order) => order.state == OrderController.stateCompleted)
        .length;
    final cancelledCount = allOrders
        .where((order) => order.state == OrderController.stateCancelled)
        .length;
    final totalSpent = allOrders
        .where((order) => order.state != OrderController.stateCancelled)
        .fold<double>(0.0, (sum, order) => sum + order.amount);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5A8A5A),
            Color(0xFF7AA37A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A8A5A).withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historial del cliente',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allOrders.isEmpty
                          ? 'Aún no tienes pedidos registrados'
                          : 'Mostrando $filteredCount de ${allOrders.length} pedido(s)',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStatCard(
                  title: 'Activos',
                  value: '$activeCount',
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStatCard(
                  title: 'Completados',
                  value: '$completedCount',
                  icon: Icons.task_alt_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _HeroStatCard(
                  title: 'Cancelados',
                  value: '$cancelledCount',
                  icon: Icons.cancel_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroStatCard(
                  title: 'Gastado',
                  value: '${totalSpent.toStringAsFixed(0)} monedas',
                  icon: Icons.monetization_on_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters({required List<OrderModel> orders}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar por empresa, pedido o dirección',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF7A736B),
              ),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF7A736B),
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F5EF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _ClientOrdersFilter.values.map((filter) {
                final selected = _selectedFilter == filter;
                final count = _countForFilter(orders, filter);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    showCheckmark: false,
                    label: Text(
                      '${filter.label} ($count)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                        selected ? Colors.white : const Color(0xFF5C544B),
                      ),
                    ),
                    selectedColor: const Color(0xFF5A8A5A),
                    backgroundColor: const Color(0xFFF5F0E8),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF5A8A5A)
                          : const Color(0xFFE0D8CE),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD0C1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD96C2F),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8B4A2C),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EC),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.person_off_outlined,
                size: 42,
                color: Color(0xFFD96C2F),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No se encontró una sesión válida',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vuelve al dashboard anterior e inicia nuevamente la carga del flujo del cliente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7A736B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A8A5A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Volver',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OrderModel> _applyFilters({
    required List<OrderModel> orders,
    required List<UserModel> producers,
  }) {
    final query = _searchController.text.trim().toLowerCase();

    return orders.where((order) {
      final matchesFilter = switch (_selectedFilter) {
        _ClientOrdersFilter.all => true,
        _ClientOrdersFilter.active => _isActiveState(order),
        _ClientOrdersFilter.pending =>
        order.state == OrderController.statePending,
        _ClientOrdersFilter.completed =>
        order.state == OrderController.stateCompleted,
        _ClientOrdersFilter.cancelled =>
        order.state == OrderController.stateCancelled,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      final producer = _findProducer(producers, order.producerID);
      final producerName = (producer?.name ?? '').toLowerCase();
      final address = (order.pickupLocationAddress ?? '').toLowerCase();
      final orderId = '#${order.id ?? 0}'.toLowerCase();
      final statusText = _statusFor(order.state).label.toLowerCase();

      return producerName.contains(query) ||
          address.contains(query) ||
          orderId.contains(query) ||
          statusText.contains(query);
    }).toList();
  }

  UserModel? _findProducer(List<UserModel> producers, int producerId) {
    try {
      return producers.firstWhere((producer) => producer.id == producerId);
    } catch (_) {
      return null;
    }
  }

  bool get _hasSearchOrFilterApplied {
    return _searchController.text.trim().isNotEmpty ||
        _selectedFilter != _ClientOrdersFilter.all;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedFilter = _ClientOrdersFilter.all;
    });
  }

  int _countForFilter(List<OrderModel> orders, _ClientOrdersFilter filter) {
    switch (filter) {
      case _ClientOrdersFilter.all:
        return orders.length;
      case _ClientOrdersFilter.active:
        return orders.where(_isActiveState).length;
      case _ClientOrdersFilter.pending:
        return orders
            .where((order) => order.state == OrderController.statePending)
            .length;
      case _ClientOrdersFilter.completed:
        return orders
            .where((order) => order.state == OrderController.stateCompleted)
            .length;
      case _ClientOrdersFilter.cancelled:
        return orders
            .where((order) => order.state == OrderController.stateCancelled)
            .length;
    }
  }

  bool _isActiveState(OrderModel order) {
    return order.state == OrderController.statePending ||
        order.state == OrderController.statePreparing ||
        order.state == OrderController.stateShipped;
  }
}

enum _ClientOrdersFilter {
  all('Todos'),
  active('Activos'),
  pending('Pendientes'),
  completed('Completados'),
  cancelled('Cancelados');

  final String label;

  const _ClientOrdersFilter(this.label);
}

class _HeroStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _HeroStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
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

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final UserModel? producer;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.producer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(order.state);
    final dateText = _formatOrderDate(order.registerDate);
    final timeText = _formatOrderTime(order.registerDate);
    final producerName = producer?.name.trim().isNotEmpty == true
        ? producer!.name.trim()
        : 'Empresa #${order.producerID}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'client-order-producer-${order.id ?? order.hashCode}',
                      child: AppImage(
                        src: producer?.image,
                        width: 58,
                        height: 58,
                        borderRadius: 18,
                        placeholder: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF4EA),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Color(0xFF5A8A5A),
                            size: 28,
                          ),
                        ),
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
                                  producerName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusPill(status: status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pedido #${order.id ?? 0}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7A736B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dateText • $timeText',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A938A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _InfoStripe(
                  icon: Icons.location_on_outlined,
                  title: 'Entrega / recojo',
                  value: (order.pickupLocationAddress ?? '').trim().isEmpty
                      ? 'Dirección no disponible'
                      : order.pickupLocationAddress!.trim(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MiniInfoCard(
                        icon: Icons.monetization_on_outlined,
                        label: 'Monto',
                        value: '${order.amount.toStringAsFixed(0)} monedas',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniInfoCard(
                        icon: status.icon,
                        label: 'Estado actual',
                        value: status.label,
                      ),
                    ),
                  ],
                ),
                if ((order.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5EF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notes_rounded,
                          size: 18,
                          color: Color(0xFF7A736B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.notes!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF5C544B),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEAF4EA), Color(0xFFF6FBF6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD7E8D7)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: Color(0xFF5A8A5A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Ver detalle completo y seguimiento',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3E623E),
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A8A5A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoStripe extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoStripe({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF5A8A5A)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A736B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2D2D),
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
}

class _MiniInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniInfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF5A8A5A)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.8,
                    color: Color(0xFF7A736B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.2,
              color: Color(0xFF2D2D2D),
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final _OrderStatusUi status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.foreground),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: status.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersLoadingState extends StatelessWidget {
  const _OrdersLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: List.generate(
          3,
              (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1ECE4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _SkeletonLine(widthFactor: 0.85),
                          const SizedBox(height: 8),
                          _SkeletonLine(widthFactor: 0.55),
                          const SizedBox(height: 8),
                          _SkeletonLine(widthFactor: 0.40),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const _SkeletonBox(height: 56),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Expanded(child: _SkeletonBox(height: 68)),
                    SizedBox(width: 10),
                    Expanded(child: _SkeletonBox(height: 68)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;

  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: const _SkeletonBox(height: 12),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;

  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECE4),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  final bool hasOrders;
  final bool hasSearchOrFilter;
  final VoidCallback onClearFilters;

  const _EmptyOrdersState({
    required this.hasOrders,
    required this.hasSearchOrFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final title = hasOrders
        ? 'No encontramos pedidos con ese filtro'
        : 'Todavía no tienes pedidos';
    final message = hasOrders
        ? 'Prueba cambiando la búsqueda o el filtro para ver otros resultados.'
        : 'Cuando confirmes una compra, tus pedidos aparecerán aquí para que puedas revisarlos fácilmente.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4EA),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 46,
                color: Color(0xFF5A8A5A),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF7A736B),
                height: 1.45,
              ),
            ),
            if (hasSearchOrFilter) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text(
                  'Limpiar filtros',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A8A5A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderStatusUi {
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;

  const _OrderStatusUi({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });
}

_OrderStatusUi _statusFor(int state) {
  switch (state) {
    case OrderController.statePending:
      return const _OrderStatusUi(
        label: 'Pendiente',
        icon: Icons.schedule_rounded,
        foreground: Color(0xFFD17B00),
        background: Color(0xFFFFF3DD),
        border: Color(0xFFFFE1A6),
      );
    case OrderController.statePreparing:
      return const _OrderStatusUi(
        label: 'En preparación',
        icon: Icons.restaurant_outlined,
        foreground: Color(0xFF8A5A00),
        background: Color(0xFFFFF0D8),
        border: Color(0xFFFFD8A0),
      );
    case OrderController.stateShipped:
      return const _OrderStatusUi(
        label: 'Enviado',
        icon: Icons.local_shipping_outlined,
        foreground: Color(0xFF2F6D99),
        background: Color(0xFFE9F5FF),
        border: Color(0xFFBFDCF2),
      );
    case OrderController.stateCompleted:
      return const _OrderStatusUi(
        label: 'Completado',
        icon: Icons.task_alt_rounded,
        foreground: Color(0xFF3D7A3D),
        background: Color(0xFFEAF4EA),
        border: Color(0xFFCBE1CB),
      );
    case OrderController.stateCancelled:
      return const _OrderStatusUi(
        label: 'Cancelado',
        icon: Icons.cancel_outlined,
        foreground: Color(0xFFC24D4D),
        background: Color(0xFFFFECEC),
        border: Color(0xFFF6C6C6),
      );
    default:
      return const _OrderStatusUi(
        label: 'Desconocido',
        icon: Icons.help_outline_rounded,
        foreground: Color(0xFF7A736B),
        background: Color(0xFFF1ECE4),
        border: Color(0xFFE0D8CE),
      );
  }
}

String _formatOrderDate(DateTime? date) {
  if (date == null) return 'Fecha no disponible';

  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  return '$day $month $year';
}

String _formatOrderTime(DateTime? date) {
  if (date == null) return '--:--';

  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
