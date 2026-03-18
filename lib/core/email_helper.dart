import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Helper para envío de emails
/// Principio S de SOLID: solo maneja el envío de correos
class EmailHelper {
  /// Credenciales del servidor SMTP
  static const String _email = 'mvaleriano1105@gmail.com';
  static const String _password = 'topu yzup buav ywsw';

  /// Configuración del servidor SMTP de Gmail
  static SmtpServer get _smtpServer => gmail(_email, _password);

  /// Envía la contraseña temporal al usuario recién registrado
  static Future<bool> sendTempPassword({
    required String toEmail,
    required String userName,
    required String tempPassword,
  }) async {
    try {
      /// Crea el mensaje de correo
      final message = Message()
        ..from = Address(_email, 'Agro App')
        ..recipients.add(toEmail)
        ..subject = 'Bienvenido a Agro App - Tu contraseña temporal'
        ..html = '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background-color: #5A8A5A; padding: 20px; text-align: center;">
              <h1 style="color: white;">¡Bienvenido a Agro App!</h1>
            </div>
            <div style="padding: 30px; background-color: #f5f5f5;">
              <p>Hola <strong>$userName</strong>,</p>
              <p>Tu cuenta ha sido creada exitosamente.</p>
              <p>Tu contraseña temporal es:</p>
              <div style="background-color: #fff; padding: 15px; 
                border-radius: 8px; text-align: center; 
                font-size: 22px; font-weight: bold; 
                color: #5A8A5A; letter-spacing: 2px;">
                $tempPassword
              </div>
              <p style="color: #888; font-size: 13px;">
                Por seguridad, deberás cambiar esta contraseña 
                al iniciar sesión por primera vez.
              </p>
            </div>
          </div>
        ''';

      /// Envía el correo
      await send(message, _smtpServer);
      return true;
    } catch (e) {
      print('Error al enviar email: $e');
      return false;
    }
  }
  /// Envía el código de recuperación de contraseña
/// Envía el código de recuperación de contraseña
static Future<bool> sendResetCode({
  required String toEmail,
  required String userName,
  required String code,
}) async {
  try {
    final message = Message()
      ..from = Address(_email, 'AgroMarket')
      ..recipients.add(toEmail)
      ..subject = 'Código de recuperación de contraseña'
      ..html = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #5A8A5A; padding: 20px; text-align: center;">
            <h1 style="color: white;">AgroMarket</h1>
          </div>
          <div style="padding: 30px; background-color: #f5f5f5;">
            <p>Hola <strong>$userName</strong>,</p>
            <p>Tu código de recuperación de contraseña es:</p>
            <div style="background-color: #fff; padding: 15px; 
              border-radius: 8px; text-align: center; 
              font-size: 36px; font-weight: bold; 
              color: #5A8A5A; letter-spacing: 8px;">
              $code
            </div>
            <p style="color: #888; font-size: 13px;">
              Este código expira en 15 minutos.
              Si no solicitaste este código ignora este mensaje.
            </p>
          </div>
        </div>
      ''';

    await send(message, _smtpServer);
    return true;
  } catch (e) {
    print('Error al enviar código de reset: $e');
    return false;
  }
}
  /// Envía un email de confirmación de cambio de contraseña
  static Future<bool> sendPasswordChanged({
    required String toEmail,
    required String userName,
  }) async {
    try {
      final message = Message()
        ..from = Address(_email, 'Agro App')
        ..recipients.add(toEmail)
        ..subject = 'Contraseña actualizada - Agro App'
        ..html = '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background-color: #5A8A5A; padding: 20px; text-align: center;">
              <h1 style="color: white;">Agro App</h1>
            </div>
            <div style="padding: 30px; background-color: #f5f5f5;">
              <p>Hola <strong>$userName</strong>,</p>
              <p>Tu contraseña ha sido actualizada exitosamente.</p>
              <p style="color: #888; font-size: 13px;">
                Si no realizaste este cambio, contacta 
                al soporte inmediatamente.
              </p>
            </div>
          </div>
        ''';

      await send(message, _smtpServer);
      return true;
    } catch (e) {
      print('Error al enviar email: $e');
      return false;
    }
  }
}