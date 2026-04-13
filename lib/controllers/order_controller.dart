import 'package:flutter/material.dart';

import '../models/order_detail_model.dart';
import '../models/order_model.dart';
import '../services/interfaces/i_order_service.dart';
import '../services/order_service.dart';

class OrderController extends ChangeNotifier {
  final IOrderService _orderService;

  OrderController({IOrderService? orderService})
      : _orderService = orderService ?? OrderService();

  /// Estados usados en APP-44:
  /// 0 = Pendiente
  /// 1 = En preparación
  /// 2 = Enviado
  /// 3 = Completado
  /// 4 = Cancelado
  static const int statePending = 0;
  static const int statePreparing = 1;
  static const int stateShipped = 2;
  static const int stateCompleted = 3;
  static const int stateCancelled = 4;

  List<OrderModel> _clientOrders = [];
  List<OrderModel> _producerOrders = [];
  List<OrderDetailModel> _orderDetails = [];

  bool _isLoading = false;
  bool _isCreating = false;
  bool _isLoadingDetails = false;
  bool _isUpdatingState = false;
  bool _isLoadingProducerStats = false;

  String? _errorMessage;
  String? _successMessage;

  int? _lastCreatedOrderId;

  ProducerSalesStats _producerSalesStats = const ProducerSalesStats.empty();
  int? _lastStatsProducerId;
  int _lastTopProductsLimit = 5;

  List<OrderModel> get clientOrders => List.unmodifiable(_clientOrders);
  List<OrderModel> get producerOrders => List.unmodifiable(_producerOrders);
  List<OrderDetailModel> get orderDetails => List.unmodifiable(_orderDetails);

  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  bool get isLoadingDetails => _isLoadingDetails;
  bool get isUpdatingState => _isUpdatingState;
  bool get isLoadingProducerStats => _isLoadingProducerStats;

  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  int? get lastCreatedOrderId => _lastCreatedOrderId;

  bool get hasClientOrders => _clientOrders.isNotEmpty;
  bool get hasProducerOrders => _producerOrders.isNotEmpty;
  bool get hasOrderDetails => _orderDetails.isNotEmpty;
  bool get hasProducerSalesStats =>
      _producerSalesStats.totalOrders > 0 ||
          _producerSalesStats.topProducts.isNotEmpty;

  ProducerSalesStats get producerSalesStats => _producerSalesStats;

  int get producerTotalOrders => _producerSalesStats.totalOrders;
  int get producerPendingOrders => _producerSalesStats.pendingOrders;

  /// Se mantiene este getter por compatibilidad con vistas ya hechas.
  /// Ahora representa pedidos "En preparación".
  int get producerAcceptedOrders => _producerSalesStats.acceptedOrders;

  int get producerPreparingOrders => _producerSalesStats.acceptedOrders;
  int get producerShippedOrders => _producerSalesStats.shippedOrders;
  int get producerCompletedOrders => _producerSalesStats.completedOrders;
  int get producerCancelledOrders => _producerSalesStats.cancelledOrders;

  double get producerManagedAmount => _producerSalesStats.managedAmount;

  /// Ingreso real ya completado.
  double get producerDeliveredRevenue => _producerSalesStats.deliveredRevenue;
  double get producerAverageTicket => _producerSalesStats.averageTicket;

  List<TopSellingProductStat> get topSellingProducts =>
      List.unmodifiable(_producerSalesStats.topProducts);

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void clearOrderDetails() {
    _orderDetails = [];
    notifyListeners();
  }

  void clearClientOrders() {
    _clientOrders = [];
    notifyListeners();
  }

  void clearProducerOrders() {
    _producerOrders = [];
    _clearProducerSalesStatsInternal();
    notifyListeners();
  }

  void clearProducerSalesStats() {
    _clearProducerSalesStatsInternal();
    notifyListeners();
  }

  void clearAll() {
    _clientOrders = [];
    _producerOrders = [];
    _orderDetails = [];
    _isLoading = false;
    _isCreating = false;
    _isLoadingDetails = false;
    _isUpdatingState = false;
    _isLoadingProducerStats = false;
    _errorMessage = null;
    _successMessage = null;
    _lastCreatedOrderId = null;
    _clearProducerSalesStatsInternal();
    notifyListeners();
  }

  Future<int?> createOrder(
      OrderModel order,
      List<OrderDetailModel> details,
      ) async {
    try {
      _isCreating = true;
      _errorMessage = null;
      _successMessage = null;
      _lastCreatedOrderId = null;
      notifyListeners();

      if (details.isEmpty) {
        _errorMessage = 'El pedido no tiene productos.';
        return null;
      }

      if (order.clientID <= 0) {
        _errorMessage = 'Cliente inválido.';
        return null;
      }

      if (order.producerID <= 0) {
        _errorMessage = 'Productor inválido.';
        return null;
      }

      if (order.pickupLocationID <= 0) {
        _errorMessage = 'Ubicación de entrega inválida.';
        return null;
      }

      if (order.amount <= 0) {
        _errorMessage = 'El monto del pedido debe ser mayor a 0.';
        return null;
      }

      final createdOrderId = await _orderService.createOrder(order, details);

      if (createdOrderId == null || createdOrderId <= 0) {
        _errorMessage = 'No se pudo registrar el pedido.';
        return null;
      }

      _lastCreatedOrderId = createdOrderId;
      _successMessage = 'Pedido registrado correctamente.';

      await loadOrdersByClient(order.clientID);

      return createdOrderId;
    } catch (e) {
      _errorMessage = 'Error al crear pedido: $e';
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<void> loadOrdersByClient(int clientID) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (clientID <= 0) {
        _errorMessage = 'ID de cliente inválido.';
        _clientOrders = [];
        return;
      }

      _clientOrders = await _orderService.getOrdersByClient(clientID);
    } catch (e) {
      _errorMessage = 'Error cargando pedidos del cliente: $e';
      _clientOrders = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrdersByProducer(int producerID) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (producerID <= 0) {
        _errorMessage = 'ID de productor inválido.';
        _producerOrders = [];
        _clearProducerSalesStatsInternal();
        return;
      }

      _producerOrders = await _orderService.getOrdersByProducer(producerID);

      if (_lastStatsProducerId == producerID) {
        _producerSalesStats = _producerSalesStats.copyWith(
          totalOrders: _producerOrders.length,
          pendingOrders: _producerOrders
              .where((order) => order.state == statePending)
              .length,
          acceptedOrders: _producerOrders
              .where((order) => order.state == statePreparing)
              .length,
          shippedOrders: _producerOrders
              .where((order) => order.state == stateShipped)
              .length,
          completedOrders: _producerOrders
              .where((order) => order.state == stateCompleted)
              .length,
          cancelledOrders: _producerOrders
              .where((order) => order.state == stateCancelled)
              .length,
          managedAmount: _producerOrders
              .where((order) => order.state != stateCancelled)
              .fold<double>(0.0, (sum, order) => sum + order.amount),
          deliveredRevenue: _producerOrders
              .where((order) => order.state == stateCompleted)
              .fold<double>(0.0, (sum, order) => sum + order.amount),
          averageTicket: _calculateAverageCompletedTicket(_producerOrders),
        );
      }
    } catch (e) {
      _errorMessage = 'Error cargando pedidos del productor: $e';
      _producerOrders = [];
      _clearProducerSalesStatsInternal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrderDetails(int orderID) async {
    try {
      _isLoadingDetails = true;
      _errorMessage = null;
      notifyListeners();

      if (orderID <= 0) {
        _errorMessage = 'ID de pedido inválido.';
        _orderDetails = [];
        return;
      }

      _orderDetails = await _orderService.getOrderDetails(orderID);
    } catch (e) {
      _errorMessage = 'Error cargando detalle del pedido: $e';
      _orderDetails = [];
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> updateOrderState(int orderID, int state) async {
    try {
      _isUpdatingState = true;
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();

      if (orderID <= 0) {
        _errorMessage = 'ID de pedido inválido.';
        return false;
      }

      if (!_isValidOrderState(state)) {
        _errorMessage = 'Estado de pedido inválido.';
        return false;
      }

      final currentOrder = _findKnownOrderById(orderID);

      if (currentOrder != null &&
          !_isTransitionAllowed(currentOrder.state, state)) {
        _errorMessage =
        'No se puede cambiar de ${_getStateText(currentOrder.state)} a ${_getStateText(state)}.';
        return false;
      }

      final success = await _orderService.updateOrderState(orderID, state);

      if (!success) {
        _errorMessage = 'No se pudo actualizar el estado del pedido.';
        return false;
      }

      _clientOrders = _clientOrders
          .map(
            (order) =>
        order.id == orderID ? order.copyWith(state: state) : order,
      )
          .toList();

      _producerOrders = _producerOrders
          .map(
            (order) =>
        order.id == orderID ? order.copyWith(state: state) : order,
      )
          .toList();

      if (_lastStatsProducerId != null) {
        await _recalculateProducerSalesStats(
          topLimit: _lastTopProductsLimit,
          notifyAtEnd: false,
        );
      }

      _successMessage =
      'Estado del pedido actualizado a ${_getStateText(state)}.';
      return true;
    } catch (e) {
      _errorMessage = 'Error actualizando estado del pedido: $e';
      return false;
    } finally {
      _isUpdatingState = false;
      notifyListeners();
    }
  }

  Future<void> loadProducerSalesStats(
      int producerID, {
        bool reloadOrders = true,
        int topLimit = 5,
      }) async {
    try {
      _isLoadingProducerStats = true;
      _errorMessage = null;
      notifyListeners();

      if (producerID <= 0) {
        _errorMessage = 'ID de productor inválido.';
        _clearProducerSalesStatsInternal();
        return;
      }

      _lastStatsProducerId = producerID;
      _lastTopProductsLimit = topLimit <= 0 ? 5 : topLimit;

      if (reloadOrders) {
        final orders = await _orderService.getOrdersByProducer(producerID);
        _producerOrders = orders;
      }

      await _recalculateProducerSalesStats(
        topLimit: _lastTopProductsLimit,
        notifyAtEnd: false,
      );
    } catch (e) {
      _errorMessage = 'Error cargando estadísticas del productor: $e';
      _clearProducerSalesStatsInternal();
    } finally {
      _isLoadingProducerStats = false;
      notifyListeners();
    }
  }

  Future<void> refreshProducerOrdersAndStats(
      int producerID, {
        int topLimit = 5,
      }) async {
    await loadProducerSalesStats(
      producerID,
      reloadOrders: true,
      topLimit: topLimit,
    );
  }

  Future<void> _recalculateProducerSalesStats({
    required int topLimit,
    bool notifyAtEnd = true,
  }) async {
    final totalOrders = _producerOrders.length;

    final pendingOrders = _producerOrders
        .where((order) => order.state == statePending)
        .length;

    final preparingOrders = _producerOrders
        .where((order) => order.state == statePreparing)
        .length;

    final shippedOrders = _producerOrders
        .where((order) => order.state == stateShipped)
        .length;

    final completedOrders = _producerOrders
        .where((order) => order.state == stateCompleted)
        .length;

    final cancelledOrders = _producerOrders
        .where((order) => order.state == stateCancelled)
        .length;

    final managedAmount = _producerOrders
        .where((order) => order.state != stateCancelled)
        .fold<double>(0.0, (sum, order) => sum + order.amount);

    final completedOrderList = _producerOrders
        .where(
          (order) => order.state == stateCompleted && (order.id ?? 0) > 0,
    )
        .toList();

    final deliveredRevenue = completedOrderList.fold<double>(
      0.0,
          (sum, order) => sum + order.amount,
    );

    final averageTicket = _calculateAverageCompletedTicket(_producerOrders);

    final Map<int, _TopSellingAccumulator> accumulatorByProduct = {};

    for (final order in completedOrderList) {
      if (order.id == null || order.id! <= 0) continue;

      final details = await _orderService.getOrderDetails(order.id!);

      for (final detail in details) {
        final subtotal = detail.quantity * detail.unitPrice;

        final current = accumulatorByProduct.putIfAbsent(
          detail.productID,
              () => _TopSellingAccumulator(productID: detail.productID),
        );

        current.totalQuantity += detail.quantity;
        current.totalRevenue += subtotal;
        current.totalOrders += 1;
      }
    }

    final topProducts = accumulatorByProduct.values
        .map(
          (item) => TopSellingProductStat(
        productID: item.productID,
        totalQuantity: item.totalQuantity,
        totalRevenue: item.totalRevenue,
        totalOrders: item.totalOrders,
      ),
    )
        .toList()
      ..sort((a, b) {
        final byQuantity = b.totalQuantity.compareTo(a.totalQuantity);
        if (byQuantity != 0) return byQuantity;

        final byRevenue = b.totalRevenue.compareTo(a.totalRevenue);
        if (byRevenue != 0) return byRevenue;

        return a.productID.compareTo(b.productID);
      });

    _producerSalesStats = ProducerSalesStats(
      totalOrders: totalOrders,
      pendingOrders: pendingOrders,
      acceptedOrders: preparingOrders,
      shippedOrders: shippedOrders,
      completedOrders: completedOrders,
      cancelledOrders: cancelledOrders,
      managedAmount: managedAmount,
      deliveredRevenue: deliveredRevenue,
      averageTicket: averageTicket,
      topProducts: topProducts.take(topLimit).toList(),
    );

    if (notifyAtEnd) {
      notifyListeners();
    }
  }

  double _calculateAverageCompletedTicket(List<OrderModel> orders) {
    final completed = orders
        .where((order) => order.state == stateCompleted)
        .toList();

    if (completed.isEmpty) return 0.0;

    final total = completed.fold<double>(
      0.0,
          (sum, order) => sum + order.amount,
    );

    return total / completed.length;
  }

  bool _isValidOrderState(int state) {
    return state >= statePending && state <= stateCancelled;
  }

  OrderModel? _findKnownOrderById(int orderID) {
    for (final order in _producerOrders) {
      if (order.id == orderID) return order;
    }

    for (final order in _clientOrders) {
      if (order.id == orderID) return order;
    }

    return null;
  }

  bool _isTransitionAllowed(int currentState, int nextState) {
    if (currentState == nextState) return true;
    return _getAllowedNextStates(currentState).contains(nextState);
  }

  List<int> _getAllowedNextStates(int currentState) {
    switch (currentState) {
      case statePending:
        return [statePreparing, stateCancelled];
      case statePreparing:
        return [stateShipped, stateCancelled];
      case stateShipped:
        return [stateCompleted, stateCancelled];
      case stateCompleted:
      case stateCancelled:
        return [];
      default:
        return [];
    }
  }

  String _getStateText(int state) {
    switch (state) {
      case statePending:
        return 'Pendiente';
      case statePreparing:
        return 'En preparación';
      case stateShipped:
        return 'Enviado';
      case stateCompleted:
        return 'Completado';
      case stateCancelled:
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  void _clearProducerSalesStatsInternal() {
    _producerSalesStats = const ProducerSalesStats.empty();
    _lastStatsProducerId = null;
    _lastTopProductsLimit = 5;
  }
}

class ProducerSalesStats {
  final int totalOrders;
  final int pendingOrders;

  /// Se mantiene este nombre por compatibilidad con vistas ya creadas.
  /// Ahora representa "En preparación".
  final int acceptedOrders;

  final int shippedOrders;
  final int completedOrders;
  final int cancelledOrders;

  final double managedAmount;
  final double deliveredRevenue;
  final double averageTicket;

  final List<TopSellingProductStat> topProducts;

  const ProducerSalesStats({
    required this.totalOrders,
    required this.pendingOrders,
    required this.acceptedOrders,
    required this.shippedOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.managedAmount,
    required this.deliveredRevenue,
    required this.averageTicket,
    required this.topProducts,
  });

  const ProducerSalesStats.empty()
      : totalOrders = 0,
        pendingOrders = 0,
        acceptedOrders = 0,
        shippedOrders = 0,
        completedOrders = 0,
        cancelledOrders = 0,
        managedAmount = 0.0,
        deliveredRevenue = 0.0,
        averageTicket = 0.0,
        topProducts = const [];

  ProducerSalesStats copyWith({
    int? totalOrders,
    int? pendingOrders,
    int? acceptedOrders,
    int? shippedOrders,
    int? completedOrders,
    int? cancelledOrders,
    double? managedAmount,
    double? deliveredRevenue,
    double? averageTicket,
    List<TopSellingProductStat>? topProducts,
  }) {
    return ProducerSalesStats(
      totalOrders: totalOrders ?? this.totalOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      acceptedOrders: acceptedOrders ?? this.acceptedOrders,
      shippedOrders: shippedOrders ?? this.shippedOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      managedAmount: managedAmount ?? this.managedAmount,
      deliveredRevenue: deliveredRevenue ?? this.deliveredRevenue,
      averageTicket: averageTicket ?? this.averageTicket,
      topProducts: topProducts ?? this.topProducts,
    );
  }
}

class TopSellingProductStat {
  final int productID;
  final int totalQuantity;
  final double totalRevenue;
  final int totalOrders;

  const TopSellingProductStat({
    required this.productID,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.totalOrders,
  });
}

class _TopSellingAccumulator {
  final int productID;
  int totalQuantity;
  double totalRevenue;
  int totalOrders;

  _TopSellingAccumulator({
    required this.productID,
    this.totalQuantity = 0,
    this.totalRevenue = 0.0,
    this.totalOrders = 0,
  });
}