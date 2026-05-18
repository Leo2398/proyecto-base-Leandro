import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationController extends ChangeNotifier {
  final NotificationService _notificationService;

  NotificationController({NotificationService? notificationService})
      : _notificationService = notificationService ?? NotificationService();

  int? _currentUserId;
  List<NotificationModel> _notifications = [];

  bool _isLoading = false;
  bool _isPolling = false;
  bool _isCheckingNewNotifications = false;

  String? _errorMessage;

  int _unreadCount = 0;
  int? _lastNotificationId;

  Timer? _pollingTimer;

  /// Callback opcional para que la UI muestre banner, snack o diálogo
  void Function(NotificationModel notification)? onNewNotification;

  int? get currentUserId => _currentUserId;

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);

  bool get isLoading => _isLoading;

  bool get isPolling => _isPolling;

  String? get errorMessage => _errorMessage;

  int get unreadCount => _unreadCount;

  bool get hasNotifications => _notifications.isNotEmpty;

  bool get hasUnreadNotifications => _unreadCount > 0;

  NotificationModel? get latestNotification =>
      _notifications.isNotEmpty ? _notifications.first : null;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearData() {
    _currentUserId = null;
    _notifications = [];
    _isLoading = false;
    _isPolling = false;
    _isCheckingNewNotifications = false;
    _errorMessage = null;
    _unreadCount = 0;
    _lastNotificationId = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    notifyListeners();
  }

  Future<void> loadNotifications(
      int userId, {
        int limit = 50,
      }) async {
    try {
      if (userId <= 0) {
        _errorMessage = 'ID de usuario inválido.';
        notifyListeners();
        return;
      }

      _currentUserId = userId;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final loadedNotifications = await _notificationService.getNotificationsByUser(
        userId,
        limit: limit,
      );

      final loadedUnreadCount = await _notificationService.getUnreadCount(userId);
      final latestId = await _notificationService.getLatestNotificationId(userId);

      _notifications = loadedNotifications;
      _unreadCount = loadedUnreadCount;
      _lastNotificationId = latestId;
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las notificaciones.';
      print('Error en loadNotifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({int? userId, int limit = 50}) async {
    final targetUserId = userId ?? _currentUserId;

    if (targetUserId == null || targetUserId <= 0) {
      _errorMessage = 'No hay un usuario válido para refrescar notificaciones.';
      notifyListeners();
      return;
    }

    await loadNotifications(targetUserId, limit: limit);
  }

  Future<void> loadUnreadNotifications({
    int? userId,
    int limit = 50,
  }) async {
    try {
      final targetUserId = userId ?? _currentUserId;

      if (targetUserId == null || targetUserId <= 0) {
        _errorMessage = 'ID de usuario inválido.';
        notifyListeners();
        return;
      }

      _currentUserId = targetUserId;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final loadedNotifications =
      await _notificationService.getUnreadNotifications(
        targetUserId,
        limit: limit,
      );

      _notifications = loadedNotifications;
      _unreadCount = loadedNotifications.length;
      _lastNotificationId =
      await _notificationService.getLatestNotificationId(targetUserId);
    } catch (e) {
      _errorMessage = 'No se pudieron cargar las notificaciones no leídas.';
      print('Error en loadUnreadNotifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> loadUnreadCount([int? userId]) async {
    try {
      final targetUserId = userId ?? _currentUserId;

      if (targetUserId == null || targetUserId <= 0) {
        _errorMessage = 'ID de usuario inválido.';
        notifyListeners();
        return 0;
      }

      _currentUserId = targetUserId;
      _errorMessage = null;

      _unreadCount = await _notificationService.getUnreadCount(targetUserId);
      notifyListeners();

      return _unreadCount;
    } catch (e) {
      _errorMessage = 'No se pudo cargar la cantidad de no leídas.';
      print('Error en loadUnreadCount: $e');
      notifyListeners();
      return 0;
    }
  }

  Future<bool> createNotification({
    required int userId,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    try {
      _errorMessage = null;
      notifyListeners();

      final notification = await _notificationService.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
      );

      if (notification == null) {
        _errorMessage = 'No se pudo crear la notificación.';
        notifyListeners();
        return false;
      }

      if (_currentUserId == userId) {
        final exists = _notifications.any((n) => n.id == notification.id);

        if (!exists) {
          _notifications.insert(0, notification);
          if (!notification.isRead) {
            _unreadCount++;
          }
        }

        if (notification.id != null) {
          if (_lastNotificationId == null ||
              notification.id! > _lastNotificationId!) {
            _lastNotificationId = notification.id;
          }
        }

        notifyListeners();
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error creando notificación: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      _errorMessage = null;

      final success = await _notificationService.markAsRead(notificationId);

      if (!success) {
        _errorMessage = 'No se pudo marcar la notificación como leída.';
        notifyListeners();
        return false;
      }

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        if (_unreadCount > 0) {
          _unreadCount--;
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error marcando notificación como leída: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAsUnread(int notificationId) async {
    try {
      _errorMessage = null;

      final success = await _notificationService.markAsUnread(notificationId);

      if (!success) {
        _errorMessage = 'No se pudo marcar la notificación como no leída.';
        notifyListeners();
        return false;
      }

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && _notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: false);
        _unreadCount++;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error marcando notificación como no leída: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAllAsRead([int? userId]) async {
    try {
      final targetUserId = userId ?? _currentUserId;

      if (targetUserId == null || targetUserId <= 0) {
        _errorMessage = 'ID de usuario inválido.';
        notifyListeners();
        return false;
      }

      _errorMessage = null;

      final success = await _notificationService.markAllAsRead(targetUserId);

      if (!success) {
        _errorMessage = 'No se pudieron marcar todas como leídas.';
        notifyListeners();
        return false;
      }

      _notifications = _notifications
          .map((notification) => notification.copyWith(isRead: true))
          .toList();

      _unreadCount = 0;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error marcando todas las notificaciones como leídas: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteNotification(int notificationId) async {
    try {
      _errorMessage = null;

      final success =
      await _notificationService.deleteNotification(notificationId);

      if (!success) {
        _errorMessage = 'No se pudo eliminar la notificación.';
        notifyListeners();
        return false;
      }

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final removed = _notifications[index];
        _notifications.removeAt(index);

        if (!removed.isRead && _unreadCount > 0) {
          _unreadCount--;
        }
      }

      if (_currentUserId != null) {
        _lastNotificationId =
        await _notificationService.getLatestNotificationId(_currentUserId!);
      } else {
        _lastNotificationId = null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error eliminando notificación: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAllNotificationsByUser([int? userId]) async {
    try {
      final targetUserId = userId ?? _currentUserId;

      if (targetUserId == null || targetUserId <= 0) {
        _errorMessage = 'ID de usuario inválido.';
        notifyListeners();
        return false;
      }

      _errorMessage = null;

      final success =
      await _notificationService.deleteAllNotificationsByUser(targetUserId);

      if (!success) {
        _errorMessage = 'No se pudieron eliminar las notificaciones.';
        notifyListeners();
        return false;
      }

      _notifications = [];
      _unreadCount = 0;
      _lastNotificationId = null;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error eliminando todas las notificaciones: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> startPolling({
    required int userId,
    Duration interval = const Duration(seconds: 8),
    bool loadImmediately = true,
  }) async {
    if (userId <= 0) {
      _errorMessage = 'ID de usuario inválido para iniciar polling.';
      notifyListeners();
      return;
    }

    stopPolling();

    _currentUserId = userId;
    _isPolling = true;
    _errorMessage = null;

    if (loadImmediately) {
      await loadNotifications(userId);
    } else {
      _lastNotificationId =
      await _notificationService.getLatestNotificationId(userId);
      notifyListeners();
    }

    _pollingTimer = Timer.periodic(interval, (_) async {
      await _checkForNewNotifications();
    });

    notifyListeners();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _isCheckingNewNotifications = false;
    notifyListeners();
  }

  Future<void> _checkForNewNotifications() async {
    if (_currentUserId == null || _currentUserId! <= 0) return;
    if (_isCheckingNewNotifications) return;

    _isCheckingNewNotifications = true;

    try {
      if (_lastNotificationId == null) {
        _lastNotificationId = await _notificationService.getLatestNotificationId(
          _currentUserId!,
        );
        return;
      }

      final newNotifications = await _notificationService.getNotificationsAfterId(
        userId: _currentUserId!,
        lastNotificationId: _lastNotificationId!,
      );

      if (newNotifications.isEmpty) {
        return;
      }

      final sortedNotifications = [...newNotifications]
        ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));

      int maxId = _lastNotificationId ?? 0;
      bool changed = false;

      for (final notification in sortedNotifications) {
        final exists = _notifications.any((n) => n.id == notification.id);
        if (exists) continue;

        _notifications.insert(0, notification);

        if (!notification.isRead) {
          _unreadCount++;
        }

        if ((notification.id ?? 0) > maxId) {
          maxId = notification.id ?? maxId;
        }

        onNewNotification?.call(notification);
        changed = true;
      }

      _lastNotificationId = maxId > 0 ? maxId : _lastNotificationId;

      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      print('Error en polling de notificaciones: $e');
    } finally {
      _isCheckingNewNotifications = false;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}