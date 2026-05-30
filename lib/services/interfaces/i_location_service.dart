import '../../models/location_model.dart';
import '../../models/pickup_location_model.dart';

/// Interfaz del servicio de ubicaciones
/// Principio I de SOLID: interfaz específica solo para ubicaciones
/// Principio D de SOLID: los controllers dependerán de esta abstracción
abstract class ILocationService {
  /// Inserta una nueva ubicación en la BD y retorna su ID
  Future<int?> createLocation(LocationModel location);

  /// Inserta un nuevo punto de recogida en la BD
  Future<bool> createPickupLocation(PickupLocationModel pickupLocation);

  /// Obtiene un punto de recogida por su ID incluyendo coordenadas
  Future<PickupLocationModel?> getPickupLocationById(int id);

  /// Actualiza una ubicación existente en la tabla Location
  Future<bool> updateLocation({
    required int locationId,
    required double latitude,
    required double longitude,
  });

  /// Actualiza la dirección de un punto de recogida existente
  Future<bool> updatePickupLocation({
    required int locationId,
    required String address,
  });
}