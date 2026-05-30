import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

/// Helper para manejar la ubicación del dispositivo
/// Principio S de SOLID: solo maneja la lógica de ubicación
class LocationHelper {
  /// Solicita permisos y obtiene la ubicación actual del dispositivo
  static Future<LatLng?> getCurrentLocation() async {
    try {
      /// Verifica si el servicio de ubicación está habilitado
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      /// Verifica los permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();

      /// Si no tiene permisos los solicita
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      /// Si los permisos fueron denegados permanentemente retorna null
      if (permission == LocationPermission.deniedForever) return null;

      /// Obtiene la posición actual
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error al obtener ubicación: $e');
      return null;
    }
  }

  /// Convierte coordenadas a dirección legible
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;

      /// Construye la dirección completa
      return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}';
    } catch (e) {
      print('Error al obtener dirección: $e');
      return null;
    }
  }

  /// Convierte una dirección a coordenadas
  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);

      if (locations.isEmpty) return null;

      return LatLng(locations.first.latitude, locations.first.longitude);
    } catch (e) {
      print('Error al obtener coordenadas: $e');
      return null;
    }
  }
}