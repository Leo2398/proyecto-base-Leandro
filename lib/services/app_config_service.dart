import '../core/db_connection.dart';

/// Servicio para configuraciones globales de la app (valor moneda, QR, etc.)
/// Usa la tabla AppConfig con clave-valor
class AppConfigService {
  final DBConnection _db = DBConnection.instance;

  /// Crea la tabla si no existe
  Future<void> initTable() async {
    try {
      final conn = await _db.getConnection();
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS AppConfig (
          configKey VARCHAR(100) PRIMARY KEY,
          configValue TEXT,
          updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
      ''');
    } catch (e) {
      print('Error en AppConfigService.initTable: $e');
    }
  }

  Future<String?> getConfig(String key) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        'SELECT configValue FROM AppConfig WHERE configKey = :key',
        {'key': key},
      );
      if (result.rows.isEmpty) return null;
      return result.rows.first.assoc()['configValue']?.toString();
    } catch (e) {
      print('Error en getConfig: $e');
      return null;
    }
  }

  Future<bool> setConfig(String key, String value) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''
        INSERT INTO AppConfig (configKey, configValue)
        VALUES (:key, :value)
        ON DUPLICATE KEY UPDATE configValue = :value
        ''',
        {'key': key, 'value': value},
      );
      return true;
    } catch (e) {
      print('Error en setConfig: $e');
      return false;
    }
  }

  Future<double> getCoinValueBs() async {
    final v = await getConfig('coin_value_bs');
    return double.tryParse(v ?? '') ?? 1.0;
  }

  Future<bool> setCoinValueBs(double value) =>
      setConfig('coin_value_bs', value.toStringAsFixed(2));

  Future<String?> getQrImageUrl() => getConfig('qr_image_url');

  Future<bool> setQrImageUrl(String url) =>
      setConfig('qr_image_url', url);
}
