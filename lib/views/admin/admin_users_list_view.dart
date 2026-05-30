import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../../models/user_model.dart';
import 'admin_create_edit_user_view.dart';

/// Vista de listado de administradores con opciones de crear, editar y eliminar.
/// UI mejorada tipo app real: resumen, búsqueda, filtros, refresh y tarjetas premium.
class AdminUsersListView extends StatefulWidget {
  const AdminUsersListView({super.key});

  @override
  State<AdminUsersListView> createState() => _AdminUsersListViewState();
}

enum _AdminFilter { all, active, inactive }

class _AdminUsersListViewState extends State<AdminUsersListView> {
  final TextEditingController _searchController = TextEditingController();

  _AdminFilter _filter = _AdminFilter.all;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdmins());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmins() async {
    await Provider.of<UserController>(context, listen: false).loadAdmins();

    if (!mounted) return;
    setState(() => _lastUpdated = DateTime.now());
  }

  List<UserModel> _applyFilters(List<UserModel> admins) {
    final query = _searchController.text.trim().toLowerCase();

    return admins.where((admin) {
      final matchesFilter = switch (_filter) {
        _AdminFilter.all => true,
        _AdminFilter.active => admin.state == 1,
        _AdminFilter.inactive => admin.state != 1,
      };

      if (!matchesFilter) return false;

      if (query.isEmpty) return true;

      final name = admin.name.toLowerCase();
      final email = admin.email.toLowerCase();
      final phone = admin.cellphone?.toLowerCase() ?? '';

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  Future<void> _confirmDelete(UserModel admin) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DeleteAdminSheet(
          adminName: admin.name,
          onCancel: () => Navigator.pop(ctx, false),
          onConfirm: () => Navigator.pop(ctx, true),
        );
      },
    );

    if (confirm != true || !mounted) return;

    final controller = Provider.of<UserController>(context, listen: false);
    final ok = await controller.deleteAdminUser(admin.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Administrador "${admin.name}" eliminado correctamente'
              : controller.errorMessage ?? 'Error al eliminar administrador',
        ),
        backgroundColor:
        ok ? _AdminUsersColors.success : _AdminUsersColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (ok) await _loadAdmins();
  }

  void _goToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateEditUserView()),
    ).then((_) {
      if (mounted) _loadAdmins();
    });
  }

  void _goToEdit(UserModel admin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCreateEditUserView(adminToEdit: admin),
      ),
    ).then((_) {
      if (mounted) _loadAdmins();
    });
  }

  String _formatLastUpdated() {
    final value = _lastUpdated;
    if (value == null) return 'Sin actualizar';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AdminUsersColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const _DecoratedBackground(),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Consumer<UserController>(
                    builder: (_, ctrl, __) {
                      final admins = ctrl.admins;
                      final filteredAdmins = _applyFilters(admins);

                      final activeCount =
                          admins.where((admin) => admin.state == 1).length;
                      final inactiveCount = admins.length - activeCount;

                      return RefreshIndicator(
                        color: _AdminUsersColors.primary,
                        backgroundColor: Colors.white,
                        onRefresh: _loadAdmins,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverPadding(
                              padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 22),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate(
                                  [
                                    _HeroAdminUsersCard(
                                      totalAdmins: admins.length,
                                      activeAdmins: activeCount,
                                      inactiveAdmins: inactiveCount,
                                      lastUpdated: _formatLastUpdated(),
                                      onCreate: _goToCreate,
                                    ),
                                    const SizedBox(height: 16),
                                    _SearchAndFilterPanel(
                                      controller: _searchController,
                                      selectedFilter: _filter,
                                      total: admins.length,
                                      visible: filteredAdmins.length,
                                      active: activeCount,
                                      inactive: inactiveCount,
                                      onChanged: (_) => setState(() {}),
                                      onFilterChanged: (filter) {
                                        setState(() => _filter = filter);
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    if (ctrl.isLoading)
                                      const _LoadingAdminsState()
                                    else if (ctrl.errorMessage != null &&
                                        admins.isEmpty)
                                      _ErrorAdminsState(
                                        message: ctrl.errorMessage ??
                                            'No se pudo cargar la lista.',
                                        onRetry: _loadAdmins,
                                      )
                                    else if (admins.isEmpty)
                                        _EmptyAdminsState(onCreate: _goToCreate)
                                      else if (filteredAdmins.isEmpty)
                                          _NoResultsState(
                                            onClear: () {
                                              _searchController.clear();
                                              setState(() {
                                                _filter = _AdminFilter.all;
                                              });
                                            },
                                          )
                                        else
                                          _AdminsListSection(
                                            admins: filteredAdmins,
                                            onEdit: _goToEdit,
                                            onDelete: _confirmDelete,
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToCreate,
        backgroundColor: _AdminUsersColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Nuevo admin',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: _AdminUsersColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _AdminUsersColors.primary.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Administradores',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AdminUsersColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Gestión de accesos del sistema',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AdminUsersColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Consumer<UserController>(
            builder: (_, ctrl, __) {
              final provider = _ImageHelper.provider(ctrl.currentUser?.image);

              return Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _AdminUsersColors.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: _AdminUsersColors.primary.withOpacity(0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _AdminUsersColors.primarySoft,
                  backgroundImage: provider,
                  child: provider == null
                      ? const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 19,
                  )
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminUsersColors {
  static const Color background = Color(0xFFF5F0E8);
  static const Color surface = Colors.white;

  static const Color primary = Color(0xFFB8860B);
  static const Color primaryDark = Color(0xFF6D4307);
  static const Color primarySoft = Color(0xFFD4A017);
  static const Color cream = Color(0xFFFFF6DD);

  static const Color textPrimary = Color(0xFF2D261B);
  static const Color textSecondary = Color(0xFF8A7C68);
  static const Color border = Color(0xFFE8DEC9);

  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFD84343);
  static const Color warning = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF7C3AED);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEAC15A),
      Color(0xFFB8860B),
      Color(0xFF7A4F07),
    ],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD8A736),
      Color(0xFFA56E12),
      Color(0xFF5F3B08),
    ],
  );

  static const LinearGradient softSurfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white,
      Color(0xFFFFFBF2),
    ],
  );
}

class _AdminUsersShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> colored(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.18),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}

class _ImageHelper {
  static ImageProvider? provider(String? image) {
    final value = image?.trim();
    if (value == null || value.isEmpty) return null;

    try {
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return NetworkImage(value);
      }

      if (value.startsWith('data:image')) {
        final base64Part = value.split(',').last;
        return MemoryImage(base64Decode(base64Part));
      }

      final looksLikeBase64 =
          value.length > 120 && !value.contains('/') && !value.contains('\\');

      if (looksLikeBase64) {
        return MemoryImage(base64Decode(value));
      }

      return FileImage(File(value));
    } catch (_) {
      return null;
    }
  }
}

class _DecoratedBackground extends StatelessWidget {
  const _DecoratedBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -62,
          child: _GlowCircle(
            size: 185,
            color: _AdminUsersColors.primary.withOpacity(0.12),
          ),
        ),
        Positioned(
          top: 230,
          left: -72,
          child: _GlowCircle(
            size: 150,
            color: _AdminUsersColors.success.withOpacity(0.08),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -80,
          child: _GlowCircle(
            size: 170,
            color: _AdminUsersColors.warning.withOpacity(0.08),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.white.withOpacity(0.88),
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              color: _AdminUsersColors.textPrimary,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroAdminUsersCard extends StatelessWidget {
  final int totalAdmins;
  final int activeAdmins;
  final int inactiveAdmins;
  final String lastUpdated;
  final VoidCallback onCreate;

  const _HeroAdminUsersCard({
    required this.totalAdmins,
    required this.activeAdmins,
    required this.inactiveAdmins,
    required this.lastUpdated,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final activePercent =
    totalAdmins <= 0 ? 0.0 : (activeAdmins / totalAdmins).clamp(0, 1);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: _AdminUsersColors.heroGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _AdminUsersColors.primary.withOpacity(0.28),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -48,
            top: -48,
            child: _GlowCircle(
              size: 155,
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          Positioned(
            left: -42,
            bottom: -54,
            child: _GlowCircle(
              size: 126,
              color: Colors.black.withOpacity(0.08),
            ),
          ),
          Positioned(
            right: 20,
            top: 72,
            child: Icon(
              Icons.security_rounded,
              color: Colors.white.withOpacity(0.08),
              size: 96,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _HeroBadge(
                      icon: Icons.verified_user_rounded,
                      text: 'Control de accesos',
                    ),
                    const Spacer(),
                    _HeroBadge(
                      icon: Icons.update_rounded,
                      text: lastUpdated,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Equipo administrativo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea, edita y controla quién puede acceder al panel principal de AgroMarket.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.86),
                    fontSize: 13.2,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMiniStat(
                        label: 'Total admins',
                        value: '$totalAdmins',
                        icon: Icons.admin_panel_settings_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMiniStat(
                        label: 'Activos',
                        value: '$activeAdmins',
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMiniStat(
                        label: 'Inactivos',
                        value: '$inactiveAdmins',
                        icon: Icons.block_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMiniProgress(
                        label: 'Operatividad',
                        value: '${(activePercent * 100).toStringAsFixed(0)}%',
                        percent: activePercent.toDouble(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 21),
                    label: const Text(
                      'Crear nuevo administrador',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _AdminUsersColors.primaryDark,
                      elevation: 0,
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
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroBadge({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.17),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroMiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 9),
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
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
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

class _HeroMiniProgress extends StatelessWidget {
  final String label;
  final String value;
  final double percent;

  const _HeroMiniProgress({
    required this.label,
    required this.value,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final safePercent = percent.clamp(0, 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              FractionallySizedBox(
                widthFactor: safePercent,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
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

class _SearchAndFilterPanel extends StatelessWidget {
  final TextEditingController controller;
  final _AdminFilter selectedFilter;
  final int total;
  final int visible;
  final int active;
  final int inactive;
  final ValueChanged<String> onChanged;
  final ValueChanged<_AdminFilter> onFilterChanged;

  const _SearchAndFilterPanel({
    required this.controller,
    required this.selectedFilter,
    required this.total,
    required this.visible,
    required this.active,
    required this.inactive,
    required this.onChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _AdminUsersColors.primary.withOpacity(0.16),
                      _AdminUsersColors.primary.withOpacity(0.07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: _AdminUsersColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mostrando $visible de $total administradores',
                  style: const TextStyle(
                    color: _AdminUsersColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(
              color: _AdminUsersColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, correo o teléfono...',
              hintStyle: const TextStyle(
                color: _AdminUsersColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _AdminUsersColors.textSecondary,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: _AdminUsersColors.textSecondary,
                ),
              ),
              filled: true,
              fillColor: _AdminUsersColors.background.withOpacity(0.75),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: _AdminUsersColors.border.withOpacity(0.75),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: _AdminUsersColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipButton(
                  label: 'Todos',
                  count: total,
                  icon: Icons.all_inclusive_rounded,
                  isSelected: selectedFilter == _AdminFilter.all,
                  color: _AdminUsersColors.primary,
                  onTap: () => onFilterChanged(_AdminFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Activos',
                  count: active,
                  icon: Icons.check_circle_rounded,
                  isSelected: selectedFilter == _AdminFilter.active,
                  color: _AdminUsersColors.success,
                  onTap: () => onFilterChanged(_AdminFilter.active),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Inactivos',
                  count: inactive,
                  icon: Icons.block_rounded,
                  isSelected: selectedFilter == _AdminFilter.inactive,
                  color: _AdminUsersColors.danger,
                  onTap: () => onFilterChanged(_AdminFilter.inactive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color : color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '$label · $count',
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: _AdminUsersColors.softSurfaceGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _AdminUsersColors.border.withOpacity(0.76)),
        boxShadow: _AdminUsersShadows.card,
      ),
      child: child,
    );
  }
}

class _AdminsListSection extends StatelessWidget {
  final List<UserModel> admins;
  final void Function(UserModel admin) onEdit;
  final void Function(UserModel admin) onDelete;

  const _AdminsListSection({
    required this.admins,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: 'Lista de administradores',
          subtitle: 'Toca una tarjeta para revisar sus acciones',
          icon: Icons.shield_rounded,
          trailing: '${admins.length}',
        ),
        const SizedBox(height: 12),
        ...admins.asMap().entries.map((entry) {
          final index = entry.key;
          final admin = entry.value;

          return _AdminCard(
            admin: admin,
            index: index,
            onEdit: () => onEdit(admin),
            onDelete: () => onDelete(admin),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _AdminUsersColors.primary.withOpacity(0.16),
                _AdminUsersColors.primary.withOpacity(0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: _AdminUsersColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _AdminUsersColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _AdminUsersColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _AdminUsersColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              trailing!,
              style: const TextStyle(
                color: _AdminUsersColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminCard extends StatelessWidget {
  final UserModel admin;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminCard({
    required this.admin,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = admin.state == 1;
    final provider = _ImageHelper.provider(admin.image);
    final cleanName = admin.name.trim();
    final letter = cleanName.isEmpty ? '?' : cleanName[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: _AdminUsersColors.softSurfaceGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isActive
              ? _AdminUsersColors.success.withOpacity(0.13)
              : _AdminUsersColors.danger.withOpacity(0.13),
        ),
        boxShadow: _AdminUsersShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -22,
              top: -22,
              child: _GlowCircle(
                size: 82,
                color: (isActive
                    ? _AdminUsersColors.success
                    : _AdminUsersColors.danger)
                    .withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? _AdminUsersColors.goldGradient
                              : LinearGradient(
                            colors: [
                              _AdminUsersColors.danger.withOpacity(0.8),
                              _AdminUsersColors.danger,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 29,
                          backgroundColor: _AdminUsersColors.primarySoft,
                          backgroundImage: provider,
                          child: provider == null
                              ? Text(
                            letter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _AdminUsersColors.success
                                : _AdminUsersColors.danger,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cleanName.isEmpty ? 'Administrador' : cleanName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: _AdminUsersColors.textPrimary,
                                  letterSpacing: -0.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _StateBadge(isActive: isActive),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: _AdminUsersColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                admin.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _AdminUsersColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (admin.cellphone != null &&
                            admin.cellphone!.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_rounded,
                                size: 14,
                                color: _AdminUsersColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  admin.cellphone!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _AdminUsersColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _SmallInfoChip(
                              icon: Icons.shield_rounded,
                              label: 'Admin',
                              color: _AdminUsersColors.primary,
                            ),
                            const SizedBox(width: 7),
                            _SmallInfoChip(
                              icon: Icons.numbers_rounded,
                              label: '#${index + 1}',
                              color: _AdminUsersColors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AdminActionsMenu(
                    onEdit: onEdit,
                    onDelete: onDelete,
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

class _StateBadge extends StatelessWidget {
  final bool isActive;

  const _StateBadge({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color =
    isActive ? _AdminUsersColors.success : _AdminUsersColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Activo' : 'Inactivo',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SmallInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionsMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminActionsMenu({
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionCircleButton(
          icon: Icons.edit_rounded,
          color: _AdminUsersColors.primary,
          onTap: onEdit,
        ),
        const SizedBox(height: 8),
        _ActionCircleButton(
          icon: Icons.delete_outline_rounded,
          color: _AdminUsersColors.danger,
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.09),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            color: color,
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _LoadingAdminsState extends StatelessWidget {
  const _LoadingAdminsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              gradient: _AdminUsersColors.goldGradient,
              shape: BoxShape.circle,
              boxShadow: _AdminUsersShadows.colored(_AdminUsersColors.primary),
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: _AdminUsersColors.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Cargando administradores',
            style: TextStyle(
              color: _AdminUsersColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Consultando usuarios con acceso administrativo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _AdminUsersColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAdminsState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyAdminsState({
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return _StateContainer(
      icon: Icons.manage_accounts_outlined,
      title: 'No hay administradores registrados',
      subtitle:
      'Crea el primer usuario administrador para gestionar el sistema desde el panel.',
      buttonText: 'Crear administrador',
      buttonIcon: Icons.person_add_alt_1_rounded,
      onPressed: onCreate,
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final VoidCallback onClear;

  const _NoResultsState({
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _StateContainer(
      icon: Icons.search_off_rounded,
      title: 'No se encontraron resultados',
      subtitle:
      'No hay administradores que coincidan con tu búsqueda o filtro actual.',
      buttonText: 'Limpiar búsqueda',
      buttonIcon: Icons.close_rounded,
      onPressed: onClear,
    );
  }
}

class _ErrorAdminsState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorAdminsState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _StateContainer(
      icon: Icons.wifi_off_rounded,
      title: 'No se pudo cargar',
      subtitle: message,
      buttonText: 'Reintentar',
      buttonIcon: Icons.refresh_rounded,
      onPressed: onRetry,
      color: _AdminUsersColors.danger,
    );
  }
}

class _StateContainer extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final IconData buttonIcon;
  final VoidCallback onPressed;
  final Color color;

  const _StateContainer({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.buttonIcon,
    required this.onPressed,
    this.color = _AdminUsersColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: _AdminUsersColors.softSurfaceGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _AdminUsersColors.border.withOpacity(0.76)),
        boxShadow: _AdminUsersShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminUsersColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminUsersColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(buttonIcon, size: 19),
            label: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAdminSheet extends StatelessWidget {
  final String adminName;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _DeleteAdminSheet({
    required this.adminName,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _AdminUsersShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: _AdminUsersColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _AdminUsersColors.danger.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: _AdminUsersColors.danger,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Eliminar administrador',
            style: TextStyle(
              color: _AdminUsersColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¿Seguro que quieres eliminar a "$adminName"?\nEsta acción desactivará su acceso al sistema.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminUsersColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _AdminUsersColors.textPrimary,
                    side: BorderSide(
                      color: _AdminUsersColors.border.withOpacity(0.9),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AdminUsersColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
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