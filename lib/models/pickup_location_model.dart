import 'location_model.dart';

/// Modelo que representa la entidad PickupLocation
/// Hereda los datos de Location (patrón de herencia en BD)
/// Principio S de SOLID: solo representa los datos de un punto de recogida
class PickupLocationModel {
  final int? locationID;
  final String address;

  /// Datos heredados de Location
  final double? latitude;
  final double? longitude;

  /// Constructor principal
  PickupLocationModel({
    this.locationID,
    required this.address,
    this.latitude,
    this.longitude,
  });

  /// Convierte un Map (resultado de la BD) a un objeto PickupLocationModel
  factory PickupLocationModel.fromMap(Map<String, dynamic> map) {
    return PickupLocationModel(
      locationID: map['LocationID'],
      address: map['address'],
      latitude: map['Latitude'] != null
          ? double.parse(map['Latitude'].toString())
          : null,
      longitude: map['Longitude'] != null
          ? double.parse(map['Longitude'].toString())
          : null,
    );
  }

  /// Convierte el objeto a un Map para insertar en la BD
  Map<String, dynamic> toMap() {
    return {
      'LocationID': locationID,
      'address': address,
    };
  }

  /// Crea un PickupLocationModel a partir de un LocationModel
  factory PickupLocationModel.fromLocation(
      LocationModel location, String address) {
    return PickupLocationModel(
      locationID: location.id,
      address: address,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }
}