import '../../models/user_model.dart';

/// Interfaz que define los contratos del servicio de Usuario
/// Principio I de SOLID: interfaz específica solo para usuarios
/// Principio D de SOLID: los controllers dependerán de esta abstracción
abstract class IUserService {
  /// Obtiene un usuario por su ID
  Future<UserModel?> getUserById(int id);

  /// Obtiene un usuario por su email
  Future<UserModel?> getUserByEmail(String email);

  /// Registra un nuevo usuario en la BD
  Future<bool> createUser(UserModel user,
      {double? latitude,
      double? longitude,
      String? address,
      int? deliveryModeID});

  /// Actualiza los datos de un usuario
  Future<bool> updateUser(UserModel user);

  /// Actualiza el balance de un usuario
  Future<bool> updateBalance(int id, double amount);

  /// Cambia el estado de un usuario (activo/inactivo)
  Future<bool> updateState(int id, int state);

  /// Verifica las credenciales para el login
  Future<UserModel?> login(String email, String password);
}