import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Helper para manejar la sesión persistente del usuario
/// Principio S de SOLID: solo maneja el almacenamiento local de sesión
class SessionHelper {
  /// Claves para el almacenamiento local
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserImage = 'user_image';
  static const String _keyUserBalance = 'user_balance';
  static const String _keyIsLoggedIn = 'is_logged_in';

  /// Guarda la sesión del usuario en el almacenamiento local
  static Future<void> saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, user.id!);
    await prefs.setString(_keyUserName, user.name);
    await prefs.setString(_keyUserEmail, user.email);
    await prefs.setInt(_keyUserRole, user.role);
    await prefs.setString(_keyUserImage, user.image ?? '');
    await prefs.setDouble(_keyUserBalance, user.balance);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  /// Obtiene la sesión guardada del almacenamiento local
  /// Retorna null si no hay sesión guardada
  static Future<UserModel?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

    if (!isLoggedIn) return null;

    return UserModel(
      id: prefs.getInt(_keyUserId),
      name: prefs.getString(_keyUserName) ?? '',
      email: prefs.getString(_keyUserEmail) ?? '',
      password: '',
      role: prefs.getInt(_keyUserRole) ?? 0,
      image: prefs.getString(_keyUserImage),
      balance: prefs.getDouble(_keyUserBalance) ?? 0.00,
    );
  }

  /// Verifica si hay una sesión activa
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Elimina la sesión del almacenamiento local
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}