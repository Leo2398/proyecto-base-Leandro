import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/request_controller.dart';
import '../../controllers/user_controller.dart';
import 'client_payment_view.dart';

/// Pantalla donde el cliente elige cuántas monedas quiere comprar
class ClientReloadView extends StatefulWidget {
  const ClientReloadView({super.key});

  @override
  State<ClientReloadView> createState() => _ClientReloadViewState();
}

class _ClientReloadViewState extends State<ClientReloadView> {
  int? _selectedCoins;

  // Paquetes disponibles — el precio se calcula con bsPerCoin de la BD
  static const List<_CoinPackage> _packages = [
    _CoinPackage(coins: 10, tag: null),
    _CoinPackage(coins: 100, tag: null),
    _CoinPackage(coins: 500, tag: 'Más popular'),
    _CoinPackage(coins: 1000, tag: 'Mejor opción'),
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
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Consumer2<RequestController, UserController>(
          builder: (context, reqCtrl, userCtrl, _) {
            final config = reqCtrl.config;
            final balance =
                userCtrl.currentUser?.balance.toStringAsFixed(0) ?? '0';

            return Column(
              children: [
                _buildTopBar(context, balance),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        const Text(
                          'Paquetes disponibles',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._packages.map(
                          (p) => _PackageCard(
                            package: p,
                            bsPerCoin: config.bsPerCoin,
                            selected: _selectedCoins == p.coins,
                            onTap: () =>
                                setState(() => _selectedCoins = p.coins),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildNote(),
                      ],
                    ),
                  ),
                ),
                _buildFooter(context, config.bsPerCoin),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, String balance) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF2D2D2D), size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
              elevation: 2,
              shadowColor: Colors.black12,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 5)
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on_outlined,
                    color: Color(0xFFB8860B), size: 18),
                const SizedBox(width: 5),
                Text(
                  '$balance monedas',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recargar monedas',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2D2D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Compra monedas para realizar pedidos',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ── Nota ───────────────────────────────────────────────────────────────────

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4EA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB8D8B8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF5A8A5A), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las monedas no expiran y puedes usarlas en cualquier momento para realizar tus pedidos.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context, double bsPerCoin) {
    final canContinue = _selectedCoins != null;
    final total = _selectedCoins != null
        ? (_selectedCoins! * bsPerCoin).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canContinue
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientPaymentView(
                        coins: _selectedCoins!,
                        totalBs: double.parse(total),
                        bsPerCoin: bsPerCoin,
                      ),
                    ),
                  )
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5A8A5A),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFCCCCCC),
            disabledForegroundColor: const Color(0xFF999999),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            canContinue
                ? 'Continuar al pago  •  $total Bs'
                : 'Selecciona un paquete',
            style: const TextStyle(
                fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ── Package data class ─────────────────────────────────────────────────────────

class _CoinPackage {
  final int coins;
  final String? tag;
  const _CoinPackage({required this.coins, this.tag});
}

// ── Package Card ───────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    final total = (package.coins * bsPerCoin).toStringAsFixed(0);
    final perUnit = bsPerCoin % 1 == 0
        ? bsPerCoin.toStringAsFixed(0)
        : bsPerCoin.toStringAsFixed(2);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF5A8A5A).withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF5A8A5A)
                : const Color(0xFFE8E0D4),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF5A8A5A).withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                  )
                ],
        ),
        child: Row(
          children: [
            // Icono moneda
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF5A8A5A).withOpacity(0.12)
                    : const Color(0xFFF5F0E8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.monetization_on_outlined,
                color: Color(0xFFB8860B),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Monedas
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${package.coins}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  Text(
                    'monedas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            // Tag + precio
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (package.tag != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: package.tag == 'Más popular'
                          ? const Color(0xFF5A8A5A)
                          : const Color(0xFFB8860B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      package.tag!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  '$total Bs',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5A8A5A),
                  ),
                ),
                Text(
                  '$perUnit Bs/moneda',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),

            // Check
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF5A8A5A)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF5A8A5A)
                      : const Color(0xFFCCC4B8),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}