import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../auth/login_view.dart';

/// Dashboard principal del cliente
/// Principio S de SOLID: solo maneja la UI del dashboard del cliente
class ClientDashboardView extends StatelessWidget {
  const ClientDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            /// AppBar personalizado
            SliverAppBar(
              backgroundColor: const Color(0xFFF5F0E8),
              floating: true,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  /// Logo
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
  /// Balance del usuario
  Consumer<UserController>(
    builder: (context, controller, child) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
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
          ],
        ),
      );
    },
  ),
  const SizedBox(width: 4),

  /// Botón de configuración
  IconButton(
    onPressed: () {
      // TODO: navegar a configuración
    },
    icon: const Icon(
      Icons.settings_outlined,
      color: Color(0xFF2D2D2D),
    ),
  ),

  /// Botón de cerrar sesión
  IconButton(
    onPressed: () async {
      final controller = Provider.of<UserController>(context, listen: false);
      await controller.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginView()),
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

            /// Contenido principal
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),

                  /// Sección productos más vendidos
                  const Text(
                    'Productos más vendidos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Lista horizontal de productos
                  SizedBox(
                    height: 180,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        _ProductCard(
                          name: 'Tomate Cherry\nOrgánico',
                          producer: 'FreshFarm Co.',
                          rating: 4.8,
                          price: '2/kg',
                          color: Color(0xFFE8F0E8),
                        ),
                        SizedBox(width: 12),
                        _ProductCard(
                          name: 'Lechuga\nHidropónica',
                          producer: 'Verde Vital',
                          rating: 4.6,
                          price: '4/100g',
                          color: Color(0xFFE8F5E8),
                        ),
                        SizedBox(width: 12),
                        _ProductCard(
                          name: 'Mango\nAtaulfo',
                          producer: 'AgroSur',
                          rating: 4.9,
                          price: '3/kg',
                          color: Color(0xFFFFF3E0),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// Sección empresas agrícolas
                  const Text(
                    'Empresas agrícolas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Lista de productores
                  const _ProducerCard(
                    name: 'FreshFarm Co.',
                    description:
                        'Especialistas en productos orgánicos certificados con más de 15 años de experiencia en agricultura sustentable.',
                    families: ['Vegetales', 'Frutas', 'Hierbas'],
                    rating: 4.8,
                    reviews: 127,
                  ),

                  const SizedBox(height: 12),

                  const _ProducerCard(
                    name: 'Verde Vital',
                    description:
                        'Innovadores en cultivos hidropónicos y verticales, ofreciendo productos frescos durante todo el año con tecnología avanzada.',
                    families: ['Hidropónicos', 'Lechugas', 'Microgreens'],
                    rating: 4.6,
                    reviews: 89,
                  ),

                  const SizedBox(height: 12),

                  const _ProducerCard(
                    name: 'AgroSur',
                    description:
                        'Productores líderes en frutas tropicales y subtropicales, con certificaciones internacionales de calidad y trazabilidad.',
                    families: ['Frutas tropicales', 'Paitas', 'Cítricos'],
                    rating: 4.9,
                    reviews: 203,
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),

      /// Bottom navigation bar
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
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Pedidos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        onTap: (index) {
          // TODO: navegar a las secciones
        },
      ),
    );
  }
}

/// Widget de tarjeta de producto
/// Principio S de SOLID: widget con responsabilidad única
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
          /// Imagen del producto
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
              child: Icon(
                Icons.eco_outlined,
                size: 40,
                color: Color(0xFF5A8A5A),
              ),
            ),
          ),

          /// Info del producto
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
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: Color(0xFFB8860B),
                        ),
                        Text(
                          '$rating',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_outlined,
                          size: 12,
                          color: Color(0xFFB8860B),
                        ),
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2D2D2D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
}

/// Widget de tarjeta de productor
/// Principio S de SOLID: widget con responsabilidad única
class _ProducerCard extends StatelessWidget {
  final String name;
  final String description;
  final List<String> families;
  final double rating;
  final int reviews;

  const _ProducerCard({
    required this.name,
    required this.description,
    required this.families,
    required this.rating,
    required this.reviews,
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
          /// Nombre del productor
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),

          const SizedBox(height: 6),

          /// Descripción
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF888888),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          /// Familias de productos
          Wrap(
            spacing: 6,
            children: families.map((family) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  family,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5A8A5A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          /// Rating y botón
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    size: 16,
                    color: Color(0xFFB8860B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$rating ($reviews reseñas)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),

              /// Botón ver productos
              ElevatedButton(
                onPressed: () {
                  // TODO: navegar a productos del productor
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A8A5A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Ver productos',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}