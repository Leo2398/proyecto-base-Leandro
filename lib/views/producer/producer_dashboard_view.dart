import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/product_model.dart';
import 'producer_create_product_view.dart';
import 'producer_products_view.dart';
import '../auth/login_view.dart';
import 'package:provider/provider.dart';

class ProducerDashboardView extends StatefulWidget {
  const ProducerDashboardView({super.key});

  @override
  State<ProducerDashboardView> createState() => _ProducerDashboardViewState();
}

class _ProducerDashboardViewState extends State<ProducerDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final userController = Provider.of<UserController>(context, listen: false);
    final productController =
    Provider.of<ProductController>(context, listen: false);

    final currentUser = userController.currentUser;

    if (currentUser == null || currentUser.id == null) return;

    await productController.getProductsByProducer(currentUser.id!);
  }

  List<ProductModel> _recentProducts(List<ProductModel> products) {
    return products.take(3).toList();
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

  String _money(double value) {
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
    if (product.stock == 0) return const Color(0xFFD96C2F);
    if (product.stock <= 3) return const Color(0xFFD96C2F);
    return const Color(0xFF2E8B57);
  }

  double _availabilityPercent(List<ProductModel> products) {
    if (products.isEmpty) return 0;
    return _activeProducts(products) / products.length;
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

  Future<void> _replenishProduct(ProductModel product) async {
    if (product.id == null) return;

    final productController =
    Provider.of<ProductController>(context, listen: false);

    final newStock = product.stock + 10;
    final success = await productController.updateStock(product.id!, newStock);

    if (!mounted) return;

    if (success) {
      await _loadDashboardData();
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

  double _maxWidth(double screenWidth) {
    if (screenWidth >= 1400) return 1120;
    if (screenWidth >= 1100) return 980;
    if (screenWidth >= 800) return 820;
    return screenWidth;
  }

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final productController = context.watch<ProductController>();
    final screenWidth = MediaQuery.of(context).size.width;

    final products = productController.products;
    final recentProducts = _recentProducts(products);
    final lowStockProducts = _lowStockProducts(products);
    final soldOutProducts = _soldOutProducts(products);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF5F0E8),
              Color(0xFFF7F2EA),
              Color(0xFFF2ECE2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadDashboardData,
            color: const Color(0xFFC69A5B),
            child: productController.isLoading
                ? ListView(
              children: const [
                SizedBox(height: 220),
                Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFC69A5B),
                  ),
                ),
              ],
            )
                : ListView(
              padding: EdgeInsets.zero,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _maxWidth(screenWidth),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(userController),
                          const SizedBox(height: 18),
                          _buildHeroCard(userController, products),
                          const SizedBox(height: 18),
                          _buildKpiGrid(products),
                          const SizedBox(height: 18),
                          _buildCollectionStatus(products),
                          const SizedBox(height: 18),
                          _buildSectionTitle(
                            title: 'Productos recientes',
                            actionText: 'Ver productos',
                            onTap: _goToProducts,
                          ),
                          const SizedBox(height: 12),
                          if (recentProducts.isEmpty)
                            _buildEmptyCard(
                              icon: Icons.inventory_2_outlined,
                              title: 'Aún no tienes productos publicados',
                              subtitle:
                              'Publica tu primer producto para que tu catálogo empiece a verse completo.',
                            )
                          else
                            ...recentProducts
                                .map(_buildRecentProductCard),
                          const SizedBox(height: 18),
                          _buildSectionTitle(
                            title: 'Alertas del catálogo',
                            actionText: lowStockProducts.isNotEmpty
                                ? 'Revisar'
                                : null,
                            onTap: lowStockProducts.isNotEmpty
                                ? _goToProducts
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _buildAlertsPanel(
                            lowStockProducts: lowStockProducts,
                            soldOutProducts: soldOutProducts,
                          ),
                          const SizedBox(height: 18),
                          _buildSectionTitle(
                            title: 'Acciones rápidas',
                            actionText: null,
                          ),
                          const SizedBox(height: 12),
                          _buildQuickActions(),
                          const SizedBox(height: 18),
                          _buildBottomShowcase(products),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFC7942E),
        elevation: 8,
        onPressed: _goToCreateProduct,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Publicar producto',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(UserController userController) {
    final user = userController.currentUser;
    final initial = (user?.name.isNotEmpty ?? false)
        ? user!.name[0].toUpperCase()
        : 'P';

    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFFC69A5B),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC69A5B).withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
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
                'Dashboard del productor',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF9B8976),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userController.currentUser?.name ?? 'Productor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E3426),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.monetization_on_outlined,
                color: Color(0xFFC7942E),
                size: 18,
              ),
              const SizedBox(width: 5),
              Text(
                '${userController.currentUser?.balance.toStringAsFixed(0) ?? '0'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E3426),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            final controller = Provider.of<UserController>(context, listen: false);
            await controller.logout();

            if (!context.mounted) return;

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginView()),
                  (route) => false,
            );
          },
          icon: const Icon(
            Icons.logout_rounded,
            color: Color(0xFF4E3426),
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(10),
            elevation: 2,
            shadowColor: Colors.black12,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(UserController userController, List<ProductModel> products) {
    final active = _activeProducts(products);
    final lowStock = _lowStockProducts(products).length;
    final totalUnits = _totalUnits(products);
    final inventoryValue = _inventoryValue(products);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6B625A),
            Color(0xFF4F4842),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -12,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -14,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
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
                    _buildHeroChip(
                      icon: Icons.eco_outlined,
                      text: 'Catálogo agrícola',
                    ),
                    _buildHeroChip(
                      icon: Icons.workspace_premium_outlined,
                      text: 'Panel premium',
                    ),
                    _buildHeroChip(
                      icon: Icons.bolt_outlined,
                      text: 'Gestión rápida',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tu negocio se ve más ordenado,\nbonito y listo para vender.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Controla tu inventario, revisa tus alertas y entra rápido a las pantallas importantes del productor.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeroStat(
                        label: 'Activos',
                        value: active.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHeroStat(
                        label: 'Stock bajo',
                        value: lowStock.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHeroStat(
                        label: 'Unidades',
                        value: totalUnits.toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.savings_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Valor estimado del inventario',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_money(inventoryValue)} monedas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _goToProducts,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC69A5B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Entrar'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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

  Widget _buildKpiGrid(List<ProductModel> products) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: Icons.inventory_2_outlined,
            title: 'Productos activos',
            value: _activeProducts(products).toString(),
            subtitle: 'Disponibles en catálogo',
            color: const Color(0xFF3F7D58),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.pause_circle_outline_rounded,
            title: 'Pausados',
            value: _pausedProducts(products).toString(),
            subtitle: 'Ocultos temporalmente',
            color: const Color(0xFF8F8F8F),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E8DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E3426),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C5A4B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF9A8E80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionStatus(List<ProductModel> products) {
    final availability = _availabilityPercent(products);
    final averagePrice = _averagePrice(products);
    final soldOut = _soldOutProducts(products).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8DED0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado general del catálogo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E3426),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Un vistazo rápido a la salud de tus publicaciones y tu inventario.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF8C7B6B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressBlock(
            title: 'Disponibilidad del catálogo',
            percent: availability,
            leftText: '${_activeProducts(products)} activos',
            rightText: '${products.length} totales',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  icon: Icons.savings_outlined,
                  label: 'Precio promedio',
                  value: '${_money(averagePrice)} mon.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniMetric(
                  icon: Icons.remove_shopping_cart_outlined,
                  label: 'Agotados',
                  value: soldOut.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniMetric(
                  icon: Icons.grid_view_rounded,
                  label: 'Unidades',
                  value: _totalUnits(products).toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBlock({
    required String title,
    required double percent,
    required String leftText,
    required String rightText,
  }) {
    final safePercent = percent.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6DDCF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF5B4332),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: safePercent,
              minHeight: 10,
              backgroundColor: const Color(0xFFE9DECF),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFC69A5B)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  leftText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A7A6A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(safePercent * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFC7942E),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rightText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8A7A6A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E8DC)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFC69A5B), size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E3426),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF8C7B6B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    String? actionText,
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E3426),
            ),
          ),
        ),
        if (actionText != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                actionText,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFC7942E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentProductCard(ProductModel product) {
    final statusColor = _productStatusColor(product);
    final statusText = _productStatusText(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E8DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
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
                    color: Color(0xFFC69A5B),
                    size: 30,
                  );
                },
              ),
            )
                : const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFFC69A5B),
              size: 30,
            ),
          ),
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
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E3426),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.description ?? 'Sin descripción disponible.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF8C7B6B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSoftTag(
                      icon: Icons.payments_outlined,
                      text:
                      '${_money(product.price)} mon. / ${product.unit ?? 'unidad'}',
                    ),
                    _buildSoftTag(
                      icon: Icons.inventory_2_outlined,
                      text: 'Stock ${product.stock}',
                    ),
                    _buildSoftTag(
                      icon: Icons.calendar_month_outlined,
                      text: _harvestLabel(product.harvestDate),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildStatusBadge(statusText, statusColor),
        ],
      ),
    );
  }

  Widget _buildSoftTag({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DED1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF8A6A45)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF6D5A49),
              fontWeight: FontWeight.w600,
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
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAlertsPanel({
    required List<ProductModel> lowStockProducts,
    required List<ProductModel> soldOutProducts,
  }) {
    if (lowStockProducts.isEmpty && soldOutProducts.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.check_circle_outline_rounded,
        title: 'Todo se ve en orden',
        subtitle:
        'No hay productos con stock bajo ni agotados en este momento.',
      );
    }

    return Column(
      children: [
        if (lowStockProducts.isNotEmpty) ...[
          ...lowStockProducts.take(2).map(
                (product) => _buildAlertCard(
              product: product,
              title: 'Stock bajo',
              subtitle: 'Solo quedan ${product.stock} unidades disponibles',
              icon: Icons.warning_amber_rounded,
              accent: const Color(0xFFD96C2F),
              buttonText: 'Reponer',
              onTap: () => _replenishProduct(product),
            ),
          ),
        ],
        if (soldOutProducts.isNotEmpty) ...[
          ...soldOutProducts.take(2).map(
                (product) => _buildAlertCard(
              product: product,
              title: 'Producto agotado',
              subtitle: 'Este producto ya no tiene stock disponible',
              icon: Icons.remove_shopping_cart_outlined,
              accent: const Color(0xFFB65E2E),
              buttonText: 'Ver catálogo',
              onTap: _goToProducts,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAlertCard({
    required ProductModel product,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF5A4333),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E8),
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
                        Icons.inventory_2_outlined,
                        color: Color(0xFFC69A5B),
                        size: 28,
                      );
                    },
                  ),
                )
                    : const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFFC69A5B),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4E3426),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(product.harvestDate),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF8C7B6B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: Text(buttonText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_box_outlined,
                title: 'Publicar producto',
                subtitle: 'Crea una nueva publicación bonita',
                onTap: _goToCreateProduct,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.storefront_outlined,
                title: 'Ver productos',
                subtitle: 'Entra a todo tu catálogo',
                onTap: _goToProducts,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.refresh_rounded,
                title: 'Actualizar panel',
                subtitle: 'Recarga estadísticas y alertas',
                onTap: _loadDashboardData,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.warning_amber_rounded,
                title: 'Ver stock bajo',
                subtitle: 'Revisa productos por reponer',
                onTap: _goToProducts,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF0E8DC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFF5F0E8),
              child: Icon(
                icon,
                color: const Color(0xFFC69A5B),
                size: 23,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4E3426),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8C7B6B),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomShowcase(List<ProductModel> products) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF0E8DC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFC69A5B),
                  Color(0xFFB58448),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu panel está listo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4E3426),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  products.isEmpty
                      ? 'Empieza publicando tus productos para ver crecer tu dashboard.'
                      : 'Ya tienes ${products.length} producto${products.length == 1 ? '' : 's'} en tu catálogo. Sigue actualizando tu stock para que todo se vea impecable.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF8C7B6B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _goToProducts,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC69A5B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Productos'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _goToCreateProduct,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8A6A45),
                        side: const BorderSide(color: Color(0xFFE2D4C2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_box_outlined, size: 18),
                      label: const Text('Publicar'),
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

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E7DA)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFF5F0E8),
            child: Icon(
              icon,
              size: 30,
              color: const Color(0xFFC69A5B),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6C5A4B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF958575),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}