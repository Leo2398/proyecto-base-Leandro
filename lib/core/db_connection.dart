import 'package:mysql_client/mysql_client.dart';

/// Clase que maneja la conexión a la base de datos MySQL
/// Implementa el patrón Singleton para asegurar una única instancia
class DBConnection {
  static DBConnection? _instance;
  MySQLConnection? _connection;

  DBConnection._();

  static DBConnection get instance {
    _instance ??= DBConnection._();
    return _instance!;
  }

  /// Retorna la conexión activa o crea una nueva si no existe o está cerrada
  Future<MySQLConnection> getConnection() async {
    try {
      /// Si la conexión existe y está activa la reutiliza
      if (_connection != null && _connection!.connected) {
        return _connection!;
      }

      /// Cierra la conexión anterior si existe pero no está activa
      if (_connection != null) {
        try {
          await _connection!.close();
        } catch (_) {}
        _connection = null;
      }

      _connection = await MySQLConnection.createConnection(
        host: 'mysql-141d5c3f-suarezmateo950-a1c5.d.aivencloud.com',
        port: 22052,
        userName: 'app_user',
        password: 'AVNS_p5dIV65HBQ0aSpAhzMI',
        databaseName: 'app_pedidos',
        secure: true,
      );

      await _connection!.connect();
      return _connection!;
    } catch (e) {
      _connection = null;
      rethrow;
    }
  }

  /// Cierra la conexión a la base de datos
  Future<void> closeConnection() async {
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
  }
}