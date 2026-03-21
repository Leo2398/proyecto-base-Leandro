class ProductModel {
  final int? id;
  final String name;
  final String? picture;
  final String? description;
  final double price;
  final String? unit;
  final int stock;
  final int state;
  final DateTime? harvestDate;
  final int userID;

  const ProductModel({
    this.id,
    required this.name,
    this.picture,
    this.description,
    required this.price,
    this.unit,
    required this.stock,
    required this.state,
    this.harvestDate,
    required this.userID,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: _toInt(map['ID']),
      name: map['name']?.toString().trim() ?? '',
      picture: _toNullableString(map['picture']),
      description: _toNullableString(map['description']),
      price: _toDouble(map['price']) ?? 0.0,
      unit: _toNullableString(map['unit']),
      stock: _toInt(map['stock']) ?? 0,
      state: _toInt(map['state']) ?? 1,
      harvestDate: _toDateTime(map['HarvestDate']),
      userID: _toInt(map['UserID']) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'name': name,
      'picture': picture,
      'description': description,
      'price': price,
      'unit': unit,
      'stock': stock,
      'state': state,
      'HarvestDate': harvestDate,
      'UserID': userID,
    };
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? picture,
    String? description,
    double? price,
    String? unit,
    int? stock,
    int? state,
    DateTime? harvestDate,
    int? userID,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      picture: picture ?? this.picture,
      description: description ?? this.description,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      state: state ?? this.state,
      harvestDate: harvestDate ?? this.harvestDate,
      userID: userID ?? this.userID,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}