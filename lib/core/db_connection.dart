import 'package:mysql_client/mysql_client.dart';

/// Clase que maneja la conexión a la base de datos MySQL
/// Implementa el patrón Singleton para asegurar una única instancia
/// de conexión en toda la aplicación
class DBConnection {
  // Instancia única de la clase (Singleton)
  static DBConnection? _instance;

  // Conexión a la base de datos
  MySQLConnection? _connection;

  // Constructor privado para evitar instanciación externa
  DBConnection._();

  /// Retorna la única instancia de DBConnection
  static DBConnection get instance {
    _instance ??= DBConnection._();
    return _instance!;
  }

  /// Inicializa y retorna la conexión a la base de datos
  /// Si ya existe una conexión activa, la retorna directamente
  Future<MySQLConnection> getConnection() async {
    if (_connection != null && !_connection!.connected) {
      _connection = null;
    }

    _connection ??= await MySQLConnection.createConnection(
      host: 'mysql-dd43cae-santiagsanchez05-9b31.f.aivencloud.com',
      port: 27698,
      userName: 'avnadmin',
      password: 'AVNS_Mdhd_rVXu2m_A2sqku_',
      databaseName: 'defaultdb',
      secure: true, // SSL requerido por Aiven
    );

    await _connection!.connect();
    return _connection!;
  }

  /// Cierra la conexión a la base de datos
  Future<void> closeConnection() async {
    await _connection?.close();
    _connection = null;
  }
}