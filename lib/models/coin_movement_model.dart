/// Modelo que representa un movimiento de monedas del productor.
/// Sirve para registrar recargas, usos de monedas al publicar productos,
/// ajustes administrativos o reembolsos.
///
/// Tipos recomendados para [type]:
/// - recarga / recharge
/// - uso / usage
/// - ajuste / adjustment
/// - reembolso / refund
class CoinMovementModel {
  /// ID del movimiento
  final int? id;

  /// ID del usuario/productor al que pertenece el movimiento
  final int userId;

  /// Cantidad de monedas del movimiento
  final double amount;

  /// Tipo de movimiento
  final String type;

  /// Descripción del movimiento
  final String description;

  /// Fecha y hora en la que se registró el movimiento
  final DateTime createdAt;

  const CoinMovementModel({
    this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  /// Crea una copia del modelo con cambios parciales
  CoinMovementModel copyWith({
    int? id,
    int? userId,
    double? amount,
    String? type,
    String? description,
    DateTime? createdAt,
  }) {
    return CoinMovementModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convierte un Map proveniente de MySQL a CoinMovementModel
  factory CoinMovementModel.fromMap(Map<String, dynamic> map) {
    return CoinMovementModel(
      id: _parseInt(map['ID'] ?? map['id']),
      userId: _parseInt(
        map['UserID'] ??
            map['userId'] ??
            map['ProducerID'] ??
            map['producerId'],
      ) ??
          0,
      amount: _parseDouble(
        map['Amount'] ?? map['amount'] ?? map['Coins'] ?? map['coins'],
      ) ??
          0.0,
      type: (map['Type'] ?? map['type'] ?? 'usage').toString().trim(),
      description:
      (map['Description'] ?? map['description'] ?? '').toString().trim(),
      createdAt:
      _parseDateTime(
        map['CreatedAt'] ??
            map['createdAt'] ??
            map['RegisterDate'] ??
            map['registerDate'],
      ) ??
          DateTime.now(),
    );
  }

  /// Convierte el modelo a Map para usarlo en inserts/updates
  Map<String, dynamic> toMap({bool includeId = false}) {
    final data = <String, dynamic>{
      'UserID': userId,
      'Amount': amount,
      'Type': type,
      'Description': description,
      'CreatedAt': createdAt.toIso8601String(),
    };

    if (includeId && id != null) {
      data['ID'] = id;
    }

    return data;
  }

  /// Tipo normalizado para trabajar internamente
  String get normalizedType {
    final value = type.toLowerCase().trim();

    switch (value) {
      case 'recarga':
      case 'recharge':
        return 'recharge';

      case 'uso':
      case 'usage':
        return 'usage';

      case 'ajuste':
      case 'adjustment':
        return 'adjustment';

      case 'reembolso':
      case 'refund':
        return 'refund';

      default:
        return value;
    }
  }

  /// Indica si el movimiento es una recarga
  bool get isRecharge => normalizedType == 'recharge';

  /// Indica si el movimiento es un uso de monedas
  bool get isUsage => normalizedType == 'usage';

  /// Indica si el movimiento es un ajuste
  bool get isAdjustment => normalizedType == 'adjustment';

  /// Indica si el movimiento es un reembolso
  bool get isRefund => normalizedType == 'refund';

  /// Retorna el monto con signo para cálculos rápidos
  /// Uso = negativo
  /// Recarga/Reembolso = positivo
  /// Ajuste = se deja positivo tal cual
  double get signedAmount {
    switch (normalizedType) {
      case 'usage':
        return -amount.abs();

      case 'recharge':
      case 'refund':
        return amount.abs();

      case 'adjustment':
      default:
        return amount;
    }
  }

  /// Texto bonito para mostrar en la interfaz
  String get displayType {
    switch (normalizedType) {
      case 'recharge':
        return 'Recarga';

      case 'usage':
        return 'Uso';

      case 'adjustment':
        return 'Ajuste';

      case 'refund':
        return 'Reembolso';

      default:
        return type;
    }
  }

  /// Convierte cualquier valor dinámico a int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  /// Convierte cualquier valor dinámico a double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    final cleanValue = value.toString().replaceAll(',', '.');
    return double.tryParse(cleanValue);
  }

  /// Convierte cualquier valor dinámico a DateTime
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  String toString() {
    return 'CoinMovementModel('
        'id: $id, '
        'userId: $userId, '
        'amount: $amount, '
        'type: $type, '
        'description: $description, '
        'createdAt: $createdAt'
        ')';
  }
}