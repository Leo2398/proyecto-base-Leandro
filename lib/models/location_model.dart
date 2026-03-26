/// Modelo que representa la entidad Location de la base de datos
/// Principio S de SOLID: solo representa los datos de una ubicación
class LocationModel {
  final int? id;
  final double latitude;
  final double longitude;

  /// Constructor principal
  LocationModel({
    this.id,
    required this.latitude,
    required this.longitude,
  });

  /// Convierte un Map (resultado de la BD) a un objeto LocationModel
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map['ID'],
      latitude: double.parse(map['Latitude'].toString()),
      longitude: double.parse(map['Longitude'].toString()),
    );
  }

  /// Convierte el objeto LocationModel a un Map para insertar en la BD
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Latitude': latitude,
      'Longitude': longitude,
    };
  }
}