import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';
import '../../models/cart_item_model.dart';
import '../../models/delivery_mode_model.dart';
import '../../models/order_detail_model.dart';
import '../../models/order_model.dart';
import '../../models/pickup_location_model.dart';
import '../../models/schedule_model.dart';
import '../../models/user_model.dart';
import '../../services/delivery_mode_service.dart';
import '../../services/location_service.dart';
import '../../services/schedule_service.dart';
import '../../services/user_service.dart';

enum _DeliveryChoice { pickup, home }

class ClientCartView extends StatefulWidget {
  const ClientCartView({super.key});

  @override
  State<ClientCartView> createState() => _ClientCartViewState();
}

class _ClientCartViewState extends State<ClientCartView> {
  final UserService _userService = UserService();
  final ScheduleService _scheduleService = ScheduleService();
  final DeliveryModeService _deliveryModeService = DeliveryModeService();
  final LocationService _locationService = LocationService();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoadingCheckoutData = false;
  bool _isSubmittingOrder = false;

  int? _loadedProducerId;
  String? _checkoutError;

  UserModel? _producer;
  DeliveryModeModel? _producerDeliveryMode;
  PickupLocationModel? _producerPickupLocation;
  PickupLocationModel? _clientPickupLocation;
  List<ScheduleModel> _producerSchedules = [];
  _DeliveryChoice? _selectedDeliveryChoice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final producerId = context.read<CartController>().currentProducerID;

    if (producerId != null && producerId > 0 && producerId != _loadedProducerId) {
      _loadCheckoutData(producerId);
    }

    if ((producerId == null || producerId <= 0) && _loadedProducerId != null) {
      _resetCheckoutData();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCheckoutData(int producerId) async {
    if (_isLoadingCheckoutData) return;

    setState(() {
      _isLoadingCheckoutData = true;
      _checkoutError = null;
      _loadedProducerId = producerId;
    });

    try {
      final userCtrl = context.read<UserController>();
      final client = userCtrl.currentUser;

      final producerFuture = _userService.getUserById(producerId);
      final schedulesFuture = _scheduleService.getSchedulesByProducerId(producerId);
      final modesFuture = _deliveryModeService.getAll();
      final clientPickupFuture = (client?.pickUpLocationID != null &&
          client!.pickUpLocationID! > 0)
          ? _locationService.getPickupLocationById(client.pickUpLocationID!)
          : Future<PickupLocationModel?>.value(null);

      final producer = await producerFuture;
      final schedules = await schedulesFuture;
      final modes = await modesFuture;
      final clientPickup = await clientPickupFuture;

      PickupLocationModel? producerPickup;
      if (producer?.pickUpLocationID != null && producer!.pickUpLocationID! > 0) {
        producerPickup =
        await _locationService.getPickupLocationById(producer.pickUpLocationID!);
      }

      DeliveryModeModel? producerMode;
      if (producer?.deliveryModeID != null) {
        for (final mode in modes) {
          if (mode.id == producer!.deliveryModeID) {
            producerMode = mode;
            break;
          }
        }
      }

      if (!mounted) return;

      final supportsPickup = _supportsPickup(mode: producerMode);
      final supportsHome = _supportsHome(mode: producerMode);

      _DeliveryChoice? initialChoice;
      if (supportsPickup && supportsHome) {
        initialChoice = clientPickup != null
            ? _DeliveryChoice.home
            : _DeliveryChoice.pickup;
      } else if (supportsPickup) {
        initialChoice = _DeliveryChoice.pickup;
      } else if (supportsHome) {
        initialChoice = _DeliveryChoice.home;
      }

      String? checkoutError;
      if (producer == null) {
        checkoutError = 'No se pudo cargar la información del productor.';
      } else if (!supportsPickup && !supportsHome) {
        checkoutError =
        'No se pudo determinar la modalidad de entrega del productor.';
      }

      setState(() {
        _producer = producer;
        _producerSchedules = schedules;
        _producerDeliveryMode = producerMode;
        _producerPickupLocation = producerPickup;
        _clientPickupLocation = clientPickup;
        _selectedDeliveryChoice = initialChoice;
        _checkoutError = checkoutError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkoutError = 'Error cargando la información del pedido: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingCheckoutData = false;
      });
    }
  }

  void _resetCheckoutData() {
    setState(() {
      _loadedProducerId = null;
      _checkoutError = null;
      _producer = null;
      _producerDeliveryMode = null;
      _producerPickupLocation = null;
      _clientPickupLocation = null;
      _producerSchedules = [];
      _selectedDeliveryChoice = null;
      _isLoadingCheckoutData = false;
      _isSubmittingOrder = false;
      _notesController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Consumer2<CartController, UserController>(
          builder: (context, cart, userCtrl, _) {
            final balance = userCtrl.currentUser?.balance ?? 0.0;
            final hasItems = cart.items.isNotEmpty;
            final canAfford = balance >= cart.total;
            final checkoutMessage = _getCheckoutValidationMessage();
            final canConfirm = hasItems && canAfford && checkoutMessage == null;

            return Column(
              children: [
                _buildTopBar(context, cart),
                Expanded(
                  child: hasItems
                      ? _buildCartList(context, cart)
                      : _buildEmptyState(context),
                ),
                if (hasItems)
                  _buildFooter(
                    context,
                    cart,
                    balance,
                    canAfford,
                    canConfirm,
                    checkoutMessage,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, CartController cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                SizedBox(height: 2),
                Text(
                  'Confirma tu pedido según modalidad y horario',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF7A756E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (cart.currentProducerName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

  Widget _buildCartList(BuildContext context, CartController cart) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _buildCheckoutInfoCard(),
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Productos en tu pedido',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ),
        ...List.generate(cart.items.length, (index) {
          final item = cart.items[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == cart.items.length - 1 ? 0 : 10,
            ),
            child: _CartItemCard(item: item),
          );
        }),
      ],
    );
  }

  Widget _buildCheckoutInfoCard() {
    final todaySchedules = _getTodaySchedules();
    final isOpenNow = _isWithinProducerScheduleNow();
    final modeLabel = _producerDeliveryMode?.name ?? 'No disponible';
    final selectedDeliveryText = _getSelectedDeliveryChoiceLabel();
    final currentAddress = _getSelectedAddress();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Color(0xFF5A8A5A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Condiciones del pedido',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Revisamos modalidad, dirección y horario del productor',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF7A756E),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingCheckoutData)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_checkoutError != null)
            _buildInfoBanner(
              icon: Icons.warning_amber_rounded,
              message: _checkoutError!,
              background: const Color(0xFFFFF0EC),
              border: const Color(0xFFFFD0C2),
              textColor: const Color(0xFFD96C2F),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPill(
                  icon: Icons.local_shipping_outlined,
                  label: 'Modalidad: $modeLabel',
                ),
                _buildPill(
                  icon: isOpenNow ? Icons.schedule : Icons.schedule_outlined,
                  label: isOpenNow ? 'Abierto ahora' : 'Fuera de horario',
                  background: isOpenNow
                      ? const Color(0xFFEAF4EA)
                      : const Color(0xFFFFF0EC),
                  foreground: isOpenNow
                      ? const Color(0xFF4D8B55)
                      : const Color(0xFFD96C2F),
                ),
                if (selectedDeliveryText != null)
                  _buildPill(
                    icon: Icons.place_outlined,
                    label: selectedDeliveryText,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              title: 'Horario de hoy',
              value: todaySchedules.isEmpty
                  ? 'Este productor no tiene horarios configurados para hoy.'
                  : todaySchedules.join(' · '),
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.map_outlined,
              title: 'Dirección usada para este pedido',
              value:
              currentAddress ?? 'Todavía no hay una dirección válida seleccionada.',
            ),
            if (_selectedDeliveryChoice == _DeliveryChoice.home &&
                _clientPickupLocation == null) ...[
              const SizedBox(height: 10),
              _buildInfoBanner(
                icon: Icons.info_outline_rounded,
                message:
                'Para entrega a domicilio, el cliente debe tener una dirección registrada.',
                background: const Color(0xFFFFF7E7),
                border: const Color(0xFFF7D994),
                textColor: const Color(0xFF8C6A1A),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(
      BuildContext context,
      CartController cart,
      double balance,
      bool canAfford,
      bool canConfirm,
      String? checkoutMessage,
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: !canAfford
                  ? const Color(0xFFFFF0EC)
                  : checkoutMessage == null
                  ? const Color(0xFFEAF4EA)
                  : const Color(0xFFFFF7E7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: !canAfford
                    ? const Color(0xFFFFCBBC)
                    : checkoutMessage == null
                    ? const Color(0xFFB8D8B8)
                    : const Color(0xFFF7D994),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  !canAfford
                      ? Icons.warning_amber_rounded
                      : checkoutMessage == null
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: !canAfford
                      ? const Color(0xFFD96C2F)
                      : checkoutMessage == null
                      ? const Color(0xFF5A8A5A)
                      : const Color(0xFF8C6A1A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    !canAfford
                        ? 'Saldo insuficiente — te faltan ${(cart.total - balance).toStringAsFixed(0)} monedas'
                        : checkoutMessage ??
                        'Todo listo: puedes confirmar tu pedido dentro del horario disponible',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: !canAfford
                          ? const Color(0xFFD96C2F)
                          : checkoutMessage == null
                          ? const Color(0xFF5A8A5A)
                          : const Color(0xFF8C6A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canConfirm && !_isSubmittingOrder
                  ? () => _openCheckoutSheet(context, cart)
                  : null,
              icon: _isSubmittingOrder
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _isSubmittingOrder ? 'Procesando pedido...' : 'Confirmar pedido',
                style: const TextStyle(
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

  Future<void> _openCheckoutSheet(
      BuildContext pageContext,
      CartController cart,
      ) async {
    final balance = pageContext.read<UserController>().currentUser?.balance ?? 0.0;

    await showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedAddress = _getSelectedAddress();
            final selectedChoiceLabel = _getSelectedDeliveryChoiceLabel();
            final checkoutMessage = _getCheckoutValidationMessage();
            final canSubmit = checkoutMessage == null && !_isSubmittingOrder;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 14,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5EF),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD6CFC4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Resumen del pedido',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _producer?.name.isNotEmpty == true
                              ? 'Comprarás a ${_producer!.name}'
                              : 'Revisa la información antes de confirmar',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7A756E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildSheetSection(
                          title: 'Modalidad de entrega',
                          icon: Icons.local_shipping_outlined,
                          child: _buildDeliveryChoiceSelector(setModalState),
                        ),
                        const SizedBox(height: 14),
                        _buildSheetSection(
                          title: 'Dirección aplicada al pedido',
                          icon: Icons.map_outlined,
                          child: Text(
                            selectedAddress ??
                                'No hay una dirección válida disponible para esta modalidad.',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF4B463F),
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildSheetSection(
                          title: 'Horario del productor',
                          icon: Icons.access_time_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isWithinProducerScheduleNow()
                                    ? 'Disponible en este momento'
                                    : 'No disponible en este momento',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _isWithinProducerScheduleNow()
                                      ? const Color(0xFF4D8B55)
                                      : const Color(0xFFD96C2F),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _buildWeeklyScheduleText(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5F5951),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildSheetSection(
                          title: 'Notas para el pedido (opcional)',
                          icon: Icons.sticky_note_2_outlined,
                          child: TextField(
                            controller: _notesController,
                            maxLines: 3,
                            maxLength: 180,
                            decoration: InputDecoration(
                              hintText:
                              'Ej.: llamar al llegar, entregar en portería, sin bolsas... ',
                              filled: true,
                              fillColor: Colors.white,
                              counterStyle: const TextStyle(fontSize: 11.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE4DBCF),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE4DBCF),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF5A8A5A),
                                  width: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7DED2)),
                          ),
                          child: Column(
                            children: [
                              _buildSummaryLine('Productos', '${cart.itemCount}'),
                              const SizedBox(height: 8),
                              _buildSummaryLine(
                                'Modalidad elegida',
                                selectedChoiceLabel ?? 'No disponible',
                              ),
                              const SizedBox(height: 8),
                              _buildSummaryLine(
                                'Saldo actual',
                                '${balance.toStringAsFixed(0)} monedas',
                              ),
                              const Divider(height: 22),
                              _buildSummaryLine(
                                'Total a pagar',
                                '${cart.total.toStringAsFixed(0)} monedas',
                                isStrong: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (checkoutMessage != null)
                          _buildInfoBanner(
                            icon: Icons.info_outline_rounded,
                            message: checkoutMessage,
                            background: const Color(0xFFFFF7E7),
                            border: const Color(0xFFF7D994),
                            textColor: const Color(0xFF8C6A1A),
                          ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmittingOrder
                                    ? null
                                    : () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(
                                    color: Color(0xFFD4CCBF),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: canSubmit
                                    ? () => _submitOrder(
                                  rootContext: pageContext,
                                  sheetContext: sheetContext,
                                  cart: cart,
                                  setModalState: setModalState,
                                )
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5A8A5A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSubmittingOrder
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                    : const Text(
                                  'Confirmar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
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
  }

  Widget _buildDeliveryChoiceSelector(StateSetter setModalState) {
    final supportsPickup = _supportsPickup();
    final supportsHome = _supportsHome();

    if (!supportsPickup && !supportsHome) {
      return const Text(
        'No hay modalidades disponibles para este productor.',
        style: TextStyle(
          fontSize: 13.5,
          color: Color(0xFFD96C2F),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (supportsPickup)
              _buildChoiceCard(
                label: 'Retiro / recojo',
                description: _producerPickupLocation?.address ??
                    'Punto del productor pendiente de validar',
                icon: Icons.store_mall_directory_outlined,
                selected: _selectedDeliveryChoice == _DeliveryChoice.pickup,
                onTap: () {
                  setState(() {
                    _selectedDeliveryChoice = _DeliveryChoice.pickup;
                  });
                  setModalState(() {});
                },
              ),
            if (supportsHome)
              _buildChoiceCard(
                label: 'Entrega a domicilio',
                description: _clientPickupLocation?.address ??
                    'Usará tu dirección registrada en la app',
                icon: Icons.home_outlined,
                selected: _selectedDeliveryChoice == _DeliveryChoice.home,
                onTap: () {
                  setState(() {
                    _selectedDeliveryChoice = _DeliveryChoice.home;
                  });
                  setModalState(() {});
                },
              ),
          ],
        ),
        if (_producerDeliveryMode != null) ...[
          const SizedBox(height: 10),
          Text(
            'Modalidad configurada por el productor: ${_producerDeliveryMode!.name}',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF7A756E),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submitOrder({
    required BuildContext rootContext,
    required BuildContext sheetContext,
    required CartController cart,
    required StateSetter setModalState,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(rootContext);
    final userCtrl = rootContext.read<UserController>();
    final orderCtrl = rootContext.read<OrderController>();

    final validationMessage = _getCheckoutValidationMessage();
    if (validationMessage != null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(validationMessage),
          backgroundColor: const Color(0xFFD96C2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final client = userCtrl.currentUser;
    final producerID = cart.currentProducerID;

    if (client == null || client.id == null || client.id! <= 0) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se encontró un cliente válido.'),
          backgroundColor: Color(0xFFD96C2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (producerID == null || producerID <= 0) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se encontró un productor válido.'),
          backgroundColor: Color(0xFFD96C2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (cart.items.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío.'),
          backgroundColor: Color(0xFFD96C2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final targetLocationId = _getSelectedLocationId();
    final targetAddress = _getSelectedAddress();

    if (targetLocationId == null || targetLocationId <= 0) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo determinar una dirección válida para el pedido.',
          ),
          backgroundColor: Color(0xFFD96C2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingOrder = true;
    });
    setModalState(() {});

    try {
      final details = cart.items
          .map(
            (item) => OrderDetailModel(
          orderID: 0,
          productID: item.productId,
          quantity: item.quantity,
          unitPrice: item.precio,
        ),
      )
          .toList();

      final notes = _notesController.text.trim();

      final order = OrderModel(
        amount: cart.total,
        state: 0,
        pickupLocationID: targetLocationId,
        clientID: client.id!,
        producerID: producerID,
        pickupLocationAddress: targetAddress,
        notes: notes.isEmpty ? null : notes,
      );

      final createdOrderId = await orderCtrl.createOrder(order, details);

      if (!mounted) return;

      if (createdOrderId == null || createdOrderId <= 0) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              orderCtrl.errorMessage ?? 'No se pudo registrar el pedido.',
            ),
            backgroundColor: const Color(0xFFD96C2F),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await userCtrl.reloadCurrentUser();

      if (!mounted) return;

      cart.clearCart();
      _notesController.clear();

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
      if (rootContext.mounted) {
        Navigator.pop(rootContext);
      }

      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            _selectedDeliveryChoice == _DeliveryChoice.home
                ? '¡Pedido confirmado! Se registró con entrega a domicilio.'
                : '¡Pedido confirmado! Se registró para retiro/recojo.',
          ),
          backgroundColor: const Color(0xFF5A8A5A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmittingOrder = false;
      });
      setModalState(() {});
    }
  }

  String? _getCheckoutValidationMessage() {
    if (_isLoadingCheckoutData) {
      return 'Cargando información del productor y del pedido...';
    }

    if (_checkoutError != null) {
      return _checkoutError;
    }

    if (_producer == null) {
      return 'No se pudo cargar al productor del carrito.';
    }

    if (_producerSchedules.isEmpty) {
      return 'Este productor no tiene horarios configurados.';
    }

    if (!_isWithinProducerScheduleNow()) {
      return 'El productor está fuera de su horario de atención en este momento.';
    }

    if (_selectedDeliveryChoice == null) {
      return 'Selecciona una modalidad válida para continuar.';
    }

    if (_selectedDeliveryChoice == _DeliveryChoice.pickup &&
        (_producerPickupLocation == null ||
            (_producerPickupLocation?.locationID ?? 0) <= 0)) {
      return 'El productor no tiene un punto de recojo válido.';
    }

    if (_selectedDeliveryChoice == _DeliveryChoice.home &&
        (_clientPickupLocation == null ||
            (_clientPickupLocation?.locationID ?? 0) <= 0)) {
      return 'Necesitas una dirección registrada para pedir a domicilio.';
    }

    return null;
  }

  bool _supportsPickup({DeliveryModeModel? mode}) {
    final currentMode = mode ?? _producerDeliveryMode;
    if (currentMode == null) return false;

    final id = currentMode.id;
    final name = currentMode.name.toLowerCase();

    if (id == 3 || name.contains('amb')) return true;
    if (id == 1 || id == 7) return true;
    if (name.contains('retiro') ||
        name.contains('recojo') ||
        name.contains('local') ||
        name.contains('punto')) {
      return true;
    }

    return false;
  }

  bool _supportsHome({DeliveryModeModel? mode}) {
    final currentMode = mode ?? _producerDeliveryMode;
    if (currentMode == null) return false;

    final id = currentMode.id;
    final name = currentMode.name.toLowerCase();

    if (id == 3 || name.contains('amb')) return true;
    if (id == 2 || id == 8 || id == 9) return true;
    if (name.contains('domicilio') || name.contains('programada')) return true;
    if (name.contains('entrega') &&
        !name.contains('retiro') &&
        !name.contains('recojo')) {
      return true;
    }

    return false;
  }

  bool _isWithinProducerScheduleNow() {
    if (_producerSchedules.isEmpty) return false;

    final now = DateTime.now();
    final today = now.weekday - 1;

    for (final schedule in _producerSchedules.where((s) => s.day == today)) {
      final start = _combineTodayWithTime(now, schedule.openingTime);
      final end = _combineTodayWithTime(now, schedule.closingTime);

      if (start == null || end == null) continue;

      if (!now.isBefore(start) && !now.isAfter(end)) {
        return true;
      }
    }

    return false;
  }

  List<String> _getTodaySchedules() {
    if (_producerSchedules.isEmpty) return [];

    final today = DateTime.now().weekday - 1;
    return _producerSchedules
        .where((schedule) => schedule.day == today)
        .map(
          (schedule) =>
      '${_normalizeDisplayTime(schedule.openingTime)} - ${_normalizeDisplayTime(schedule.closingTime)}',
    )
        .toList();
  }

  String _buildWeeklyScheduleText() {
    if (_producerSchedules.isEmpty) {
      return 'Sin horarios registrados.';
    }

    return _producerSchedules
        .map(
          (schedule) =>
      '${schedule.dayName}: ${_normalizeDisplayTime(schedule.openingTime)} - ${_normalizeDisplayTime(schedule.closingTime)}',
    )
        .join('\n');
  }

  DateTime? _combineTodayWithTime(DateTime now, String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length >= 3 ? int.tryParse(parts[2]) ?? 0 : 0;

    return DateTime(now.year, now.month, now.day, hour, minute, second);
  }

  String _normalizeDisplayTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return value;

    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }

  int? _getSelectedLocationId() {
    switch (_selectedDeliveryChoice) {
      case _DeliveryChoice.pickup:
        return _producerPickupLocation?.locationID;
      case _DeliveryChoice.home:
        return _clientPickupLocation?.locationID;
      case null:
        return null;
    }
  }

  String? _getSelectedAddress() {
    switch (_selectedDeliveryChoice) {
      case _DeliveryChoice.pickup:
        return _producerPickupLocation?.address;
      case _DeliveryChoice.home:
        return _clientPickupLocation?.address;
      case null:
        return null;
    }
  }

  String? _getSelectedDeliveryChoiceLabel() {
    switch (_selectedDeliveryChoice) {
      case _DeliveryChoice.pickup:
        return 'Retiro / recojo';
      case _DeliveryChoice.home:
        return 'Entrega a domicilio';
      case null:
        return null;
    }
  }

  Widget _buildChoiceCard({
    required String label,
    required String description,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF4EA) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
            selected ? const Color(0xFF5A8A5A) : const Color(0xFFE3DBD0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color:
              selected ? const Color(0xFF5A8A5A) : const Color(0xFF7A756E),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color:
                selected ? const Color(0xFF315D38) : const Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.2,
                color: Color(0xFF6F695F),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7DED2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF5A8A5A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value, {bool isStrong = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.2,
            color: const Color(0xFF6F695F),
            fontWeight: isStrong ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.6,
              color: const Color(0xFF2D2D2D),
              fontWeight: isStrong ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEE6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF7A756E)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.8,
                  color: Color(0xFF6F695F),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    Color background = const Color(0xFFF3EEE6),
    Color foreground = const Color(0xFF5E564D),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String message,
    required Color background,
    required Color border,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.8,
                color: textColor,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Ver productores',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Row(
                  children: [
                    Text(
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
                      item.subtotal.toStringAsFixed(
                        item.subtotal % 1 == 0 ? 0 : 1,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                                color: const Color(0xFF5A8A5A).withOpacity(0.25),
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