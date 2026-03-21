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

  /// Usuario actualmente logueado
  UserModel? _currentUser;

  List<UserModel> _producers = [];

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

  /// Cierra la sesión del usuario actual
  Future<void> logout() async {
    await SessionHelper.clearSession();
    _currentUser = null;
    _errorMessage = null;
    _mustChangePassword = false;
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