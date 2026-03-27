/// Modelo para la tabla AppConfig
/// El admin puede cambiar bsPerCoin y qrImage
class AppConfigModel {
  final int id;
  final double bsPerCoin;
  final String? qrImage;
  final DateTime? updatedAt;

  const AppConfigModel({
    required this.id,
    required this.bsPerCoin,
    this.qrImage,
    this.updatedAt,
  });

  factory AppConfigModel.fromMap(Map<String, dynamic> map) {
    return AppConfigModel(
      id: int.tryParse(map['id']?.toString() ?? '1') ?? 1,
      bsPerCoin: double.tryParse(map['bsPerCoin']?.toString() ?? '9') ?? 9.0,
      qrImage: map['qrImage']?.toString(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  /// Config por defecto si falla la BD
  static AppConfigModel get defaults => const AppConfigModel(
        id: 1,
        bsPerCoin: 9.0,
        qrImage: null,
      );
}