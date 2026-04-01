import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/cart_item_model.dart';
import '../../core/image_helper.dart';
class ClientCartView extends StatelessWidget {
  const ClientCartView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Consumer2<CartController, UserController>(
          builder: (context, cart, userCtrl, _) {
            final balance = userCtrl.currentUser?.balance ?? 0.0;
            final canAfford = balance >= cart.total;
            final hasItems = cart.items.isNotEmpty;

            return Column(
              children: [
                // ── Top Bar ──────────────────────────────────────────────
                _buildTopBar(context, cart),

                // ── Contenido ────────────────────────────────────────────
                Expanded(
                  child: hasItems
                      ? _buildCartList(context, cart)
                      : _buildEmptyState(context),
                ),

                // ── Footer con total y botón ──────────────────────────
                if (hasItems)
                  _buildFooter(context, cart, balance, canAfford),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, CartController cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F0E8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF2D2D2D),
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
              elevation: 2,
              shadowColor: Colors.black12,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu carrito',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),
          // Empresa activa
          if (cart.currentProducerName != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE0D8CE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 14,
                    color: Color(0xFF5A8A5A),
                  ),
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      cart.currentProducerName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
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

  // ── Lista de productos ─────────────────────────────────────────────────────

  Widget _buildCartList(BuildContext context, CartController cart) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return _CartItemCard(item: item);
      },
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(
    BuildContext context,
    CartController cart,
    double balance,
    bool canAfford,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Total del pedido
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total del pedido',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on_outlined,
                    size: 20,
                    color: Color(0xFFB8860B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cart.total.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Saldo disponible
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Saldo disponible: ${balance.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 12.5,
                color: canAfford
                    ? const Color(0xFF888888)
                    : const Color(0xFFD96C2F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Aviso de saldo suficiente / insuficiente
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: canAfford
                  ? const Color(0xFFEAF4EA)
                  : const Color(0xFFFFF0EC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: canAfford
                    ? const Color(0xFFB8D8B8)
                    : const Color(0xFFFFCBBC),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  canAfford
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: canAfford
                      ? const Color(0xFF5A8A5A)
                      : const Color(0xFFD96C2F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    canAfford
                        ? 'Tienes saldo suficiente para completar este pedido'
                        : 'Saldo insuficiente — te faltan ${(cart.total - balance).toStringAsFixed(0)} monedas',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: canAfford
                          ? const Color(0xFF5A8A5A)
                          : const Color(0xFFD96C2F),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Botón confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canAfford
                  ? () => _confirmOrder(context, cart)
                  : null,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text(
                'Confirmar pedido',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A8A5A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCCCCCC),
                disabledForegroundColor: const Color(0xFF999999),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmOrder(BuildContext context, CartController cart) {
    // TODO: implementar flujo de pedido real
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar pedido'),
        content: Text(
          '¿Confirmas tu pedido de ${cart.itemCount} producto(s) por ${cart.total.toStringAsFixed(0)} monedas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context); // cierra dialog
              Navigator.pop(context); // vuelve al dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Pedido confirmado!'),
                  backgroundColor: Color(0xFF5A8A5A),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A8A5A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4EA),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 44,
                color: Color(0xFF5A8A5A),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tu carrito está vacío',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explora los productores y agrega productos a tu carrito.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A8A5A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Ver productores',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CartItemCard ───────────────────────────────────────────────────────────────

class _CartItemCard extends StatelessWidget {
  final CartItem item;

  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Imagen
            AppImage(
  src: item.picture,
  width: 72,
  height: 72,
  borderRadius: 16,
  placeholder: const Icon(
    Icons.eco_outlined,
    color: Color(0xFF5A8A5A),
    size: 30,
  ),
),

            const SizedBox(width: 12),

            // Nombre + precio unitario
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_outlined,
                        size: 13,
                        color: Color(0xFFB8860B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${item.precio.toStringAsFixed(item.precio % 1 == 0 ? 0 : 1)} / ${item.unidad}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF888888),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Controles de cantidad + subtotal
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Subtotal
                Row(
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_outlined,
                      size: 14,
                      color: Color(0xFFB8860B),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      item.subtotal
                          .toStringAsFixed(item.subtotal % 1 == 0 ? 0 : 1),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Controles - cantidad +
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón -
                      GestureDetector(
                        onTap: () => cart.decrement(item.productId),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.remove_rounded,
                            size: 16,
                            color: Color(0xFF5A8A5A),
                          ),
                        ),
                      ),

                      // Cantidad
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ),

                      // Botón +
                      GestureDetector(
                        onTap: () => cart.increment(item.productId),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A8A5A),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5A8A5A)
                                    .withOpacity(0.25),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 16,
                            color: Colors.white,
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
      ),
    );
  }
}