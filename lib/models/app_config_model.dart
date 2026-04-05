/// Modelo para la tabla AppConfig (esquema clave-valor)
/// Claves usadas: 'bsPerCoin', 'qrImage'
class AppConfigModel {
  final double bsPerCoin;
  final String? qrImage;

  const AppConfigModel({
    required this.bsPerCoin,
    this.qrImage,
  });

  /// Construye el modelo a partir de una lista de filas clave-valor de AppConfig
  factory AppConfigModel.fromRows(List<Map<String, dynamic>> rows) {
    double bsPerCoin = 9.0;
    String? qrImage;
    for (final row in rows) {
      final key = row['configKey']?.toString();
      final val = row['configValue']?.toString();
      if (key == 'bsPerCoin') {
        bsPerCoin = double.tryParse(val ?? '') ?? 9.0;
      } else if (key == 'qrImage') {
        qrImage = val?.isNotEmpty == true ? val : null;
      }
    }
    return AppConfigModel(bsPerCoin: bsPerCoin, qrImage: qrImage);
  }

  /// Config por defecto si falla la BD
  static AppConfigModel get defaults =>
      const AppConfigModel(bsPerCoin: 9.0, qrImage: null);
}