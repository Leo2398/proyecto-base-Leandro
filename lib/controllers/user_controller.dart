import '../models/user_model.dart';
import '../services/interfaces/i_user_service.dart';
import '../services/user_service.dart';
import '../core/encryption_helper.dart';
import '../core/session_helper.dart';
import 'package:flutter/material.dart';

/// Controlador de Usuario
/// Principio S de SOLID: solo maneja la lógica de negocio de usuarios
/// Principio D de SOLID: depende de la interfaz IUserService
/// no de la implementación concreta
/// Implementa ChangeNotifier para el patrón Observer,
/// notifica a la UI cuando hay cambios
class UserController extends ChangeNotifier {
  /// Dependencia de la interfaz, no de la implementación (principio D)
  final IUserService _userService;

  /// Usuario actualmente logueado
  UserModel? _currentUser;

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
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get mustChangePassword => _mustChangePassword;
  bool get sessionChecked => _sessionChecked;

  /// Verifica si hay una sesión guardada al iniciar la app
  /// Si existe, restaura el usuario sin necesidad de login
  Future<void> _checkSavedSession() async {
    try {
      _isLoading = true;
      notifyListeners();

      /// Intenta obtener la sesión guardada
      final savedUser = await SessionHelper.getSession();

      if (savedUser != null) {
        /// Verifica que el usuario siga activo en la BD
        final user = await _userService.getUserById(savedUser.id!);
        if (user != null && user.state == 1) {
          _currentUser = user;
        } else {
          /// Si el usuario fue desactivado, limpia la sesión
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
  /// Verifica si la contraseña es temporal y obliga al cambio
  Future<bool> login(String email, String password) async {
    try {
      /// Activa el indicador de carga y notifica a la UI
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      /// Verifica credenciales en la BD
      final user = await _userService.login(email, password);

      if (user == null) {
        _errorMessage = 'Email o contraseña incorrectos';
        return false;
      }

      /// Guarda el usuario logueado
      _currentUser = user;

      /// Guarda la sesión en el almacenamiento local
      await SessionHelper.saveSession(user);

      /// Verifica si la contraseña es temporal
      /// Si empieza con 1pc el usuario debe cambiarla obligatoriamente
      _mustChangePassword = EncryptionHelper.isTempPassword(password);

      return true;
    } catch (e) {
      _errorMessage = 'Error al iniciar sesión: $e';
      return false;
    } finally {
      /// Desactiva el indicador de carga y notifica a la UI
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registra un nuevo usuario
  /// La contraseña temporal se genera y envía automáticamente
  Future<bool> register(UserModel user) async {
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

      /// Crea el usuario en la BD
      /// El servicio genera la contraseña temporal y la envía por email
      final success = await _userService.createUser(user);
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

  /// Cambia la contraseña del usuario actual
  /// Se usa cuando el usuario tiene contraseña temporal
  Future<bool> changePassword(String newPassword) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (_currentUser == null) {
        _errorMessage = 'No hay usuario logueado';
        return false;
      }

      /// Validación mínima de contraseña
      if (newPassword.length < 8) {
        _errorMessage = 'La contraseña debe tener mínimo 8 caracteres';
        return false;
      }

      /// Verifica que la nueva contraseña no sea temporal
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
        /// Ya no necesita cambiar la contraseña
        _mustChangePassword = false;
        /// Actualiza la sesión guardada
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
        /// Actualiza el balance localmente sin consultar la BD de nuevo
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
        /// Actualiza la sesión guardada con el nuevo balance
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
  /// Limpia la sesión guardada en el almacenamiento local
  Future<void> logout() async {
    await SessionHelper.clearSession();
    _currentUser = null;
    _errorMessage = null;
    _mustChangePassword = false;
    notifyListeners();
  }
}