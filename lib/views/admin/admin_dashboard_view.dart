import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../../models/app_config_model.dart';
import '../../models/order_model.dart';
import '../../models/report_models.dart';
import '../../models/request_model.dart';
import '../../models/user_model.dart';
import '../../services/order_service.dart';
import '../../services/report_service.dart';
import '../../services/request_service.dart';
import '../../services/user_service.dart';
import '../auth/login_view.dart';
import 'admin_clients_view.dart';
import 'admin_coin_recharge_view.dart';
import 'admin_companies_view.dart';
import 'admin_reports_view.dart';
import 'admin_settings_view.dart';
import 'admin_users_list_view.dart';

/// Dashboard principal del administrador.
/// UI premium + datos reales desde servicios del proyecto.
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final UserService _userService = UserService();
  final RequestService _requestService = RequestService();
  final OrderService _orderService = OrderService();
  final ReportService _reportService = ReportService();

  bool _loadingStats = true;
  String? _errorMessage;
  DateTime? _lastUpdated;

  int _clientCount = 0;
  int _activeClientCount = 0;
  int _companyCount = 0;
  int _activeCompanyCount = 0;
  int _adminCount = 0;

  int _totalOrders = 0;
  int _pendingOrders = 0;
  int _preparingOrders = 0;
  int _shippedOrders = 0;
  int _completedOrders = 0;
  int _cancelledOrders = 0;

  int _pendingRequests = 0;
  int _approvedRequests = 0;
  int _rejectedRequests = 0;

  double _completedSalesBs = 0;
  double _approvedRechargeBs = 0;
  double _bsPerCoin = 9;

  List<EmpresaReportItem> _topEmpresas = [];
  List<ProductoReportItem> _topProductos = [];
  List<ClienteReportItem> _topClientes = [];
  List<SectorReportItem> _sectores = [];
  List<RequestModel> _recentRequests = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _loadingStats = true;
        _errorMessage = null;
      });
    }

    try {
      final now = DateTime.now();
      final from = DateTime(now.year - 10, 1, 1);
      final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final results = await Future.wait<dynamic>([
        _userService.getUsersByRole(0),
        _userService.getUsersByRole(1),
        _userService.getAllAdmins(),
        _requestService.getAllRequests(),
        _requestService.getAppConfig(),
        _reportService.getTopEmpresas(from: from, to: to),
        _reportService.getTopProductos(from: from, to: to),
        _reportService.getTopClientes(from: from, to: to),
        _reportService.getSectores(),
      ]);

      final clients = results[0] as List<UserModel>;
      final companies = results[1] as List<UserModel>;
      final admins = results[2] as List<UserModel>;
      final requests = results[3] as List<RequestModel>;
      final appConfig = results[4] as AppConfigModel;
      final topEmpresas = results[5] as List<EmpresaReportItem>;
      final topProductos = results[6] as List<ProductoReportItem>;
      final topClientes = results[7] as List<ClienteReportItem>;
      final sectores = results[8] as List<SectorReportItem>;

      final companiesWithId = companies.where((u) => u.id != null).toList();

      final orderGroups = await Future.wait<List<OrderModel>>(
        companiesWithId.map((producer) {
          return _orderService.getOrdersByProducer(producer.id!);
        }),
      );

      final allOrders = orderGroups.expand((items) => items).toList();

      if (!mounted) return;

      setState(() {
        _clientCount = clients.length;
        _activeClientCount = clients.where((u) => u.state == 1).length;

        _companyCount = companies.length;
        _activeCompanyCount = companies.where((u) => u.state == 1).length;

        _adminCount = admins.length;

        _totalOrders = allOrders.length;
        _pendingOrders = allOrders.where((o) => o.state == 0).length;
        _preparingOrders = allOrders.where((o) => o.state == 1).length;
        _shippedOrders = allOrders.where((o) => o.state == 2).length;
        _completedOrders = allOrders.where((o) => o.state == 3).length;
        _cancelledOrders = allOrders.where((o) => o.state == 4).length;

        _completedSalesBs = allOrders
            .where((o) => o.state == 3)
            .fold<double>(0, (sum, order) => sum + order.amount);

        _pendingRequests = requests.where((r) => r.state == 0).length;
        _approvedRequests = requests.where((r) => r.state == 1).length;
        _rejectedRequests = requests.where((r) => r.state == 2).length;

        _approvedRechargeBs = requests
            .where((r) => r.state == 1)
            .fold<double>(0, (sum, request) => sum + request.amount);

        _bsPerCoin = appConfig.bsPerCoin;

        _topEmpresas = topEmpresas;
        _topProductos = topProductos;
        _topClientes = topClientes;
        _sectores = sectores;
        _recentRequests = requests.take(5).toList();

        _lastUpdated = DateTime.now();
        _loadingStats = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
        _errorMessage = 'No se pudo cargar el dashboard. Intenta nuevamente.';
      });
    }
  }

  int get _activeOrders => _pendingOrders + _preparingOrders + _shippedOrders;

  int get _totalUsers => _clientCount + _companyCount + _adminCount;

  double get _usersActivePercent {
    final total = _clientCount + _companyCount;
    if (total <= 0) return 0;
    return ((_activeClientCount + _activeCompanyCount) / total).clamp(0, 1);
  }

  double get _ordersCompletedPercent {
    if (_totalOrders <= 0) return 0;
    return (_completedOrders / _totalOrders).clamp(0, 1);
  }

  double get _requestsApprovedPercent {
    final total = _pendingRequests + _approvedRequests + _rejectedRequests;
    if (total <= 0) return 0;
    return (_approvedRequests / total).clamp(0, 1);
  }

  double get _systemScore {
    final usersScore = _usersActivePercent * 36;
    final ordersScore = _ordersCompletedPercent * 34;
    final requestPenalty = _pendingRequests > 0
        ? (_pendingRequests >= 10 ? 18 : _pendingRequests * 1.8)
        : 0;
    final cancelPenalty = _cancelledOrders > 0
        ? (_cancelledOrders >= 10 ? 10 : _cancelledOrders * 1.0)
        : 0;

    final score = 30 + usersScore + ordersScore - requestPenalty - cancelPenalty;
    return score.clamp(0, 100);
  }

  ImageProvider? _buildImageProvider(String? image) {
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

  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Sin actualizar';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Sin fecha';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  String _systemLabel() {
    if (_systemScore >= 80) return 'Excelente';
    if (_systemScore >= 60) return 'Estable';
    if (_systemScore >= 40) return 'Revisar';
    return 'Crítico';
  }

  Color _systemColor() {
    if (_systemScore >= 80) return _AdminColors.success;
    if (_systemScore >= 60) return _AdminColors.blue;
    if (_systemScore >= 40) return _AdminColors.warning;
    return _AdminColors.danger;
  }

  void _openPage(Widget page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _logout() async {
    Navigator.pop(context);

    final controller = Provider.of<UserController>(context, listen: false);
    await controller.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _AdminColors.background,
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Stack(
          children: [
            const _DecoratedBackground(),
            RefreshIndicator(
              color: _AdminColors.primary,
              backgroundColor: Colors.white,
              onRefresh: () => _loadDashboard(showLoader: false),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  if (_loadingStats)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildLoadingState(),
                    )
                  else if (_errorMessage != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildErrorState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            _buildWelcomeCard(),
                            const SizedBox(height: 18),
                            _buildControlCenter(),
                            const SizedBox(height: 18),
                            _buildMainMetrics(),
                            const SizedBox(height: 18),
                            _buildQuickActions(),
                            const SizedBox(height: 18),
                            _buildOrdersResume(),
                            const SizedBox(height: 18),
                            _buildRequestsResume(),
                            const SizedBox(height: 18),
                            _buildTopCompanies(),
                            const SizedBox(height: 18),
                            _buildTopProducts(),
                            const SizedBox(height: 18),
                            _buildClientsAndSectors(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      floating: true,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _RoundIconButton(
          icon: Icons.menu_rounded,
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      titleSpacing: 4,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: _AdminColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _AdminColors.primary.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'AgroMarket Admin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _AdminColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
      actions: [
        _NotificationButton(
          count: _pendingRequests,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminCoinRechargeView()),
            );
          },
        ),
        Consumer<UserController>(
          builder: (_, controller, __) {
            final img = controller.currentUser?.image;
            final provider = _buildImageProvider(img);

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminSettingsView()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _AdminColors.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: _AdminColors.primary.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: _AdminColors.primarySoft,
                    backgroundImage: provider,
                    child: provider == null
                        ? const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 19,
                    )
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              gradient: _AdminColors.goldGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _AdminColors.primary.withOpacity(0.26),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _AdminColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Cargando panel administrativo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _AdminColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Consultando usuarios, pedidos, recargas, reportes y estado general del marketplace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: _AdminColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: _AdminColors.danger.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: _AdminColors.danger.withOpacity(0.14),
              ),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: _AdminColors.danger,
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No se pudo cargar',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _AdminColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Ocurrió un error inesperado.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: _AdminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _loadDashboard(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AdminColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Reintentar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Consumer<UserController>(
      builder: (_, controller, __) {
        final name = controller.currentUser?.name.trim();
        final displayName = name == null || name.isEmpty ? 'Administrador' : name;

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: _AdminColors.heroGradient,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: _AdminColors.primary.withOpacity(0.28),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -48,
                top: -45,
                child: _GlowCircle(
                  size: 150,
                  color: Colors.white.withOpacity(0.14),
                ),
              ),
              Positioned(
                right: 34,
                bottom: -50,
                child: _GlowCircle(
                  size: 115,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              Positioned(
                left: -42,
                bottom: -48,
                child: _GlowCircle(
                  size: 124,
                  color: Colors.black.withOpacity(0.08),
                ),
              ),
              Positioned(
                right: 20,
                top: 75,
                child: Icon(
                  Icons.spa_rounded,
                  color: Colors.white.withOpacity(0.08),
                  size: 90,
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
                          icon: Icons.admin_panel_settings_rounded,
                          text: 'Centro de control',
                        ),
                        const Spacer(),
                        _HeroBadge(
                          icon: Icons.update_rounded,
                          text: _formatDateTime(_lastUpdated),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hola, $displayName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Controla usuarios, empresas, recargas, pedidos y reportes desde un panel limpio, rápido y visual.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 13.2,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMiniStat(
                            label: 'Usuarios',
                            value: _formatNumber(_totalUsers),
                            icon: Icons.diversity_3_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeroMiniStat(
                            label: 'Pedidos activos',
                            value: '$_activeOrders',
                            icon: Icons.route_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroMiniStat(
                            label: 'Recargas pendientes',
                            value: '$_pendingRequests',
                            icon: Icons.receipt_long_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeroMiniStat(
                            label: 'Ventas cerradas',
                            value: _formatBs(_completedSalesBs),
                            icon: Icons.payments_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlCenter() {
    final scoreColor = _systemColor();

    return _DashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Estado general',
            subtitle: 'Lectura rápida del rendimiento actual',
            icon: Icons.monitor_heart_rounded,
            compact: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ScoreRing(
                value: _systemScore / 100,
                text: '${_systemScore.round()}%',
                color: scoreColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusPill(
                      label: _systemLabel(),
                      color: scoreColor,
                      icon: Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Salud del marketplace',
                      style: TextStyle(
                        color: _AdminColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _pendingRequests > 0
                          ? 'Hay $_pendingRequests recargas esperando revisión administrativa.'
                          : 'Todo está tranquilo. No hay recargas pendientes por revisar.',
                      style: const TextStyle(
                        color: _AdminColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressInsight(
            title: 'Usuarios activos',
            valueText:
            '${(_usersActivePercent * 100).toStringAsFixed(0)}%',
            percent: _usersActivePercent,
            color: _AdminColors.green,
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 12),
          _ProgressInsight(
            title: 'Pedidos completados',
            valueText:
            '${(_ordersCompletedPercent * 100).toStringAsFixed(0)}%',
            percent: _ordersCompletedPercent,
            color: _AdminColors.success,
            icon: Icons.verified_rounded,
          ),
          const SizedBox(height: 12),
          _ProgressInsight(
            title: 'Recargas aprobadas',
            valueText:
            '${(_requestsApprovedPercent * 100).toStringAsFixed(0)}%',
            percent: _requestsApprovedPercent,
            color: _AdminColors.primary,
            icon: Icons.account_balance_wallet_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildMainMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Resumen principal',
          subtitle: 'Indicadores vivos del sistema',
          icon: Icons.insights_rounded,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PremiumMetricCard(
                title: 'Clientes',
                value: _formatNumber(_clientCount),
                subtitle: '$_activeClientCount activos',
                icon: Icons.people_alt_rounded,
                color: _AdminColors.green,
                backgroundIcon: Icons.groups_2_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminClientsView()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PremiumMetricCard(
                title: 'Empresas',
                value: _formatNumber(_companyCount),
                subtitle: '$_activeCompanyCount activas',
                icon: Icons.store_mall_directory_rounded,
                color: _AdminColors.primary,
                backgroundIcon: Icons.storefront_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminCompaniesView()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PremiumMetricCard(
                title: 'Ventas completadas',
                value: _formatBs(_completedSalesBs),
                subtitle: '$_completedOrders pedidos cerrados',
                icon: Icons.payments_rounded,
                color: _AdminColors.success,
                backgroundIcon: Icons.trending_up_rounded,
                isMoney: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PremiumMetricCard(
                title: 'Recargas pendientes',
                value: _formatNumber(_pendingRequests),
                subtitle: '$_approvedRequests aprobadas',
                icon: Icons.account_balance_wallet_rounded,
                color: _pendingRequests > 0
                    ? _AdminColors.warning
                    : _AdminColors.blue,
                backgroundIcon: Icons.wallet_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminCoinRechargeView(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Accesos rápidos',
          subtitle: 'Herramientas principales del administrador',
          icon: Icons.touch_app_rounded,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.16,
          children: [
            _ActionTile(
              title: 'Crear usuarios',
              subtitle: 'Admins y cuentas',
              icon: Icons.person_add_alt_1_rounded,
              color: _AdminColors.primary,
              badge: '$_adminCount admins',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersListView()),
                );
              },
            ),
            _ActionTile(
              title: 'Solicitudes',
              subtitle: 'Revisar comprobantes',
              icon: Icons.receipt_long_rounded,
              color: _AdminColors.warning,
              badge: '$_pendingRequests pendientes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCoinRechargeView(),
                  ),
                );
              },
            ),
            _ActionTile(
              title: 'Reportes PDF',
              subtitle: 'Empresas, clientes y ventas',
              icon: Icons.picture_as_pdf_rounded,
              color: _AdminColors.danger,
              badge: 'Exportar',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReportsView()),
                );
              },
            ),
            _ActionTile(
              title: 'Configuración',
              subtitle: 'QR y valor de moneda',
              icon: Icons.tune_rounded,
              color: _AdminColors.blue,
              badge: 'Bs ${_bsPerCoin.toStringAsFixed(0)}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminSettingsView()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrdersResume() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Flujo de pedidos',
            subtitle:
            '$_totalOrders pedidos registrados · $_activeOrders actualmente en proceso',
            icon: Icons.local_shipping_rounded,
            compact: true,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OrderFlowStep(
                  label: 'Pendiente',
                  value: _pendingOrders,
                  icon: Icons.schedule_rounded,
                  color: _AdminColors.warning,
                  isFirst: true,
                ),
              ),
              Expanded(
                child: _OrderFlowStep(
                  label: 'Preparación',
                  value: _preparingOrders,
                  icon: Icons.inventory_2_rounded,
                  color: _AdminColors.blue,
                ),
              ),
              Expanded(
                child: _OrderFlowStep(
                  label: 'Enviado',
                  value: _shippedOrders,
                  icon: Icons.delivery_dining_rounded,
                  color: _AdminColors.primary,
                  isLast: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SoftInfoTile(
                  icon: Icons.verified_rounded,
                  title: 'Completados',
                  value: '$_completedOrders',
                  color: _AdminColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SoftInfoTile(
                  icon: Icons.cancel_rounded,
                  title: 'Cancelados',
                  value: '$_cancelledOrders',
                  color: _AdminColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsResume() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Recargas y monedas',
            subtitle:
            'Precio actual: Bs ${_bsPerCoin.toStringAsFixed(2)} por moneda',
            icon: Icons.monetization_on_rounded,
            compact: true,
            actionText: 'Ver todo',
            onActionTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminCoinRechargeView(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SoftInfoTile(
                  icon: Icons.pending_actions_rounded,
                  title: 'Pendientes',
                  value: '$_pendingRequests',
                  color: _AdminColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SoftInfoTile(
                  icon: Icons.check_circle_rounded,
                  title: 'Aprobadas',
                  value: '$_approvedRequests',
                  color: _AdminColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SoftInfoTile(
                  icon: Icons.highlight_off_rounded,
                  title: 'Rechazadas',
                  value: '$_rejectedRequests',
                  color: _AdminColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MoneyResumeCard(
            title: 'Monto aprobado en recargas',
            amount: _formatBs(_approvedRechargeBs),
            subtitle: 'Saldo acreditado mediante solicitudes aprobadas',
          ),
          const SizedBox(height: 14),
          if (_recentRequests.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Sin solicitudes todavía',
              subtitle: 'Cuando un usuario solicite recarga aparecerá aquí.',
            )
          else
            Column(
              children: _recentRequests.map((request) {
                return _RequestTile(
                  request: request,
                  dateText: _formatDate(request.registerDate),
                  amountText: _formatBs(request.amount),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopCompanies() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Empresas con mayor movimiento',
            subtitle: 'Ranking real desde reportes del sistema',
            icon: Icons.leaderboard_rounded,
            compact: true,
          ),
          const SizedBox(height: 14),
          if (_topEmpresas.isEmpty)
            const _EmptyState(
              icon: Icons.storefront_rounded,
              title: 'Sin empresas para mostrar',
              subtitle: 'Aparecerán cuando existan productos activos con stock.',
            )
          else
            _TopCompaniesChart(
              data: _topEmpresas,
              formatMoney: _formatBs,
            ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Productos destacados',
            subtitle: 'Productos con mayor valor de inventario',
            icon: Icons.shopping_basket_rounded,
            compact: true,
          ),
          const SizedBox(height: 14),
          if (_topProductos.isEmpty)
            const _EmptyState(
              icon: Icons.inventory_2_rounded,
              title: 'Sin productos activos',
              subtitle: 'Cuando haya productos con stock se verán aquí.',
            )
          else
            Column(
              children: _topProductos.take(5).toList().asMap().entries.map(
                    (entry) {
                  final index = entry.key;
                  final product = entry.value;
                  final total = product.precio * product.stock;

                  return _ProductTile(
                    rank: index + 1,
                    name: product.nombre,
                    producer: product.empresaNombre,
                    stock: '${product.stock} ${product.unidad}',
                    amount: _formatBs(total),
                  );
                },
              ).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildClientsAndSectors() {
    return Column(
      children: [
        _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Clientes con mayor saldo',
                subtitle: 'Usuarios con más poder de compra',
                icon: Icons.person_pin_rounded,
                compact: true,
              ),
              const SizedBox(height: 14),
              if (_topClientes.isEmpty)
                const _EmptyState(
                  icon: Icons.people_alt_rounded,
                  title: 'Sin clientes destacados',
                  subtitle: 'Aparecerán clientes activos con saldo disponible.',
                )
              else
                Column(
                  children: _topClientes.take(5).map((client) {
                    return _ClientTile(
                      name: client.nombre,
                      email: client.email,
                      balance: _formatBs(client.balance),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Sectores activos',
                subtitle: 'Familias de productos registradas',
                icon: Icons.category_rounded,
                compact: true,
              ),
              const SizedBox(height: 14),
              if (_sectores.isEmpty)
                const _EmptyState(
                  icon: Icons.category_rounded,
                  title: 'Sin sectores registrados',
                  subtitle: 'Aquí se mostrarán las familias de productos.',
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _sectores.take(8).map((sector) {
                    return _SectorChip(
                      name: sector.nombre,
                      products: sector.totalProductos,
                      companies: sector.totalEmpresas,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Consumer<UserController>(
              builder: (_, controller, __) {
                final user = controller.currentUser;
                final name =
                user?.name.trim().isNotEmpty == true ? user!.name : 'Admin';
                final email = user?.email ?? 'Panel administrativo';
                final provider = _buildImageProvider(user?.image);

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    gradient: _AdminColors.heroGradient,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: _AdminColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -35,
                        child: _GlowCircle(
                          size: 100,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.white.withOpacity(0.18),
                            backgroundImage: provider,
                            child: provider == null
                                ? const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                            )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.78),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _MiniDrawerBadge(
                                  text:
                                  '${_systemLabel()} · ${_systemScore.round()}%',
                                  color: _systemColor(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            _DrawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              isSelected: true,
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Crear Usuarios',
              onTap: () => _openPage(const AdminUsersListView()),
            ),
            _DrawerItem(
              icon: Icons.groups_rounded,
              label: 'Clientes',
              onTap: () => _openPage(const AdminClientsView()),
            ),
            _DrawerItem(
              icon: Icons.storefront_rounded,
              label: 'Empresas',
              onTap: () => _openPage(const AdminCompaniesView()),
            ),
            _DrawerItem(
              icon: Icons.receipt_long_rounded,
              label: 'Solicitudes de Carga',
              badgeText: _pendingRequests > 0 ? '$_pendingRequests' : null,
              onTap: () => _openPage(const AdminCoinRechargeView()),
            ),
            _DrawerItem(
              icon: Icons.bar_chart_rounded,
              label: 'Reportes',
              onTap: () => _openPage(const AdminReportsView()),
            ),
            _DrawerItem(
              icon: Icons.settings_rounded,
              label: 'Configuraciones',
              onTap: () => _openPage(const AdminSettingsView()),
            ),
            const Spacer(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Cerrar sesión',
                iconColor: _AdminColors.danger,
                labelColor: _AdminColors.danger,
                onTap: _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminColors {
  static const Color background = Color(0xFFF5F0E8);
  static const Color surface = Colors.white;

  static const Color primary = Color(0xFFB8860B);
  static const Color primaryDark = Color(0xFF6D4307);
  static const Color primarySoft = Color(0xFFD4A017);
  static const Color cream = Color(0xFFFFF6DD);

  static const Color textPrimary = Color(0xFF2D261B);
  static const Color textSecondary = Color(0xFF8A7C68);
  static const Color border = Color(0xFFE8DEC9);

  static const Color green = Color(0xFF5E8C45);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFD84343);
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

class _AdminShadows {
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

class _DecoratedBackground extends StatelessWidget {
  const _DecoratedBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -65,
          child: _GlowCircle(
            size: 185,
            color: _AdminColors.primary.withOpacity(0.12),
          ),
        ),
        Positioned(
          top: 190,
          left: -75,
          child: _GlowCircle(
            size: 150,
            color: _AdminColors.green.withOpacity(0.08),
          ),
        ),
        Positioned(
          bottom: 120,
          right: -85,
          child: _GlowCircle(
            size: 170,
            color: _AdminColors.warning.withOpacity(0.08),
          ),
        ),
      ],
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
        gradient: _AdminColors.softSurfaceGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _AdminColors.border.withOpacity(0.76)),
        boxShadow: _AdminShadows.card,
      ),
      child: child,
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
              color: _AdminColors.textPrimary,
              size: 23,
            ),
          ),
        ),
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
                    fontSize: 17.5,
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

class _NotificationButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationButton({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.86),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _AdminColors.textPrimary,
              size: 22,
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _AdminColors.danger,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _AdminColors.background, width: 2),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;
  final String? actionText;
  final VoidCallback? onActionTap;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.compact = false,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: compact ? 36 : 40,
      height: compact ? 36 : 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _AdminColors.primary.withOpacity(0.16),
            _AdminColors.primary.withOpacity(0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        icon,
        color: _AdminColors.primary,
        size: compact ? 18 : 21,
      ),
    );

    return Row(
      children: [
        iconBox,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _AdminColors.textPrimary,
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AdminColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (actionText != null && onActionTap != null)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              foregroundColor: _AdminColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              actionText!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final double value;
  final String text;
  final Color color;

  const _ScoreRing({
    required this.value,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(92, 92),
            painter: _RingPainter(
              value: value,
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'score',
                style: TextStyle(
                  color: _AdminColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  _RingPainter({
    required this.value,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 9.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withOpacity(0.45),
          color,
          color.withOpacity(0.8),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.28318 * value.clamp(0, 1),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressInsight extends StatelessWidget {
  final String title;
  final String valueText;
  final double percent;
  final Color color;
  final IconData icon;

  const _ProgressInsight({
    required this.title,
    required this.valueText,
    required this.percent,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final safePercent = percent.clamp(0, 1).toDouble();

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _AdminColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    valueText,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: _AdminColors.background,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: safePercent,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final IconData backgroundIcon;
  final Color color;
  final VoidCallback? onTap;
  final bool isMoney;

  const _PremiumMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.backgroundIcon,
    required this.color,
    this.onTap,
    this.isMoney = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          height: 158,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                color.withOpacity(0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _AdminColors.border.withOpacity(0.75)),
            boxShadow: _AdminShadows.card,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -18,
                child: Icon(
                  backgroundIcon,
                  size: 84,
                  color: color.withOpacity(0.07),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icon, color: color, size: 23),
                        ),
                        const Spacer(),
                        if (onTap != null)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: color,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _AdminColors.textPrimary,
                        fontSize: isMoney ? 19 : 25,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AdminColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AdminColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _AdminColors.border.withOpacity(0.75)),
            boxShadow: _AdminShadows.card,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -16,
                top: -16,
                child: _GlowCircle(
                  size: 74,
                  color: color.withOpacity(0.09),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.18),
                                color.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(icon, color: color, size: 25),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: color,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AdminColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AdminColors.textSecondary,
                        fontSize: 11.2,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderFlowStep extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _OrderFlowStep({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (!isFirst)
              Expanded(
                child: Container(
                  height: 3,
                  color: color.withOpacity(0.18),
                ),
              )
            else
              const Expanded(child: SizedBox()),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.16)),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  height: 3,
                  color: color.withOpacity(0.18),
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _AdminColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SoftInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SoftInfoTile({
    required this.icon,
    required this.title,
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
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AdminColors.textSecondary,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyResumeCard extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;

  const _MoneyResumeCard({
    required this.title,
    required this.amount,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _AdminColors.success.withOpacity(0.11),
            _AdminColors.green.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _AdminColors.success.withOpacity(0.13),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.savings_rounded,
              color: _AdminColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textSecondary,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(
              color: _AdminColors.success,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final RequestModel request;
  final String dateText;
  final String amountText;

  const _RequestTile({
    required this.request,
    required this.dateText,
    required this.amountText,
  });

  Color get _stateColor {
    switch (request.state) {
      case 1:
        return _AdminColors.success;
      case 2:
        return _AdminColors.danger;
      default:
        return _AdminColors.warning;
    }
  }

  IconData get _stateIcon {
    switch (request.state) {
      case 1:
        return Icons.check_circle_rounded;
      case 2:
        return Icons.cancel_rounded;
      default:
        return Icons.pending_actions_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = request.userName?.trim().isNotEmpty == true
        ? request.userName!.trim()
        : 'Usuario #${request.userID}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AdminColors.background.withOpacity(0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AdminColors.border.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _stateColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_stateIcon, color: _stateColor, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateText · ${request.value} monedas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: const TextStyle(
                  color: _AdminColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _stateColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  request.stateLabel,
                  style: TextStyle(
                    color: _stateColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
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

class _TopCompaniesChart extends StatelessWidget {
  final List<EmpresaReportItem> data;
  final String Function(double value) formatMoney;

  const _TopCompaniesChart({
    required this.data,
    required this.formatMoney,
  });

  double get _maxValue {
    double max = 1;
    for (final item in data) {
      if (item.totalVentas > max) max = item.totalVentas;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final max = _maxValue;
    final top = data.isNotEmpty ? data.first : null;

    return Column(
      children: [
        if (top != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: _AdminColors.heroGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Empresa líder',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        top.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(top.totalVentas),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        Column(
          children: data.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percent = (item.totalVentas / max).clamp(0.06, 1.0).toDouble();

            return Container(
              margin: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: index == 0
                          ? _AdminColors.goldGradient
                          : LinearGradient(
                        colors: [
                          _AdminColors.primary.withOpacity(0.15),
                          _AdminColors.primary.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index == 0
                              ? Colors.white
                              : _AdminColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _AdminColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatMoney(item.totalVentas),
                              style: const TextStyle(
                                color: _AdminColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: _AdminColors.background,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: percent,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: _AdminColors.goldGradient,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${item.totalProductos} productos activos',
                          style: const TextStyle(
                            color: _AdminColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final int rank;
  final String name;
  final String producer;
  final String stock;
  final String amount;

  const _ProductTile({
    required this.rank,
    required this.name,
    required this.producer,
    required this.stock,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTop
            ? _AdminColors.primary.withOpacity(0.08)
            : _AdminColors.background.withOpacity(0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTop
              ? _AdminColors.primary.withOpacity(0.14)
              : _AdminColors.border.withOpacity(0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isTop
                  ? _AdminColors.goldGradient
                  : LinearGradient(
                colors: [
                  _AdminColors.green.withOpacity(0.14),
                  _AdminColors.green.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: isTop
                  ? const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 22,
              )
                  : Text(
                '$rank',
                style: const TextStyle(
                  color: _AdminColors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  producer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  color: _AdminColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stock,
                style: const TextStyle(
                  color: _AdminColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final String name;
  final String email;
  final String balance;

  const _ClientTile({
    required this.name,
    required this.email,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final cleanName = name.trim();
    final letter = cleanName.isEmpty ? 'C' : cleanName[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AdminColors.background.withOpacity(0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AdminColors.border.withOpacity(0.45)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _AdminColors.primary.withOpacity(0.12),
            child: Text(
              letter,
              style: const TextStyle(
                color: _AdminColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanName.isEmpty ? 'Cliente' : cleanName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _AdminColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              balance,
              style: const TextStyle(
                color: _AdminColors.success,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectorChip extends StatelessWidget {
  final String name;
  final int products;
  final int companies;

  const _SectorChip({
    required this.name,
    required this.products,
    required this.companies,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _AdminColors.primary.withOpacity(0.1),
            _AdminColors.primary.withOpacity(0.045),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AdminColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.eco_rounded,
            color: _AdminColors.primary,
            size: 19,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Sector' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$products prod. · $companies emp.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textSecondary,
                    fontSize: 10.5,
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _AdminColors.background.withOpacity(0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _AdminColors.border.withOpacity(0.45)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _AdminColors.textSecondary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: _AdminColors.textSecondary.withOpacity(0.65),
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminColors.textSecondary,
              fontSize: 11.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDrawerBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniDrawerBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.17),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final String? badgeText;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.iconColor,
    this.labelColor,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
    isSelected ? Colors.white : labelColor ?? _AdminColors.textPrimary;

    final iconForeground =
    isSelected ? Colors.white : iconColor ?? _AdminColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected ? _AdminColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.16)
                        : iconForeground.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconForeground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                      isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _AdminColors.danger,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badgeText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
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