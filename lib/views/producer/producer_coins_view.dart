import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/coin_movement_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/coin_movement_model.dart';
import 'producer_dashboard_view.dart';
import 'producer_products_view.dart';
import 'producer_profile_view.dart';

class ProducerCoinsView extends StatefulWidget {
  const ProducerCoinsView({super.key});

  @override
  State<ProducerCoinsView> createState() => _ProducerCoinsViewState();
}

class _ProducerCoinsViewState extends State<ProducerCoinsView> {
  bool _initialLoadDone = false;
  DateTime? _lastUpdatedAt;

  static const Color _bgTop = Color(0xFFF8F2EA);
  static const Color _bgMid = Color(0xFFF3EADF);
  static const Color _bgBottom = Color(0xFFEBDDCB);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8B6B4A);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF3F7D58);
  static const Color _orange = Color(0xFFD96C2F);
  static const Color _brownText = Color(0xFF4E3426);
  static const Color _softText = Color(0xFF8C7B6B);
  static const Color _border = Color(0xFFF0E8DC);
  static const Color _divider = Color(0xFFE7DACA);
  static const Color _card = Colors.white;
  static const Color _danger = Color(0xFFD85B5B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    final userController = context.read<UserController>();
    final coinController = context.read<CoinMovementController>();
    final user = userController.currentUser;

    if (user == null || user.id == null || user.id! <= 0) {
      setState(() {
        _initialLoadDone = true;
      });
      return;
    }

    await coinController.loadCoinData(user.id!);

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
    final user = userController.currentUser;

    if (user == null || user.id == null || user.id! <= 0) return;

    await coinController.loadCoinData(user.id!);

    if (!mounted) return;
    setState(() {
      _lastUpdatedAt = DateTime.now();
    });
  }

  Future<void> _goToDashboard() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerDashboardView(),
      ),
    );
  }

  Future<void> _goToProducts() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerProductsView(),
      ),
    );
  }

  Future<void> _goToProfile() async {
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProducerProfileView(),
      ),
    );
  }

  Future<void> _onBottomNavigationTap(int index) async {
    switch (index) {
      case 0:
        await _goToDashboard();
        break;
      case 1:
        await _goToProducts();
        break;
      case 2:
        await _refreshData();
        break;
      case 3:
        await _goToProfile();
        break;
    }
  }

  Future<void> _showRechargeDialog() async {
    if (!mounted) return;

    final pageContext = context;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(pageContext);
    final userController = pageContext.read<UserController>();
    final coinController = pageContext.read<CoinMovementController>();
    final user = userController.currentUser;

    if (user == null || user.id == null || user.id! <= 0) {
      scaffoldMessenger?.hideCurrentSnackBar();
      scaffoldMessenger?.showSnackBar(
        const SnackBar(
          content: Text('No se encontró un productor válido.'),
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    try {
      final result = await showModalBottomSheet<bool>(
        context: pageContext,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          bool isSubmitting = false;

          return StatefulBuilder(
            builder: (modalContext, setSheetState) {
              Future<void> submitRequest() async {
                final amountText = amountController.text.trim();
                final description = descriptionController.text.trim();

                if (amountText.isEmpty) {
                  scaffoldMessenger?.hideCurrentSnackBar();
                  scaffoldMessenger?.showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa la cantidad de monedas.'),
                    ),
                  );
                  return;
                }

                final amount = double.tryParse(amountText);

                if (amount == null || amount <= 0) {
                  scaffoldMessenger?.hideCurrentSnackBar();
                  scaffoldMessenger?.showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa una cantidad válida de monedas.'),
                    ),
                  );
                  return;
                }

                if (amount != amount.toInt().toDouble()) {
                  scaffoldMessenger?.hideCurrentSnackBar();
                  scaffoldMessenger?.showSnackBar(
                    const SnackBar(
                      content: Text('La cantidad de monedas debe ser entera.'),
                    ),
                  );
                  return;
                }

                if (isSubmitting) return;

                if (sheetContext.mounted) {
                  setSheetState(() {
                    isSubmitting = true;
                  });
                }

                bool success = false;

                try {
                  success = await coinController.requestRecharge(
                    userId: user.id!,
                    amount: amount,
                    description: description.isEmpty ? null : description,
                  );
                } catch (_) {
                  success = false;
                }

                if (!mounted) return;

                if (sheetContext.mounted) {
                  setSheetState(() {
                    isSubmitting = false;
                  });
                }

                if (success) {
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop(true);
                  }
                  return;
                }

                scaffoldMessenger?.hideCurrentSnackBar();
                scaffoldMessenger?.showSnackBar(
                  SnackBar(
                    content: Text(
                      coinController.errorMessage ??
                          'No se pudo registrar la solicitud de recarga.',
                    ),
                  ),
                );
              }

              final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

              return Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_primary, Color(0xFFB9854A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.add_card_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Solicitar recarga',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: _brownText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'El administrador deberá aprobar la solicitud para que las monedas aparezcan en tu saldo.',
                            style: TextStyle(
                              fontSize: 14,
                              color: _softText,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Cantidad de monedas',
                              hintText: 'Ejemplo: 5',
                              filled: true,
                              fillColor: const Color(0xFFFBF8F3),
                              labelStyle: const TextStyle(color: _softText),
                              hintStyle: const TextStyle(color: _softText),
                              prefixIcon: const Icon(
                                Icons.monetization_on_outlined,
                                color: _primaryDark,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(color: _border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(color: _primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Descripción opcional',
                              hintText:
                              'Ejemplo: Recarga para publicar nuevos productos',
                              filled: true,
                              fillColor: const Color(0xFFFBF8F3),
                              labelStyle: const TextStyle(color: _softText),
                              hintStyle: const TextStyle(color: _softText),
                              alignLabelWithHint: true,
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 46),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  color: _primaryDark,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(color: _border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(color: _primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F4EC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE6DDCF)),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: _primaryDark,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Regla actual: 1 moneda = 100',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          OverflowBar(
                            spacing: 12,
                            overflowSpacing: 12,
                            alignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () {
                                  if (Navigator.of(sheetContext).canPop()) {
                                    Navigator.of(sheetContext).pop(false);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(120, 52),
                                  side: const BorderSide(color: _border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: isSubmitting ? null : submitRequest,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(145, 52),
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  'Solicitar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (!mounted) return;

      if (result == true) {
        scaffoldMessenger?.hideCurrentSnackBar();
        scaffoldMessenger?.showSnackBar(
          const SnackBar(
            content: Text('Solicitud de recarga enviada correctamente.'),
          ),
        );
        await _refreshData();
      }
    } finally {
      amountController.dispose();
      descriptionController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userController = context.watch<UserController>();
    final coinController = context.watch<CoinMovementController>();
    final user = userController.currentUser;
    final movements = coinController.movements;

    final pendingCount = _countByStatus(movements, 'Pendiente');
    final approvedCount = _countByStatus(movements, 'Aprobado');
    final rejectedCount = _countByStatus(movements, 'Rechazado');
    final registeredCount = _countByStatus(movements, 'Registrado');

    final screenWidth = MediaQuery.of(context).size.width;
    final isInitialLoading =
        !_initialLoadDone && coinController.isLoading && movements.isEmpty;

    return Scaffold(
      extendBody: true,
      backgroundColor: _bgTop,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton.extended(
          backgroundColor: _primary,
          elevation: 12,
          onPressed: coinController.isBusy ? null : _showRechargeDialog,
          icon: const Icon(Icons.add_card_rounded, color: Colors.white),
          label: const Text(
            'Solicitar',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgMid, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -60,
              child: _buildBackgroundOrb(
                size: 230,
                color: _primary.withOpacity(0.10),
              ),
            ),
            Positioned(
              top: 160,
              right: -70,
              child: _buildBackgroundOrb(
                size: 180,
                color: _primaryDark.withOpacity(0.08),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -20,
              child: _buildBackgroundOrb(
                size: 210,
                color: _green.withOpacity(0.06),
              ),
            ),
            Positioned(
              bottom: 230,
              right: -20,
              child: _buildBackgroundOrb(
                size: 95,
                color: _gold.withOpacity(0.10),
              ),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: _maxWidth(screenWidth),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopBar(
                              isBusy: coinController.isBusy,
                              pendingCount: pendingCount,
                            ),
                            const SizedBox(height: 18),
                            if (isInitialLoading)
                              _buildLoadingCard()
                            else ...[
                              _buildHeroCard(
                                producerName: user.name,
                                balance: coinController.balance,
                                balanceInMoney: coinController.balanceInMoney,
                                requestCount: movements.length,
                                pendingCount: pendingCount,
                                isBusy: coinController.isBusy,
                              ),
                              const SizedBox(height: 18),
                              _buildSectionContainer(
                                title: 'Resumen de monedas',
                                subtitle:
                                'Vista rápida y clara del estado actual de tu billetera.',
                                child: _buildOverviewCards(
                                  balance: coinController.balance,
                                  balanceInMoney: coinController.balanceInMoney,
                                  requestCount: movements.length,
                                  pendingCount: pendingCount,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildSectionContainer(
                                title: 'Estado de solicitudes',
                                subtitle:
                                'Distribución real de tus recargas registradas.',
                                child: _buildStatusOverview(
                                  pendingCount: pendingCount,
                                  approvedCount: approvedCount,
                                  rejectedCount: rejectedCount,
                                  registeredCount: registeredCount,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildSectionContainer(
                                title: 'Acciones rápidas',
                                subtitle:
                                'Accesos principales para recargar o actualizar tu saldo.',
                                child: _buildActionsSection(
                                  onRequestRecharge: _showRechargeDialog,
                                  onRefresh: _refreshData,
                                  isBusy: coinController.isBusy,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _buildSectionContainer(
                                title: 'Información importante',
                                subtitle:
                                'Reglas y contexto útil para el uso de monedas.',
                                child: _buildQuickInfoCard(),
                              ),
                              const SizedBox(height: 18),
                              _buildSectionContainer(
                                title: 'Historial de solicitudes',
                                subtitle:
                                'Aquí puedes revisar tus recargas y su estado actual.',
                                child: Column(
                                  children: [
                                    if (coinController.hasError)
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(bottom: 12),
                                        child: _buildErrorCard(
                                          coinController.errorMessage!,
                                        ),
                                      ),
                                    _buildMovementsContent(
                                      movements: movements,
                                      isLoading:
                                      coinController.isLoadingMovements ||
                                          coinController.isLoading,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }

  double _maxWidth(double width) {
    if (width >= 1500) return 1320;
    if (width >= 1200) return 1080;
    if (width >= 1000) return 920;
    return width;
  }

  Widget _buildBackgroundOrb({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTopBar({
    required bool isBusy,
    required int pendingCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFFB9854A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildHeaderChip(
                          icon: Icons.wallet_outlined,
                          label: 'Mis monedas',
                          color: _primaryDark,
                          background: const Color(0xFFFFF7EC),
                        ),
                        _buildHeaderChip(
                          icon: Icons.hourglass_top_rounded,
                          label: '$pendingCount pendientes',
                          color: _orange,
                          background: const Color(0xFFFFF4E7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Billetera del productor',
                      style: TextStyle(
                        fontSize: 24,
                        color: _brownText,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastUpdatedAt == null
                          ? 'Sin actualización reciente'
                          : 'Actualizado ${_formatHour(_lastUpdatedAt!)} · ${_formatDate(_lastUpdatedAt!)}',
                      style: const TextStyle(
                        fontSize: 11.8,
                        color: _softText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isBusy ? null : _refreshData,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _card.withOpacity(0.98),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Icon(
              Icons.refresh_rounded,
              color: isBusy ? _softText : _primaryDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      decoration: BoxDecoration(
        color: _card.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 16),
          Text(
            'Cargando monedas...',
            style: TextStyle(
              color: _brownText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estamos trayendo tu saldo y el historial de solicitudes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _softText,
              fontSize: 12.5,
              height: 1.4,
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
            color: _card.withOpacity(0.96),
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
              Icon(
                Icons.person_off_rounded,
                size: 58,
                color: _primaryDark,
              ),
              SizedBox(height: 16),
              Text(
                'No se encontró una sesión activa del productor.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _brownText,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Vuelve a iniciar sesión para visualizar tus monedas y solicitudes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _softText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required String producerName,
    required double balance,
    required double balanceInMoney,
    required int requestCount,
    required int pendingCount,
    required bool isBusy,
  }) {
    final displayBalance = _formatCoins(balance);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF554941),
            Color(0xFF403732),
            Color(0xFF2E2926),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.17),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -34,
            right: -20,
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
            bottom: -40,
            left: -18,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 20,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                color: Colors.white70,
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
                      icon: Icons.account_balance_wallet_outlined,
                      text: 'Billetera premium',
                    ),
                    _buildHeroChip(
                      icon: Icons.verified_outlined,
                      text: 'Datos reales',
                    ),
                    _buildHeroChip(
                      icon: Icons.bolt_outlined,
                      text: 'Recarga rápida',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  producerName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$displayBalance monedas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildHeroMetric(
                          icon: Icons.payments_outlined,
                          title: 'Referencia',
                          value: balanceInMoney.toStringAsFixed(0),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withOpacity(0.10),
                      ),
                      Expanded(
                        child: _buildHeroMetric(
                          icon: Icons.receipt_long_outlined,
                          title: 'Solicitudes',
                          value: requestCount.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildHeroStat(
                      label: 'Pendientes',
                      value: pendingCount.toString(),
                    ),
                    _buildHeroStat(
                      label: 'Regla actual',
                      value: '1 = 100',
                    ),
                    _buildHeroStat(
                      label: 'Saldo visible',
                      value: displayBalance,
                    ),
                    _buildHeroStat(
                      label: 'Estado',
                      value: isBusy ? 'Cargando' : 'Disponible',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : _showRechargeDialog,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.add_card_rounded, size: 18),
                        label: const Text('Solicitar recarga'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : _refreshData,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _brownText,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Actualizar'),
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
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStat({
    required String label,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
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

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _card.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
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
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(99),
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
                        color: _brownText,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _softText,
                        fontSize: 12.5,
                        height: 1.4,
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

  Widget _buildOverviewCards({
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
        accent: _primary,
      ),
      _OverviewItem(
        icon: Icons.payments_outlined,
        title: 'Valor referencial',
        value: balanceInMoney.toStringAsFixed(0),
        subtitle: 'Equivalencia actual',
        accent: _primaryDark,
      ),
      _OverviewItem(
        icon: Icons.receipt_long_outlined,
        title: 'Solicitudes',
        value: requestCount.toString(),
        subtitle: 'Registros históricos',
        accent: _green,
      ),
      _OverviewItem(
        icon: Icons.hourglass_top_rounded,
        title: 'Pendientes',
        value: pendingCount.toString(),
        subtitle: 'Esperando aprobación',
        accent: _orange,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        double childAspectRatio = constraints.maxWidth < 400 ? 1.08 : 1.25;

        if (constraints.maxWidth >= 980) {
          crossAxisCount = 4;
          childAspectRatio = 1.22;
        } else if (constraints.maxWidth >= 700) {
          crossAxisCount = 2;
          childAspectRatio = 1.55;
        }

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (_, index) => _buildOverviewCard(items[index]),
        );
      },
    );
  }

  Widget _buildOverviewCard(_OverviewItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFCF8), Color(0xFFF8F1E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              item.icon,
              color: item.accent,
              size: 22,
            ),
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: _brownText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C5A4B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: _softText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverview({
    required int pendingCount,
    required int approvedCount,
    required int rejectedCount,
    required int registeredCount,
  }) {
    final items = [
      _StatusMiniData(
        label: 'Pendiente',
        value: pendingCount.toString(),
        icon: Icons.hourglass_top_rounded,
        color: _orange,
        bg: const Color(0xFFFFF5E8),
      ),
      _StatusMiniData(
        label: 'Aprobado',
        value: approvedCount.toString(),
        icon: Icons.check_circle_rounded,
        color: _green,
        bg: const Color(0xFFEAF7EF),
      ),
      _StatusMiniData(
        label: 'Rechazado',
        value: rejectedCount.toString(),
        icon: Icons.cancel_rounded,
        color: _danger,
        bg: const Color(0xFFFFEFEF),
      ),
      _StatusMiniData(
        label: 'Registrado',
        value: registeredCount.toString(),
        icon: Icons.receipt_long_rounded,
        color: _primaryDark,
        bg: const Color(0xFFF4EEE5),
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, index) => _buildStatusMiniCard(items[index]),
    );
  }

  Widget _buildStatusMiniCard(_StatusMiniData item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: item.color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: item.color, size: 20),
          const Spacer(),
          Text(
            item.value,
            style: TextStyle(
              color: item.color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: const TextStyle(
              color: _softText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _divider),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _primaryDark,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información importante',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _brownText,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Las recargas se registran como solicitudes y deben ser aprobadas por el administrador. El historial mostrado corresponde a esas solicitudes.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _softText,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Regla actual: 1 moneda = 100',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection({
    required VoidCallback onRequestRecharge,
    required Future<void> Function() onRefresh,
    required bool isBusy,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 620;

        if (vertical) {
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : onRequestRecharge,
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text(
                    'Solicitar recarga',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : () => onRefresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Actualizar saldo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: _primaryDark,
                    side: const BorderSide(color: _border),
                    backgroundColor: _card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : onRequestRecharge,
                icon: const Icon(Icons.add_card_rounded),
                label: const Text(
                  'Solicitar recarga',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : () => onRefresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Actualizar saldo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: _primaryDark,
                  side: const BorderSide(color: _border),
                  backgroundColor: _card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
          const Icon(
            Icons.error_outline_rounded,
            color: _danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A3C3C),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsContent({
    required List<CoinMovementModel> movements,
    required bool isLoading,
  }) {
    if (isLoading && movements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 26),
        child: Center(
          child: CircularProgressIndicator(
            color: _primary,
          ),
        ),
      );
    }

    if (movements.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
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
              'Aún no tienes solicitudes registradas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _brownText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cuando solicites una recarga, aquí podrás ver su estado y la fecha en que fue registrada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _softText,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: movements
          .map(
            (movement) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildMovementCard(movement),
        ),
      )
          .toList(),
    );
  }

  Widget _buildMovementCard(CoinMovementModel movement) {
    final description = _safeDescription(movement.description);
    final status = _extractStatus(description);
    final statusColor = _statusColor(status);
    final statusBackground = _statusBackground(status);
    final statusIcon = _statusIcon(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card.withOpacity(0.97),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    Text(
                      '${_formatCoins(movement.amount)} monedas',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _brownText,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _softText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSoftInfoChip(
                      icon: Icons.schedule_rounded,
                      text: _formatDateTime(movement.createdAt),
                    ),
                    _buildSoftInfoChip(
                      icon: Icons.receipt_long_outlined,
                      text: 'Solicitud registrada',
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

  Widget _buildSoftInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3EA),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryDark),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: _softText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final items = <_BottomNavData>[
      const _BottomNavData(
        icon: Icons.home_rounded,
        label: 'Inicio',
        index: 0,
      ),
      const _BottomNavData(
        icon: Icons.storefront_rounded,
        label: 'Productos',
        index: 1,
      ),
      const _BottomNavData(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Monedas',
        index: 2,
      ),
      const _BottomNavData(
        icon: Icons.person_rounded,
        label: 'Perfil',
        index: 3,
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 82,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.86),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.65)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBottomNavItem(items[0], selected: false),
                  ),
                  Expanded(
                    child: _buildBottomNavItem(items[1], selected: false),
                  ),
                  const SizedBox(width: 68),
                  Expanded(
                    child: _buildBottomNavItem(items[2], selected: true),
                  ),
                  Expanded(
                    child: _buildBottomNavItem(items[3], selected: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(_BottomNavData item, {required bool selected}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _onBottomNavigationTap(item.index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: selected ? _primaryDark : _softText,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? _primaryDark : _softText,
                fontSize: 11.3,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countByStatus(List<CoinMovementModel> movements, String status) {
    return movements
        .where(
          (movement) =>
      _extractStatus(_safeDescription(movement.description)) == status,
    )
        .length;
  }

  String _safeDescription(String? description) {
    final text = (description ?? '').trim();
    if (text.isEmpty) {
      return 'Solicitud registrada en el sistema.';
    }
    return text;
  }

  String _extractStatus(String description) {
    final text = description.toLowerCase();

    if (text.contains('aprobado')) return 'Aprobado';
    if (text.contains('rechazado')) return 'Rechazado';
    if (text.contains('pendiente')) return 'Pendiente';

    return 'Registrado';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Aprobado':
        return _green;
      case 'Rechazado':
        return _danger;
      case 'Pendiente':
        return _orange;
      default:
        return _primaryDark;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'Aprobado':
        return const Color(0xFFEAF7EF);
      case 'Rechazado':
        return const Color(0xFFFFEFEF);
      case 'Pendiente':
        return const Color(0xFFFFF5E8);
      default:
        return const Color(0xFFF4EEE5);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Aprobado':
        return Icons.check_circle_rounded;
      case 'Rechazado':
        return Icons.cancel_rounded;
      case 'Pendiente':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _formatCoins(double value) {
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
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
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year - $hour:$minute';
  }
}

class _OverviewItem {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  const _OverviewItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
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

class _BottomNavData {
  final IconData icon;
  final String label;
  final int index;

  const _BottomNavData({
    required this.icon,
    required this.label,
    required this.index,
  });
}