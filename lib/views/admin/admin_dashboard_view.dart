import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../auth/login_view.dart';
import 'admin_settings_view.dart';
import 'admin_users_list_view.dart';

/// Dashboard principal del administrador
/// Principio S de SOLID: solo maneja la UI del dashboard del admin
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F0E8),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: const Color(0xFFF5F0E8),
              floating: true,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: IconButton(
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                icon: const Icon(
                  Icons.menu,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB8860B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.eco_outlined,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'AgroMarket Admin',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                Consumer<UserController>(
                  builder: (_, ctrl, __) {
                    final img = ctrl.currentUser?.image;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminSettingsView()),
                          );
                        },
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(0xFFD4A017),
                          backgroundImage: img != null && img.isNotEmpty
                              ? (img.startsWith('http')
                                  ? NetworkImage(img) as ImageProvider
                                  : FileImage(File(img)))
                              : null,
                          child: (img == null || img.isEmpty)
                              ? const Icon(Icons.person,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  /// Tarjeta de bienvenida
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Consumer<UserController>(
                      builder: (context, controller, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Bienvenido de nuevo${controller.currentUser != null ? ', ${controller.currentUser!.name}' : ''}!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Aquí tienes un resumen de tu\nmarketplace agrícola',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Tarjetas de estadísticas
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.group_outlined,
                          iconColor: const Color(0xFFB8860B),
                          iconBgColor: const Color(0xFFFFF3E0),
                          value: '1,247',
                          label: 'Total Clientes',
                          trend: '+12% este mes',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.store_outlined,
                          iconColor: const Color(0xFFB8860B),
                          iconBgColor: const Color(0xFFFFF3E0),
                          value: '89',
                          label: 'Total Empresas',
                          trend: '+8% este mes',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Empresas que Más Venden',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const _BarChart(),
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8860B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.eco_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),
            const SizedBox(height: 8),

            _DrawerItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              isSelected: true,
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.person_add_outlined,
              label: 'Crear Usuarios',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminUsersListView()),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.group_outlined,
              label: 'Clientes',
              onTap: () {
                Navigator.pop(context);
                // TODO: navegar a clientes
              },
            ),
            _DrawerItem(
              icon: Icons.store_outlined,
              label: 'Empresas',
              onTap: () {
                Navigator.pop(context);
                // TODO: navegar a empresas
              },
            ),
            _DrawerItem(
              icon: Icons.upload_outlined,
              label: 'Solicitudes de Carga',
              onTap: () {
                Navigator.pop(context);
                // TODO: navegar a solicitudes
              },
            ),
            _DrawerItem(
              icon: Icons.bar_chart_outlined,
              label: 'Reportes',
              onTap: () {
                Navigator.pop(context);
                // TODO: navegar a reportes
              },
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Configuraciones',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminSettingsView()),
                );
              },
            ),

            const Spacer(),
            const Divider(height: 1),

            _DrawerItem(
              icon: Icons.logout,
              label: 'Cerrar sesión',
              iconColor: const Color(0xFFB8860B),
              labelColor: const Color(0xFFB8860B),
              onTap: () async {
                Navigator.pop(context);
                final controller =
                    Provider.of<UserController>(context, listen: false);
                await controller.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginView()),
                    (route) => false,
                  );
                }
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;
  final String trend;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF5A8A5A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<_BarData> data = const [
    _BarData(label: 'AgroVerde S.A.', value: 234, displayValue: '\$234K'),
    _BarData(label: 'Cosecha Natural', value: 198, displayValue: '\$198K'),
    _BarData(label: 'Campo Dorado', value: 156, displayValue: '\$156K'),
    _BarData(label: 'Frutas Premium', value: 134, displayValue: '\$134K'),
    _BarData(label: 'Verduras', value: 112, displayValue: '\$112K'),
  ];

  const _BarChart();

  @override
  Widget build(BuildContext context) {
    const maxValue = 250.0;
    const chartHeight = 180.0;

    return SizedBox(
      height: chartHeight + 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: data.map((item) {
          final barHeight = (item.value / maxValue) * chartHeight;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                item.displayValue,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 44,
                height: barHeight,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFD4A017),
                      Color(0xFFB8860B),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 52,
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF888888),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _BarData {
  final String label;
  final double value;
  final String displayValue;

  const _BarData({
    required this.label,
    required this.value,
    required this.displayValue,
  });
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB8860B) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? Colors.white
                  : iconColor ?? const Color(0xFF2D2D2D),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : labelColor ?? const Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}