import '../../models/delivery_mode_model.dart';

/// Interfaz del servicio de modalidades de entrega
/// Principio I de SOLID: interfaz específica solo para delivery modes
abstract class IDeliveryModeService {
  /// Obtiene todas las modalidades de entrega
  Future<List<DeliveryModeModel>> getAll();
}