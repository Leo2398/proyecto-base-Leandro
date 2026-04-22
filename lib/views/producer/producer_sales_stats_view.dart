import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/order_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
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
  static const Color _bgTop = Color(0xFFF7F2EA);
  static const Color _bgMid = Color(0xFFF2E8DB);
  static const Color _bgBottom = Color(0xFFE7D8C6);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF8F2E9);

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

  static const int _currentNavIndex = 3;

  DateTime? _lastSyncedAt;
  bool _isRefreshing = false;
  bool _productsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadStats();
    });
  }

  Future<void> _loadStats() async {
    if (!mounted || _isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final userController = context.read<UserController>();
      final orderController = context.read<OrderController>();
      final productController = context.read<ProductController>();

      final user = userController.currentUser;
      if (user == null || user.id == null || user.id! <= 0) return;

      await Future.wait([
        orderController.loadProducerSalesStats(user.id!),
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
    return '$day/$month/${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '--:--';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatLastSync(DateTime? date) {
    if (date == null) return 'Sin sincronizar';
    return 'Act. ${_formatTime(date)} · ${_formatDate(date)}';
  }

  EdgeInsets _pagePadding(double width) {
    if (width >= 1200) {
      return const EdgeInsets.fromLTRB(28, 16, 28, 170);
    }
    if (width >= 800) {
      return const EdgeInsets.fromLTRB(20, 14, 20, 170);
    }
    return const EdgeInsets.fromLTRB(16, 12, 16, 170);
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
    if (width >= 760) return 158;
    if (width >= 360) return 172;
    return 178;
  }

  int _heroMetricCount(double width) {
    if (width >= 1000) return 4;
    if (width >= 650) return 2;
    return 2;
  }

  double _heroMetricAspectRatio(double width) {
    if (width >= 1200) return 1.8;
    if (width >= 850) return 1.52;
    if (width >= 360) return 1.22;
    return 1.05;
  }

  int _productGridCount(double width) {
    if (width >= 1300) return 3;
    if (width >= 850) return 2;
    return 1;
  }

  double _safeRatio(int completed, int total) {
    if (total <= 0) return 0;
    return completed / total;
  }

  ProductModel? _findProductById(List<ProductModel> products, int productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
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
        const SnackBar(
          content: Text('Producto publicado correctamente'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        await _goToOrders();
        break;
      case 3:
        await _loadStats();
        break;
      case 4:
        await _goToCoins();
        break;
      case 5:
        await _goToProfile();
        break;
    }
  }

  Widget _buildTopHeader({
    required String producerName,
  }) {
    final initial = producerName.trim().isNotEmpty
        ? producerName.trim().characters.first.toUpperCase()
        : 'P';

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [_primary, Color(0xFFB9854A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ventas y estadísticas',
                style: TextStyle(
                  color: _textSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                producerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatLastSync(_lastSyncedAt),
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildSmallIconButton(
          icon: Icons.history_rounded,
          onTap: _goToSalesHistory,
        ),
        const SizedBox(width: 8),
        _buildSmallIconButton(
          icon: Icons.refresh_rounded,
          onTap: _loadStats,
        ),
      ],
    );
  }

  Widget _buildSmallIconButton({
    required IconData icon,
    required Future<void> Function() onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          onTap();
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.94),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Icon(
            icon,
            color: _primaryDark,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required String producerName,
    required ProducerSalesStats stats,
    required List<ProductModel> products,
    required double screenWidth,
  }) {
    final totalProducts = products.length;
    final completedRate =
    (_safeRatio(stats.completedOrders, stats.totalOrders) * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5A4A41),
            Color(0xFF443832),
            Color(0xFF302826),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _HeroTag(
                icon: Icons.trending_up_rounded,
                label: '${stats.completedOrders} ventas cerradas',
              ),
              _HeroTag(
                icon: Icons.inventory_2_outlined,
                label: '$totalProducts productos',
              ),
              _HeroTag(
                icon: Icons.auto_graph_rounded,
                label: '$completedRate% efectividad',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Haz crecer las ventas de $producerName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Un panel elegante para revisar ingresos, pedidos completados, ticket promedio y tus productos más vendidos sin salir del módulo del productor.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 13.4,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: _heroMetricCount(screenWidth),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: _heroMetricAspectRatio(screenWidth),
            children: [
              _HeroMetric(
                title: 'Ingresos',
                value: _formatCurrency(stats.deliveredRevenue),
                icon: Icons.savings_rounded,
              ),
              _HeroMetric(
                title: 'Completados',
                value: '${stats.completedOrders}',
                icon: Icons.verified_rounded,
              ),
              _HeroMetric(
                title: 'Ticket prom.',
                value: _formatCurrency(stats.averageTicket),
                icon: Icons.receipt_long_rounded,
              ),
              _HeroMetric(
                title: 'Gestionado',
                value: _formatCurrency(stats.managedAmount),
                icon: Icons.payments_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _goToOrders,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _textDark,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text(
                    'Ver pedidos',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _goToProducts,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.14),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text(
                    'Ver productos',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _goToSalesHistory,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.32)),
                backgroundColor: Colors.white.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text(
                'Ir al historial de ventas',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid({
    required ProducerSalesStats stats,
    required double width,
  }) {
    final items = [
      _SummaryCardData(
        title: 'Pedidos totales',
        value: '${stats.totalOrders}',
        subtitle: 'Todos los pedidos registrados',
        icon: Icons.shopping_bag_rounded,
        color: _primaryDark,
      ),
      _SummaryCardData(
        title: 'Pendientes',
        value: '${stats.pendingOrders}',
        subtitle: 'Aún requieren atención',
        icon: Icons.pending_actions_rounded,
        color: _orange,
      ),
      _SummaryCardData(
        title: 'Aceptados',
        value: '${stats.acceptedOrders}',
        subtitle: 'Pedidos confirmados',
        icon: Icons.inventory_2_rounded,
        color: _blue,
      ),
      _SummaryCardData(
        title: 'Cancelados',
        value: '${stats.cancelledOrders}',
        subtitle: 'Pedidos anulados',
        icon: Icons.cancel_rounded,
        color: _red,
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

  Widget _buildInsightSection({
    required ProducerSalesStats stats,
    required double width,
  }) {
    final completion = (_safeRatio(stats.completedOrders, stats.totalOrders) * 100)
        .clamp(0.0, 100.0);
    final attentionNeeded = stats.pendingOrders + stats.cancelledOrders;
    final isWide = width >= 860;

    final performanceCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.95),
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
          const Text(
            'Rendimiento de cierre',
            style: TextStyle(
              color: _textDark,
              fontSize: 16.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${completion.toStringAsFixed(0)}% de tus pedidos terminaron entregados.',
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12.8,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completion / 100,
              minHeight: 13,
              backgroundColor: const Color(0xFFE9DCCB),
              valueColor: const AlwaysStoppedAnimation(_green),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SoftKpi(
                  title: 'Completados',
                  value: '${stats.completedOrders}',
                  color: _green,
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SoftKpi(
                  title: 'Monto cobrado',
                  value: _formatCurrency(stats.deliveredRevenue),
                  color: _gold,
                  icon: Icons.payments_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final sideCards = Column(
      children: [
        _MiniInsightCard(
          title: 'Atención requerida',
          value: '$attentionNeeded',
          subtitle: 'Pendientes + cancelados',
          icon: Icons.notifications_active_rounded,
          color: attentionNeeded > 0 ? _orange : _green,
        ),
        const SizedBox(height: 12),
        _MiniInsightCard(
          title: 'Ticket promedio',
          value: _formatCurrency(stats.averageTicket),
          subtitle: 'Promedio de ventas entregadas',
          icon: Icons.receipt_long_rounded,
          color: _blue,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visión general del negocio',
          style: TextStyle(
            color: _textDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Lectura rápida, limpia y bonita para saber cómo va tu operación.',
          style: TextStyle(
            color: _textSoft,
            fontSize: 12.8,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: performanceCard),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: sideCards),
            ],
          )
        else ...[
          performanceCard,
          const SizedBox(height: 12),
          sideCards,
        ],
      ],
    );
  }

  Widget _buildTopProductsSection({
    required List<TopSellingProductStat> topProducts,
    required List<ProductModel> products,
    required double width,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productos más vendidos',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Lo más fuerte de tu catálogo, ordenado por cantidad vendida.',
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 12.8,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
              ),
              child: Text(
                '${topProducts.length} destacados',
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (topProducts.isEmpty)
          _buildTopProductsEmpty()
        else
          GridView.builder(
            itemCount: topProducts.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _productGridCount(width),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: width >= 1200
                  ? 1.18
                  : width >= 850
                  ? 1.04
                  : 0.98,
            ),
            itemBuilder: (_, index) {
              final stat = topProducts[index];
              final product = _findProductById(products, stat.productID);
              return _TopProductCard(
                rank: index + 1,
                stat: stat,
                product: product,
                formatCurrency: _formatCurrency,
              );
            },
          ),
      ],
    );
  }

  Widget _buildTopProductsEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primary.withOpacity(0.12),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: _primaryDark,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aún no hay ranking de productos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textDark,
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuando existan pedidos entregados con detalle registrado, aquí aparecerán tus productos más vendidos con un diseño tipo panel comercial.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStatsView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.95),
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
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              size: 36,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Todavía no hay estadísticas disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textDark,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuando existan pedidos o ventas registradas para este productor, aquí verás el resumen comercial completo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isRefreshing ? null : _loadStats,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: _isRefreshing
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.refresh_rounded),
            label: Text(
              _isRefreshing ? 'Actualizando...' : 'Actualizar estadísticas',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _goToSalesHistory,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryDark,
              side: BorderSide(color: _border),
              backgroundColor: _surfaceSoft,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
            label: const Text(
              'Ir al historial de ventas',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUserView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.person_off_rounded,
            size: 44,
            color: _primaryDark,
          ),
          SizedBox(height: 12),
          Text(
            'No se encontró un productor válido',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Vuelve a iniciar sesión para cargar correctamente tus estadísticas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final items = <_BottomNavData>[
      const _BottomNavData(
        icon: Icons.grid_view_rounded,
        label: 'Inicio',
        index: 0,
      ),
      const _BottomNavData(
        icon: Icons.storefront_rounded,
        label: 'Productos',
        index: 1,
      ),
      const _BottomNavData(
        icon: Icons.receipt_long_rounded,
        label: 'Pedidos',
        index: 2,
      ),
      const _BottomNavData(
        icon: Icons.bar_chart_rounded,
        label: 'Ventas',
        index: 3,
      ),
      const _BottomNavData(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Monedas',
        index: 4,
      ),
      const _BottomNavData(
        icon: Icons.person_outline_rounded,
        label: 'Perfil',
        index: 5,
      ),
    ];

    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 94,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.70)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: _buildBottomNavItem(items[0], selected: false)),
                Expanded(child: _buildBottomNavItem(items[1], selected: false)),
                Expanded(child: _buildBottomNavItem(items[2], selected: false)),
                const SizedBox(width: 72),
                Expanded(child: _buildBottomNavItem(items[3], selected: true)),
                Expanded(child: _buildBottomNavItem(items[4], selected: false)),
                Expanded(child: _buildBottomNavItem(items[5], selected: false)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(_BottomNavData item, {required bool selected}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _onBottomNavigationTap(item.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 22,
                color: selected ? _primary : _textSoft,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? _primary : _textSoft,
                  fontSize: 11.2,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Column(
      children: [
        _LoadingHeroCard(),
        SizedBox(height: 14),
        _LoadingSummaryGrid(),
        SizedBox(height: 14),
        _LoadingInsights(),
        SizedBox(height: 14),
        _LoadingTopProducts(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final orderController = context.watch<OrderController>();
    final productController = context.watch<ProductController>();

    final currentUser = userController.currentUser;
    final producerName = currentUser?.name ?? 'Tu tienda';

    final hasStats = orderController.hasProducerSalesStats;
    final ProducerSalesStats? stats =
    hasStats ? orderController.producerSalesStats : null;

    final products = productController.products;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = _maxWidth(screenWidth);

    final isInitialLoading = orderController.isLoadingProducerStats &&
        !orderController.hasProducerSalesStats &&
        _lastSyncedAt == null;

    return Scaffold(
      extendBody: true,
      backgroundColor: _bgTop,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton(
          backgroundColor: _primary,
          elevation: 12,
          onPressed: _openCreateProduct,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
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
              top: -95,
              left: -65,
              child: _buildBubble(220, _primary.withOpacity(0.10)),
            ),
            Positioned(
              top: 160,
              right: -55,
              child: _buildBubble(170, _gold.withOpacity(0.10)),
            ),
            Positioned(
              bottom: 180,
              left: -45,
              child: _buildBubble(190, _green.withOpacity(0.07)),
            ),
            Positioned(
              bottom: -50,
              right: -15,
              child: _buildBubble(140, _blue.withOpacity(0.07)),
            ),
            SafeArea(
              child: RefreshIndicator(
                color: _primaryDark,
                onRefresh: _loadStats,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: _pagePadding(screenWidth),
                      children: [
                        _buildTopHeader(producerName: producerName),
                        const SizedBox(height: 16),
                        if (currentUser == null || currentUser.id == null)
                          _buildNoUserView()
                        else if (isInitialLoading)
                          _buildLoadingView()
                        else if (stats == null)
                            _buildNoStatsView()
                          else ...[
                              _buildHeroCard(
                                producerName: producerName,
                                stats: stats,
                                products: products,
                                screenWidth: screenWidth,
                              ),
                              const SizedBox(height: 14),
                              _buildSummaryGrid(
                                stats: stats,
                                width: screenWidth,
                              ),
                              const SizedBox(height: 14),
                              _buildInsightSection(
                                stats: stats,
                                width: screenWidth,
                              ),
                              const SizedBox(height: 14),
                              _buildTopProductsSection(
                                topProducts: stats.topProducts,
                                products: products,
                                width: screenWidth,
                              ),
                            ],
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

class _HeroTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _HeroMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
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
        final compact = constraints.maxHeight < 165;

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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEADACA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
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

class _SoftKpi extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SoftKpi({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _ProducerSalesStatsViewState._surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ProducerSalesStatsViewState._border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 19),
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
                    color: _ProducerSalesStatsViewState._textSoft,
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
                    color: _ProducerSalesStatsViewState._textDark,
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

class _TopProductCard extends StatelessWidget {
  final int rank;
  final TopSellingProductStat stat;
  final ProductModel? product;
  final String Function(double) formatCurrency;

  const _TopProductCard({
    required this.rank,
    required this.stat,
    required this.product,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFFFFFFF);
    const border = Color(0xFFEADACA);
    const textDark = Color(0xFF4A3428);
    const textSoft = Color(0xFF8A7360);
    const primary = Color(0xFFC89B5D);
    const primaryDark = Color(0xFF8B6847);
    const gold = Color(0xFFE5BB7A);
    const green = Color(0xFF4B7D63);
    const blue = Color(0xFF5E7FA3);

    return Container(
      decoration: BoxDecoration(
        color: surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
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
            height: 165,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF3EBDD),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              gradient: LinearGradient(
                colors: [
                  primary.withOpacity(0.12),
                  gold.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: product?.picture != null &&
                      product!.picture!.trim().isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      product!.picture!,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return _buildFallbackIcon();
                      },
                    ),
                  )
                      : _buildFallbackIcon(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product?.name ?? 'Producto ID ${stat.productID}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product?.description?.trim().isNotEmpty == true
                        ? product!.description!
                        : 'Uno de los productos con mejor salida dentro de tus pedidos entregados.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textSoft,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SmallChip(
                        icon: Icons.shopping_cart_checkout_rounded,
                        text: '${stat.totalQuantity} vendidas',
                        color: green,
                      ),
                      _SmallChip(
                        icon: Icons.attach_money_rounded,
                        text: formatCurrency(stat.totalRevenue),
                        color: blue,
                      ),
                      _SmallChip(
                        icon: Icons.receipt_long_rounded,
                        text: '${stat.totalOrders} pedidos',
                        color: primaryDark,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: primaryDark,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product?.unit?.trim().isNotEmpty == true
                                ? 'Unidad: ${product!.unit}'
                                : 'ID interno: ${stat.productID}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textSoft,
                              fontSize: 12.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildFallbackIcon() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.76),
        border: Border.all(color: const Color(0xFFEADACA)),
      ),
      child: const Icon(
        Icons.eco_rounded,
        color: Color(0xFF8B6847),
        size: 42,
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SmallChip({
    required this.icon,
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
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingHeroCard extends StatelessWidget {
  const _LoadingHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFB98E59),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              _Skeleton(width: 110, height: 30, radius: 18, dark: true),
              Spacer(),
              _Skeleton(width: 120, height: 28, radius: 999, dark: true),
            ],
          ),
          SizedBox(height: 16),
          _Skeleton(
            width: double.infinity,
            height: 30,
            radius: 12,
            dark: true,
          ),
          SizedBox(height: 10),
          _Skeleton(width: 250, height: 14, radius: 12, dark: true),
          SizedBox(height: 14),
          _Skeleton(
            width: double.infinity,
            height: 96,
            radius: 22,
            dark: true,
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Skeleton(
                  width: double.infinity,
                  height: 50,
                  radius: 18,
                  dark: true,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _Skeleton(
                  width: double.infinity,
                  height: 50,
                  radius: 18,
                  dark: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingSummaryGrid extends StatelessWidget {
  const _LoadingSummaryGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: _SkeletonCard()),
            SizedBox(width: 12),
            Expanded(child: _SkeletonCard()),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SkeletonCard()),
            SizedBox(width: 12),
            Expanded(child: _SkeletonCard()),
          ],
        ),
      ],
    );
  }
}

class _LoadingInsights extends StatelessWidget {
  const _LoadingInsights();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Skeleton(
          width: double.infinity,
          height: 200,
          radius: 28,
        ),
        SizedBox(height: 12),
      ],
    );
  }
}

class _LoadingTopProducts extends StatelessWidget {
  const _LoadingTopProducts();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(child: _Skeleton(width: 170, height: 24, radius: 12)),
            SizedBox(width: 12),
            _Skeleton(width: 108, height: 34, radius: 14),
          ],
        ),
        SizedBox(height: 12),
        _Skeleton(width: double.infinity, height: 270, radius: 28),
        SizedBox(height: 12),
        _Skeleton(width: double.infinity, height: 270, radius: 28),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEADACA)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Skeleton(width: 46, height: 46, radius: 16),
          SizedBox(height: 14),
          _Skeleton(width: 90, height: 14, radius: 10),
          SizedBox(height: 8),
          _Skeleton(width: 70, height: 24, radius: 10),
          Spacer(),
          _Skeleton(width: 120, height: 13, radius: 10),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final bool dark;

  const _Skeleton({
    required this.width,
    required this.height,
    required this.radius,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(0.18)
            : const Color(0xFFF0E6DA),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}