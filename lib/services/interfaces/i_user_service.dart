import '../../models/user_model.dart';

/// Interfaz que define los contratos del servicio de Usuario
/// Principio I de SOLID: interfaz específica solo para usuarios
/// Principio D de SOLID: los controllers dependerán de esta abstracción
abstract class IUserService {
  /// Obtiene un usuario por su ID
  Future<UserModel?> getUserById(int id);

  /// Obtiene un usuario por su email
  Future<UserModel?> getUserByEmail(String email);

  /// Obtiene todos los productores activos
  Future<List<UserModel>> getAllProducers();

  /// Registra un nuevo usuario en la BD
  Future<bool> createUser(UserModel user,
      {double? latitude,
      double? longitude,
      String? address,
      int? deliveryModeID});

  /// Actualiza los datos de un usuario
  Future<bool> updateUser(UserModel user);

  /// Actualiza el perfil editable del usuario (nombre, email, teléfono, imagen)
  Future<bool> updateUserProfile(UserModel user);

  /// Actualiza el perfil del productor incluyendo ubicación/punto de entrega
  Future<bool> updateProducerProfileData({
    required UserModel user,
    required double latitude,
    required double longitude,
    required String address,
  });

  /// Obtiene todos los administradores del sistema (role = 2)
  Future<List<UserModel>> getAllAdmins();

  /// Crea un administrador con contraseña directa (sin temporal)
  Future<bool> createAdminUser(UserModel user, String password);

  /// Elimina lógicamente un administrador (state = 0)
  Future<bool> deleteAdmin(int id);

  /// Actualiza los datos de un administrador (nombre, email, teléfono, estado)
  Future<bool> updateAdmin(UserModel user, {String? newPassword});

  /// Actualiza el balance de un usuario
  Future<bool> updateBalance(int id, double amount);

  /// Cambia el estado de un usuario (activo/inactivo)
  Future<bool> updateState(int id, int state);

  /// Verifica las credenciales para el login
  Future<UserModel?> login(String email, String password);
}