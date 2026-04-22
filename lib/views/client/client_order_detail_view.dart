import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/order_controller.dart';
import '../../controllers/review_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';
import '../../models/delivery_mode_model.dart';
import '../../models/order_detail_model.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/review_model.dart';
import '../../models/user_model.dart';
import '../../services/delivery_mode_service.dart';
import '../../services/product_service.dart';
import '../../services/user_service.dart';

class ClientOrderDetailView extends StatefulWidget {
  final OrderModel order;
  final UserModel? producer;

  const ClientOrderDetailView({
    super.key,
    required this.order,
    this.producer,
  });

  @override
  State<ClientOrderDetailView> createState() => _ClientOrderDetailViewState();
}

class _ClientOrderDetailViewState extends State<ClientOrderDetailView> {
  final ProductService _productService = ProductService();
  final UserService _userService = UserService();
  final DeliveryModeService _deliveryModeService = DeliveryModeService();

  bool _isBootstrapping = true;
  bool _isCheckingReview = false;
  bool _isSubmittingReview = false;
  bool _hasReview = false;
  bool _reviewCheckDone = false;
  String? _localError;

  UserModel? _producer;
  ReviewModel? _existingReview;
  Map<int, ProductModel> _productsById = {};
  Map<int, DeliveryModeModel> _deliveryModesById = {};

  @override
  void initState() {
    super.initState();
    _producer = widget.producer;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isBootstrapping = true;
      _localError = null;
    });

    final orderCtrl = context.read<OrderController>();
    final userCtrl = context.read<UserController>();
    final currentUser = userCtrl.currentUser;

    try {
      final futures = <Future<void>>[];

      if (currentUser?.id != null && currentUser!.id! > 0) {
        futures.add(orderCtrl.loadOrdersByClient(currentUser.id!));
      }

      if ((widget.order.id ?? 0) > 0) {
        futures.add(orderCtrl.loadOrderDetails(widget.order.id!));
      }

      futures.add(_loadProducerAndProducts());
      futures.add(_loadDeliveryModes());

      await Future.wait(futures);

      final refreshedOrder = _resolveCurrentOrder(orderCtrl);
      await _loadReviewStatus(refreshedOrder);
    } catch (e) {
      _localError = 'Ocurrió un error al cargar el pedido: $e';
    } finally {
      if (!mounted) return;
      setState(() {
        _isBootstrapping = false;
      });
    }
  }

  Future<void> _loadProducerAndProducts() async {
    try {
      final producerId = widget.order.producerID;
      if (producerId <= 0) return;

      UserModel? producer = _producer;
      producer ??= await _userService.getUserById(producerId);

      final products = await _productService.getProductsByProducer(producerId);
      final mappedProducts = <int, ProductModel>{};
      for (final product in products) {
        if (product.id != null) {
          mappedProducts[product.id!] = product;
        }
      }

      if (!mounted) return;
      setState(() {
        _producer = producer;
        _productsById = mappedProducts;
      });
    } catch (e) {
      _localError = 'No se pudo cargar la información del productor: $e';
    }
  }

  Future<void> _loadDeliveryModes() async {
    try {
      final modes = await _deliveryModeService.getAll();
      final mappedModes = <int, DeliveryModeModel>{};
      for (final mode in modes) {
        if (mode.id != null) {
          mappedModes[mode.id!] = mode;
        }
      }

      if (!mounted) return;
      setState(() {
        _deliveryModesById = mappedModes;
      });
    } catch (e) {
      _localError = 'No se pudo cargar la modalidad de entrega: $e';
    }
  }

  Future<void> _loadReviewStatus(OrderModel order) async {
    final orderId = order.id ?? 0;
    if (orderId <= 0) {
      if (!mounted) return;
      setState(() {
        _isCheckingReview = false;
        _hasReview = false;
        _existingReview = null;
        _reviewCheckDone = true;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isCheckingReview = true;
    });

    try {
      final reviewCtrl = context.read<ReviewController>();
      final review = await reviewCtrl.loadReviewByOrderId(orderId);

      if (!mounted) return;
      setState(() {
        _existingReview = review;
        _hasReview = review != null;
        _reviewCheckDone = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _existingReview = null;
        _hasReview = false;
        _reviewCheckDone = true;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isCheckingReview = false;
      });
    }
  }

  OrderModel _resolveCurrentOrder(OrderController orderCtrl) {
    final currentId = widget.order.id;
    if (currentId == null) return widget.order;

    try {
      return orderCtrl.clientOrders.firstWhere((order) => order.id == currentId);
    } catch (_) {
      return widget.order;
    }
  }

  bool _canReviewOrder(OrderModel order, UserModel? currentUser) {
    if (currentUser?.id == null || currentUser!.id! <= 0) return false;
    if ((order.id ?? 0) <= 0) return false;
    if (order.clientID != currentUser.id) return false;
    if (order.state != OrderController.stateCompleted) return false;
    if (_hasReview) return false;
    if (_isSubmittingReview) return false;
    return true;
  }

  Future<void> _showReviewDialog(OrderModel order, UserModel currentUser) async {
    if ((order.id ?? 0) <= 0 || currentUser.id == null || currentUser.id! <= 0) {
      return;
    }

    final draft = await showDialog<_ReviewDraft>(
      context: context,
      builder: (dialogContext) => const _ReviewDialog(),
    );

    if (!mounted || draft == null) return;

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      final reviewCtrl = context.read<ReviewController>();

      final review = await reviewCtrl.createReview(
        orderId: order.id!,
        userId: currentUser.id!,
        value: draft.stars,
        comment: draft.comment,
      );

      if (!mounted) return;

      if (review != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calificación enviada correctamente.'),
            backgroundColor: Color(0xFF3D7A3D),
          ),
        );

        await _loadReviewStatus(order);

        if (!mounted) return;
        setState(() {});
      } else {
        final message = reviewCtrl.errorMessage?.trim().isNotEmpty == true
            ? reviewCtrl.errorMessage!
            : 'No se pudo guardar la calificación.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFC24D4D),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocurrió un error al guardar la calificación: $e'),
          backgroundColor: const Color(0xFFC24D4D),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmittingReview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Consumer3<OrderController, UserController, ReviewController>(
          builder: (context, orderCtrl, userCtrl, reviewCtrl, _) {
            final order = _resolveCurrentOrder(orderCtrl);
            final details = orderCtrl.orderDetails;
            final status = _statusFor(order.state);
            final totalItems = _countTotalItems(details);
            final computedSubtotal = _computeSubtotal(details);
            final deliveryModeLabel = _deliveryModeLabel(_producer);
            final deliveryIcon = _deliveryModeIcon(deliveryModeLabel);
            final currentUser = userCtrl.currentUser;
            final canReview = _canReviewOrder(order, currentUser);

            return RefreshIndicator(
              color: const Color(0xFF5A8A5A),
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildTopBar(),
                        _buildHeroCard(order, status),
                        if (_localError != null && _localError!.trim().isNotEmpty)
                          _buildErrorBanner(_localError!),
                        if (orderCtrl.errorMessage != null &&
                            orderCtrl.errorMessage!.trim().isNotEmpty)
                          _buildErrorBanner(orderCtrl.errorMessage!),
                        if (reviewCtrl.errorMessage != null &&
                            reviewCtrl.errorMessage!.trim().isNotEmpty &&
                            !_isBootstrapping)
                          _buildErrorBanner(reviewCtrl.errorMessage!),
                      ],
                    ),
                  ),
                  if (_isBootstrapping)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _DetailLoadingState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _SectionCard(
                            title: 'Seguimiento del pedido',
                            subtitle:
                            'Consulta el avance general de tu compra en la plataforma.',
                            icon: Icons.route_rounded,
                            child: Column(
                              children: [
                                _OrderProgressStepper(state: order.state),
                                const SizedBox(height: 18),
                                _StatusMessage(status: status),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniStatCard(
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'Productos',
                                  value: '$totalItems',
                                  subtitle: totalItems == 1
                                      ? 'item en el pedido'
                                      : 'items en el pedido',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MiniStatCard(
                                  icon: Icons.monetization_on_outlined,
                                  title: 'Total pagado',
                                  value: '${_formatMoney(order.amount)} monedas',
                                  subtitle: 'monto del pedido',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Empresa / productor',
                            subtitle:
                            'Información general del negocio que preparó tu pedido.',
                            icon: Icons.storefront_outlined,
                            child: _ProducerCard(producer: _producer),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Entrega y dirección',
                            subtitle:
                            'Se muestra la información actualmente disponible del pedido.',
                            icon: Icons.local_shipping_outlined,
                            child: Column(
                              children: [
                                _InfoRowCard(
                                  icon: deliveryIcon,
                                  label: 'Modalidad',
                                  value: deliveryModeLabel,
                                  hint:
                                  'Basado en la configuración registrada del productor.',
                                ),
                                const SizedBox(height: 10),
                                _InfoRowCard(
                                  icon: Icons.location_on_outlined,
                                  label: 'Dirección registrada',
                                  value: _safeAddress(order.pickupLocationAddress),
                                  hint:
                                  'Esta dirección se toma del pedido registrado actualmente.',
                                ),
                                const SizedBox(height: 10),
                                _InfoRowCard(
                                  icon: Icons.schedule_outlined,
                                  label: 'Fecha y hora',
                                  value:
                                  '${_formatOrderDate(order.registerDate)} • ${_formatOrderTime(order.registerDate)}',
                                  hint:
                                  'Momento en que la orden fue generada por el cliente.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Notas del pedido',
                            subtitle:
                            'Observaciones, indicaciones o referencias adicionales.',
                            icon: Icons.notes_rounded,
                            child: _NotesCard(notes: order.notes),
                          ),
                          const SizedBox(height: 14),
                          if (order.state == OrderController.stateCompleted)
                            Column(
                              children: [
                                _SectionCard(
                                  title: 'Tu calificación',
                                  subtitle: _hasReview
                                      ? 'Esta es la calificación que registraste para este pedido.'
                                      : 'Cuando completes tu experiencia, puedes compartir tu opinión aquí.',
                                  icon: Icons.star_rounded,
                                  child: _ReviewSection(
                                    isCheckingReview: _isCheckingReview,
                                    reviewCheckDone: _reviewCheckDone,
                                    hasReview: _hasReview,
                                    existingReview: _existingReview,
                                    canReview: canReview,
                                    isSubmitting: _isSubmittingReview,
                                    onTapReview: canReview && currentUser != null
                                        ? () => _showReviewDialog(order, currentUser)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                            ),
                          _SectionCard(
                            title: 'Detalle de productos',
                            subtitle:
                            'Listado de productos incluidos con cantidad, precio y subtotal.',
                            icon: Icons.inventory_2_outlined,
                            child: _buildDetailsSection(
                              details: details,
                              isLoading: orderCtrl.isLoadingDetails,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Resumen de pago',
                            subtitle:
                            'Totales calculados en base a los productos del pedido.',
                            icon: Icons.receipt_long_rounded,
                            child: Column(
                              children: [
                                _SummaryRow(
                                  label: 'Subtotal calculado',
                                  value: '${_formatMoney(computedSubtotal)} monedas',
                                ),
                                const SizedBox(height: 10),
                                _SummaryRow(
                                  label: 'Monto guardado en la orden',
                                  value: '${_formatMoney(order.amount)} monedas',
                                  highlight: true,
                                ),
                                const SizedBox(height: 10),
                                _SummaryRow(
                                  label: 'Cantidad total de items',
                                  value: '$totalItems',
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF4EA),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFCBE1CB),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        color: Color(0xFF3D7A3D),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          computedSubtotal > 0 &&
                                              (computedSubtotal - order.amount).abs() > 0.01
                                              ? 'El total calculado puede diferir del monto guardado si el pedido fue registrado con datos anteriores o ajustes pendientes.'
                                              : 'El resumen coincide correctamente con la información principal disponible del pedido.',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF3D7A3D),
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _BottomActionCard(
                            onRefresh: _loadData,
                            orderId: order.id,
                            stateLabel: status.label,
                            canReview: canReview,
                            isCheckingReview: _isCheckingReview,
                            isSubmittingReview: _isSubmittingReview,
                            onReview: canReview && currentUser != null
                                ? () => _showReviewDialog(order, currentUser)
                                : null,
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  'Detalle del pedido',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Revisa productos, estado, dirección y resumen del pedido',
                  style: TextStyle(
                    fontSize: 12.8,
                    color: Color(0xFF7A736B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7DED2)),
            ),
            child: IconButton(
              onPressed: _loadData,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF5A8A5A),
              ),
              tooltip: 'Actualizar detalle',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(OrderModel order, _OrderStatusUi status) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5A8A5A),
            Color(0xFF7AA37A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A8A5A).withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${order.id ?? 0}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatOrderDate(order.registerDate)} • ${_formatOrderTime(order.registerDate)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              _HeroStatusPill(status: status),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroInfoTile(
                  icon: Icons.storefront_outlined,
                  title: 'Productor',
                  value: _producer?.name?.trim().isNotEmpty == true
                      ? _producer!.name.trim()
                      : 'Empresa #${order.producerID}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroInfoTile(
                  icon: Icons.monetization_on_outlined,
                  title: 'Total',
                  value: '${_formatMoney(order.amount)} monedas',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD0C1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD96C2F),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8B4A2C),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection({
    required List<OrderDetailModel> details,
    required bool isLoading,
  }) {
    if (isLoading) {
      return Column(
        children: List.generate(
          3,
              (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
            child: const _ProductItemSkeleton(),
          ),
        ),
      );
    }

    if (details.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5EF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: Color(0xFF7A736B),
            ),
            SizedBox(height: 10),
            Text(
              'Aún no se encontró el detalle de productos para este pedido.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.2,
                color: Color(0xFF5C544B),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(details.length, (index) {
        final detail = details[index];
        final product = _productsById[detail.productID];
        return Padding(
          padding: EdgeInsets.only(bottom: index == details.length - 1 ? 0 : 10),
          child: _ProductDetailCard(
            detail: detail,
            product: product,
          ),
        );
      }),
    );
  }

  int _countTotalItems(List<OrderDetailModel> details) {
    if (details.isEmpty) return 0;
    return details.fold<int>(0, (sum, detail) => sum + detail.quantity);
  }

  double _computeSubtotal(List<OrderDetailModel> details) {
    if (details.isEmpty) return 0.0;
    return details.fold<double>(
      0.0,
          (sum, detail) => sum + (detail.unitPrice * detail.quantity),
    );
  }

  String _deliveryModeLabel(UserModel? producer) {
    if (producer?.deliveryModeID == null || producer!.deliveryModeID! <= 0) {
      return 'Modalidad no disponible';
    }

    final mode = _deliveryModesById[producer.deliveryModeID!];
    final name = mode?.name.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'Modalidad #${producer.deliveryModeID}';
  }

  IconData _deliveryModeIcon(String label) {
    final text = label.toLowerCase();
    if (text.contains('domic')) return Icons.delivery_dining_rounded;
    if (text.contains('reti') || text.contains('recoj')) {
      return Icons.store_mall_directory_outlined;
    }
    if (text.contains('amb') || text.contains('mixt')) {
      return Icons.compare_arrows_rounded;
    }
    return Icons.local_shipping_outlined;
  }
}

class _ReviewDraft {
  final int stars;
  final String? comment;

  const _ReviewDraft({
    required this.stars,
    this.comment,
  });
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int selectedStars = 5;
  final TextEditingController commentController = TextEditingController();

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _ReviewDraft(
        stars: selectedStars,
        comment: commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFDFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: const Text(
        'Calificar pedido',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF2D2D2D),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Cómo fue tu experiencia?',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                spacing: 6,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  final isActive = star <= selectedStars;

                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      setState(() {
                        selectedStars = star;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isActive ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 38,
                        color: isActive
                            ? const Color(0xFFE2A73B)
                            : const Color(0xFFB9B2A8),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                _reviewLabelForValue(selectedStars),
                style: const TextStyle(
                  fontSize: 12.8,
                  color: Color(0xFF7A736B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: commentController,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Cuéntanos cómo estuvo tu pedido',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE7DED2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE7DED2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5A8A5A), width: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.star_rounded),
          label: const Text(
            'Enviar calificación',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5A8A5A),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFF5A8A5A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.4,
                        color: Color(0xFF7A736B),
                        height: 1.35,
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
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _MiniStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5EF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF5A8A5A)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.2,
              color: Color(0xFF7A736B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF2D2D2D),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.8,
              color: Color(0xFF9A938A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProducerCard extends StatelessWidget {
  final UserModel? producer;

  const _ProducerCard({required this.producer});

  @override
  Widget build(BuildContext context) {
    final hasProducer = producer != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            src: producer?.image,
            width: 64,
            height: 64,
            borderRadius: 20,
            placeholder: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: Color(0xFF5A8A5A),
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProducer && producer!.name.trim().isNotEmpty
                      ? producer!.name.trim()
                      : 'Empresa no disponible',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 6),
                _SmallInfoLine(
                  icon: Icons.phone_outlined,
                  text: hasProducer &&
                      (producer!.cellphone ?? '').trim().isNotEmpty
                      ? producer!.cellphone!.trim()
                      : 'Sin teléfono registrado',
                ),
                const SizedBox(height: 6),
                _SmallInfoLine(
                  icon: Icons.email_outlined,
                  text: hasProducer ? producer!.email : 'Sin correo disponible',
                ),
                if (hasProducer &&
                    (producer!.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    producer!.description!.trim(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF5C544B),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7A736B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF5C544B),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRowCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;

  const _InfoRowCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: const Color(0xFF5A8A5A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.2,
                    color: Color(0xFF7A736B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.2,
                    color: Color(0xFF2D2D2D),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 11.8,
                    color: Color(0xFF9A938A),
                    height: 1.35,
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

class _NotesCard extends StatelessWidget {
  final String? notes;

  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    final cleanNotes = (notes ?? '').trim();

    if (cleanNotes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5EF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF7A736B),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Este pedido no tiene notas registradas por ahora. Cuando conectes la persistencia completa, aquí se verán indicaciones como referencias, observaciones o instrucciones especiales.',
                style: TextStyle(
                  fontSize: 12.8,
                  color: Color(0xFF5C544B),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        cleanNotes,
        style: const TextStyle(
          fontSize: 13.2,
          color: Color(0xFF2D2D2D),
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final bool isCheckingReview;
  final bool reviewCheckDone;
  final bool hasReview;
  final ReviewModel? existingReview;
  final bool canReview;
  final bool isSubmitting;
  final VoidCallback? onTapReview;

  const _ReviewSection({
    required this.isCheckingReview,
    required this.reviewCheckDone,
    required this.hasReview,
    required this.existingReview,
    required this.canReview,
    required this.isSubmitting,
    required this.onTapReview,
  });

  @override
  Widget build(BuildContext context) {
    if (isCheckingReview && !reviewCheckDone) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5EF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF5A8A5A),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Estamos verificando si este pedido ya fue calificado.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5C544B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (hasReview && existingReview != null) {
      final comment = (existingReview!.comment ?? '').trim();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0DCA5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(5, (index) {
                  final active = index < existingReview!.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      active ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFE2A73B),
                      size: 22,
                    ),
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  '${existingReview!.value}/5',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8A5A00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _reviewLabelForValue(existingReview!.value),
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF7A736B),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2D2D2D),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (isSubmitting) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4EA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCBE1CB)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF5A8A5A),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Guardando tu calificación...',
                style: TextStyle(
                  fontSize: 12.8,
                  color: Color(0xFF3D7A3D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (canReview) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4EA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCBE1CB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  color: Color(0xFF3D7A3D),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu pedido ya está completado. Ahora puedes dejar una calificación para compartir tu experiencia.',
                    style: TextStyle(
                      fontSize: 12.8,
                      color: Color(0xFF3D7A3D),
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTapReview,
                icon: const Icon(Icons.star_rounded),
                label: const Text(
                  'Calificar pedido',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A8A5A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF7A736B),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'La calificación solo estará disponible cuando el pedido esté completado y todavía no tenga una review registrada.',
              style: TextStyle(
                fontSize: 12.8,
                color: Color(0xFF5C544B),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailCard extends StatelessWidget {
  final OrderDetailModel detail;
  final ProductModel? product;

  const _ProductDetailCard({
    required this.detail,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = detail.unitPrice * detail.quantity;
    final name = (product?.name ?? '').trim().isNotEmpty
        ? product!.name.trim()
        : 'Producto #${detail.productID}';
    final unit = (product?.unit ?? '').trim().isNotEmpty
        ? product!.unit!.trim()
        : 'unidad';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            src: product?.picture,
            width: 70,
            height: 70,
            borderRadius: 18,
            placeholder: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.eco_outlined,
                color: Color(0xFF5A8A5A),
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14.8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2D2D),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatMoney(detail.unitPrice)} por $unit',
                  style: const TextStyle(
                    fontSize: 12.3,
                    color: Color(0xFF7A736B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TinyChip(
                      icon: Icons.shopping_basket_outlined,
                      text: 'Cantidad: ${detail.quantity}',
                    ),
                    _TinyChip(
                      icon: Icons.calculate_outlined,
                      text: 'Subtotal: ${_formatMoney(subtotal)}',
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

class _TinyChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TinyChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF5A8A5A)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.8,
              color: Color(0xFF5C544B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.2,
              color: highlight ? const Color(0xFF2D2D2D) : const Color(0xFF7A736B),
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.8,
            color: highlight ? const Color(0xFF5A8A5A) : const Color(0xFF2D2D2D),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _BottomActionCard extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final int? orderId;
  final String stateLabel;
  final bool canReview;
  final bool isCheckingReview;
  final bool isSubmittingReview;
  final VoidCallback? onReview;

  const _BottomActionCard({
    required this.onRefresh,
    required this.orderId,
    required this.stateLabel,
    this.canReview = false,
    this.isCheckingReview = false,
    this.isSubmittingReview = false,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones rápidas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pedido #${orderId ?? 0} • Estado actual: $stateLabel',
            style: const TextStyle(
              fontSize: 12.8,
              color: Color(0xFF7A736B),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Actualizar detalle',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A8A5A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          if (canReview) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (isCheckingReview || isSubmittingReview) ? null : onReview,
                icon: (isCheckingReview || isSubmittingReview)
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.star_rounded),
                label: Text(
                  isSubmittingReview ? 'Guardando calificación...' : 'Calificar pedido',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5A8A5A),
                  side: const BorderSide(color: Color(0xFF5A8A5A)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderProgressStepper extends StatelessWidget {
  final int state;

  const _OrderProgressStepper({required this.state});

  bool _isStepActive(int index) {
    if (state == OrderController.stateCancelled) {
      return index == 4;
    }
    if (state == OrderController.statePending) return index == 0;
    if (state == OrderController.statePreparing) return index <= 1;
    if (state == OrderController.stateShipped) return index <= 2;
    if (state == OrderController.stateCompleted) return index <= 3;
    return false;
  }

  Color _stepColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFD17B00);
      case 1:
        return const Color(0xFF8A5A00);
      case 2:
        return const Color(0xFF2F6D99);
      case 3:
        return const Color(0xFF3D7A3D);
      case 4:
        return const Color(0xFFC24D4D);
      default:
        return const Color(0xFF9A938A);
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Pendiente',
      'En preparación',
      'Enviado',
      'Completado',
      'Cancelado',
    ];

    const icons = [
      Icons.schedule_rounded,
      Icons.inventory_2_rounded,
      Icons.local_shipping_rounded,
      Icons.check_circle_rounded,
      Icons.cancel_rounded,
    ];

    return Column(
      children: [
        Row(
          children: List.generate(labels.length * 2 - 1, (i) {
            if (i.isOdd) {
              final leftStep = i ~/ 2;
              final activeLine = state != OrderController.stateCancelled &&
                  _isStepActive(leftStep + 1) &&
                  leftStep < 3;

              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: activeLine
                        ? _stepColor(leftStep + 1).withOpacity(0.45)
                        : const Color(0xFFE4DDD3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }

            final step = i ~/ 2;
            final active = _isStepActive(step);
            final color = _stepColor(step);

            return Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? color.withOpacity(0.14)
                        : const Color(0xFFF1ECE4),
                    border: Border.all(
                      color: active ? color : const Color(0xFFE0D8CE),
                    ),
                  ),
                  child: Icon(
                    icons[step],
                    size: 18,
                    color: active ? color : const Color(0xFF9A938A),
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: labels.map((label) {
            final index = labels.indexOf(label);
            final active = _isStepActive(index);
            final color = _stepColor(index);

            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? color : const Color(0xFF9A938A),
                  fontSize: 10.8,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final _OrderStatusUi status;

  const _StatusMessage({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: status.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, color: status.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusLongMessage(status.label),
              style: TextStyle(
                fontSize: 12.8,
                color: status.foreground,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _HeroInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
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
                  title,
                  style: const TextStyle(
                    fontSize: 11.8,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Colors.white,
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

class _HeroStatusPill extends StatelessWidget {
  final _OrderStatusUi status;

  const _HeroStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: status.foreground),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12.2,
              color: status.foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductItemSkeleton extends StatelessWidget {
  const _ProductItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(
                    2,
                        (index) => Padding(
                      padding: EdgeInsets.only(right: index == 0 ? 8 : 0),
                      child: Container(
                        height: 28,
                        width: index == 0 ? 90 : 110,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
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

class _DetailLoadingState extends StatelessWidget {
  const _DetailLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4EA),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF5A8A5A),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cargando detalle del pedido',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Estamos reuniendo productos, estado, información del productor y el resumen de la orden.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7A736B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusUi {
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;

  const _OrderStatusUi({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });
}

_OrderStatusUi _statusFor(int state) {
  switch (state) {
    case OrderController.statePending:
      return const _OrderStatusUi(
        label: 'Pendiente',
        icon: Icons.schedule_rounded,
        foreground: Color(0xFFD17B00),
        background: Color(0xFFFFF3DD),
        border: Color(0xFFFFE1A6),
      );
    case OrderController.statePreparing:
      return const _OrderStatusUi(
        label: 'En preparación',
        icon: Icons.restaurant_outlined,
        foreground: Color(0xFF8A5A00),
        background: Color(0xFFFFF0D8),
        border: Color(0xFFFFD8A0),
      );
    case OrderController.stateShipped:
      return const _OrderStatusUi(
        label: 'Enviado',
        icon: Icons.local_shipping_outlined,
        foreground: Color(0xFF2F6D99),
        background: Color(0xFFE9F5FF),
        border: Color(0xFFBFDCF2),
      );
    case OrderController.stateCompleted:
      return const _OrderStatusUi(
        label: 'Completado',
        icon: Icons.task_alt_rounded,
        foreground: Color(0xFF3D7A3D),
        background: Color(0xFFEAF4EA),
        border: Color(0xFFCBE1CB),
      );
    case OrderController.stateCancelled:
      return const _OrderStatusUi(
        label: 'Cancelado',
        icon: Icons.cancel_outlined,
        foreground: Color(0xFFC24D4D),
        background: Color(0xFFFFECEC),
        border: Color(0xFFF6C6C6),
      );
    default:
      return const _OrderStatusUi(
        label: 'Desconocido',
        icon: Icons.help_outline_rounded,
        foreground: Color(0xFF7A736B),
        background: Color(0xFFF1ECE4),
        border: Color(0xFFE0D8CE),
      );
  }
}

String _statusLongMessage(String label) {
  switch (label) {
    case 'Pendiente':
      return 'Tu pedido fue registrado correctamente y está esperando la atención del productor.';
    case 'En preparación':
      return 'El productor ya está preparando tu pedido. Sigue atento al próximo cambio de estado.';
    case 'Enviado':
      return 'El pedido salió del punto de preparación y se encuentra en proceso de entrega o recojo.';
    case 'Completado':
      return 'El pedido fue marcado como completado. Ya puedes usar este historial como referencia de compra.';
    case 'Cancelado':
      return 'Este pedido fue cancelado y ya no continuará en el flujo normal de atención.';
    default:
      return 'No se pudo determinar una descripción ampliada para este estado.';
  }
}

String _formatOrderDate(DateTime? date) {
  if (date == null) return 'Fecha no disponible';

  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  final day = date.day.toString().padLeft(2, '0');
  final month = months[date.month - 1];
  final year = date.year;
  return '$day $month $year';
}

String _formatOrderTime(DateTime? date) {
  if (date == null) return '--:--';

  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatMoney(double value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}

String _safeAddress(String? address) {
  final text = (address ?? '').trim();
  if (text.isEmpty) {
    return 'Dirección no disponible por ahora';
  }
  return text;
}

String _reviewLabelForValue(int value) {
  switch (value) {
    case 1:
      return 'Muy mala';
    case 2:
      return 'Regular';
    case 3:
      return 'Buena';
    case 4:
      return 'Muy buena';
    case 5:
      return 'Excelente';
    default:
      return 'Calificación';
  }
}