import 'package:mysql_client/mysql_client.dart';

import '../core/db_connection.dart';
import '../models/notification_model.dart';

class NotificationService {
  final DBConnection _db = DBConnection.instance;

  int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  String _normalizeType(String? value) {
    final type = (value ?? '').trim();
    return type.isEmpty ? 'general' : type;
  }

  List<NotificationModel> _mapRowsToNotifications(IResultSet result) {
    return result.rows
        .map((row) => NotificationModel.fromMap(row.assoc()))
        .toList();
  }

  Future<List<NotificationModel>> getNotificationsByUser(
      int userId, {
        int limit = 50,
      }) async {
    try {
      final MySQLConnection conn = await _db.getConnection();
      final int safeLimit = limit <= 0 ? 50 : limit;

      final result = await conn.execute(
        '''
        SELECT
          ID,
          UserID,
          Title,
          Message,
          Type,
          IsRead,
          CreatedAt
        FROM `Notification`
        WHERE UserID = :userId
        ORDER BY CreatedAt DESC, ID DESC
        LIMIT $safeLimit
        ''',
        {
          'userId': userId,
        },
      );

      return _mapRowsToNotifications(result);
    } catch (e) {
      print('Error en getNotificationsByUser: $e');
      return [];
    }
  }

  Future<List<NotificationModel>> getUnreadNotifications(
      int userId, {
        int limit = 50,
      }) async {
    try {
      final MySQLConnection conn = await _db.getConnection();
      final int safeLimit = limit <= 0 ? 50 : limit;

      final result = await conn.execute(
        '''
        SELECT
          ID,
          UserID,
          Title,
          Message,
          Type,
          IsRead,
          CreatedAt
        FROM `Notification`
        WHERE UserID = :userId
          AND IsRead = 0
        ORDER BY CreatedAt DESC, ID DESC
        LIMIT $safeLimit
        ''',
        {
          'userId': userId,
        },
      );

      return _mapRowsToNotifications(result);
    } catch (e) {
      print('Error en getUnreadNotifications: $e');
      return [];
    }
  }

  Future<List<NotificationModel>> getNotificationsAfterId({
    required int userId,
    required int lastNotificationId,
  }) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT
          ID,
          UserID,
          Title,
          Message,
          Type,
          IsRead,
          CreatedAt
        FROM `Notification`
        WHERE UserID = :userId
          AND ID > :lastNotificationId
        ORDER BY ID DESC
        ''',
        {
          'userId': userId,
          'lastNotificationId': lastNotificationId,
        },
      );

      return _mapRowsToNotifications(result);
    } catch (e) {
      print('Error en getNotificationsAfterId: $e');
      return [];
    }
  }

  Future<NotificationModel?> getNotificationById(int notificationId) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT
          ID,
          UserID,
          Title,
          Message,
          Type,
          IsRead,
          CreatedAt
        FROM `Notification`
        WHERE ID = :notificationId
        LIMIT 1
        ''',
        {
          'notificationId': notificationId,
        },
      );

      if (result.rows.isEmpty) {
        return null;
      }

      return NotificationModel.fromMap(result.rows.first.assoc());
    } catch (e) {
      print('Error en getNotificationById: $e');
      return null;
    }
  }

  Future<int> getUnreadCount(int userId) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT COUNT(*) AS Total
        FROM `Notification`
        WHERE UserID = :userId
          AND IsRead = 0
        ''',
        {
          'userId': userId,
        },
      );

      if (result.rows.isEmpty) {
        return 0;
      }

      final row = result.rows.first.assoc();
      return _parseInt(row['Total']);
    } catch (e) {
      print('Error en getUnreadCount: $e');
      return 0;
    }
  }

  Future<int?> getLatestNotificationId(int userId) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT ID
        FROM `Notification`
        WHERE UserID = :userId
        ORDER BY ID DESC
        LIMIT 1
        ''',
        {
          'userId': userId,
        },
      );

      if (result.rows.isEmpty) {
        return null;
      }

      final row = result.rows.first.assoc();
      final int latestId = _parseInt(row['ID']);

      return latestId > 0 ? latestId : null;
    } catch (e) {
      print('Error en getLatestNotificationId: $e');
      return null;
    }
  }

  Future<NotificationModel?> createNotification({
    required int userId,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      final String cleanTitle = title.trim();
      final String cleanMessage = message.trim();
      final String cleanType = _normalizeType(type);

      if (userId <= 0) {
        print('Error en createNotification: userId inválido.');
        return null;
      }

      if (cleanTitle.isEmpty) {
        print('Error en createNotification: title vacío.');
        return null;
      }

      if (cleanMessage.isEmpty) {
        print('Error en createNotification: message vacío.');
        return null;
      }

      final DateTime now = DateTime.now();

      await conn.execute(
        '''
        INSERT INTO `Notification` (
          UserID,
          Title,
          Message,
          Type,
          IsRead,
          CreatedAt
        )
        VALUES (
          :userId,
          :title,
          :message,
          :type,
          :isRead,
          :createdAt
        )
        ''',
        {
          'userId': userId,
          'title': cleanTitle,
          'message': cleanMessage,
          'type': cleanType,
          'isRead': 0,
          'createdAt': now.toIso8601String(),
        },
      );

      final idResult = await conn.execute(
        'SELECT LAST_INSERT_ID() AS id',
      );

      int? newId;
      if (idResult.rows.isNotEmpty) {
        newId = _parseInt(idResult.rows.first.assoc()['id']);
        if (newId <= 0) {
          newId = null;
        }
      }

      return NotificationModel(
        id: newId,
        userId: userId,
        title: cleanTitle,
        message: cleanMessage,
        type: cleanType,
        isRead: false,
        createdAt: now,
      );
    } catch (e) {
      print('Error en createNotification: $e');
      return null;
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        UPDATE `Notification`
        SET IsRead = 1
        WHERE ID = :notificationId
        ''',
        {
          'notificationId': notificationId,
        },
      );

      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error en markAsRead: $e');
      return false;
    }
  }

  Future<bool> markAsUnread(int notificationId) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        UPDATE `Notification`
        SET IsRead = 0
        WHERE ID = :notificationId
        ''',
        {
          'notificationId': notificationId,
        },
      );

      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error en markAsUnread: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead(int userId) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      await conn.execute(
        '''
        UPDATE `Notification`
        SET IsRead = 1
        WHERE UserID = :userId
          AND IsRead = 0
        ''',
        {
          'userId': userId,
        },
      );

      return true;
    } catch (e) {
      print('Error en markAllAsRead: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(int notificationId) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        DELETE FROM `Notification`
        WHERE ID = :notificationId
        ''',
        {
          'notificationId': notificationId,
        },
      );

      return result.affectedRows.toInt() > 0;
    } catch (e) {
      print('Error en deleteNotification: $e');
      return false;
    }
  }

  Future<bool> deleteAllNotificationsByUser(int userId) async {
    try {
      final MySQLConnection conn = await _db.getConnection();

      await conn.execute(
        '''
        DELETE FROM `Notification`
        WHERE UserID = :userId
        ''',
        {
          'userId': userId,
        },
      );

      return true;
    } catch (e) {
      print('Error en deleteAllNotificationsByUser: $e');
      return false;
    }
  }
}