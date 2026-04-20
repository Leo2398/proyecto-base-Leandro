import 'dart:convert';

class NotificationModel {
  final int? id;
  final int userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  NotificationModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap({bool forDatabase = false}) {
    if (forDatabase) {
      return {
        'ID': id,
        'UserID': userId,
        'Title': title,
        'Message': message,
        'Type': type,
        'IsRead': isRead ? 1 : 0,
        'CreatedAt': createdAt.toIso8601String(),
      };
    }

    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: _toInt(map['id'] ?? map['ID']),
      userId: _toInt(map['userId'] ?? map['UserID']) ?? 0,
      title: (map['title'] ?? map['Title'] ?? '').toString(),
      message: (map['message'] ?? map['Message'] ?? '').toString(),
      type: (map['type'] ?? map['Type'] ?? '').toString(),
      isRead: _toBool(map['isRead'] ?? map['IsRead']),
      createdAt:
      _parseDateTime(map['createdAt'] ?? map['CreatedAt']) ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory NotificationModel.fromJson(String source) =>
      NotificationModel.fromMap(json.decode(source) as Map<String, dynamic>);

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' ||
          normalized == 'true' ||
          normalized == 'yes' ||
          normalized == 'si';
    }
    return false;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  String toString() {
    return 'NotificationModel('
        'id: $id, '
        'userId: $userId, '
        'title: $title, '
        'message: $message, '
        'type: $type, '
        'isRead: $isRead, '
        'createdAt: $createdAt'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NotificationModel &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.message == message &&
        other.type == type &&
        other.isRead == isRead &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      title,
      message,
      type,
      isRead,
      createdAt,
    );
  }
}