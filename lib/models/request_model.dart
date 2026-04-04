/// Modelo que representa la tabla Request en la BD
/// state: 0=pendiente, 1=aprobado, 2=rechazado
class RequestModel {
  final int? id;
  final int value;
  final double amount;
  final String image;
  final int state;
  final DateTime? registerDate;
  final DateTime? processedDate;
  final int userID;
  final int? adminID;
  // Datos del usuario (disponibles cuando se hace JOIN con User)
  final String? userName;
  final String? userEmail;
  final String? userImage;

  const RequestModel({
    this.id,
    required this.value,
    required this.amount,
    required this.image,
    this.state = 0,
    this.registerDate,
    this.processedDate,
    required this.userID,
    this.adminID,
    this.userName,
    this.userEmail,
    this.userImage,
  });

  factory RequestModel.fromMap(Map<String, dynamic> map) {
    return RequestModel(
      id: _toInt(map['ID']),
      value: _toInt(map['value']) ?? 0,
      amount: _toDouble(map['amount']) ?? 0.0,
      image: map['image']?.toString() ?? '',
      state: _toInt(map['state']) ?? 0,
      registerDate: _toDateTime(map['registerDate']),
      processedDate: _toDateTime(map['processedDate']),
      userID: _toInt(map['userID']) ?? 0,
      adminID: _toInt(map['adminID']),
      userName: map['userName']?.toString(),
      userEmail: map['userEmail']?.toString(),
      userImage: map['userImage']?.toString(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  String get stateLabel {
    switch (state) {
      case 0: return 'Pendiente';
      case 1: return 'Aprobado';
      case 2: return 'Rechazado';
      default: return 'Desconocido';
    }
  }
}