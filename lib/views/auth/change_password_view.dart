import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';

/// Pantalla de cambio de contraseña temporal
/// Principio S de SOLID: solo maneja la UI del cambio de contraseña
class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  /// Controladores para los campos de texto
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// Clave del formulario para validaciones
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controla si las contraseñas son visibles
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  /// Validaciones en tiempo real
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasNumber = false;

  /// Libera los recursos al destruir el widget
  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Valida los requisitos de la contraseña en tiempo real
  void _validatePassword(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasUpperCase = value.contains(RegExp(r'[A-Z]'));
      _hasNumber = value.contains(RegExp(r'[0-9]'));
    });
  }

  /// Maneja el cambio de contraseña
  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = Provider.of<UserController>(context, listen: false);
    final success =
        await controller.changePassword(_passwordController.text.trim());

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada exitosamente'),
          backgroundColor: Color(0xFF5A8A5A),
        ),
      );
      /// TODO: navegar al dashboard según el rol
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(controller.errorMessage ?? 'Error al cambiar contraseña'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      /// Evita que el usuario regrese sin cambiar la contraseña
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              const SizedBox(height: 40),

              /// Icono superior
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A8A5A),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 35,
                ),
              ),

              const SizedBox(height: 24),

              /// Título
              const Text(
                'Crea tu contraseña',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),

              const SizedBox(height: 8),

              /// Subtítulo
              const Text(
                'Por seguridad, debes establecer una nueva\ncontraseña para continuar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF888888),
                ),
              ),

              const SizedBox(height: 32),

              /// Formulario
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Label nueva contraseña
                      const Text(
                        'Nueva contraseña',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),

                      const SizedBox(height: 8),

                      /// Campo nueva contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        onChanged: _validatePassword,
                        decoration: InputDecoration(
                          hintText: 'Ingresa tu nueva contraseña',
                          hintStyle:
                              const TextStyle(color: Color(0xFFAAAAAA)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF888888),
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F0E8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu nueva contraseña';
                          }
                          if (value.length < 8) {
                            return 'Mínimo 8 caracteres';
                          }
                          if (!value.contains(RegExp(r'[A-Z]'))) {
                            return 'Debe tener al menos una mayúscula';
                          }
                          if (!value.contains(RegExp(r'[0-9]'))) {
                            return 'Debe tener al menos un número';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      /// Indicadores de requisitos en tiempo real
                      _buildRequirement('Mínimo 8 caracteres', _hasMinLength),
                      _buildRequirement(
                          'Al menos una letra mayúscula', _hasUpperCase),
                      _buildRequirement('Al menos un número', _hasNumber),

                      const SizedBox(height: 16),

                      /// Label confirmar contraseña
                      const Text(
                        'Confirmar contraseña',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),

                      const SizedBox(height: 8),

                      /// Campo confirmar contraseña
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_isConfirmPasswordVisible,
                        decoration: InputDecoration(
                          hintText: 'Confirma tu contraseña',
                          hintStyle:
                              const TextStyle(color: Color(0xFFAAAAAA)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF888888),
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F0E8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirma tu contraseña';
                          }
                          if (value != _passwordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      /// Botón guardar
                      Consumer<UserController>(
                        builder: (context, controller, child) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: controller.isLoading
                                  ? null
                                  : _handleChangePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5A8A5A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: controller.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
                                      'Guardar y continuar',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget para mostrar los requisitos de la contraseña en tiempo real
  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? const Color(0xFF5A8A5A) : const Color(0xFF888888),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? const Color(0xFF5A8A5A) : const Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}