class OrderModel {
  final int? id;
  final double amount;
  final DateTime? registerDate;
  final int state;
  final int pickupLocationID;
  final int clientID;
  final int producerID;

  OrderModel({
    this.id,
    required this.amount,
    this.registerDate,
    required this.state,
    required this.pickupLocationID,
    required this.clientID,
    required this.producerID,
  });

  OrderModel copyWith({
    int? id,
    double? amount,
    DateTime? registerDate,
    int? state,
    int? pickupLocationID,
    int? clientID,
    int? producerID,
  }) {
    return OrderModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      registerDate: registerDate ?? this.registerDate,
      state: state ?? this.state,
      pickupLocationID: pickupLocationID ?? this.pickupLocationID,
      clientID: clientID ?? this.clientID,
      producerID: producerID ?? this.producerID,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: _toInt(map['UniqueID'] ?? map['id'] ?? map['orderID']),
      amount: _toDouble(map['amount']),
      registerDate: _toDateTime(map['registerDate']),
      state: _toInt(map['state']),
      pickupLocationID: _toInt(map['pickupLocationID']),
      clientID: _toInt(map['ClientID'] ?? map['clientID']),
      producerID: _toInt(map['ProducerID'] ?? map['producerID']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'UniqueID': id,
      'amount': amount,
      'registerDate': registerDate?.toIso8601String(),
      'state': state,
      'pickupLocationID': pickupLocationID,
      'ClientID': clientID,
      'ProducerID': producerID,
    };
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}