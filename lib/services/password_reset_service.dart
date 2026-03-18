import '../core/db_connection.dart';
import '../models/password_reset_token_model.dart';
import 'interfaces/i_password_reset_service.dart';

/// Implementación del servicio de recuperación de contraseña
/// Principio S de SOLID: solo maneja operaciones de BD para reset de contraseña
class PasswordResetService implements IPasswordResetService {
  final DBConnection _db = DBConnection.instance;

  /// Crea un nuevo token de recuperación para el usuario
  @override
  Future<bool> createToken(PasswordResetTokenModel token) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''INSERT INTO PasswordResetToken (token, userID, expiresAt, used)
        VALUES (:token, :userID, :expiresAt, 0)''',
        {
          'token': token.token,
          'userID': token.userID,
          'expiresAt': token.expiresAt
              .toIso8601String()
              .replaceFirst('T', ' ')
              .substring(0, 19),
        },
      );
      return true;
    } catch (e) {
      print('Error en createToken: $e');
      return false;
    }
  }

  /// Obtiene el token más reciente válido de un usuario
Future<PasswordResetTokenModel?> getValidToken(int userID, String token) async {
  try {
    final conn = await _db.getConnection();
    
    /// Debug: busca sin filtros para ver qué hay en la BD
    final debug = await conn.execute(
      'SELECT * FROM PasswordResetToken WHERE userID = :userID ORDER BY ID DESC LIMIT 1',
      {'userID': userID},
    );
    
    if (debug.rows.isNotEmpty) {
      print('Token en BD: ${debug.rows.first.assoc()}');
    } else {
      print('No hay tokens para este usuario');
    }

    final result = await conn.execute(
  '''SELECT * FROM PasswordResetToken 
  WHERE userID = :userID 
  AND token = :token 
  AND used = '0'
  AND expiresAt > UTC_TIMESTAMP()
  ORDER BY ID DESC 
  LIMIT 1''',
  {'userID': userID, 'token': token},
);

    if (result.rows.isEmpty) return null;

    return PasswordResetTokenModel.fromMap(result.rows.first.assoc());
  } catch (e) {
    print('Error en getValidToken: $e');
    return null;
  }
}

  /// Marca el token como usado
  @override
  Future<bool> markTokenAsUsed(int tokenID) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        'UPDATE PasswordResetToken SET used = 1 WHERE ID = :id',
        {'id': tokenID},
      );
      return true;
    } catch (e) {
      print('Error en markTokenAsUsed: $e');
      return false;
    }
  }

  /// Elimina tokens anteriores del usuario para evitar acumulación
  @override
  Future<bool> deleteUserTokens(int userID) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        'DELETE FROM PasswordResetToken WHERE userID = :userID',
        {'userID': userID},
      );
      return true;
    } catch (e) {
      print('Error en deleteUserTokens: $e');
      return false;
    }
  }
}