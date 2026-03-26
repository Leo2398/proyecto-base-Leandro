/// Modelo que representa el token de recuperación de contraseña
/// Principio S de SOLID: solo representa los datos del token
class PasswordResetTokenModel {
  final int? id;
  final String token;
  final int userID;
  final DateTime expiresAt;
  final int used;

  PasswordResetTokenModel({
    this.id,
    required this.token,
    required this.userID,
    required this.expiresAt,
    this.used = 0,
  });

  factory PasswordResetTokenModel.fromMap(Map<String, dynamic> map) {
    return PasswordResetTokenModel(
      id: map['ID'] != null ? int.parse(map['ID'].toString()) : null,
      token: map['token']?.toString() ?? '',
      userID: int.parse(map['userID'].toString()),
      expiresAt: DateTime.parse(map['expiresAt'].toString()),
      used: map['used'] != null ? int.parse(map['used'].toString()) : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'token': token,
      'userID': userID,
      'expiresAt': expiresAt.toIso8601String(),
      'used': used,
    };
  }

  /// Verifica si el token ya expiró
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Verifica si el token ya fue usado
  bool get isUsed => used == 1;

  /// Verifica si el token es válido (no expirado y no usado)
  bool get isValid => !isExpired && !isUsed;
}