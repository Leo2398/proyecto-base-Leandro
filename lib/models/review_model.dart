class ReviewModel {
  final int? id;
  final int value;
  final String? comment;
  final int orderId;
  final int userId;

  const ReviewModel({
    this.id,
    required this.value,
    this.comment,
    required this.orderId,
    required this.userId,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: _toInt(map['ID'] ?? map['id']),
      value: _toInt(map['value']) ?? 0,
      comment: _toNullableString(map['comment']),
      orderId: _toInt(map['OrderID'] ?? map['orderId']) ?? 0,
      userId: _toInt(map['UserID'] ?? map['userId']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'value': value,
      'comment': comment,
      'OrderID': orderId,
      'UserID': userId,
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'value': value,
      'comment': comment,
      'OrderID': orderId,
      'UserID': userId,
    };
  }

  ReviewModel copyWith({
    int? id,
    int? value,
    String? comment,
    int? orderId,
    int? userId,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      value: value ?? this.value,
      comment: comment ?? this.comment,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
    );
  }

  bool get hasComment => comment != null && comment!.trim().isNotEmpty;

  bool get isValidValue => value >= 1 && value <= 5;

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  String toString() {
    return 'ReviewModel(id: $id, value: $value, comment: $comment, orderId: $orderId, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ReviewModel &&
        other.id == id &&
        other.value == value &&
        other.comment == comment &&
        other.orderId == orderId &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    value.hashCode ^
    comment.hashCode ^
    orderId.hashCode ^
    userId.hashCode;
  }
}