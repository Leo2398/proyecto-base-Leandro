import 'package:flutter/material.dart';
import 'register_client_view.dart';
import 'register_producer_view.dart';

/// Pantalla de selección de rol
/// Principio S de SOLID: solo maneja la UI de selección de rol
class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// Color de fondo beige
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const SizedBox(height: 20),

              /// Icono superior
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A8A5A),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.eco_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(height: 24),

              /// Título
              const Text(
                '¿Cómo quieres usar la app?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),

              const SizedBox(height: 12),

              /// Subtítulo
              const Text(
                'Selecciona tu tipo de cuenta para\npersonalizar tu experiencia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                ),
              ),

              const SizedBox(height: 32),

              /// Tarjeta Cliente
              _RoleCard(
                icon: Icons.restaurant_outlined,
                iconColor: const Color(0xFF5A8A5A),
                iconBgColor: const Color(0xFFE8F0E8),
                title: 'Cliente',
                description:
                    'Comprar ingredientes frescos de\nproveedores agrícolas',
                arrowColor: const Color(0xFF5A8A5A),
                onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const RegisterClientView(),
    ),
  );
},
              ),

              const SizedBox(height: 16),

              /// Tarjeta Productor
              _RoleCard(
                icon: Icons.energy_savings_leaf_outlined,
                iconColor: const Color(0xFFB8860B),
                iconBgColor: const Color(0xFFF5F0E0),
                title: 'Productor',
                description: 'Vender productos a restaurantes',
                arrowColor: const Color(0xFFB8860B),
                                onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const RegisterProducerView(),
    ),
  );
},
              ),

              const SizedBox(height: 32),

              /// Nota inferior
              const Text(
                'Podrás cambiar esto más tarde en configuración',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget reutilizable para las tarjetas de rol
/// Principio S de SOLID: widget con responsabilidad única
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String description;
  final Color arrowColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
    required this.arrowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            /// Icono del rol
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),

            const SizedBox(height: 12),

            /// Título del rol
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),

            const SizedBox(height: 8),

            /// Descripción
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
              ),
            ),

            const SizedBox(height: 16),

            /// Botón continuar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continuar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: arrowColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, color: arrowColor, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}