import '../core/db_connection.dart';
import '../models/location_model.dart';
import '../models/pickup_location_model.dart';
import 'interfaces/i_location_service.dart';

/// Implementación del servicio de ubicaciones
/// Principio S de SOLID: solo maneja operaciones de BD para ubicaciones
/// Principio O de SOLID: implementa ILocationService sin modificarla
class LocationService implements ILocationService {
  /// Instancia de la conexión a la BD
  final DBConnection _db = DBConnection.instance;

  /// Inserta una nueva ubicación en la BD y retorna su ID generado
  @override
  Future<int?> createLocation(LocationModel location) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''INSERT INTO Location (Latitude, Longitude) 
        VALUES (:latitude, :longitude)''',
        {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
      );

      /// Retorna el ID generado por AUTO_INCREMENT
      return result.lastInsertID.toInt();
    } catch (e) {
      print('Error en createLocation: $e');
      return null;
    }
  }

  /// Inserta un nuevo punto de recogida en la BD
  @override
  Future<bool> createPickupLocation(PickupLocationModel pickupLocation) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''INSERT INTO PickupLocation (LocationID, address) 
        VALUES (:locationID, :address)''',
        {
          'locationID': pickupLocation.locationID,
          'address': pickupLocation.address,
        },
      );
      return true;
    } catch (e) {
      print('Error en createPickupLocation: $e');
      return false;
    }
  }

  /// Obtiene un punto de recogida por su ID incluyendo coordenadas
  @override
  Future<PickupLocationModel?> getPickupLocationById(int id) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''SELECT pl.LocationID, pl.address, l.Latitude, l.Longitude 
        FROM PickupLocation pl 
        INNER JOIN Location l ON pl.LocationID = l.ID 
        WHERE pl.LocationID = :id''',
        {'id': id},
      );

      if (result.rows.isEmpty) return null;

      return PickupLocationModel.fromMap(result.rows.first.assoc());
    } catch (e) {
      print('Error en getPickupLocationById: $e');
      return null;
    }
  }
}