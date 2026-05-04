import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/user_service.dart';

/// Vista de administración de clientes.
/// Solo lectura, con búsqueda, filtros, resumen y detalle visual.
class AdminClientsView extends StatefulWidget {
  const AdminClientsView({super.key});

  @override
  State<AdminClientsView> createState() => _AdminClientsViewState();
}

class _AdminClientsViewState extends State<AdminClientsView> {
  final UserService _service = UserService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _all = [];
  List<UserModel> _filtered = [];

  bool _loading = true;
  String? _errorMessage;
  int _stateFilter = -1; // -1=todos, 1=activos, 0=inactivos
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await _service.getUsersByRole(0);

      if (!mounted) return;

      setState(() {
        _all = data;
        _loading = false;
        _lastUpdated = DateTime.now();
      });

      _applyFilter();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'No se pudo cargar la lista de clientes.';
      });
    }
  }

  void _applyFilter() {
    final search = _searchController.text.trim().toLowerCase();

    final result = _all.where((user) {
      final name = user.name.toLowerCase();
      final email = user.email.toLowerCase();
      final phone = user.cellphone?.toLowerCase() ?? '';

      final matchSearch = search.isEmpty ||
          name.contains(search) ||
          email.contains(search) ||
          phone.contains(search);

      final matchState = _stateFilter == -1 || user.state == _stateFilter;

      return matchSearch && matchState;
    }).toList();

    if (!mounted) return;

    setState(() {
      _filtered = result;
    });
  }

  int get _activeClients => _all.where((u) => u.state == 1).length;

  int get _inactiveClients => _all.where((u) => u.state == 0).length;

  double get _totalBalance {
    return _all.fold<double>(0, (sum, user) => sum + user.balance);
  }

  double get _averageBalance {
    if (_all.isEmpty) return 0;
    return _totalBalance / _all.length;
  }

  double get _activePercent {
    if (_all.isEmpty) return 0;
    return (_activeClients / _all.length).clamp(0, 1).toDouble();
  }

  String _formatBs(double value) {
    if (value >= 1000000) {
      return 'Bs ${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return 'Bs ${(value / 1000).toStringAsFixed(1)}K';
    }

    final decimals = value == value.truncateToDouble() ? 0 : 2;
    return 'Bs ${value.toStringAsFixed(decimals)}';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Sin fecha';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day/$month/$year';
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

  void _showDetail(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ClientDetailSheet(
          user: user,
          formatDate: _formatDate,
          formatBs: _formatBs,
        );
      },
    );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _stateFilter = -1;
    });
    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ClientColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const _DecoratedBackground(),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    color: _ClientColors.primary,
                    backgroundColor: Colors.white,
                    onRefresh: _load,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate(
                              [
                                _ClientsHeroCard(
                                  total: _all.length,
                                  active: _activeClients,
                                  inactive: _inactiveClients,
                                  activePercent: _activePercent,
                                  totalBalance: _formatBs(_totalBalance),
                                  averageBalance: _formatBs(_averageBalance),
                                  lastUpdated: _formatLastUpdated(),
                                ),
                                const SizedBox(height: 16),
                                _SearchFilterPanel(
                                  controller: _searchController,
                                  selectedState: _stateFilter,
                                  total: _all.length,
                                  visible: _filtered.length,
                                  active: _activeClients,
                                  inactive: _inactiveClients,
                                  onChanged: (_) => _applyFilter(),
                                  onFilterChanged: (state) {
                                    setState(() => _stateFilter = state);
                                    _applyFilter();
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (_loading)
                                  const _LoadingState()
                                else if (_errorMessage != null)
                                  _ErrorState(
                                    message: _errorMessage!,
                                    onRetry: _load,
                                  )
                                else if (_all.isEmpty)
                                    const _EmptyClientsState()
                                  else if (_filtered.isEmpty)
                                      _NoResultsState(onClear: _clearFilters)
                                    else
                                      _ClientsListSection(
                                        clients: _filtered,
                                        onTap: _showDetail,
                                        formatBs: _formatBs,
                                      ),
                              ],
                            ),
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
              gradient: _ClientColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _ClientColors.primary.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.groups_rounded,
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
                  'Clientes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ClientColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Consulta de usuarios compradores',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ClientColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.visibility_rounded,
              color: _ClientColors.textPrimary,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientColors {
  static const Color background = Color(0xFFF5F0E8);
  static const Color surface = Colors.white;

  static const Color primary = Color(0xFFB8860B);
  static const Color primaryDark = Color(0xFF6D4307);
  static const Color primarySoft = Color(0xFFD4A017);

  static const Color textPrimary = Color(0xFF2D261B);
  static const Color textSecondary = Color(0xFF8A7C68);
  static const Color border = Color(0xFFE8DEC9);

  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFD84343);
  static const Color warning = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF3B82F6);
  static const Color green = Color(0xFF5E8C45);

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

class _ClientShadows {
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
            color: _ClientColors.primary.withOpacity(0.12),
          ),
        ),
        Positioned(
          top: 230,
          left: -72,
          child: _GlowCircle(
            size: 150,
            color: _ClientColors.success.withOpacity(0.08),
          ),
        ),
        Positioned(
          bottom: 110,
          right: -80,
          child: _GlowCircle(
            size: 170,
            color: _ClientColors.warning.withOpacity(0.08),
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
              color: _ClientColors.textPrimary,
              size: 21,
            ),
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
        gradient: _ClientColors.softSurfaceGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _ClientColors.border.withOpacity(0.76)),
        boxShadow: _ClientShadows.card,
      ),
      child: child,
    );
  }
}

class _ClientsHeroCard extends StatelessWidget {
  final int total;
  final int active;
  final int inactive;
  final double activePercent;
  final String totalBalance;
  final String averageBalance;
  final String lastUpdated;

  const _ClientsHeroCard({
    required this.total,
    required this.active,
    required this.inactive,
    required this.activePercent,
    required this.totalBalance,
    required this.averageBalance,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final percent = activePercent.clamp(0, 1).toDouble();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: _ClientColors.heroGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _ClientColors.primary.withOpacity(0.28),
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
            right: 18,
            top: 76,
            child: Icon(
              Icons.shopping_cart_checkout_rounded,
              color: Colors.white.withOpacity(0.08),
              size: 100,
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
                      icon: Icons.groups_rounded,
                      text: 'Gestión de clientes',
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
                  'Clientes registrados',
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
                  'Consulta rápida de compradores, saldo disponible, estado de cuenta e información de contacto.',
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
                        label: 'Total clientes',
                        value: '$total',
                        icon: Icons.people_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMiniStat(
                        label: 'Activos',
                        value: '$active',
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
                        label: 'Saldo total',
                        value: totalBalance,
                        icon: Icons.savings_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMiniProgress(
                        label: 'Actividad',
                        value: '${(percent * 100).toStringAsFixed(0)}%',
                        percent: percent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.13)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Promedio por cliente: $averageBalance · Inactivos: $inactive',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 11.5,
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

class _SearchFilterPanel extends StatelessWidget {
  final TextEditingController controller;
  final int selectedState;
  final int total;
  final int visible;
  final int active;
  final int inactive;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onFilterChanged;

  const _SearchFilterPanel({
    required this.controller,
    required this.selectedState,
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
                      _ClientColors.primary.withOpacity(0.16),
                      _ClientColors.primary.withOpacity(0.07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: _ClientColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mostrando $visible de $total clientes',
                  style: const TextStyle(
                    color: _ClientColors.textPrimary,
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
              color: _ClientColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, correo o teléfono...',
              hintStyle: const TextStyle(
                color: _ClientColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _ClientColors.textSecondary,
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
                  color: _ClientColors.textSecondary,
                ),
              ),
              filled: true,
              fillColor: _ClientColors.background.withOpacity(0.75),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: _ClientColors.border.withOpacity(0.75),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: _ClientColors.primary,
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
                  isSelected: selectedState == -1,
                  color: _ClientColors.primary,
                  onTap: () => onFilterChanged(-1),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Activos',
                  count: active,
                  icon: Icons.check_circle_rounded,
                  isSelected: selectedState == 1,
                  color: _ClientColors.success,
                  onTap: () => onFilterChanged(1),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Inactivos',
                  count: inactive,
                  icon: Icons.block_rounded,
                  isSelected: selectedState == 0,
                  color: _ClientColors.danger,
                  onTap: () => onFilterChanged(0),
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

class _ClientsListSection extends StatelessWidget {
  final List<UserModel> clients;
  final void Function(UserModel user) onTap;
  final String Function(double value) formatBs;

  const _ClientsListSection({
    required this.clients,
    required this.onTap,
    required this.formatBs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          title: 'Lista de clientes',
          subtitle: 'Toca una tarjeta para ver información completa',
          icon: Icons.people_alt_rounded,
          trailing: '${clients.length}',
        ),
        const SizedBox(height: 12),
        ...clients.asMap().entries.map((entry) {
          final index = entry.key;
          final client = entry.value;

          return _ClientCard(
            user: client,
            index: index,
            onTap: () => onTap(client),
            formatBs: formatBs,
          );
        }),
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
                _ClientColors.primary.withOpacity(0.16),
                _ClientColors.primary.withOpacity(0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: _ClientColors.primary,
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
                  color: _ClientColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _ClientColors.textSecondary,
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
              color: _ClientColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              trailing!,
              style: const TextStyle(
                color: _ClientColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _ClientCard extends StatelessWidget {
  final UserModel user;
  final int index;
  final VoidCallback onTap;
  final String Function(double value) formatBs;

  const _ClientCard({
    required this.user,
    required this.index,
    required this.onTap,
    required this.formatBs,
  });

  @override
  Widget build(BuildContext context) {
    final active = user.state == 1;
    final provider = _ImageHelper.provider(user.image);
    final cleanName = user.name.trim();
    final letter = cleanName.isEmpty ? 'C' : cleanName[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: _ClientColors.softSurfaceGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: active
              ? _ClientColors.success.withOpacity(0.13)
              : _ClientColors.danger.withOpacity(0.13),
        ),
        boxShadow: _ClientShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                Positioned(
                  right: -22,
                  top: -22,
                  child: _GlowCircle(
                    size: 82,
                    color: (active ? _ClientColors.success : _ClientColors.danger)
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
                              gradient: active
                                  ? _ClientColors.goldGradient
                                  : LinearGradient(
                                colors: [
                                  _ClientColors.danger.withOpacity(0.8),
                                  _ClientColors.danger,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 29,
                              backgroundColor:
                              _ClientColors.primary.withOpacity(0.15),
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
                                color: active
                                    ? _ClientColors.success
                                    : _ClientColors.danger,
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: Colors.white, width: 2),
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
                                    cleanName.isEmpty ? 'Cliente' : cleanName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: _ClientColors.textPrimary,
                                      letterSpacing: -0.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _StateBadge(isActive: active),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.email_outlined,
                                  size: 14,
                                  color: _ClientColors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: _ClientColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (user.cellphone != null &&
                                user.cellphone!.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_rounded,
                                    size: 14,
                                    color: _ClientColors.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      user.cellphone!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: _ClientColors.textSecondary,
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
                                  icon: Icons.account_balance_wallet_rounded,
                                  label: formatBs(user.balance),
                                  color: _ClientColors.success,
                                ),
                                const SizedBox(width: 7),
                                _SmallInfoChip(
                                  icon: Icons.numbers_rounded,
                                  label: '#${index + 1}',
                                  color: _ClientColors.blue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _ClientColors.primary.withOpacity(0.09),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: _ClientColors.primary,
                          size: 24,
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

class _StateBadge extends StatelessWidget {
  final bool isActive;

  const _StateBadge({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _ClientColors.success : _ClientColors.danger;

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

class _ClientDetailSheet extends StatelessWidget {
  final UserModel user;
  final String Function(DateTime? value) formatDate;
  final String Function(double value) formatBs;

  const _ClientDetailSheet({
    required this.user,
    required this.formatDate,
    required this.formatBs,
  });

  @override
  Widget build(BuildContext context) {
    final active = user.state == 1;
    final provider = _ImageHelper.provider(user.image);
    final cleanName = user.name.trim();
    final letter = cleanName.isEmpty ? 'C' : cleanName[0].toUpperCase();

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _ClientColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: _ClientColors.heroGradient,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -35,
                          top: -38,
                          child: _GlowCircle(
                            size: 120,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: _ClientColors.primarySoft,
                                backgroundImage: provider,
                                child: provider == null
                                    ? Text(
                                  letter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 30,
                                  ),
                                )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              cleanName.isEmpty ? 'Cliente' : cleanName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 7),
                            _WhiteStateBadge(isActive: active),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _HeroMiniStat(
                                    label: 'Balance',
                                    value: formatBs(user.balance),
                                    icon: Icons.account_balance_wallet_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _HeroMiniStat(
                                    label: 'ID usuario',
                                    value: '#${user.id ?? "-"}',
                                    icon: Icons.badge_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailInfoCard(
                    title: 'Información del cliente',
                    children: [
                      _DetailRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email,
                      ),
                      _DetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Teléfono',
                        value: user.cellphone?.trim().isNotEmpty == true
                            ? user.cellphone!.trim()
                            : 'Sin teléfono',
                      ),
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Registro',
                        value: formatDate(user.registerDate),
                      ),
                      _DetailRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Estado',
                        value: active ? 'Activo' : 'Inactivo',
                        valueColor:
                        active ? _ClientColors.success : _ClientColors.danger,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailInfoCard(
                    title: 'Resumen financiero',
                    children: [
                      _DetailRow(
                        icon: Icons.monetization_on_outlined,
                        label: 'Balance',
                        value: formatBs(user.balance),
                        valueColor: _ClientColors.success,
                      ),
                      _DetailRow(
                        icon: Icons.shopping_bag_outlined,
                        label: 'Tipo de cuenta',
                        value: 'Cliente comprador',
                      ),
                      _DetailRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Permisos',
                        value: 'Solo acceso cliente',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'Entendido',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ClientColors.primary,
                        foregroundColor: Colors.white,
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
          );
        },
      ),
    );
  }
}

class _WhiteStateBadge extends StatelessWidget {
  final bool isActive;

  const _WhiteStateBadge({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _ClientColors.success : _ClientColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.17),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle_rounded : Icons.block_rounded,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Cuenta activa' : 'Cuenta inactiva',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailInfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ClientColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _ClientColors.background.withOpacity(0.72),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: _ClientColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              size: 18,
              color: _ClientColors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _ClientColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? _ClientColors.textPrimary,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

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
              gradient: _ClientColors.goldGradient,
              shape: BoxShape.circle,
              boxShadow: _ClientShadows.colored(_ClientColors.primary),
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
                  color: _ClientColors.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Cargando clientes',
            style: TextStyle(
              color: _ClientColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Consultando usuarios registrados como clientes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ClientColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyClientsState extends StatelessWidget {
  const _EmptyClientsState();

  @override
  Widget build(BuildContext context) {
    return const _StateContainer(
      icon: Icons.people_outline_rounded,
      title: 'No hay clientes registrados',
      subtitle:
      'Cuando los usuarios se registren como clientes aparecerán en esta lista.',
      buttonText: 'Actualizar',
      buttonIcon: Icons.refresh_rounded,
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
      title: 'Sin resultados',
      subtitle:
      'No hay clientes que coincidan con tu búsqueda o filtro actual.',
      buttonText: 'Limpiar búsqueda',
      buttonIcon: Icons.close_rounded,
      onPressed: onClear,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
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
      color: _ClientColors.danger,
    );
  }
}

class _StateContainer extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final IconData buttonIcon;
  final VoidCallback? onPressed;
  final Color color;

  const _StateContainer({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.buttonIcon,
    this.onPressed,
    this.color = _ClientColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: _ClientColors.softSurfaceGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _ClientColors.border.withOpacity(0.76)),
        boxShadow: _ClientShadows.card,
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
              color: _ClientColors.textPrimary,
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
              color: _ClientColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (onPressed != null) ...[
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
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}