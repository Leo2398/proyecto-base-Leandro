import '../models/user_model.dart';
import '../services/interfaces/i_user_service.dart';
import '../services/user_service.dart';
import '../services/product_family_service.dart';
import '../core/encryption_helper.dart';
import '../core/session_helper.dart';
import '../models/product_family_model.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import '../services/password_reset_service.dart';
import '../models/password_reset_token_model.dart';
import '../core/email_helper.dart';
import '../services/password_reset_service.dart';
import '../models/schedule_model.dart';
import '../services/schedule_service.dart';



/// Controlador de Usuario
/// Principio S de SOLID: solo maneja la lógica de negocio de usuarios
/// Principio D de SOLID: depende de la interfaz IUserService
/// Implementa ChangeNotifier para el patrón Observer
class UserController extends ChangeNotifier {
  /// Dependencia de la interfaz, no de la implementación (principio D)
  final IUserService _userService;

  /// Servicio de familias de productos
  final ProductFamilyService _productFamilyService = ProductFamilyService();
  /// Servicio de recuperación de contraseña
  final PasswordResetService _passwordResetService = PasswordResetService();

  final ScheduleService _scheduleService = ScheduleService();

  /// Usuario actualmente logueado
  UserModel? _currentUser;

  List<UserModel> _producers = [];
  List<UserModel> _admins = [];
  List<ScheduleModel> _producerSchedules = [];

  /// Indica si hay una operación en progreso
  bool _isLoading = false;

  /// Mensaje de error de la última operación
  String? _errorMessage;

  /// Indica si el usuario debe cambiar su contraseña temporal
  bool _mustChangePassword = false;

  /// Indica si la sesión ya fue verificada al iniciar la app
  bool _sessionChecked = false;

  /// Constructor que recibe la interfaz por inyección de dependencias
  UserController({IUserService? userService})
      : _userService = userService ?? UserService() {
    /// Verifica si hay sesión guardada al iniciar
    _checkSavedSession();
  }

  /// Getters para acceder al estado desde la UI
  UserModel? get currentUser => _currentUser;
  List<UserModel> get producers => _producers;
  List<UserModel> get admins => _admins;
  List<ScheduleModel> get producerSchedules => _producerSchedules;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get mustChangePassword => _mustChangePassword;
  bool get sessionChecked => _sessionChecked;

  /// Verifica si hay una sesión guardada al iniciar la app
  Future<void> _checkSavedSession() async {
    try {
      _isLoading = true;
      notifyListeners();

      final savedUser = await SessionHelper.getSession();

      if (savedUser != null) {
        final user = await _userService.getUserById(savedUser.id!);
        if (user != null && user.state == 1) {
          _currentUser = user;
        } else {
          await SessionHelper.clearSession();
        }
      }
    } catch (e) {
      print('Error al verificar sesión: $e');
    } finally {
      _isLoading = false;
      _sessionChecked = true;
      notifyListeners();
    }
  }

  /// Inicia sesión con email y password
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final user = await _userService.login(email, password);

      if (user == null) {
        _errorMessage = 'Email o contraseña incorrectos';
        return false;
      }

      _currentUser = user;
      await SessionHelper.saveSession(user);

      /// Verifica si la contraseña es temporal
      _mustChangePassword = EncryptionHelper.isTempPassword(password);

      return true;
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registra un nuevo cliente
  Future<bool> registerClient({
    required UserModel user,
    double? latitude,
    double? longitude,
    required String address,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      /// Verifica si el email ya existe
      final existingUser = await _userService.getUserByEmail(user.email);
      if (existingUser != null) {
        _errorMessage = 'El email ya está registrado';
        return false;
      }

      /// Crea el usuario con su ubicación
      final success = await _userService.createUser(
        user,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      if (!success) {
        _errorMessage = 'Error al registrar usuario';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error en el registro: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registra un nuevo productor con familias de productos y delivery mode
  Future<bool> registerProducer({
    required UserModel user,
    double? latitude,
    double? longitude,
    required String address,
    required int deliveryModeID,
    required List<int> familyIDs,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      /// Verifica si el email ya existe
      final existingUser = await _userService.getUserByEmail(user.email);
      if (existingUser != null) {
        _errorMessage = 'El email ya está registrado';
        return false;
      }

      /// Crea el usuario productor con su ubicación y delivery mode
      final success = await _userService.createUser(
        user,
        latitude: latitude,
        longitude: longitude,
        address: address,
        deliveryModeID: deliveryModeID,
      );

      if (!success) {
        _errorMessage = 'Error al registrar productor';
        return false;
      }

      /// Obtiene el ID del productor recién creado
      final producerID = await (_userService as UserService)
          .getUserIdByEmail(user.email);

      if (producerID == null) return false;

      /// Guarda las familias de productos seleccionadas
      final familiesSuccess = await _productFamilyService
          .saveProducerFamilies(producerID, familyIDs);

      if (!familiesSuccess) {
        _errorMessage = 'Error al guardar familias de productos';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error en el registro del productor: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getAllProducers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _producers = await _userService.getAllProducers();
    } catch (e) {
      _errorMessage = 'Error al cargar productores';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProducerSchedules() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentUser == null) {
        _errorMessage = 'No hay usuario logueado';
        return;
      }

      _producerSchedules =
      await _scheduleService.getSchedulesByProducerId(_currentUser!.id!);
    } catch (e) {
      _errorMessage = 'Error al cargar horarios del productor: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel?> getFreshCurrentUser() async {
    try {
      if (_currentUser == null || _currentUser!.id == null) {
        return null;
      }

      final freshUser = await _userService.getUserById(_currentUser!.id!);

      if (freshUser != null) {
        _currentUser = freshUser;
        await SessionHelper.saveSession(_currentUser!);
        notifyListeners();
      }

      return _currentUser;
    } catch (e) {
      _errorMessage = 'Error al refrescar usuario: $e';
      notifyListeners();
      return _currentUser;
    }
  }

  /// Cambia la contraseña del usuario actual
  Future<bool> changePassword(String newPassword) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentUser == null) {
        _errorMessage = 'No hay usuario logueado';
        return false;
      }

      if (newPassword.length < 8) {
        _errorMessage = 'La contraseña debe tener mínimo 8 caracteres';
        return false;
      }

      if (EncryptionHelper.isTempPassword(newPassword)) {
        _errorMessage = 'No puedes usar una contraseña temporal';
        return false;
      }

      final success = await (_userService as UserService).updatePassword(
        _currentUser!.id!,
        newPassword,
        _currentUser!.email,
        _currentUser!.name,
      );

      if (success) {
        _mustChangePassword = false;
        await SessionHelper.saveSession(_currentUser!);
      } else {
        _errorMessage = 'Error al cambiar la contraseña';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error al cambiar contraseña: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza el balance del usuario actual
  Future<bool> updateBalance(double amount) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentUser == null) {
        _errorMessage = 'No hay usuario logueado';
        return false;
      }

      final success =
          await _userService.updateBalance(_currentUser!.id!, amount);

      if (success) {
        _currentUser = UserModel(
          id: _currentUser!.id,
          name: _currentUser!.name,
          image: _currentUser!.image,
          balance: _currentUser!.balance + amount,
          email: _currentUser!.email,
          password: _currentUser!.password,
          description: _currentUser!.description,
          role: _currentUser!.role,
          cellphone: _currentUser!.cellphone,
          state: _currentUser!.state,
        );
        await SessionHelper.saveSession(_currentUser!);
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error al actualizar balance: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza el perfil del usuario actual (nombre, email, teléfono, imagen)
  Future<bool> updateProfile({
    required String name,
    required String email,
    required String cellphone,
    String? image,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentUser == null) {
        _errorMessage = 'No hay usuario logueado';
        return false;
      }

      if (name.trim().isEmpty) {
        _errorMessage = 'El nombre no puede estar vacío';
        return false;
      }

      if (email.trim().isEmpty) {
        _errorMessage = 'El correo no puede estar vacío';
        return false;
      }

      /// Si el email cambió, verifica que no esté en uso por otro usuario
      if (email.trim() != _currentUser!.email) {
        final existing = await _userService.getUserByEmail(email.trim());
        if (existing != null && existing.id != _currentUser!.id) {
          _errorMessage = 'Ese correo ya está en uso por otra cuenta';
          return false;
        }
      }

      final updatedUser = UserModel(
        id: _currentUser!.id,
        name: name.trim(),
        image: image ?? _currentUser!.image,
        balance: _currentUser!.balance,
        email: email.trim(),
        password: _currentUser!.password,
        description: _currentUser!.description,
        role: _currentUser!.role,
        cellphone: cellphone.trim().isEmpty ? null : cellphone.trim(),
        deliveryModeID: _currentUser!.deliveryModeID,
        pickUpLocationID: _currentUser!.pickUpLocationID,
        state: _currentUser!.state,
      );

      final success = await _userService.updateUserProfile(updatedUser);

      if (success) {
        _currentUser = updatedUser;
        await SessionHelper.saveSession(_currentUser!);
      } else {
        _errorMessage = 'Error al actualizar el perfil';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error al actualizar el perfil: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<bool> updateProducerProfile({
    required String name,
    required String email,
    required String cellphone,
    required String description,
    String? image,
    required List<ScheduleModel> schedules,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentUser == null) {
        _errorMessage = 'No hay usuario logueado';
        return false;
      }

      if (name.trim().isEmpty) {
        _errorMessage = 'El nombre no puede estar vacío';
        return false;
      }

      if (email.trim().isEmpty) {
        _errorMessage = 'El correo no puede estar vacío';
        return false;
      }

      if (description.trim().isEmpty) {
        _errorMessage = 'La descripción no puede estar vacía';
        return false;
      }

      if ((address?.trim().isNotEmpty ?? false) &&
          (latitude == null || longitude == null)) {
        _errorMessage = 'Debes seleccionar una ubicación válida en el mapa';
        return false;
      }

      if (email.trim() != _currentUser!.email) {
        final existing = await _userService.getUserByEmail(email.trim());
        if (existing != null && existing.id != _currentUser!.id) {
          _errorMessage = 'Ese correo ya está en uso por otra cuenta';
          return false;
        }
      }

      final updatedUser = UserModel(
        id: _currentUser!.id,
        name: name.trim(),
        image: image ?? _currentUser!.image,
        balance: _currentUser!.balance,
        email: email.trim(),
        password: _currentUser!.password,
        description: description.trim(),
        role: _currentUser!.role,
        cellphone: cellphone.trim().isEmpty ? null : cellphone.trim(),
        deliveryModeID: _currentUser!.deliveryModeID,
        pickUpLocationID: _currentUser!.pickUpLocationID,
        state: _currentUser!.state,
      );

      final success = await (_userService as UserService).updateProducerProfileData(
        user: updatedUser,
        latitude: latitude,
        longitude: longitude,
        address: address?.trim(),
      );

      if (!success) {
        _errorMessage = 'Error al actualizar el perfil del productor';
        return false;
      }

      final schedulesSuccess = await _scheduleService.saveProducerSchedules(
        _currentUser!.id!,
        schedules,
      );

      if (!schedulesSuccess) {
        _errorMessage =
        'Se actualizó el perfil, pero ocurrió un error al guardar los horarios';
        return false;
      }

      final refreshedUser = await _userService.getUserById(_currentUser!.id!);
      _currentUser = refreshedUser ?? updatedUser;
      _producerSchedules = schedules;
      await SessionHelper.saveSession(_currentUser!);

      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar el perfil del productor: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cambia la contraseña verificando primero la contraseña actual
  Future<bool> changePasswordWithVerification({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentUser == null) {
        _errorMessage = 'No hay usuario logueado';
        return false;
      }

      if (!EncryptionHelper.verifyPassword(currentPassword, _currentUser!.password)) {
        _errorMessage = 'La contraseña actual es incorrecta';
        return false;
      }

      if (newPassword.length < 8) {
        _errorMessage = 'La nueva contraseña debe tener mínimo 8 caracteres';
        return false;
      }

      if (newPassword != confirmPassword) {
        _errorMessage = 'Las contraseñas nuevas no coinciden';
        return false;
      }

      if (EncryptionHelper.isTempPassword(newPassword)) {
        _errorMessage = 'No puedes usar una contraseña temporal';
        return false;
      }

      final success = await (_userService as UserService).updatePassword(
        _currentUser!.id!,
        newPassword,
        _currentUser!.email,
        _currentUser!.name,
      );

      if (!success) _errorMessage = 'Error al cambiar la contraseña';

      return success;
    } catch (e) {
      _errorMessage = 'Error al cambiar contraseña: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------- ADMINS CRUD

  /// Carga todos los administradores del sistema
  Future<void> loadAdmins() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      _admins = await _userService.getAllAdmins();
    } catch (e) {
      _errorMessage = 'Error al cargar administradores';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Crea un nuevo administrador con contraseña directa
  Future<bool> createAdmin({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required int state,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (name.trim().isEmpty) {
        _errorMessage = 'El nombre no puede estar vacío';
        return false;
      }
      if (email.trim().isEmpty) {
        _errorMessage = 'El correo no puede estar vacío';
        return false;
      }
      if (password.length < 8) {
        _errorMessage = 'La contraseña debe tener mínimo 8 caracteres';
        return false;
      }
      if (password != confirmPassword) {
        _errorMessage = 'Las contraseñas no coinciden';
        return false;
      }

      final existing = await _userService.getUserByEmail(email.trim());
      if (existing != null) {
        _errorMessage = 'Ese correo ya está registrado';
        return false;
      }

      final newAdmin = UserModel(
        name: name.trim(),
        email: email.trim(),
        password: '',
        role: 2,
        state: state,
      );

      final success = await _userService.createAdminUser(newAdmin, password);
      if (success) {
        await loadAdmins();
      } else {
        _errorMessage = 'Error al crear el administrador';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error al crear administrador: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza los datos de un administrador existente
  Future<bool> updateAdminUser({
    required UserModel admin,
    required String name,
    required String email,
    required String cellphone,
    required int state,
    String? newPassword,
    String? confirmPassword,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (name.trim().isEmpty) {
        _errorMessage = 'El nombre no puede estar vacío';
        return false;
      }
      if (email.trim().isEmpty) {
        _errorMessage = 'El correo no puede estar vacío';
        return false;
      }

      if (newPassword != null && newPassword.isNotEmpty) {
        if (newPassword.length < 8) {
          _errorMessage = 'La contraseña debe tener mínimo 8 caracteres';
          return false;
        }
        if (newPassword != confirmPassword) {
          _errorMessage = 'Las contraseñas no coinciden';
          return false;
        }
      }

      if (email.trim() != admin.email) {
        final existing = await _userService.getUserByEmail(email.trim());
        if (existing != null && existing.id != admin.id) {
          _errorMessage = 'Ese correo ya está en uso';
          return false;
        }
      }

      final updated = UserModel(
        id: admin.id,
        name: name.trim(),
        email: email.trim(),
        password: admin.password,
        role: 2,
        cellphone: cellphone.trim().isEmpty ? null : cellphone.trim(),
        state: state,
        image: admin.image,
        balance: admin.balance,
        description: admin.description,
      );

      final success = await _userService.updateAdmin(
        updated,
        newPassword: (newPassword != null && newPassword.isNotEmpty)
            ? newPassword
            : null,
      );

      if (success) {
        await loadAdmins();
      } else {
        _errorMessage = 'Error al actualizar el administrador';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error al actualizar administrador: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina lógicamente un administrador
  Future<bool> deleteAdminUser(int id) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _userService.deleteAdmin(id);
      if (success) {
        await loadAdmins();
      } else {
        _errorMessage = 'Error al eliminar el administrador';
      }
      return success;
    } catch (e) {
      _errorMessage = 'Error al eliminar administrador: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cierra la sesión del usuario actual
  Future<void> logout() async {
    await SessionHelper.clearSession();
    _currentUser = null;
    _errorMessage = null;
    _mustChangePassword = false;
    _producerSchedules = [];
    notifyListeners();
  }
  /// Envía el código de recuperación al email del usuario
Future<bool> sendResetCode(String email) async {
  try {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    /// Verifica que el email exista en la BD
    final user = await _userService.getUserByEmail(email);
    if (user == null) {
      _errorMessage = 'No existe una cuenta con ese email';
      return false;
    }

    /// Elimina tokens anteriores del usuario
    await _passwordResetService.deleteUserTokens(user.id!);

    /// Genera un código de 6 dígitos aleatorio
    final random = Random();
    final code = (100000 + random.nextInt(900000)).toString();

    /// Crea el token con expiración de 15 minutos
    final token = PasswordResetTokenModel(
      token: code,
      userID: user.id!,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    );

    /// Guarda el token primero
final created = await _passwordResetService.createToken(token);
if (!created) {
  _errorMessage = 'Error al generar el código';
  return false;
}

/// Envía el email con timeout extendido en segundo plano
Future(() async {
  try {
    await EmailHelper.sendResetCode(
      toEmail: email,
      userName: user.name,
      code: code,
    ).timeout(const Duration(seconds: 60));
  } catch (e) {
    print('Error enviando email reset: $e');
  }
});

return true;

  } catch (e) {
    _errorMessage = 'Error al enviar el código: $e';
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

/// Verifica el código ingresado por el usuario
Future<bool> verifyResetCode(String email, String code) async {
  try {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    print('Email: ${email}');
print('Código ingresado: "$code"');
    /// Obtiene el usuario por email
    final user = await _userService.getUserByEmail(email);
    if (user == null) {
      _errorMessage = 'No existe una cuenta con ese email';
      return false;
    }

    /// Verifica que el token sea válido
    final token = await _passwordResetService.getValidToken(user.id!, code);
    if (token == null) {
      _errorMessage = 'Código inválido o expirado';
      return false;
    }

    /// Guarda el usuario temporalmente para el cambio de contraseña
    _currentUser = user;

    return true;
  } catch (e) {
    _errorMessage = 'Error al verificar el código: $e';
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

/// Completa el reset de contraseña marcando el token como usado
Future<bool> completePasswordReset(String email, String code, String newPassword) async {
  try {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final user = await _userService.getUserByEmail(email);
    if (user == null) {
      _errorMessage = 'No existe una cuenta con ese email';
      return false;
    }

    /// Verifica el token una última vez antes de cambiar
    final token = await _passwordResetService.getValidToken(user.id!, code);
    if (token == null) {
      _errorMessage = 'Código inválido o expirado';
      return false;
    }

    if (newPassword.length < 8) {
      _errorMessage = 'La contraseña debe tener mínimo 8 caracteres';
      return false;
    }

    /// Actualiza la contraseña
    final success = await (_userService as UserService).updatePassword(
      user.id!,
      newPassword,
      user.email,
      user.name,
    );

    if (!success) {
      _errorMessage = 'Error al actualizar la contraseña';
      return false;
    }

    /// Marca el token como usado
    await _passwordResetService.markTokenAsUsed(token.id!);

    return true;
  } catch (e) {
    _errorMessage = 'Error al restablecer la contraseña: $e';
    return false;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
}