import '../core/db_connection.dart';

/// Servicio para configuraciones globales de la app (valor moneda, QR, etc.)
/// Usa la tabla AppConfig con clave-valor
class AppConfigService {
  final DBConnection _db = DBConnection.instance;

  /// Crea la tabla (fuerza esquema correcto si ya existía con otro esquema)
  Future<void> initTable() async {
    try {
      final conn = await _db.getConnection();
      // Verificar si la tabla existe con el esquema correcto
      try {
        await conn.execute(
            'SELECT configKey FROM AppConfig LIMIT 1');
        // Si llega aquí, el esquema es correcto
      } catch (_) {
        // La tabla no existe o tiene columnas distintas → recrear
        await conn.execute('DROP TABLE IF EXISTS AppConfig');
        await conn.execute('''
          CREATE TABLE AppConfig (
            configKey VARCHAR(100) PRIMARY KEY,
            configValue TEXT,
            updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
          )
        ''');
      }
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
        VALUES (:key, :val)
        ON DUPLICATE KEY UPDATE configValue = VALUES(configValue)
        ''',
        {'key': key, 'val': value},
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
