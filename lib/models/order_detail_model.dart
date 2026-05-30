class OrderDetailModel {
  final int orderID;
  final int productID;
  final int quantity;
  final double unitPrice;

  OrderDetailModel({
    required this.orderID,
    required this.productID,
    required this.quantity,
    required this.unitPrice,
  });

  OrderDetailModel copyWith({
    int? orderID,
    int? productID,
    int? quantity,
    double? unitPrice,
  }) {
    return OrderDetailModel(
      orderID: orderID ?? this.orderID,
      productID: productID ?? this.productID,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  factory OrderDetailModel.fromMap(Map<String, dynamic> map) {
    return OrderDetailModel(
      orderID: _toInt(map['OrderID'] ?? map['orderID']),
      productID: _toInt(map['ProductID'] ?? map['productID']),
      quantity: _toInt(map['Quantity'] ?? map['quantity']),
      unitPrice: _toDouble(map['unitPrice'] ?? map['UnitPrice']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'OrderID': orderID,
      'ProductID': productID,
      'Quantity': quantity,
      'unitPrice': unitPrice,
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
}