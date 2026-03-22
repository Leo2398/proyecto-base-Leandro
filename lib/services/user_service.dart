import '../core/db_connection.dart';
import '../core/email_helper.dart';
import '../core/encryption_helper.dart';
import '../models/location_model.dart';
import '../models/pickup_location_model.dart';
import '../models/user_model.dart';
import 'interfaces/i_user_service.dart';
import 'location_service.dart';

/// Implementación del servicio de Usuario
/// Principio S de SOLID: solo maneja operaciones de la BD para usuarios
/// Principio O de SOLID: implementa la interfaz IUserService sin modificarla
class UserService implements IUserService {
  /// Instancia de la conexión a la BD
  final DBConnection _db = DBConnection.instance;

  /// Servicio de ubicaciones
  final LocationService _locationService = LocationService();

  /// Obtiene un usuario por su ID
  @override
  Future<UserModel?> getUserById(int id) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        'SELECT * FROM User WHERE ID = :id',
        {'id': id},
      );

      if (result.rows.isEmpty) return null;

      return UserModel.fromMap(result.rows.first.assoc());
    } catch (e) {
      print('Error en getUserById: $e');
      return null;
    }
  }

  /// Obtiene un usuario por su email
  @override
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        'SELECT * FROM User WHERE email = :email',
        {'email': email},
      );

      if (result.rows.isEmpty) return null;

      return UserModel.fromMap(result.rows.first.assoc());
    } catch (e) {
      print('Error en getUserByEmail: $e');
      return null;
    }
  }
  @override
  Future<List<UserModel>> getAllProducers() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
      SELECT *
      FROM User
      WHERE role = 1 AND state = 1
      ORDER BY name ASC
      ''',
      );

      return result.rows
          .map((row) => UserModel.fromMap(row.assoc()))
          .toList();
    } catch (e) {
      print('Error en getAllProducers: $e');
      return [];
    }
  }

  /// Registra un nuevo usuario en la BD
  /// Guarda Location, PickupLocation y User en orden
  @override
  Future<bool> createUser(UserModel user,
      {double? latitude,
      double? longitude,
      String? address,
      int? deliveryModeID}) async {
    try {
      final conn = await _db.getConnection();
      int? pickUpLocationID;

      /// Si tiene ubicación la guarda en Location y PickupLocation
      if (latitude != null && longitude != null && address != null) {
        /// Paso 1: inserta en Location
        final locationID = await _locationService.createLocation(
          LocationModel(latitude: latitude, longitude: longitude),
        );

        if (locationID == null) return false;

        /// Paso 2: inserta en PickupLocation
        final pickupSuccess = await _locationService.createPickupLocation(
          PickupLocationModel(
            locationID: locationID,
            address: address,
          ),
        );

        if (!pickupSuccess) return false;

        pickUpLocationID = locationID;
      }

      /// Genera la contraseña temporal con los datos del usuario
      final tempPassword = EncryptionHelper.generateTempPassword(
        user.name,
        user.email,
      );

      /// Cifra la contraseña antes de guardarla en la BD
      final hashedPassword = EncryptionHelper.hashPassword(tempPassword);

      /// Paso 3: inserta en User
      await conn.execute(
        '''INSERT INTO User (name, image, balance, email, password, 
        description, role, cellphone, deliveryModeID, pickUpLocationID) 
        VALUES (:name, :image, :balance, :email, :password, 
        :description, :role, :cellphone, :deliveryModeID, :pickUpLocationID)''',
        {
          'name': user.name,
          'image': user.image,
          'balance': user.balance,
          'email': user.email,
          'password': hashedPassword,
          'description': user.description,
          'role': user.role,
          'cellphone': user.cellphone,
          'deliveryModeID': deliveryModeID,
          'pickUpLocationID': pickUpLocationID,
        },
      );

      /// Envía la contraseña temporal al email del usuario
      await EmailHelper.sendTempPassword(
        toEmail: user.email,
        userName: user.name,
        tempPassword: tempPassword,
      );

      return true;
    } catch (e) {
      print('Error en createUser: $e');
      return false;
    }
  }

  /// Obtiene el ID del último usuario insertado por email
  Future<int?> getUserIdByEmail(String email) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        'SELECT ID FROM User WHERE email = :email',
        {'email': email},
      );

      if (result.rows.isEmpty) return null;

      return int.parse(result.rows.first.assoc()['ID'].toString());
    } catch (e) {
      print('Error en getUserIdByEmail: $e');
      return null;
    }
  }

  /// Actualiza los datos de un usuario
  @override
  Future<bool> updateUser(UserModel user) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''UPDATE User SET name = :name, image = :image, 
        description = :description, cellphone = :cellphone 
        WHERE ID = :id''',
        {
          'name': user.name,
          'image': user.image,
          'description': user.description,
          'cellphone': user.cellphone,
          'id': user.id,
        },
      );
      return true;
    } catch (e) {
      print('Error en updateUser: $e');
      return false;
    }
  }

  /// Actualiza el perfil editable del usuario (nombre, email, teléfono, imagen)
  @override
  Future<bool> updateUserProfile(UserModel user) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        '''UPDATE User SET name = :name, email = :email,
        cellphone = :cellphone, image = :image
        WHERE ID = :id''',
        {
          'name': user.name,
          'email': user.email,
          'cellphone': user.cellphone,
          'image': user.image,
          'id': user.id,
        },
      );
      return true;
    } catch (e) {
      print('Error en updateUserProfile: $e');
      return false;
    }
  }

  /// Actualiza el balance de un usuario
  @override
  Future<bool> updateBalance(int id, double amount) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        'UPDATE User SET balance = balance + :amount WHERE ID = :id',
        {'amount': amount, 'id': id},
      );
      return true;
    } catch (e) {
      print('Error en updateBalance: $e');
      return false;
    }
  }

  /// Cambia el estado de un usuario (activo/inactivo)
  @override
  Future<bool> updateState(int id, int state) async {
    try {
      final conn = await _db.getConnection();
      await conn.execute(
        'UPDATE User SET state = :state WHERE ID = :id',
        {'state': state, 'id': id},
      );
      return true;
    } catch (e) {
      print('Error en updateState: $e');
      return false;
    }
  }

  /// Verifica las credenciales para el login usando bcrypt
  @override
  Future<UserModel?> login(String email, String password) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        'SELECT * FROM User WHERE email = :email AND state = 1',
        {'email': email},
      );

      if (result.rows.isEmpty) return null;

      final user = UserModel.fromMap(result.rows.first.assoc());

      /// Verifica la contraseña con bcrypt
      final isValid = EncryptionHelper.verifyPassword(password, user.password);

      if (!isValid) return null;

      return user;
    } catch (e) {
      print('Error en login: $e');
      return null;
    }
  }

  /// Actualiza la contraseña de un usuario y envía confirmación por email
  Future<bool> updatePassword(
      int id, String newPassword, String email, String name) async {
    try {
      final conn = await _db.getConnection();

      /// Cifra la nueva contraseña
      final hashedPassword = EncryptionHelper.hashPassword(newPassword);

      await conn.execute(
        'UPDATE User SET password = :password WHERE ID = :id',
        {'password': hashedPassword, 'id': id},
      );

      /// Envía confirmación por email
      await EmailHelper.sendPasswordChanged(
        toEmail: email,
        userName: name,
      );

      return true;
    } catch (e) {
      print('Error en updatePassword: $e');
      return false;
    }
  }
}