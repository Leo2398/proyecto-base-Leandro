import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/user_controller.dart';
import '../auth/login_view.dart';
import 'client_best_sellers_view.dart';
import 'client_cart_view.dart';
import 'client_producer_products_view.dart';
import 'client_settings_view.dart';
import 'client_reload_view.dart';

/// Dashboard principal del cliente
class ClientDashboardView extends StatefulWidget {
  const ClientDashboardView({super.key});

  @override
  State<ClientDashboardView> createState() => _ClientDashboardViewState();
}

class _ClientDashboardViewState extends State<ClientDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserController>().getAllProducers();
    });
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientCartView()),
    );
  }

  void _showDifferentProducerWarning(String currentProducer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8CE),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: Color(0xFFD96C2F),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Solo una empresa por pedido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu carrito ya tiene productos de "$currentProducer". '
              'Vacía el carrito para agregar productos de otra empresa.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5A8A5A),
                      side: const BorderSide(color: Color(0xFF5A8A5A)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<CartController>().clearCart();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD96C2F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Vaciar carrito',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFFF5F0E8),
              floating: true,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A8A5A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AgroMarket',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
              actions: [
                // ── Balance (tappable → recarga de monedas) ──────────────
                Consumer<UserController>(
                  builder: (context, controller, _) {
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ClientReloadView()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.monetization_on_outlined,
                              color: Color(0xFFB8860B),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${controller.currentUser?.balance.toStringAsFixed(0) ?? '0'}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              color: Color(0xFF5A8A5A),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 4),

                // ── Carrito con badge ────────────────────────────────────
                Consumer<CartController>(
                  builder: (_, cart, __) => Stack(
                    children: [
                      IconButton(
                        onPressed: _openCart,
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                      if (cart.itemCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF5A8A5A),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${cart.itemCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Configuración ────────────────────────────────────────
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClientSettingsView()),
                  ),
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Color(0xFF2D2D2D),
                  ),
                ),

                // ── Cerrar sesión ────────────────────────────────────────
                IconButton(
                  onPressed: () async {
                    final controller = Provider.of<UserController>(
                        context,
                        listen: false);
                    await controller.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginView()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.logout,
                    color: Color(0xFF2D2D2D),
                  ),
                ),

                const SizedBox(width: 4),
              ],
            ),

            // ── Contenido principal ──────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),

                  // Productos más vendidos
                  const Text(
                    'Productos más vendidos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ClientBestSellersView())),
                          child: const _ProductCard(
                            name: 'Tomate Cherry\nOrgánico',
                            producer: 'FreshFarm Co.',
                            rating: 4.8,
                            price: '2/kg',
                            color: Color(0xFFE8F0E8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ClientBestSellersView())),
                          child: const _ProductCard(
                            name: 'Lechuga\nHidropónica',
                            producer: 'Verde Vital',
                            rating: 4.6,
                            price: '4/100g',
                            color: Color(0xFFE8F5E8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ClientBestSellersView())),
                          child: const _ProductCard(
                            name: 'Mango\nAtaulfo',
                            producer: 'AgroSur',
                            rating: 4.9,
                            price: '3/kg',
                            color: Color(0xFFFFF3E0),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Empresas agrícolas
                  const Text(
                    'Empresas agrícolas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Consumer<UserController>(
                    builder: (context, controller, child) {
                      if (controller.isLoading &&
                          controller.producers.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(
                                color: Color(0xFF5A8A5A)),
                          ),
                        );
                      }

                      if (controller.producers.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No hay productores disponibles.',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF888888)),
                          ),
                        );
                      }

                      return Column(
                        children: controller.producers.map((producer) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProducerCard(
                              name: producer.name,
                              description:
                                  producer.description?.isNotEmpty == true
                                      ? producer.description!
                                      : 'Productor agrícola disponible en AgroMarket.',
                              onViewProducts: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ClientProducerProductsView(
                                            producer: producer),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom navigation bar ──────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF5A8A5A),
        unselectedItemColor: const Color(0xFF888888),
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Buscar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_outlined),
              activeIcon: Icon(Icons.trending_up),
              label: 'Más vendidos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Pedidos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
        onTap: (index) {
          if (index == 2) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ClientBestSellersView()));
          } else if (index == 3) {
            _openCart();
          }
        },
      ),
    );
  }
}

// ── _ProductCard ───────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final String name;
  final String producer;
  final double rating;
  final String price;
  final Color color;

  const _ProductCard({
    required this.name,
    required this.producer,
    required this.rating,
    required this.price,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Center(
              child: Icon(Icons.eco_outlined,
                  size: 40, color: Color(0xFF5A8A5A)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Text(
                  producer,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.star,
                          size: 12, color: Color(0xFFB8860B)),
                      Text('$rating',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888888))),
                    ]),
                    Row(children: [
                      const Icon(Icons.monetization_on_outlined,
                          size: 12, color: Color(0xFFB8860B)),
                      Text(price,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2D2D2D),
                            fontWeight: FontWeight.w500,
                          )),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ProducerCard ──────────────────────────────────────────────────────────────

class _ProducerCard extends StatelessWidget {
  final String name;
  final String description;
  final VoidCallback onViewProducts;

  const _ProducerCard({
    required this.name,
    required this.description,
    required this.onViewProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style:
                const TextStyle(fontSize: 13, color: Color(0xFF888888)),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: onViewProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A8A5A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Ver productos',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}