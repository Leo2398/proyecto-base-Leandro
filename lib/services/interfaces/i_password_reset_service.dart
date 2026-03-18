import '../../models/password_reset_token_model.dart';

/// Interfaz del servicio de recuperación de contraseña
/// Principio I de SOLID: interfaz específica solo para reset de contraseña
/// Principio D de SOLID: los controllers dependerán de esta abstracción
abstract class IPasswordResetService {
  /// Crea un nuevo token de recuperación para el usuario
  Future<bool> createToken(PasswordResetTokenModel token);

  /// Obtiene el token más reciente válido de un usuario
  Future<PasswordResetTokenModel?> getValidToken(int userID, String token);

  /// Marca el token como usado
  Future<bool> markTokenAsUsed(int tokenID);

  /// Elimina tokens anteriores del usuario para evitar acumulación
  Future<bool> deleteUserTokens(int userID);
}