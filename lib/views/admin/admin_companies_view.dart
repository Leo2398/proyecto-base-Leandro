import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/user_service.dart';

/// Vista de administración de empresas/productores (role=1).
/// Solo lectura: lista, busca, filtra y muestra detalle de productores.
class AdminCompaniesView extends StatefulWidget {
  const AdminCompaniesView({super.key});

  @override
  State<AdminCompaniesView> createState() => _AdminCompaniesViewState();
}

class _AdminCompaniesViewState extends State<AdminCompaniesView> {
  final UserService _service = UserService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<UserModel> _companies = [];

  bool _loading = true;
  int _stateFilter = -1; // -1 todos, 1 activos, 0 inactivos

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    try {
      final data = await _service.getUsersByRole(1);

      data.sort((a, b) {
        final ad = a.registerDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.registerDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      if (!mounted) return;
      setState(() {
        _companies = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('No se pudieron cargar las empresas.', error: true);
    }
  }

  List<UserModel> get _filteredCompanies {
    final query = _searchCtrl.text.trim().toLowerCase();

    return _companies.where((user) {
      final name = user.name.toLowerCase();
      final email = user.email.toLowerCase();
      final phone = (user.cellphone ?? '').toLowerCase();
      final description = (user.description ?? '').toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          phone.contains(query) ||
          description.contains(query);

      final matchesState = _stateFilter == -1 || user.state == _stateFilter;

      return matchesSearch && matchesState;
    }).toList();
  }

  int get _activeCount => _companies.where((u) => u.state == 1).length;

  int get _inactiveCount => _companies.where((u) => u.state == 0).length;

  int get _newThisMonth {
    final now = DateTime.now();
    return _companies.where((u) {
      final date = u.registerDate;
      if (date == null) return false;
      return date.year == now.year && date.month == now.month;
    }).length;
  }

  double get _activePercent {
    if (_companies.isEmpty) return 0;
    return (_activeCount / _companies.length) * 100;
  }

  void _showDetail(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyDetailSheet(user: user),
    );
  }

  void _clearFilters() {
    setState(() {
      _stateFilter = -1;
      _searchCtrl.clear();
    });
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: error ? _AdminCompaniesColors.red : _AdminCompaniesColors.green,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Sin registro';

    final diff = DateTime.now().difference(date);

    if (diff.inDays > 365) {
      final years = diff.inDays ~/ 365;
      return 'Hace $years año${years > 1 ? "s" : ""}';
    }

    if (diff.inDays > 30) {
      final months = diff.inDays ~/ 30;
      return 'Hace $months mes${months > 1 ? "es" : ""}';
    }

    if (diff.inDays > 0) {
      return 'Hace ${diff.inDays} día${diff.inDays > 1 ? "s" : ""}';
    }

    if (diff.inHours > 0) {
      return 'Hace ${diff.inHours} hora${diff.inHours > 1 ? "s" : ""}';
    }

    if (diff.inMinutes > 0) {
      return 'Hace ${diff.inMinutes} min';
    }

    return 'Hoy';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCompanies;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _AdminCompaniesColors.bg,
      appBar: AppBar(
        backgroundColor: _AdminCompaniesColors.bg,
        surfaceTintColor: _AdminCompaniesColors.bg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _AdminCompaniesColors.text,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Empresas',
              style: TextStyle(
                color: _AdminCompaniesColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Productores registrados en la plataforma',
              style: TextStyle(
                color: _AdminCompaniesColors.textSoft,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _AdminCompaniesColors.primary,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: _AdminCompaniesColors.primary,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomPadding),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildSearchAndFilters(),
            const SizedBox(height: 18),
            _buildListHeader(filtered.length),
            const SizedBox(height: 12),
            if (_loading)
              const _LoadingCard(message: 'Cargando empresas registradas...')
            else if (_companies.isEmpty)
              _EmptyStateCard(
                icon: Icons.storefront_rounded,
                color: _AdminCompaniesColors.primary,
                title: 'No hay empresas registradas',
                message: 'Cuando un productor se registre aparecerá en esta sección.',
                buttonText: 'Actualizar',
                onPressed: _load,
              )
            else if (filtered.isEmpty)
                _EmptyStateCard(
                  icon: Icons.search_off_rounded,
                  color: _AdminCompaniesColors.textSoft,
                  title: 'Sin resultados',
                  message: 'No encontramos empresas con esa búsqueda o filtro.',
                  buttonText: 'Limpiar filtros',
                  onPressed: _clearFilters,
                )
              else
                ...filtered.map(
                      (user) => _CompanyCard(
                    user: user,
                    registerText: _timeAgo(user.registerDate),
                    registerDate: _formatDate(user.registerDate),
                    onTap: () => _showDetail(user),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _AdminCompaniesColors.primaryDark,
            _AdminCompaniesColors.primary,
            _AdminCompaniesColors.primaryLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _AdminCompaniesColors.primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -28,
            child: _DecorCircle(
              size: 120,
              color: Colors.white.withOpacity(0.13),
            ),
          ),
          Positioned(
            bottom: -46,
            left: -32,
            child: _DecorCircle(
              size: 110,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: Icon(
              Icons.storefront_rounded,
              size: 92,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Directorio de empresas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Consulta productores, estado de cuenta y datos principales.',
                            style: TextStyle(
                              color: Color(0xFFFFF3D7),
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroMetric(
                      icon: Icons.groups_rounded,
                      label: 'Total',
                      value: '${_companies.length}',
                    ),
                    _HeroMetric(
                      icon: Icons.verified_rounded,
                      label: 'Activas',
                      value: '$_activeCount',
                    ),
                    _HeroMetric(
                      icon: Icons.trending_up_rounded,
                      label: 'Actividad',
                      value: '${_activePercent.toStringAsFixed(0)}%',
                    ),
                    _HeroMetric(
                      icon: Icons.calendar_month_rounded,
                      label: 'Este mes',
                      value: '$_newThisMonth',
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

  Widget _buildSearchAndFilters() {
    return _SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              filled: true,
              fillColor: _AdminCompaniesColors.input,
              hintText: 'Buscar por nombre, correo, teléfono o descripción...',
              hintStyle: const TextStyle(
                color: _AdminCompaniesColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _AdminCompaniesColors.textSoft,
              ),
              suffixIcon: _searchCtrl.text.trim().isEmpty
                  ? null
                  : IconButton(
                onPressed: () => _searchCtrl.clear(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: _AdminCompaniesColors.textSoft,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _AdminCompaniesColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: _AdminCompaniesColors.primary,
                  width: 1.3,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
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
                  icon: Icons.grid_view_rounded,
                  selected: _stateFilter == -1,
                  onTap: () => setState(() => _stateFilter = -1),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Activas',
                  icon: Icons.check_circle_rounded,
                  selected: _stateFilter == 1,
                  color: _AdminCompaniesColors.green,
                  onTap: () => setState(() => _stateFilter = 1),
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: 'Inactivas',
                  icon: Icons.cancel_rounded,
                  selected: _stateFilter == 0,
                  color: _AdminCompaniesColors.red,
                  onTap: () => setState(() => _stateFilter = 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(int count) {
    return Row(
      children: [
        const _IconBubble(
          icon: Icons.store_mall_directory_rounded,
          color: _AdminCompaniesColors.primary,
          background: _AdminCompaniesColors.primarySoft,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Listado de empresas',
                style: TextStyle(
                  color: _AdminCompaniesColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _loading ? 'Cargando información...' : '$count resultado${count == 1 ? "" : "s"} encontrado${count == 1 ? "" : "s"}',
                style: const TextStyle(
                  color: _AdminCompaniesColors.textSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!_loading && _companies.isNotEmpty)
          _StatusBadge(
            label: '${_companies.length}',
            color: _AdminCompaniesColors.primary,
            background: _AdminCompaniesColors.primarySoft,
          ),
      ],
    );
  }
}

class _AdminCompaniesColors {
  static const Color bg = Color(0xFFF5F0E8);
  static const Color card = Colors.white;
  static const Color cardSoft = Color(0xFFFBF8F1);
  static const Color input = Color(0xFFF8F5EF);

  static const Color primary = Color(0xFFB8860B);
  static const Color primaryDark = Color(0xFF7C4F08);
  static const Color primaryLight = Color(0xFFD7A84D);
  static const Color primarySoft = Color(0xFFFFF3D7);

  static const Color green = Color(0xFF5A8A5A);
  static const Color greenSoft = Color(0xFFEAF4EA);

  static const Color red = Color(0xFFD9534F);
  static const Color redSoft = Color(0xFFFFECEA);

  static const Color text = Color(0xFF2D2D2D);
  static const Color textSoft = Color(0xFF7B756B);
  static const Color textLight = Color(0xFFB5AFA4);
  static const Color border = Color(0xFFE7DED0);
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _AdminCompaniesColors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final UserModel user;
  final String registerText;
  final String registerDate;
  final VoidCallback onTap;

  const _CompanyCard({
    required this.user,
    required this.registerText,
    required this.registerDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = user.state == 1;
    final statusColor = active ? _AdminCompaniesColors.green : _AdminCompaniesColors.red;
    final statusBg = active ? _AdminCompaniesColors.greenSoft : _AdminCompaniesColors.redSoft;

    final name = user.name.trim().isEmpty ? 'Empresa sin nombre' : user.name.trim();
    final email = user.email.trim();
    final phone = (user.cellphone ?? '').trim();
    final description = (user.description ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _AdminCompaniesColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: _AdminCompaniesColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
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
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _AdminCompaniesColors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            label: active ? 'Activa' : 'Inactiva',
                            color: statusColor,
                            background: statusBg,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (email.isNotEmpty)
                        _MiniLine(
                          icon: Icons.email_outlined,
                          text: email,
                        ),
                      if (phone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: _MiniLine(
                            icon: Icons.phone_outlined,
                            text: phone,
                          ),
                        ),
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _AdminCompaniesColors.textSoft,
                              fontSize: 11.5,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _TinyBadge(
                            icon: Icons.calendar_today_rounded,
                            label: registerText,
                            color: _AdminCompaniesColors.primary,
                            background: _AdminCompaniesColors.primarySoft,
                          ),
                          _TinyBadge(
                            icon: Icons.badge_outlined,
                            label: 'ID #${user.id ?? "-"}',
                            color: _AdminCompaniesColors.textSoft,
                            background: _AdminCompaniesColors.input,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _AdminCompaniesColors.textLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyDetailSheet extends StatelessWidget {
  final UserModel user;

  const _CompanyDetailSheet({required this.user});

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha de registro';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    final active = user.state == 1;
    final statusColor = active ? _AdminCompaniesColors.green : _AdminCompaniesColors.red;
    final statusBg = active ? _AdminCompaniesColors.greenSoft : _AdminCompaniesColors.redSoft;

    final name = user.name.trim().isEmpty ? 'Empresa sin nombre' : user.name.trim();
    final email = user.email.trim();
    final phone = (user.cellphone ?? '').trim();
    final description = (user.description ?? '').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _AdminCompaniesColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _AdminCompaniesColors.primaryDark,
                            _AdminCompaniesColors.primary,
                            _AdminCompaniesColors.primaryLight,
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withOpacity(0.22)),
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email.isEmpty ? 'Sin correo registrado' : email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFF3D7),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StatusBadge(
                            label: active ? 'Empresa activa' : 'Empresa inactiva',
                            color: statusColor,
                            background: statusBg,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.18),
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailInfoGrid(
                  id: '#${user.id ?? "-"}',
                  state: active ? 'Activa' : 'Inactiva',
                  registerDate: _formatDate(user.registerDate),
                ),
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Información de contacto',
                  icon: Icons.contact_mail_rounded,
                  children: [
                    _DetailRow(
                      icon: Icons.email_outlined,
                      label: 'Correo',
                      value: email.isEmpty ? 'Sin correo' : email,
                    ),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Teléfono',
                      value: phone.isEmpty ? 'Sin teléfono' : phone,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailSection(
                  title: 'Descripción de la empresa',
                  icon: Icons.info_outline_rounded,
                  children: [
                    _DetailParagraph(
                      value: description.isEmpty
                          ? 'Esta empresa todavía no registró una descripción.'
                          : description,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailSection(
                  title: 'Datos administrativos',
                  icon: Icons.admin_panel_settings_rounded,
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Registro',
                      value: _formatDate(user.registerDate),
                    ),
                    _DetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Identificador',
                      value: '#${user.id ?? "-"}',
                    ),
                    _DetailRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Estado',
                      value: active ? 'Activa' : 'Inactiva',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailInfoGrid extends StatelessWidget {
  final String id;
  final String state;
  final String registerDate;

  const _DetailInfoGrid({
    required this.id,
    required this.state,
    required this.registerDate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DetailStatBox(
            icon: Icons.badge_outlined,
            label: 'ID',
            value: id,
            color: _AdminCompaniesColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DetailStatBox(
            icon: Icons.verified_rounded,
            label: 'Estado',
            value: state,
            color: state == 'Activa'
                ? _AdminCompaniesColors.green
                : _AdminCompaniesColors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DetailStatBox(
            icon: Icons.calendar_today_rounded,
            label: 'Registro',
            value: registerDate,
            color: _AdminCompaniesColors.textSoft,
          ),
        ),
      ],
    );
  }
}

class _DetailStatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailStatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AdminCompaniesColors.textSoft,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: _AdminCompaniesColors.cardSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _AdminCompaniesColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _IconBubble(
                icon: icon,
                color: _AdminCompaniesColors.primary,
                background: _AdminCompaniesColors.primarySoft,
                size: 38,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _AdminCompaniesColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailParagraph extends StatelessWidget {
  final String value;

  const _DetailParagraph({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: _AdminCompaniesColors.textSoft,
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: _AdminCompaniesColors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _AdminCompaniesColors.textSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _AdminCompaniesColors.text,
                    fontSize: 13,
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

class _FilterChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color = _AdminCompaniesColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : _AdminCompaniesColors.input,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : _AdminCompaniesColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : _AdminCompaniesColors.textSoft,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _AdminCompaniesColors.textSoft,
                  fontSize: 12,
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

class _MiniLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: _AdminCompaniesColors.textSoft,
          size: 14,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AdminCompaniesColors.textSoft,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFF3D7),
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _TinyBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
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

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;

  const _IconBubble({
    required this.icon,
    required this.color,
    required this.background,
    this.size = 42,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorCircle({
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

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _EmptyStateCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        children: [
          _IconBubble(
            icon: icon,
            color: color,
            background: color.withOpacity(0.10),
            size: 58,
            iconSize: 30,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminCompaniesColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminCompaniesColors.textSoft,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(buttonText!),
              style: OutlinedButton.styleFrom(
                foregroundColor: _AdminCompaniesColors.primary,
                side: const BorderSide(color: _AdminCompaniesColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String message;

  const _LoadingCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: _AdminCompaniesColors.primary,
              strokeWidth: 2.4,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _AdminCompaniesColors.textSoft,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}