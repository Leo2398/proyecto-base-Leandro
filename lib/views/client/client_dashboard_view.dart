import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';
import '../../models/notification_model.dart';
import '../auth/login_view.dart';
import 'client_best_sellers_view.dart';
import 'client_cart_view.dart';
import 'client_orders_view.dart';
import 'client_producer_products_view.dart';
import 'client_reload_view.dart';
import 'client_settings_view.dart';

/// Dashboard principal del cliente
class ClientDashboardView extends StatefulWidget {
  const ClientDashboardView({super.key});

  @override
  State<ClientDashboardView> createState() => _ClientDashboardViewState();
}

class _ClientDashboardViewState extends State<ClientDashboardView> {
  DateTime? _lastSyncedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    await _refreshDashboard();
    await _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final userCtrl = context.read<UserController>();
    final notificationCtrl = context.read<NotificationController>();
    final currentUser = userCtrl.currentUser;

    if (currentUser?.id == null || currentUser!.id! <= 0) {
      return;
    }

    notificationCtrl.onNewNotification = (notification) {
      if (!mounted) return;
      _showNotificationSnack(notification);
    };

    await notificationCtrl.startPolling(
      userId: currentUser.id!,
      interval: const Duration(seconds: 8),
      loadImmediately: false,
    );
  }

  Future<void> _refreshDashboard() async {
    if (!mounted) return;

    final userCtrl = context.read<UserController>();
    final notificationCtrl = context.read<NotificationController>();

    await Future.wait([
      userCtrl.getAllProducers(),
      userCtrl.reloadCurrentUser(),
    ]);

    final currentUser = userCtrl.currentUser;
    if (currentUser?.id != null && currentUser!.id! > 0) {
      await notificationCtrl.refresh(userId: currentUser.id!);
    }

    if (!mounted) return;
    setState(() {
      _lastSyncedAt = DateTime.now();
    });
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientCartView()),
    );
  }

  void _openOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientOrdersView()),
    );
  }

  void _openReload() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientReloadView()),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientSettingsView()),
    );
  }

  void _openBestSellers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientBestSellersView()),
    );
  }

  void _showNotificationSnack(NotificationModel notification) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2F5D50),
          content: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _notificationIcon(notification.type),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.4,
                        height: 1.25,
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

  Future<void> _showNotificationsSheet() async {
    final userId = context.read<UserController>().currentUser?.id;
    if (userId == null || userId <= 0) return;

    final notificationCtrl = context.read<NotificationController>();
    if (notificationCtrl.currentUserId != userId && !notificationCtrl.isLoading) {
      await notificationCtrl.loadNotifications(userId);
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9F5EE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8CEC1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: Consumer<NotificationController>(
                      builder: (context, notificationCtrl, __) {
                        final unreadCount = notificationCtrl.unreadCount;
                        final hasNotifications =
                            notificationCtrl.notifications.isNotEmpty;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF4EA),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_active_outlined,
                                    color: Color(0xFF5A8A5A),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Notificaciones',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2D2D2D),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        unreadCount > 0
                                            ? 'Tienes $unreadCount pendiente(s) por revisar.'
                                            : 'Todo está al día por ahora.',
                                        style: const TextStyle(
                                          fontSize: 12.8,
                                          color: Color(0xFF7A736B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF5C544B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3E6),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.mark_email_unread_outlined,
                                            color: Color(0xFFD96C2F),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'No leídas',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF7A736B),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$unreadCount',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF2D2D2D),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (unreadCount > 0)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final ok = await notificationCtrl
                                            .markAllAsRead(userId);
                                        if (!mounted) return;
                                        if (ok) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Todas las notificaciones fueron marcadas como leídas.',
                                              ),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.done_all_rounded,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Marcar todas',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF5A8A5A),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: hasNotifications
                                          ? () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(22),
                                              ),
                                              title: const Text(
                                                'Eliminar notificaciones',
                                              ),
                                              content: const Text(
                                                'Se eliminarán todas tus notificaciones. Esta acción no se puede deshacer.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(
                                                    dialogContext,
                                                    false,
                                                  ),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(
                                                    dialogContext,
                                                    true,
                                                  ),
                                                  style:
                                                  ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                    const Color(0xFFD96C2F),
                                                    foregroundColor:
                                                    Colors.white,
                                                  ),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (confirm != true) return;
                                        final ok = await notificationCtrl
                                            .deleteAllNotificationsByUser(
                                          userId,
                                        );
                                        if (!mounted) return;
                                        if (ok) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Se eliminaron todas las notificaciones.',
                                              ),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                          : null,
                                      icon: const Icon(
                                        Icons.delete_sweep_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Limpiar lista',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFD96C2F),
                                        side: const BorderSide(
                                          color: Color(0xFFD96C2F),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Consumer<NotificationController>(
                      builder: (context, notificationCtrl, __) {
                        if (notificationCtrl.isLoading &&
                            notificationCtrl.notifications.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF5A8A5A),
                            ),
                          );
                        }

                        if (notificationCtrl.notifications.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF4EA),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_none_rounded,
                                        color: Color(0xFF5A8A5A),
                                        size: 34,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Aún no tienes notificaciones',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2D2D2D),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Aquí verás avisos sobre el estado de tus pedidos y otras novedades importantes.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13.2,
                                        color: Color(0xFF7A736B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (_, index) => _buildNotificationTile(
                            notificationCtrl.notifications[index],
                          ),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemCount: notificationCtrl.notifications.length,
                        );
                      },
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

  Future<void> _handleNotificationTap(
      NotificationModel item, {
        bool closeSheet = true,
      }) async {
    if (item.id != null && !item.isRead) {
      await context.read<NotificationController>().markAsRead(item.id!);
    }

    if (!mounted) return;
    if (closeSheet) {
      Navigator.pop(context);
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
    }

    if (!mounted) return;

    final normalizedType = item.type.trim().toLowerCase();
    if (normalizedType == 'recarga') {
      _openReload();
      return;
    }

    _openOrders();
  }

  IconData _notificationIcon(String type) {
    switch (type.trim().toLowerCase()) {
      case 'order':
        return Icons.local_shipping_outlined;
      case 'recarga':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _notificationAccentColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'order':
        return const Color(0xFF5A8A5A);
      case 'recarga':
        return const Color(0xFFD96C2F);
      default:
        return const Color(0xFF8A7F74);
    }
  }

  Color _notificationSoftColor(String type) {
    switch (type.trim().toLowerCase()) {
      case 'order':
        return const Color(0xFFEAF4EA);
      case 'recarga':
        return const Color(0xFFFFF3E6);
      default:
        return const Color(0xFFF0ECE6);
    }
  }

  String _notificationTypeLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'order':
        return 'Pedido';
      case 'recarga':
        return 'Recarga';
      default:
        return 'Aviso';
    }
  }

  String _formatNotificationTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Hace un momento';
    }
    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    }
    if (difference.inDays == 1) {
      return 'Ayer';
    }
    if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showDifferentProducerWarning(String currentProducer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8CE),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0EC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: Color(0xFFD96C2F),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Solo una empresa por pedido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu carrito ya tiene productos de "$currentProducer". '
                  'Vacía el carrito para agregar productos de otra empresa.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5A8A5A),
                      side: const BorderSide(color: Color(0xFF5A8A5A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<CartController>().clearCart();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD96C2F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Vaciar carrito',
                      style: TextStyle(fontWeight: FontWeight.w600),
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

  Future<void> _handleProducerTap(dynamic producer) async {
    final cart = context.read<CartController>();
    final currentProducerName = cart.currentProducerName;
    final currentProducerId = cart.currentProducerID;
    final nextProducerId = producer.id as int?;

    if (cart.itemCount > 0 &&
        currentProducerId != null &&
        nextProducerId != null &&
        currentProducerId != nextProducerId &&
        currentProducerName != null &&
        currentProducerName.trim().isNotEmpty) {
      _showDifferentProducerWarning(currentProducerName);
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProducerProductsView(producer: producer),
      ),
    );
  }

  Future<void> _logout() async {
    final controller = context.read<UserController>();
    await controller.logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
    );
  }

  @override
  void dispose() {
    final notificationCtrl = context.read<NotificationController>();
    notificationCtrl.onNewNotification = null;
    notificationCtrl.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF5A8A5A),
          onRefresh: _refreshDashboard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFFF5F0E8),
                surfaceTintColor: Colors.transparent,
                floating: true,
                pinned: false,
                elevation: 0,
                automaticallyImplyLeading: false,
                toolbarHeight: 82,
                titleSpacing: 16,
                title: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5A8A5A), Color(0xFF79A96B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5A8A5A).withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.eco_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AgroMarket',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pedidos frescos y productores orgánicos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.8,
                              color: Color(0xFF7A736B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  Consumer<UserController>(
                    builder: (context, controller, _) {
                      final balance =
                          controller.currentUser?.balance.toStringAsFixed(0) ??
                              '0';
                      return GestureDetector(
                        onTap: _openReload,
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.monetization_on_outlined,
                                color: Color(0xFFB8860B),
                                size: 17,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                balance,
                                style: const TextStyle(
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2D2D2D),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                color: Color(0xFF5A8A5A),
                                size: 15,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<NotificationController>(
                    builder: (_, notificationCtrl, __) =>
                        _buildNotificationButton(notificationCtrl.unreadCount),
                  ),
                  Consumer<CartController>(
                    builder: (_, cart, __) => Stack(
                      children: [
                        IconButton(
                          onPressed: _openCart,
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        if (cart.itemCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFF5A8A5A),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${cart.itemCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _openSettings,
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Consumer2<UserController, CartController>(
                      builder: (context, userCtrl, cartCtrl, _) {
                        final user = userCtrl.currentUser;
                        final userName = (user?.name ?? '').trim().isEmpty
                            ? 'Cliente'
                            : user!.name.trim();
                        final balance = user?.balance ?? 0.0;
                        final hasCart = cartCtrl.itemCount > 0;

                        return _DashboardHeroCard(
                          userName: userName,
                          userImage: user?.image,
                          balance: balance,
                          cartItems: cartCtrl.itemCount,
                          onOrdersTap: _openOrders,
                          onReloadTap: _openReload,
                          onCartTap: _openCart,
                          cartHighlightText: hasCart
                              ? 'Tienes ${cartCtrl.itemCount} producto(s) esperando en tu carrito.'
                              : 'Explora productores y arma tu próximo pedido.',
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.receipt_long_rounded,
                            title: 'Mis pedidos',
                            subtitle: 'Revisa estados y compras',
                            onTap: _openOrders,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Recargar',
                            subtitle: 'Añade monedas a tu saldo',
                            onTap: _openReload,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Consumer<NotificationController>(
                      builder: (context, notificationCtrl, _) {
                        final recentNotifications =
                        notificationCtrl.notifications.take(3).toList();

                        return _buildNotificationsPreviewSection(
                          unreadCount: notificationCtrl.unreadCount,
                          recentNotifications: recentNotifications,
                          isLoading: notificationCtrl.isLoading &&
                              recentNotifications.isEmpty,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Productos más vendidos',
                      subtitle: 'Descubre opciones populares y rápidas de pedir',
                      actionLabel: 'Ver más',
                      onActionTap: _openBestSellers,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 228,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          GestureDetector(
                            onTap: _openBestSellers,
                            child: const _FeaturedProductCard(
                              name: 'Tomate Cherry\nOrgánico',
                              producer: 'FreshFarm Co.',
                              rating: 4.8,
                              price: '2/kg',
                              emoji: '🍅',
                              accentColor: Color(0xFFE8F4E8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _openBestSellers,
                            child: const _FeaturedProductCard(
                              name: 'Lechuga\nHidropónica',
                              producer: 'Verde Vital',
                              rating: 4.6,
                              price: '4/100g',
                              emoji: '🥬',
                              accentColor: Color(0xFFEAF8EA),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _openBestSellers,
                            child: const _FeaturedProductCard(
                              name: 'Mango\nAtaulfo',
                              producer: 'AgroSur',
                              rating: 4.9,
                              price: '3/kg',
                              emoji: '🥭',
                              accentColor: Color(0xFFFFF4E3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    _SectionHeader(
                      title: 'Empresas agrícolas',
                      subtitle:
                      'Explora productores y entra directo a sus productos',
                      actionLabel: 'Actualizar',
                      onActionTap: _refreshDashboard,
                    ),
                    const SizedBox(height: 12),
                    Consumer<UserController>(
                      builder: (context, controller, child) {
                        if (controller.isLoading &&
                            controller.producers.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: CircularProgressIndicator(
                                color: Color(0xFF5A8A5A),
                              ),
                            ),
                          );
                        }

                        if (controller.producers.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF4EA),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.storefront_outlined,
                                    size: 30,
                                    color: Color(0xFF5A8A5A),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'No hay productores disponibles',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Cuando existan productores registrados, aparecerán aquí para que puedas explorar sus productos.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF7A736B),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: controller.producers.map((producer) {
                            final description =
                            producer.description?.trim().isNotEmpty == true
                                ? producer.description!.trim()
                                : 'Productor agrícola disponible en AgroMarket.';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ProducerShowcaseCard(
                                name: producer.name,
                                description: description,
                                image: producer.image,
                                onViewProducts: () =>
                                    _handleProducerTap(producer),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF5A8A5A),
        unselectedItemColor: const Color(0xFF888888),
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_outlined),
            activeIcon: Icon(Icons.trending_up),
            label: 'Más vendidos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 2:
              _openBestSellers();
              break;
            case 3:
              _openOrders();
              break;
            case 4:
              _openSettings();
              break;
            default:
              break;
          }
        },
      ),
    );
  }


  Widget _buildNotificationButton(int unreadCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            onPressed: _showNotificationsSheet,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD96C2F),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFF5F0E8), width: 2),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationsPreviewSection({
    required int unreadCount,
    required List<NotificationModel> recentNotifications,
    required bool isLoading,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFF5A8A5A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notificaciones recientes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unreadCount > 0
                          ? 'Tienes $unreadCount notificación(es) sin leer.'
                          : 'Revisa aquí los últimos movimientos importantes.',
                      style: const TextStyle(
                        fontSize: 12.6,
                        color: Color(0xFF7A736B),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showNotificationsSheet,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text(
                  'Ver todo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5A8A5A),
                ),
              ),
            ],
          ),
          if (_lastSyncedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Última actualización: ${_lastSyncedAt!.day.toString().padLeft(2, '0')}/${_lastSyncedAt!.month.toString().padLeft(2, '0')} ${_lastSyncedAt!.hour.toString().padLeft(2, '0')}:${_lastSyncedAt!.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 11.8,
                color: Color(0xFF9A9288),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF5A8A5A)),
              ),
            )
          else if (recentNotifications.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: Color(0xFF5A8A5A),
                    size: 28,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Sin notificaciones por ahora',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.2,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Cuando cambie el estado de un pedido, aparecerá aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.6,
                      color: Color(0xFF7A736B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: recentNotifications.map(_buildNotificationPreviewCard).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationPreviewCard(NotificationModel item) {
    final accent = _notificationAccentColor(item.type);
    final softColor = _notificationSoftColor(item.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(item, closeSheet: false),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: item.isRead ? Colors.transparent : accent.withOpacity(0.20),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _notificationIcon(item.type),
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.2,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                          ),
                          if (!item.isRead)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD96C2F),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.8,
                          color: Color(0xFF6E665E),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _notificationTypeLabel(item.type),
                              style: TextStyle(
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatNotificationTime(item.createdAt),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF8A827A),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel item) {
    final accent = _notificationAccentColor(item.type);
    final softColor = _notificationSoftColor(item.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNotificationTap(item),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: item.isRead ? const Color(0xFFF0E8DC) : accent.withOpacity(0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _notificationIcon(item.type),
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 15.4,
                              fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w800,
                              color: const Color(0xFF2D2D2D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!item.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD96C2F),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.message,
                      style: const TextStyle(
                        fontSize: 13.2,
                        color: Color(0xFF6E665E),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: softColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _notificationTypeLabel(item.type),
                            style: TextStyle(
                              fontSize: 11.6,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          _formatNotificationTime(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11.8,
                            color: Color(0xFF8A827A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (!item.isRead && item.id != null)
                    IconButton(
                      tooltip: 'Marcar como leída',
                      onPressed: () async {
                        await context.read<NotificationController>().markAsRead(
                          item.id!,
                        );
                      },
                      icon: const Icon(
                        Icons.mark_email_read_outlined,
                        color: Color(0xFF5A8A5A),
                      ),
                    ),
                  if (item.id != null)
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () async {
                        await context.read<NotificationController>()
                            .deleteNotification(item.id!);
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFD96C2F),
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
}

class _DashboardHeroCard extends StatelessWidget {
  final String userName;
  final String? userImage;
  final double balance;
  final int cartItems;
  final String cartHighlightText;
  final VoidCallback onOrdersTap;
  final VoidCallback onReloadTap;
  final VoidCallback onCartTap;

  const _DashboardHeroCard({
    required this.userName,
    this.userImage,
    required this.balance,
    required this.cartItems,
    required this.cartHighlightText,
    required this.onOrdersTap,
    required this.onReloadTap,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF5A8A5A), Color(0xFF79A96B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A8A5A).withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppImage(
                src: userImage,
                width: 58,
                height: 58,
                borderRadius: 18,
                placeholder: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $userName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pide productos frescos, revisa tus compras y gestiona tu saldo desde un solo lugar.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMiniStat(
                  icon: Icons.monetization_on_outlined,
                  title: 'Saldo',
                  value: '${balance.toStringAsFixed(0)} monedas',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMiniStat(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Carrito',
                  value: '$cartItems producto(s)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cartHighlightText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOrdersTap,
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text(
                    'Mis pedidos',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4B744B),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReloadTap,
                  icon: const Icon(Icons.add_card_rounded, size: 18),
                  label: const Text(
                    'Recargar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.75)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onCartTap,
              icon: const Icon(
                Icons.shopping_cart_checkout_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Ir al carrito',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMiniStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _HeroMiniStat({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF5A8A5A), size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.8,
                  color: Color(0xFF7A736B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onActionTap;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.8,
                  color: Color(0xFF7A736B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF5A8A5A),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _FeaturedProductCard extends StatelessWidget {
  final String name;
  final String producer;
  final double rating;
  final String price;
  final String emoji;
  final Color accentColor;

  const _FeaturedProductCard({
    required this.name,
    required this.producer,
    required this.rating,
    required this.price,
    required this.emoji,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFB8860B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$rating',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 46),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2D2D),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  producer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.2,
                    color: Color(0xFF7A736B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_outlined,
                      size: 16,
                      color: Color(0xFFB8860B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF5A8A5A),
                        size: 18,
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
}

class _ProducerShowcaseCard extends StatelessWidget {
  final String name;
  final String description;
  final String? image;
  final VoidCallback onViewProducts;

  const _ProducerShowcaseCard({
    required this.name,
    required this.description,
    required this.image,
    required this.onViewProducts,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onViewProducts,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppImage(
                    src: image,
                    width: 66,
                    height: 66,
                    borderRadius: 20,
                    placeholder: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4EA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Color(0xFF5A8A5A),
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF4EA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Productor disponible',
                            style: TextStyle(
                              fontSize: 11.8,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4B744B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13.3,
                  color: Color(0xFF7A736B),
                  height: 1.45,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5EF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.eco_outlined,
                          size: 15,
                          color: Color(0xFF5A8A5A),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Ver catálogo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5C544B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: onViewProducts,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: const Text(
                      'Ver productos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A8A5A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
}