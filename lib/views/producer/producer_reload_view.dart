import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/request_controller.dart';
import '../../controllers/user_controller.dart';
import 'producer_payment_view.dart';

class ProducerReloadView extends StatefulWidget {
  const ProducerReloadView({super.key});

  @override
  State<ProducerReloadView> createState() => _ProducerReloadViewState();
}

class _ProducerReloadViewState extends State<ProducerReloadView> {
  int? _selectedCoins;

  static const Color _bg = Color(0xFFF8F2EA);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8B6B4A);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF3F7D58);
  static const Color _orange = Color(0xFFD96C2F);
  static const Color _text = Color(0xFF4E3426);
  static const Color _textSoft = Color(0xFF8C7B6B);
  static const Color _border = Color(0xFFF0E8DC);

  static const List<_CoinPackage> _packages = [
    _CoinPackage(coins: 10, tag: null, subtitle: 'Ideal para empezar'),
    _CoinPackage(coins: 50, tag: null, subtitle: 'Buen equilibrio'),
    _CoinPackage(coins: 100, tag: 'Más popular', subtitle: 'Para varias publicaciones'),
    _CoinPackage(coins: 500, tag: 'Mejor opción', subtitle: 'Para productores activos'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestController>().loadConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer2<RequestController, UserController>(
          builder: (context, requestController, userController, _) {
            final config = requestController.config;

            /// Usa el mismo valor que el cliente.
            /// Si en algún caso raro la BD entrega 0 o negativo, cae al
            /// default del modelo (AppConfigModel.defaults = 9 Bs).
            final bsPerCoin = config.bsPerCoin > 0
                ? config.bsPerCoin
                : 9.0;

            final balance =
                userController.currentUser?.balance.toStringAsFixed(0) ?? '0';

            return Column(
              children: [
                _buildTopBar(context, balance),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(bsPerCoin),
                        const SizedBox(height: 22),
                        _buildSectionTitle(),
                        const SizedBox(height: 12),
                        ..._packages.map(
                              (pack) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PackageCard(
                              package: pack,
                              bsPerCoin: bsPerCoin,
                              selected: _selectedCoins == pack.coins,
                              onTap: () {
                                setState(() {
                                  _selectedCoins = pack.coins;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(bsPerCoin),
                      ],
                    ),
                  ),
                ),
                _buildFooter(context, bsPerCoin),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String balance) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _text,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _surface,
              padding: const EdgeInsets.all(10),
              elevation: 2,
              shadowColor: Colors.black12,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                ),
              ],
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _gold,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$balance monedas',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(double bsPerCoin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            right: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip(Icons.qr_code_2_rounded, 'Pago por QR'),
                  _heroChip(Icons.receipt_long_outlined, 'Con comprobante'),
                  _heroChip(Icons.verified_outlined, 'Aprobación admin'),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Recargar monedas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona un paquete para seguir al pago. Las monedas se acreditan cuando el administrador apruebe tu solicitud.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: _gold, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tasa actual: 1 moneda = Bs ${bsPerCoin.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
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

  Widget _buildSectionTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paquetes disponibles',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Elige la cantidad de monedas que quieres solicitar.',
          style: TextStyle(
            fontSize: 13,
            color: _textSoft,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(double bsPerCoin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _infoRow(
            icon: Icons.info_outline_rounded,
            text:
            'Tus monedas no se acreditan al instante. Primero envías la solicitud y luego el admin la aprueba.',
          ),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.sell_outlined,
            text:
            'Referencia actual: 1 moneda = Bs ${bsPerCoin.toStringAsFixed(2)}.',
          ),
          const SizedBox(height: 10),
          _infoRow(
            icon: Icons.campaign_outlined,
            text:
            'Estas monedas te sirven para publicar productos y seguir operando como productor.',
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 2),
        Icon(icon, size: 18, color: _primaryDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: _textSoft,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, double bsPerCoin) {
    final canContinue = _selectedCoins != null;
    final total = _selectedCoins == null
        ? '0.00'
        : (_selectedCoins! * bsPerCoin).toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total a pagar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: _gold, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Bs $total',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                canContinue
                    ? '${_selectedCoins!} monedas seleccionadas'
                    : 'Selecciona un paquete para continuar',
                style: TextStyle(
                  fontSize: 12.8,
                  color: canContinue ? _green : _orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: canContinue
                    ? () async {
                  final sent = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProducerPaymentView(
                        coins: _selectedCoins!,
                        totalBs: _selectedCoins! * bsPerCoin,
                        bsPerCoin: bsPerCoin,
                      ),
                    ),
                  );

                  if (!context.mounted) return;

                  if (sent == true) {
                    if (!context.mounted) return;
                    Navigator.of(context).pop(true);
                  }
                }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primary.withOpacity(0.40),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text(
                  'Continuar al pago',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final _CoinPackage package;
  final double bsPerCoin;
  final bool selected;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.bsPerCoin,
    required this.selected,
    required this.onTap,
  });

  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8B6B4A);
  static const Color _text = Color(0xFF4E3426);
  static const Color _textSoft = Color(0xFF8C7B6B);
  static const Color _border = Color(0xFFF0E8DC);
  static const Color _gold = Color(0xFFE0B56E);
  static const Color _green = Color(0xFF3F7D58);

  @override
  Widget build(BuildContext context) {
    final total = (package.coins * bsPerCoin).toStringAsFixed(2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? _primary : _border,
              width: selected ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? _primary.withOpacity(0.10)
                    : Colors.black.withOpacity(0.04),
                blurRadius: selected ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: selected
                      ? _primary.withOpacity(0.15)
                      : _gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.monetization_on_outlined,
                  color: selected ? _primaryDark : _gold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${package.coins} monedas',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        if (package.tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF7EF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              package.tag!,
                              style: const TextStyle(
                                fontSize: 11.2,
                                color: _green,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      package.subtitle,
                      style: const TextStyle(
                        fontSize: 12.8,
                        color: _textSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: Bs $total',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? _primary : _textSoft.withOpacity(0.5),
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 15)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinPackage {
  final int coins;
  final String? tag;
  final String subtitle;

  const _CoinPackage({
    required this.coins,
    required this.tag,
    required this.subtitle,
  });
}