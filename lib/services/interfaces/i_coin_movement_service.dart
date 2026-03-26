import '../../models/coin_movement_model.dart';

/// Interfaz del servicio de movimientos de monedas.
///
/// Principio O de SOLID:
/// permite extender la implementación sin modificar a los consumidores.
///
/// Principio D de SOLID:
/// los controladores deben depender de abstracciones, no de implementaciones.
abstract class ICoinMovementService {
  /// Obtiene el saldo actual de monedas del usuario/productor.
  ///
  /// Este saldo puede venir desde la tabla User, desde movimientos,
  /// o desde la lógica que uses en la implementación concreta.
  Future<double> getUserCoinBalance(int userId);

  /// Obtiene todo el historial de movimientos de monedas del usuario/productor.
  ///
  /// Debe devolver la lista ordenada, idealmente del más reciente al más antiguo.
  Future<List<CoinMovementModel>> getMovementsByUserId(int userId);

  /// Obtiene una cantidad limitada de movimientos recientes.
  Future<List<CoinMovementModel>> getRecentMovementsByUserId(
      int userId, {
        int limit = 20,
      });

  /// Registra un nuevo movimiento de monedas.
  ///
  /// Ejemplos:
  /// - recarga de monedas
  /// - uso de monedas al publicar un producto
  /// - ajuste administrativo
  /// - reembolso
  Future<bool> createMovement(CoinMovementModel movement);

  /// Registra una recarga de monedas al usuario/productor.
  ///
  /// [amount] = cantidad de monedas recargadas.
  /// [description] = detalle opcional del movimiento.
  Future<bool> registerRecharge({
    required int userId,
    required double amount,
    String? description,
  });

  /// Registra un uso de monedas al usuario/productor.
  ///
  /// [amount] = cantidad de monedas consumidas.
  /// [description] = motivo del gasto, por ejemplo:
  /// "Publicación de producto: Papa orgánica".
  Future<bool> registerUsage({
    required int userId,
    required double amount,
    String? description,
  });
}