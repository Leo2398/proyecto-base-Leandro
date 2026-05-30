import 'dart:async';
import 'package:flutter/material.dart';
import '../models/request_model.dart';
import '../models/app_config_model.dart';
import '../services/request_service.dart';
import '../services/user_service.dart';

/// Maneja la lógica de recargas de monedas
/// Incluye polling para detectar cuando el admin aprueba/rechaza
class RequestController extends ChangeNotifier {
  final RequestService _requestService = RequestService();
  final UserService _userService = UserService();

  AppConfigModel _config = AppConfigModel.defaults;
  List<RequestModel> _userRequests = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // ── Polling ────────────────────────────────────────────────────────────────
  Timer? _pollingTimer;
  int? _watchingRequestId; // ID del request que estamos vigilando
  int? _watchingUserId; // ID del usuario actual
  int _lastKnownState = 0; // último estado conocido del request vigilado

  // ── Notificación in-app ────────────────────────────────────────────────────
  /// Se llama cuando el admin aprueba o rechaza la solicitud
  /// La UI escucha esto para mostrar el banner/dialog
  void Function(RequestModel)? onRequestStatusChanged;

  // ── Getters ────────────────────────────────────────────────────────────────
  AppConfigModel get config => _config;
  List<RequestModel> get userRequests => _userRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // ── Config ─────────────────────────────────────────────────────────────────

  Future<void> loadConfig() async {
    try {
      _config = await _requestService.getAppConfig();
      notifyListeners();
    } catch (e) {
      print('Error cargando config: $e');
    }
  }

  // ── Requests del usuario ───────────────────────────────────────────────────

  Future<void> loadUserRequests(int userID) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _userRequests = await _requestService.getRequestsByUser(userID);
    } catch (e) {
      _errorMessage = 'Error cargando solicitudes';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea el request en la BD y arranca el polling
  Future<bool> submitRequest({
    required int userID,
    required int coins,
    required double amount,
    required String imageUrl,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();

      final request = RequestModel(
        value: coins,
        amount: amount,
        image: imageUrl,
        userID: userID,
      );

      final success = await _requestService.createRequest(request);

      if (!success) {
        _errorMessage = 'Error al enviar la solicitud';
        return false;
      }

      _successMessage = 'Solicitud enviada correctamente';

      // Recarga la lista y arranca polling
      await loadUserRequests(userID);

      // Busca el request recién creado (el más reciente pendiente)
      final created = await _requestService.getLatestPendingRequest(userID);
      if (created?.id != null) {
        startPolling(requestId: created!.id!, userId: userID);
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error al enviar solicitud: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  /// Arranca el polling cada 15 segundos para vigilar el request
  void startPolling({required int requestId, required int userId}) {
    stopPolling();

    _watchingRequestId = requestId;
    _watchingUserId = userId;
    _lastKnownState = 0;

    print('🔄 Polling iniciado para request #$requestId');

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 15),
          (_) => _checkRequestStatus(),
    );
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _watchingRequestId = null;
    _watchingUserId = null;
    _lastKnownState = 0;
  }

  Future<void> _checkRequestStatus() async {
    if (_watchingRequestId == null || _watchingUserId == null) return;

    try {
      final request = await _requestService.getRequestById(_watchingRequestId!);

      if (request == null) return;

      // Si el estado cambió de 0 a 1 o 2 → notifica
      if (request.state != _lastKnownState && request.state != 0) {
        _lastKnownState = request.state;
        print('✓ Estado del request cambió a ${request.stateLabel}');

        // IMPORTANTE:
        // Ya NO se actualiza el balance aquí.
        // El balance se suma en RequestService.approveRequest().
        // Si lo sumamos aquí también, se duplica la recarga.

        // Recarga lista del usuario
        await loadUserRequests(_watchingUserId!);

        // Refresca datos del usuario si hace falta que la UI tome el nuevo balance
        // desde la BD por su flujo normal
        try {
          await _userService.getUserById(_watchingUserId!);
        } catch (_) {}

        // Notifica a la UI
        onRequestStatusChanged?.call(request);

        // Detiene el polling: el request ya fue resuelto
        stopPolling();
      }
    } catch (e) {
      print('Error en polling: $e');
    }
  }

  /// Retoma el polling si hay un request pendiente al volver a la app
  Future<void> resumePollingIfNeeded(int userId) async {
    try {
      final pending = await _requestService.getLatestPendingRequest(userId);
      if (pending?.id != null) {
        startPolling(requestId: pending!.id!, userId: userId);
      }
    } catch (e) {
      print('Error reanudando polling: $e');
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}