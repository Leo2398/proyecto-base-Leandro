import 'package:flutter/foundation.dart';

import '../models/coin_movement_model.dart';
import '../services/interfaces/i_coin_movement_service.dart';

/// Controller para manejar el saldo e historial de monedas del productor.
///
/// Responsabilidades:
/// - cargar saldo actual desde User.balance
/// - cargar historial de solicitudes de recarga desde Request
/// - solicitar recarga de monedas
/// - descontar monedas por uso/publicación
///
/// Sigue el patrón de tu proyecto:
/// Controller + Service + Provider/ChangeNotifier
class CoinMovementController extends ChangeNotifier {
  /// Servicio abstracto de movimientos de monedas
  final ICoinMovementService _coinMovementService;

  CoinMovementController({
    required ICoinMovementService coinMovementService,
  }) : _coinMovementService = coinMovementService;

  /// ID del usuario actualmente cargado en el controller
  int? _currentUserId;

  /// Saldo actual del productor
  double _balance = 0.0;

  /// Historial de movimientos
  List<CoinMovementModel> _movements = [];

  /// Estados de carga
  bool _isLoading = false;
  bool _isLoadingBalance = false;
  bool _isLoadingMovements = false;
  bool _isRequestingRecharge = false;
  bool _isProcessingUsage = false;

  /// Mensaje de error para mostrar en UI
  String? _errorMessage;

  /// =========================
  /// Getters públicos
  /// =========================

  int? get currentUserId => _currentUserId;

  double get balance => _balance;

  List<CoinMovementModel> get movements => List.unmodifiable(_movements);

  bool get isLoading => _isLoading;

  bool get isLoadingBalance => _isLoadingBalance;

  bool get isLoadingMovements => _isLoadingMovements;

  bool get isRequestingRecharge => _isRequestingRecharge;

  bool get isProcessingUsage => _isProcessingUsage;

  String? get errorMessage => _errorMessage;

  bool get hasError => _errorMessage != null && _errorMessage!.trim().isNotEmpty;

  bool get hasMovements => _movements.isNotEmpty;

  bool get isBusy =>
      _isLoading ||
          _isLoadingBalance ||
          _isLoadingMovements ||
          _isRequestingRecharge ||
          _isProcessingUsage;

  /// Regla del proyecto:
  /// 1 moneda = 100
  double get balanceInMoney => _balance * 100.0;

  /// =========================
  /// Métodos de control de estado
  /// =========================

  /// Limpia el mensaje de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpia los datos cargados en memoria
  void clearData() {
    _currentUserId = null;
    _balance = 0.0;
    _movements = [];
    _isLoading = false;
    _isLoadingBalance = false;
    _isLoadingMovements = false;
    _isRequestingRecharge = false;
    _isProcessingUsage = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Verifica si el saldo actual alcanza para una acción
  bool hasEnoughBalance(double amount) {
    if (amount <= 0) return true;
    return _balance >= amount;
  }

  /// =========================
  /// Carga inicial
  /// =========================

  /// Carga saldo + historial del usuario
  Future<void> loadCoinData(int userId) async {
    try {
      if (userId <= 0) {
        _errorMessage = 'ID de usuario inválido.';
        notifyListeners();
        return;
      }

      _currentUserId = userId;
      _errorMessage = null;
      _isLoading = true;
      notifyListeners();

      final loadedBalance =
      await _coinMovementService.getUserCoinBalance(userId);
      final loadedMovements =
      await _coinMovementService.getMovementsByUserId(userId);

      _balance = loadedBalance;
      _movements = loadedMovements;
    } catch (e) {
      _errorMessage = 'No se pudo cargar la información de monedas.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recarga nuevamente el saldo e historial del usuario actual
  Future<void> refresh() async {
    if (_currentUserId == null || _currentUserId! <= 0) {
      _errorMessage = 'No hay un usuario cargado.';
      notifyListeners();
      return;
    }

    await loadCoinData(_currentUserId!);
  }

  /// =========================
  /// Saldo
  /// =========================

  /// Carga solo el saldo del usuario
  Future<void> loadBalance([int? userId]) async {
    try {
      final targetUserId = userId ?? _currentUserId;

      if (targetUserId == null || targetUserId <= 0) {
        _errorMessage = 'ID de usuario inválido para cargar saldo.';
        notifyListeners();
        return;
      }

      _currentUserId = targetUserId;
      _errorMessage = null;
      _isLoadingBalance = true;
      notifyListeners();

      _balance = await _coinMovementService.getUserCoinBalance(targetUserId);
    } catch (e) {
      _errorMessage = 'No se pudo cargar el saldo de monedas.';
    } finally {
      _isLoadingBalance = false;
      notifyListeners();
    }
  }

  /// =========================
  /// Historial
  /// =========================

  /// Carga el historial completo del usuario
  Future<void> loadMovements([int? userId]) async {
    try {
      final targetUserId = userId ?? _currentUserId;

      if (targetUserId == null || targetUserId <= 0) {
        _errorMessage = 'ID de usuario inválido para cargar historial.';
        notifyListeners();
        return;
      }

      _currentUserId = targetUserId;
      _errorMessage = null;
      _isLoadingMovements = true;
      notifyListeners();

      _movements = await _coinMovementService.getMovementsByUserId(
        targetUserId,
      );
    } catch (e) {
      _errorMessage = 'No se pudo cargar el historial de monedas.';
    } finally {
      _isLoadingMovements = false;
      notifyListeners();
    }
  }

  /// Carga una cantidad limitada de movimientos recientes
  Future<void> loadRecentMovements({
    int? userId,
    int limit = 10,
  }) async {
    try {
      final targetUserId = userId ?? _currentUserId;

      if (targetUserId == null || targetUserId <= 0) {
        _errorMessage = 'ID de usuario inválido para cargar historial.';
        notifyListeners();
        return;
      }

      _currentUserId = targetUserId;
      _errorMessage = null;
      _isLoadingMovements = true;
      notifyListeners();

      _movements = await _coinMovementService.getRecentMovementsByUserId(
        targetUserId,
        limit: limit,
      );
    } catch (e) {
      _errorMessage = 'No se pudo cargar el historial reciente.';
    } finally {
      _isLoadingMovements = false;
      notifyListeners();
    }
  }

  /// =========================
  /// Solicitud de recarga
  /// =========================

  /// Solicita una recarga de monedas.
  ///
  /// En la BD actual esto crea una solicitud en Request.
  /// No suma saldo automáticamente hasta aprobación del admin.
  Future<bool> requestRecharge({
    required int userId,
    required double amount,
    String? description,
  }) async {
    try {
      if (userId <= 0) {
        _errorMessage = 'Usuario inválido.';
        notifyListeners();
        return false;
      }

      if (amount <= 0) {
        _errorMessage = 'La cantidad de monedas debe ser mayor a 0.';
        notifyListeners();
        return false;
      }

      /// En tu BD actual Request.value es entero
      if (!_isWholeNumber(amount)) {
        _errorMessage = 'La cantidad de monedas debe ser un número entero.';
        notifyListeners();
        return false;
      }

      _currentUserId = userId;
      _errorMessage = null;
      _isRequestingRecharge = true;
      notifyListeners();

      final success = await _coinMovementService.registerRecharge(
        userId: userId,
        amount: amount,
        description: description,
      );

      if (!success) {
        _errorMessage = 'No se pudo registrar la solicitud de recarga.';
        return false;
      }

      await loadCoinData(userId);
      return true;
    } catch (e) {
      _errorMessage = 'Ocurrió un error al solicitar la recarga.';
      return false;
    } finally {
      _isRequestingRecharge = false;
      notifyListeners();
    }
  }

  /// =========================
  /// Uso de monedas
  /// =========================

  /// Descuenta monedas del saldo del productor.
  ///
  /// En la BD actual esto solo descuenta de User.balance.
  /// No existe una tabla extra para historial de consumo.
  Future<bool> useCoins({
    required int userId,
    required double amount,
    String? description,
  }) async {
    try {
      if (userId <= 0) {
        _errorMessage = 'Usuario inválido.';
        notifyListeners();
        return false;
      }

      if (amount <= 0) {
        _errorMessage = 'La cantidad de monedas a usar debe ser mayor a 0.';
        notifyListeners();
        return false;
      }

      _currentUserId = userId;
      _errorMessage = null;
      _isProcessingUsage = true;
      notifyListeners();

      /// Validación rápida antes de golpear la BD
      final currentBalance = await _coinMovementService.getUserCoinBalance(
        userId,
      );

      _balance = currentBalance;

      if (currentBalance < amount) {
        _errorMessage = 'No tienes monedas suficientes.';
        return false;
      }

      final success = await _coinMovementService.registerUsage(
        userId: userId,
        amount: amount,
        description: description,
      );

      if (!success) {
        _errorMessage = 'No se pudo descontar las monedas.';
        return false;
      }

      await loadBalance(userId);
      return true;
    } catch (e) {
      _errorMessage = 'Ocurrió un error al usar monedas.';
      return false;
    } finally {
      _isProcessingUsage = false;
      notifyListeners();
    }
  }

  /// Método de apoyo para publicación de productos
  Future<bool> useCoinsForProductPublication({
    required int userId,
    required double amount,
    String? productName,
  }) async {
    final description = (productName != null && productName.trim().isNotEmpty)
        ? 'Publicación de producto: ${productName.trim()}'
        : 'Publicación de producto';

    return await useCoins(
      userId: userId,
      amount: amount,
      description: description,
    );
  }

  /// =========================
  /// Utilidades privadas
  /// =========================

  bool _isWholeNumber(double value) {
    return value == value.toInt().toDouble();
  }
}