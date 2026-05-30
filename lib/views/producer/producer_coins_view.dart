import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/coin_movement_controller.dart';
import '../../controllers/request_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';
import '../../models/app_config_model.dart';
import '../../models/request_model.dart';
import 'producer_dashboard_view.dart';
import 'producer_orders_view.dart';
import 'producer_products_view.dart';
import 'producer_profile_view.dart';
import 'producer_reload_view.dart';
import 'producer_sales_stats_view.dart';

class ProducerCoinsView extends StatefulWidget {
  const ProducerCoinsView({super.key});

  @override
  State<ProducerCoinsView> createState() => _ProducerCoinsViewState();
}

class _ProducerCoinsViewState extends State<ProducerCoinsView> {
  bool _initialLoadDone = false;
  DateTime? _lastUpdatedAt;
  RequestController? _requestController;

  String _selectedHistoryFilter = 'Todos';
  int _visibleHistoryCount = 5;

  static const int _historyBatchSize = 5;

  static const List<String> _historyFilters = [
    'Todos',
    'Pendientes',
    'Aprobadas',
    'Rechazadas',
  ];

  // ─── Paleta visual productor ───────────────────────────────────────────────
  static const Color _bgTop = Color(0xFFF8F2EA);
  static const Color _bgMiddle = Color(0xFFF2E5D5);
  static const Color _bgBottom = Color(0xFFE4D2BE);

  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);
  static const Color _surfaceMuted = Color(0xFFF7EFE5);
  static const Color _surfaceWarm = Color(0xFFFFF7EC);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8A6848);
  static const Color _coffee = Color(0xFF4B3427);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF43795C);
  static const Color _orange = Color(0xFFD97A33);
  static const Color _red = Color(0xFFBC5F39);
  static const Color _blue = Color(0xFF5E7FA3);
  static const Color _purple = Color(0xFF7A67A8);

  static const Color _textDark = Color(0xFF4B3427);
  static const Color _textSoft = Color(0xFF857261);
  static const Color _textMuted = Color(0xFFA19182);
  static const Color _border = Color(0xFFEEE3D5);
  static const Color _divider = Color(0xFFE7DACA);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _requestController = context.read<RequestController>();

      await _loadInitialData();

      if (!mounted) return;
      _configureRequestListener();
    });
  }

  @override
  void dispose() {
    _requestController?.onRequestStatusChanged = null;
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CARGA Y REFRESH
  // ────────────────────────────────────────────────────────────────────────────
  void _configureRequestListener() {
    final requestController = context.read<RequestController>();
    final userController = context.read<UserController>();
    final coinController = context.read<CoinMovementController>();

    requestController.onRequestStatusChanged = (request) async {
      if (!mounted) return;

      await userController.reloadCurrentUser();
      if (!mounted) return;

      final user = userController.currentUser;
      if (user?.id != null) {
        await Future.wait([
          coinController.loadCoinData(user!.id!),
          requestController.loadUserRequests(user.id!),
        ]);
      }

      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          backgroundColor: request.state == 1 ? _green : _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(
            request.state == 1
                ? 'Tu recarga fue aprobada. Las monedas ya están disponibles.'
                : 'Tu solicitud de recarga fue rechazada.',
          ),
        ),
      );

      setState(() {
        _lastUpdatedAt = DateTime.now();
      });
    };
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    final userController = context.read<UserController>();
    final coinController = context.read<CoinMovementController>();
    final requestController = context.read<RequestController>();
    final user = userController.currentUser;

    if (user == null || user.id == null || user.id! <= 0) {
      if (!mounted) return;
      setState(() => _initialLoadDone = true);
      return;
    }

    await Future.wait([
      coinController.loadCoinData(user.id!),
      requestController.loadConfig(),
      requestController.loadUserRequests(user.id!),
      requestController.resumePollingIfNeeded(user.id!),
    ]);

    if (!mounted) return;

    setState(() {
      _initialLoadDone = true;
      _lastUpdatedAt = DateTime.now();
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    final userController = context.read<UserController>();
    final coinController = context.read<CoinMovementController>();
    final requestController = context.read<RequestController>();
    final user = userController.currentUser;

    if (user == null || user.id == null || user.id! <= 0) return;

    await Future.wait([
      userController.reloadCurrentUser(),
      coinController.loadCoinData(user.id!),
      requestController.loadConfig(),
      requestController.loadUserRequests(user.id!),
      requestController.resumePollingIfNeeded(user.id!),
    ]);

    if (!mounted) return;

    setState(() {
      _lastUpdatedAt = DateTime.now();
    });
  }

  Future<void> _refreshAfterRequestSent() async {
    if (!mounted) return;

    final user = context.read<UserController>().currentUser;
    final requestController = context.read<RequestController>();
    final coinController = context.read<CoinMovementController>();

    if (user == null || user.id == null || user.id! <= 0) return;

    await Future.wait([
      requestController.loadUserRequests(user.id!),
      coinController.loadCoinData(user.id!),
      requestController.resumePollingIfNeeded(user.id!),
    ]);

    if (!mounted) return;

    setState(() {
      _visibleHistoryCount = _historyBatchSize;
      _lastUpdatedAt = DateTime.now();
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HISTORIAL
  // ────────────────────────────────────────────────────────────────────────────
  List<RequestModel> _sortedRequests(List<RequestModel> requests) {
    final copy = [...requests];
    copy.sort((a, b) {
      final aDate = a.registerDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.registerDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return copy;
  }

  List<RequestModel> _filteredRequests(List<RequestModel> requests) {
    final sorted = _sortedRequests(requests);

    switch (_selectedHistoryFilter) {
      case 'Pendientes':
        return sorted.where((r) => r.state == 0).toList();
      case 'Aprobadas':
        return sorted.where((r) => r.state == 1).toList();
      case 'Rechazadas':
        return sorted.where((r) => r.state == 2).toList();
      default:
        return sorted;
    }
  }

  List<RequestModel> _visibleRequests(List<RequestModel> requests) {
    return _filteredRequests(requests).take(_visibleHistoryCount).toList();
  }

  bool _hasMoreHistory(List<RequestModel> requests) {
    return _filteredRequests(requests).length > _visibleHistoryCount;
  }

  void _changeHistoryFilter(String filter) {
    setState(() {
      _selectedHistoryFilter = filter;
      _visibleHistoryCount = _historyBatchSize;
    });
  }

  void _showMoreHistory(List<RequestModel> requests) {
    final total = _filteredRequests(requests).length;
    setState(() {
      _visibleHistoryCount =
          (_visibleHistoryCount + _historyBatchSize).clamp(0, total);
    });
  }

  void _showLessHistory() {
    setState(() {
      _visibleHistoryCount = _historyBatchSize;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // NAVEGACIÓN
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _goToDashboard() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerDashboardView()),
    );
  }

  Future<void> _goToProducts() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerProductsView()),
    );
  }

  Future<void> _goToOrders() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerOrdersView()),
    );
  }

  Future<void> _goToSalesStats() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerSalesStatsView()),
    );
  }

  Future<void> _goToProfile() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProducerProfileView()),
    );
  }

  Future<void> _goToReloadView() async {
    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProducerReloadView()),
    );

    if (!mounted) return;

    if (result == true) {
      final messenger = ScaffoldMessenger.maybeOf(context);

      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: const Text(
            'Solicitud de recarga enviada. Quedará pendiente hasta aprobación.',
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

      await _refreshAfterRequestSent();
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // FORMATO
  // ────────────────────────────────────────────────────────────────────────────
  int _countRequestsByState(List<RequestModel> requests, int state) {
    return requests.where((request) => request.state == state).length;
  }

  Color _stateColor(int state) {
    switch (state) {
      case 1:
        return _green;
      case 2:
        return _red;
      default:
        return _orange;
    }
  }

  Color _stateBackground(int state) {
    switch (state) {
      case 1:
        return const Color(0xFFEAF7EF);
      case 2:
        return const Color(0xFFFFEFEF);
      default:
        return const Color(0xFFFFF5E8);
    }
  }

  IconData _stateIcon(int state) {
    switch (state) {
      case 1:
        return Icons.check_circle_rounded;
      case 2:
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  String _formatCoins(double value) {
    if (value == value.toInt().toDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  String _formatBs(double value) {
    if (value == value.toInt().toDouble()) return 'Bs ${value.toInt()}';
    return 'Bs ${value.toStringAsFixed(2)}';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }

  String _formatHour(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} • ${_formatHour(dateTime)}';
  }

  String _lastSyncText() {
    if (_lastUpdatedAt == null) return 'Sin actualización reciente';
    return 'Act. ${_formatHour(_lastUpdatedAt!)} · ${_formatDate(_lastUpdatedAt!)}';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _walletAdvice({
    required double balance,
    required int pendingCount,
    required int rejectedCount,
  }) {
    if (pendingCount > 0) {
      return 'Tienes $pendingCount solicitud${pendingCount == 1 ? '' : 'es'} esperando aprobación del administrador.';
    }

    if (balance <= 0) {
      return 'Tu saldo está en cero. Solicita una recarga para seguir publicando productos.';
    }

    if (balance <= 2) {
      return 'Tu saldo está bajo. Te conviene recargar antes de quedarte sin monedas.';
    }

    if (rejectedCount > 0) {
      return 'Revisa tus comprobantes rechazados antes de enviar una nueva solicitud.';
    }

    return 'Tu billetera está lista. Puedes seguir publicando productos sin problemas.';
  }

  Color _walletAdviceColor({
    required double balance,
    required int pendingCount,
    required int rejectedCount,
  }) {
    if (pendingCount > 0) return _orange;
    if (balance <= 2) return _red;
    if (rejectedCount > 0) return _purple;
    return _green;
  }

  double _maxWidth(double width) {
    if (width >= 1500) return 1320;
    if (width >= 1200) return 1080;
    if (width >= 1000) return 920;
    return width;
  }

  EdgeInsets _pagePadding(double width) {
    if (width >= 1200) return const EdgeInsets.fromLTRB(28, 16, 28, 130);
    if (width >= 800) return const EdgeInsets.fromLTRB(20, 14, 20, 130);
    return const EdgeInsets.fromLTRB(16, 12, 16, 130);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // IMÁGENES / AVATAR
  // ────────────────────────────────────────────────────────────────────────────
  Uint8List? _decodeBase64Image(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    try {
      final raw = value.trim();
      final normalized =
      raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkImage(String? value) {
    if (value == null) return false;

    final normalized = value.trim().toLowerCase();
    return normalized.startsWith('http://') || normalized.startsWith('https://');
  }

  Widget _buildUserAvatar({
    required String name,
    required String? image,
    double size = 58,
    double radius = 20,
    double fontSize = 22,
  }) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final bytes = _decodeBase64Image(image);

    Widget content;
    if (_isNetworkImage(image)) {
      content = Image.network(
        image!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialAvatar(
          initial: initial,
          size: size,
          radius: radius,
          fontSize: fontSize,
        ),
      );
    } else if (bytes != null) {
      content = Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitialAvatar(
          initial: initial,
          size: size,
          radius: radius,
          fontSize: fontSize,
        ),
      );
    } else {
      return _buildInitialAvatar(
        initial: initial,
        size: size,
        radius: radius,
        fontSize: fontSize,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }

  Widget _buildInitialAvatar({
    required String initial,
    required double size,
    required double radius,
    required double fontSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFFB9854A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // SHEET DETALLE
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _showRequestDetailsSheet(RequestModel request) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final stateColor = _stateColor(request.state);
        final stateBackground = _stateBackground(request.state);

        return DraggableScrollableSheet(
          initialChildSize: 0.80,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F2EA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6C6B3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: stateBackground,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              _stateIcon(request.state),
                              color: stateColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${request.value} monedas',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textDark,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildStatePill(
                                      text: request.stateLabel,
                                      color: stateColor,
                                      background: stateBackground,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatBs(request.amount),
                                      style: const TextStyle(
                                        color: _textSoft,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailCard(
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.payments_outlined,
                            label: 'Monto pagado',
                            value: _formatBs(request.amount),
                          ),
                          _buildDetailDivider(),
                          _buildDetailRow(
                            icon: Icons.monetization_on_outlined,
                            label: 'Monedas solicitadas',
                            value: '${request.value}',
                          ),
                          _buildDetailDivider(),
                          _buildDetailRow(
                            icon: Icons.schedule_rounded,
                            label: 'Fecha de registro',
                            value: request.registerDate != null
                                ? _formatDateTime(request.registerDate!)
                                : 'Sin fecha',
                          ),
                          if (request.processedDate != null) ...[
                            _buildDetailDivider(),
                            _buildDetailRow(
                              icon: Icons.task_alt_rounded,
                              label: 'Fecha de proceso',
                              value: _formatDateTime(request.processedDate!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            color: _primaryDark,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Comprobante enviado',
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _border),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: request.image.trim().isNotEmpty
                              ? AppImage(
                            src: request.image,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: _surfaceMuted,
                              child: const Center(
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  color: _primaryDark,
                                  size: 42,
                                ),
                              ),
                            ),
                          )
                              : Container(
                            color: _surfaceMuted,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    color: _primaryDark,
                                    size: 42,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Sin comprobante disponible',
                                    style: TextStyle(
                                      color: _textSoft,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _surfaceMuted,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _primaryDark, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: _textDark,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 1, color: _divider),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final coinController = context.watch<CoinMovementController>();
    final requestController = context.watch<RequestController>();

    final user = userController.currentUser;
    final requests = requestController.userRequests;

    final filteredRequests = _filteredRequests(requests);
    final visibleRequests = _visibleRequests(requests);

    final pendingCount = _countRequestsByState(requests, 0);
    final approvedCount = _countRequestsByState(requests, 1);
    final rejectedCount = _countRequestsByState(requests, 2);

    final screenWidth = MediaQuery.of(context).size.width;
    final isBusy = coinController.isBusy || requestController.isLoading;

    final isInitialLoading = !_initialLoadDone &&
        (coinController.isLoading || requestController.isLoading) &&
        requests.isEmpty;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF6EFE6),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFloatingActionButton(isBusy),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgMiddle, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -88,
              left: -60,
              child: _buildDecorBubble(190, _primary.withOpacity(0.10)),
            ),
            Positioned(
              top: 115,
              right: -58,
              child: _buildDecorBubble(180, _gold.withOpacity(0.14)),
            ),
            Positioned(
              bottom: 150,
              left: -70,
              child: _buildDecorBubble(185, _green.withOpacity(0.07)),
            ),
            Positioned(
              bottom: -80,
              right: -75,
              child: _buildDecorBubble(185, _coffee.withOpacity(0.06)),
            ),
            SafeArea(
              child: user == null || user.id == null
                  ? _buildNoUserState()
                  : RefreshIndicator(
                color: _primary,
                onRefresh: _refreshData,
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.zero,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _maxWidth(screenWidth),
                        ),
                        child: Padding(
                          padding: _pagePadding(screenWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTopBar(
                                userName: user.name,
                                userImage: user.image,
                                isBusy: isBusy,
                                pendingCount: pendingCount,
                              ),
                              const SizedBox(height: 18),
                              if (isInitialLoading)
                                _buildLoadingCard()
                              else ...[
                                _buildHeroCard(
                                  producerName: user.name,
                                  balance: coinController.balance,
                                  balanceInMoney:
                                  coinController.balanceInMoney,
                                  requestCount: requests.length,
                                  pendingCount: pendingCount,
                                  rejectedCount: rejectedCount,
                                  isBusy: isBusy,
                                ),
                                const SizedBox(height: 18),
                                _buildAdviceCard(
                                  balance: coinController.balance,
                                  pendingCount: pendingCount,
                                  rejectedCount: rejectedCount,
                                ),
                                const SizedBox(height: 18),
                                _buildOverviewSection(
                                  balance: coinController.balance,
                                  balanceInMoney:
                                  coinController.balanceInMoney,
                                  requestCount: requests.length,
                                  pendingCount: pendingCount,
                                ),
                                const SizedBox(height: 18),
                                _buildQuickActionsSection(isBusy: isBusy),
                                const SizedBox(height: 18),
                                _buildPaymentAndInfoSection(
                                  config: requestController.config,
                                ),
                                const SizedBox(height: 18),
                                _buildHistorySection(
                                  requests: requests,
                                  filteredRequests: filteredRequests,
                                  visibleRequests: visibleRequests,
                                  pendingCount: pendingCount,
                                  approvedCount: approvedCount,
                                  rejectedCount: rejectedCount,
                                  isLoading: requestController.isLoading,
                                  errorMessage:
                                  requestController.errorMessage,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // TOP BAR
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar({
    required String userName,
    required String? userImage,
    required bool isBusy,
    required int pendingCount,
  }) {
    final firstName = userName.split(' ').first;

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showMoreMenu,
          child: _buildUserAvatar(
            name: userName,
            image: userImage,
            size: 54,
            radius: 18,
            fontSize: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                  color: _textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Monedas de $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildTinyStatusChip(
                    pendingCount > 0 ? '$pendingCount pendientes' : 'Sin pendientes',
                    pendingCount > 0 ? _orange : _green,
                  ),
                  Text(
                    isBusy ? 'Actualizando...' : _lastSyncText(),
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildAppBarButton(
          icon: isBusy ? Icons.sync_rounded : Icons.refresh_rounded,
          color: _primary,
          onTap: _refreshData,
        ),
        const SizedBox(width: 8),
        _buildAppBarButton(
          icon: Icons.menu_rounded,
          color: _primaryDark,
          onTap: _showMoreMenu,
        ),
      ],
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required Color color,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onTap(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HERO
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildHeroCard({
    required String producerName,
    required double balance,
    required double balanceInMoney,
    required int requestCount,
    required int pendingCount,
    required int rejectedCount,
    required bool isBusy,
  }) {
    final displayBalance = _formatCoins(balance);
    final adviceColor = _walletAdviceColor(
      balance: balance,
      pendingCount: pendingCount,
      rejectedCount: rejectedCount,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF604E43), Color(0xFF493B35), Color(0xFF2E2624)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -38,
            right: -34,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withOpacity(0.11),
              ),
            ),
          ),
          Positioned(
            bottom: -46,
            left: -28,
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _HeroTag(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Billetera',
                  ),
                  _HeroTag(
                    icon: Icons.qr_code_2_rounded,
                    label: 'Pago QR',
                  ),
                  _HeroTag(
                    icon: Icons.verified_outlined,
                    label: 'Aprobación admin',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                producerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '$displayBalance monedas',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Saldo disponible para publicar productos y mantener activo tu catálogo.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.76),
                  fontSize: 12.8,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Equivalencia',
                      value: _formatBs(balanceInMoney),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Solicitudes',
                      value: requestCount.toString(),
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Pendientes',
                      value: pendingCount.toString(),
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildHeroStatBox(
                      label: 'Estado',
                      value: isBusy ? 'Cargando' : 'Disponible',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Row(
                  children: [
                    Icon(
                      balance <= 2 || pendingCount > 0
                          ? Icons.tips_and_updates_rounded
                          : Icons.verified_rounded,
                      color: adviceColor == _green
                          ? const Color(0xFFCDE8D9)
                          : const Color(0xFFFFD6A8),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _walletAdvice(
                          balance: balance,
                          pendingCount: pendingCount,
                          rejectedCount: rejectedCount,
                        ),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              LayoutBuilder(
                builder: (context, constraints) {
                  final vertical = constraints.maxWidth < 380;

                  final primaryButton = FilledButton.icon(
                    onPressed: isBusy ? null : _goToReloadView,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: const Text(
                      'Recargar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  );

                  final secondaryButton = FilledButton.icon(
                    onPressed: isBusy ? null : _refreshData,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _textDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Actualizar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  );

                  if (vertical) {
                    return Column(
                      children: [
                        SizedBox(width: double.infinity, child: primaryButton),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: secondaryButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: primaryButton),
                      const SizedBox(width: 10),
                      Expanded(child: secondaryButton),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatBox({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
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

  Widget _buildAdviceCard({
    required double balance,
    required int pendingCount,
    required int rejectedCount,
  }) {
    final color = _walletAdviceColor(
      balance: balance,
      pendingCount: pendingCount,
      rejectedCount: rejectedCount,
    );

    final title = color == _green
        ? 'Billetera saludable'
        : pendingCount > 0
        ? 'Solicitud en revisión'
        : 'Revisa tu saldo';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              color == _green
                  ? Icons.verified_rounded
                  : Icons.tips_and_updates_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _walletAdvice(
                    balance: balance,
                    pendingCount: pendingCount,
                    rejectedCount: rejectedCount,
                  ),
                  style: const TextStyle(
                    color: _textSoft,
                    fontSize: 12.5,
                    height: 1.42,
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

  // ────────────────────────────────────────────────────────────────────────────
  // RESUMEN
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewSection({
    required double balance,
    required double balanceInMoney,
    required int requestCount,
    required int pendingCount,
  }) {
    final items = [
      _OverviewItem(
        icon: Icons.monetization_on_outlined,
        title: 'Saldo actual',
        value: _formatCoins(balance),
        subtitle: 'Monedas disponibles',
        color: _primary,
      ),
      _OverviewItem(
        icon: Icons.payments_outlined,
        title: 'Valor referencial',
        value: _formatBs(balanceInMoney),
        subtitle: 'Equivalencia actual',
        color: _primaryDark,
      ),
      _OverviewItem(
        icon: Icons.receipt_long_outlined,
        title: 'Solicitudes',
        value: requestCount.toString(),
        subtitle: 'Recargas registradas',
        color: _green,
      ),
      _OverviewItem(
        icon: Icons.hourglass_top_rounded,
        title: 'Pendientes',
        value: pendingCount.toString(),
        subtitle: 'Esperando aprobación',
        color: _orange,
      ),
    ];

    return _buildSectionContainer(
      icon: Icons.dashboard_customize_rounded,
      iconColor: _primary,
      title: 'Resumen de monedas',
      subtitle: 'Vista rápida del estado actual de tu billetera.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 980 ? 4 : 2;

          return GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 128,
            ),
            itemBuilder: (_, index) => _buildOverviewCard(items[index]),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(_OverviewItem item) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up_rounded,
                color: item.color.withOpacity(0.55),
                size: 17,
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textDark,
              fontSize: 11.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ACCIONES RÁPIDAS
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildQuickActionsSection({
    required bool isBusy,
  }) {
    final actions = [
      _QuickActionData(
        icon: Icons.add_card_rounded,
        title: 'Solicitar recarga',
        subtitle: 'Sube comprobante QR',
        badge: 'Recargar',
        color: _primary,
        onTap: _goToReloadView,
      ),
      _QuickActionData(
        icon: Icons.refresh_rounded,
        title: 'Actualizar saldo',
        subtitle: 'Sincroniza monedas',
        badge: 'Actualizar',
        color: _blue,
        onTap: _refreshData,
      ),
      _QuickActionData(
        icon: Icons.bar_chart_rounded,
        title: 'Estadísticas',
        subtitle: 'Ver rendimiento',
        badge: 'Revisar',
        color: _purple,
        onTap: _goToSalesStats,
      ),
    ];

    return _buildSectionContainer(
      icon: Icons.bolt_rounded,
      iconColor: _gold,
      title: 'Acciones rápidas',
      subtitle: 'Todo lo importante para manejar tus monedas sin perder tiempo.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final verySmall = constraints.maxWidth < 345;
          final useHorizontalList = constraints.maxWidth < 430;

          if (verySmall) {
            return Column(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  _buildQuickActionCard(
                    data: actions[i],
                    compact: true,
                    enabled: !isBusy,
                  ),
                  if (i != actions.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }

          if (useHorizontalList) {
            return SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: actions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  return SizedBox(
                    width: 152,
                    child: _buildQuickActionCard(
                      data: actions[index],
                      compact: false,
                      enabled: !isBusy,
                    ),
                  );
                },
              ),
            );
          }

          return Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                Expanded(
                  child: _buildQuickActionCard(
                    data: actions[i],
                    compact: false,
                    enabled: !isBusy,
                  ),
                ),
                if (i != actions.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickActionCard({
    required _QuickActionData data,
    required bool compact,
    required bool enabled,
  }) {
    final color = enabled ? data.color : _textMuted;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled
            ? () async {
          await data.onTap();
        }
            : null,
        child: Ink(
          height: compact ? 86 : 154,
          padding: EdgeInsets.all(compact ? 12 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(enabled ? 0.16 : 0.08),
                _surfaceSoft,
                _surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -18,
                bottom: -18,
                child: Icon(
                  data.icon,
                  size: compact ? 58 : 70,
                  color: color.withOpacity(0.055),
                ),
              ),
              if (compact)
                Row(
                  children: [
                    _buildQuickActionIcon(icon: data.icon, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSoft,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionArrow(color),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildQuickActionIcon(icon: data.icon, color: color),
                        const Spacer(),
                        _buildQuickActionArrow(color),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        data.badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionIcon({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  Widget _buildQuickActionArrow(Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: color,
        size: 16,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // QR + INFO
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildPaymentAndInfoSection({
    required AppConfigModel config,
  }) {
    return _buildSectionContainer(
      icon: Icons.qr_code_2_rounded,
      iconColor: _primaryDark,
      title: 'Pago e información',
      subtitle: 'Escanea el QR, paga el monto correcto y sube tu comprobante.',
      child: Column(
        children: [
          _buildQrPaymentCard(config: config),
          const SizedBox(height: 14),
          _buildQuickInfoCard(bsPerCoin: config.bsPerCoin),
        ],
      ),
    );
  }

  Widget _buildQrPaymentCard({
    required AppConfigModel config,
  }) {
    final bsPerCoin = config.bsPerCoin <= 0 ? 100.0 : config.bsPerCoin;
    final qrImage = config.qrImage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 560;

          final qrWidget = Container(
            width: vertical ? double.infinity : 168,
            constraints: const BoxConstraints(minHeight: 168),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: qrImage != null && qrImage.trim().isNotEmpty
                ? AppImage(
              src: qrImage,
              borderRadius: 16,
              fit: BoxFit.contain,
              placeholder: const Center(
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 72,
                  color: _primaryDark,
                ),
              ),
            )
                : const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 72,
                    color: _primaryDark,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'QR no configurado',
                    style: TextStyle(
                      color: _textSoft,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );

          final infoWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: _primaryDark,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Recarga por QR',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '1 moneda = Bs ${bsPerCoin.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: _primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildMiniStep('1', 'Escanea el QR y realiza el pago.'),
              _buildMiniStep('2', 'Calcula el monto según las monedas que necesitas.'),
              _buildMiniStep('3', 'Adjunta el comprobante y envía la solicitud.'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _goToReloadView,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_card_rounded, size: 18),
                  label: const Text(
                    'Iniciar solicitud',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          );

          if (vertical) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                qrWidget,
                const SizedBox(height: 14),
                infoWidget,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              qrWidget,
              const SizedBox(width: 16),
              Expanded(child: infoWidget),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.2,
                color: _textSoft,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoCard({
    required double bsPerCoin,
  }) {
    final rate = bsPerCoin <= 0 ? 100.0 : bsPerCoin;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceWarm,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: _primaryDark),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importante antes de recargar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tu recarga primero queda como solicitud pendiente. Las monedas se acreditan recién cuando el administrador aprueba el comprobante.',
                      style: TextStyle(
                        fontSize: 13.2,
                        color: _textSoft,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.price_change_outlined,
                    color: _primaryDark,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Regla actual: 1 moneda = Bs ${rate.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w900,
                      color: _primaryDark,
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

  // ────────────────────────────────────────────────────────────────────────────
  // HISTORIAL
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildHistorySection({
    required List<RequestModel> requests,
    required List<RequestModel> filteredRequests,
    required List<RequestModel> visibleRequests,
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
    required bool isLoading,
    required String? errorMessage,
  }) {
    return _buildSectionContainer(
      icon: Icons.history_rounded,
      iconColor: _purple,
      title: 'Historial de solicitudes',
      subtitle: 'Filtra, revisa y abre cada recarga sin que la lista se vuelva eterna.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusOverview(
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            rejectedCount: rejectedCount,
          ),
          const SizedBox(height: 14),
          _buildHistoryToolbar(
            totalFiltered: filteredRequests.length,
            totalVisible: visibleRequests.length,
          ),
          const SizedBox(height: 12),
          _buildHistoryFilters(),
          const SizedBox(height: 14),
          if (errorMessage != null && errorMessage.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildErrorCard(errorMessage),
            ),
          _buildRequestsContent(
            requests: requests,
            filteredRequests: filteredRequests,
            visibleRequests: visibleRequests,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverview({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    final items = [
      _StatusMiniData(
        label: 'Pendientes',
        value: pendingCount.toString(),
        icon: Icons.hourglass_top_rounded,
        color: _orange,
        bg: const Color(0xFFFFF5E8),
      ),
      _StatusMiniData(
        label: 'Aprobadas',
        value: approvedCount.toString(),
        icon: Icons.check_circle_rounded,
        color: _green,
        bg: const Color(0xFFEAF7EF),
      ),
      _StatusMiniData(
        label: 'Rechazadas',
        value: rejectedCount.toString(),
        icon: Icons.cancel_rounded,
        color: _red,
        bg: const Color(0xFFFFEFEF),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        if (compact) {
          return Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _buildStatusMiniCard(items[i], compact: true),
                if (i != items.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _buildStatusMiniCard(items[i], compact: false)),
              if (i != items.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatusMiniCard(_StatusMiniData item, {required bool compact}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: item.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.color.withOpacity(0.15)),
      ),
      child: compact
          ? Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                color: _textDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 20),
          const SizedBox(height: 12),
          Text(
            item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryToolbar({
    required int totalFiltered,
    required int totalVisible,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            totalFiltered == 0
                ? 'No hay solicitudes para este filtro'
                : 'Mostrando $totalVisible de $totalFiltered solicitudes',
            style: const TextStyle(
              color: _textSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (_selectedHistoryFilter != 'Todos')
          TextButton.icon(
            onPressed: () => _changeHistoryFilter('Todos'),
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text(
              'Quitar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _historyFilters.map((filter) {
          final isSelected = _selectedHistoryFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _changeHistoryFilter(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : _surfaceMuted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? _primary : _divider,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: _primary.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : [],
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _textDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequestsContent({
    required List<RequestModel> requests,
    required List<RequestModel> filteredRequests,
    required List<RequestModel> visibleRequests,
    required bool isLoading,
  }) {
    if (isLoading && requests.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 26, bottom: 18),
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    if (filteredRequests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceSoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _divider),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 54,
              color: _primaryDark,
            ),
            SizedBox(height: 14),
            Text(
              'No hay solicitudes para mostrar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _textDark,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cuando envíes recargas o cambies de filtro, aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _textSoft,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...visibleRequests.map(
              (request) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRequestTile(request),
          ),
        ),
        if (_hasMoreHistory(requests) || _visibleHistoryCount > _historyBatchSize)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                if (_hasMoreHistory(requests))
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _showMoreHistory(requests),
                      icon: const Icon(Icons.expand_more_rounded, size: 18),
                      label: const Text(
                        'Ver más',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                if (_hasMoreHistory(requests) &&
                    _visibleHistoryCount > _historyBatchSize)
                  const SizedBox(width: 10),
                if (_visibleHistoryCount > _historyBatchSize)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showLessHistory,
                      icon: const Icon(Icons.expand_less_rounded, size: 18),
                      label: const Text(
                        'Ver menos',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryDark,
                        side: const BorderSide(color: _border),
                        backgroundColor: _surface,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRequestTile(RequestModel request) {
    final stateColor = _stateColor(request.state);
    final stateBackground = _stateBackground(request.state);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showRequestDetailsSheet(request),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _divider),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: stateBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _stateIcon(request.state),
                  color: stateColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${request.value} monedas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _buildStatePill(
                          text: request.stateLabel,
                          color: stateColor,
                          background: stateBackground,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatBs(request.amount),
                      style: const TextStyle(
                        color: _primaryDark,
                        fontSize: 12.4,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      request.registerDate != null
                          ? _formatDateTime(request.registerDate!)
                          : 'Sin fecha',
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: _textSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatePill({
    required String text,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.6,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // ESTADOS
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 18),
          Text(
            'Cargando monedas...',
            style: TextStyle(
              color: _textDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos sincronizando tu saldo, QR e historial de recargas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUserState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 620),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded, size: 58, color: _primaryDark),
              SizedBox(height: 16),
              Text(
                'No se encontró una sesión activa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Vuelve a iniciar sesión para visualizar tus monedas y solicitudes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _textSoft,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD5D5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A3C3C),
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // COMPONENTES COMUNES
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildSectionContainer({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 12.3,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTinyStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildDecorBubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // FAB
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildFloatingActionButton(bool isBusy) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.40),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: isBusy ? _textMuted : _primary,
          elevation: 0,
          shape: const CircleBorder(),
          onPressed: isBusy ? null : _goToReloadView,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BOTTOM NAV
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNavigationBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            border: Border(
              top: BorderSide(color: _border.withOpacity(0.85)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Inicio',
                  selected: false,
                  onTap: _goToDashboard,
                ),
                _buildNavItem(
                  icon: Icons.storefront_outlined,
                  label: 'Productos',
                  selected: false,
                  onTap: _goToProducts,
                ),
                const SizedBox(width: 56),
                _buildNavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Monedas',
                  selected: true,
                  onTap: _refreshData,
                ),
                _buildNavItem(
                  icon: Icons.menu_rounded,
                  label: 'Más',
                  selected: false,
                  onTap: _showMoreMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool selected,
    required Future<void> Function() onTap,
  }) {
    final color = selected ? _primary : _textSoft;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // MENÚ
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _showMoreMenu() async {
    final user = context.read<UserController>().currentUser;
    final name = user?.name ?? 'Productor';
    final email = user?.email ?? '';
    final image = user?.image;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8F2EA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6C6B3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.035),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildUserAvatar(
                          name: name,
                          image: image,
                          size: 54,
                          radius: 18,
                          fontSize: 22,
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
                                  color: _textDark,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                email.isEmpty ? 'Panel de productor' : email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _textSoft,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        _buildMenuAction(
                          icon: Icons.dashboard_rounded,
                          color: _primary,
                          title: 'Dashboard',
                          subtitle: 'Volver a la vista principal',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToDashboard();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.storefront_outlined,
                          color: _primaryDark,
                          title: 'Productos',
                          subtitle: 'Gestiona tu catálogo y stock',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToProducts();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.receipt_long_rounded,
                          color: _blue,
                          title: 'Pedidos',
                          subtitle: 'Atiende tus órdenes activas',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToOrders();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.bar_chart_rounded,
                          color: _purple,
                          title: 'Estadísticas',
                          subtitle: 'Métricas y rendimiento',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToSalesStats();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.person_outline_rounded,
                          color: _green,
                          title: 'Perfil',
                          subtitle: 'Datos, ubicación y horarios',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToProfile();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        _buildMenuAction(
                          icon: Icons.add_card_rounded,
                          color: _gold,
                          title: 'Solicitar recarga',
                          subtitle: 'Enviar comprobante de pago',
                          onTap: () {
                            Navigator.pop(ctx);
                            _goToReloadView();
                          },
                        ),
                        _buildMenuDivider(),
                        _buildMenuAction(
                          icon: Icons.refresh_rounded,
                          color: _primaryDark,
                          title: 'Actualizar monedas',
                          subtitle: 'Sincronizar saldo, QR e historial',
                          onTap: () {
                            Navigator.pop(ctx);
                            _refreshData();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuAction({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
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
                      color: _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _textSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _textSoft,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Divider(height: 1, thickness: 1, color: _divider),
    );
  }
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
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewItem {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _OverviewItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}

class _StatusMiniData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatusMiniData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });
}

class _QuickActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final Future<void> Function() onTap;

  const _QuickActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.onTap,
  });
}