import 'package:bcrypt/bcrypt.dart';

/// Helper para cifrado de contraseñas
/// Principio S de SOLID: solo maneja el cifrado y verificación
class EncryptionHelper {
  /// Cifra una contraseña usando bcrypt
  static String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Verifica si una contraseña coincide con su hash
  static bool verifyPassword(String password, String hash) {
    return BCrypt.checkpw(password, hash);
  }

  /// Genera una contraseña temporal con el prefijo 1pc
  /// Usa el nombre, email y hora de registro
  static String generateTempPassword(String name, String email) {
    /// Toma las primeras 3 letras del nombre
    final namePart = name.length >= 3
        ? name.substring(0, 3).toLowerCase()
        : name.toLowerCase();

    /// Toma las primeras 2 letras del email
    final emailPart = email.substring(0, 2).toLowerCase();

    /// Toma el año actual
    final year = DateTime.now().year;

    /// Genera un número random de 4 dígitos
    final random = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;

    /// Contraseña final: 1pc_nombreemailAño####
    return '1pc_$namePart$emailPart$year$random';
  }

  /// Verifica si una contraseña es temporal (empieza con 1pc)
  static bool isTempPassword(String password) {
    return password.startsWith('1pc');
  }
}