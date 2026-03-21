import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import 'role_selection_view.dart';
import 'change_password_view.dart';
import '../client/client_dashboard_view.dart';
import 'forgot_password_view.dart';
import '../admin/admin_dashboard_view.dart';
import '../producer/producer_dashboard_view.dart';
/// Pantalla de inicio de sesión
/// Principio S de SOLID: solo maneja la UI del login
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  /// Controladores para los campos de texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// Clave del formulario para validaciones
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controla si la contraseña es visible o no
  bool _isPasswordVisible = false;

  /// Controla el checkbox de recordarme
  bool _rememberMe = false;

  /// Libera los recursos al destruir el widget
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Maneja el inicio de sesión
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = Provider.of<UserController>(context, listen: false);
    final success = await controller.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
  if (controller.mustChangePassword) {
    /// Si la contraseña es temporal navega al cambio de contraseña
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordView(),
      ),
    );
  } else {
      if (controller.currentUser!.role == 0) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ClientDashboardView(),
      ),
    );
  }
      else if (controller.currentUser!.role == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ProducerDashboardView(),
          ),
        );
      }
  else if (controller.currentUser!.role == 2) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminDashboardView(),
      ),
    );
  }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inicio de sesión exitoso')),
    );
  }
} else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Error al iniciar sesión'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Obtiene el tamaño de la pantalla para evitar overflow
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      /// Color de fondo beige como en el diseño
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight),
            child: IntrinsicHeight(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    /// Icono de la app
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A8A5A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.shopping_basket_outlined,
                        color: Color(0xFFF5F0E8),
                        size: 45,
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// Título de bienvenida
                    const Text(
                      '¡Bienvenido!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),

                    const SizedBox(height: 8),

                    /// Subtítulo
                    const Text(
                      'Inicia sesión para realizar tus pedidos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF888888),
                      ),
                    ),

                    const SizedBox(height: 32),

                    /// Tarjeta del formulario
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Label correo
                          const Text(
                            'Correo electrónico',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 8),

                          /// Campo de correo
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'tu@email.com',
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xFF888888),
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
                                return 'Ingresa tu correo';
                              }
                              if (!value.contains('@')) {
                                return 'Ingresa un correo válido';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          /// Label contraseña
                          const Text(
                            'Contraseña',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 8),

                          /// Campo de contraseña
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF888888),
                              ),
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
                                return 'Ingresa tu contraseña';
                              }
                              if (value.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          /// Recordarme y olvidaste contraseña
                          /// Recordarme y olvidaste contraseña
Column(
  children: [
    Row(
      children: [
        Checkbox(
          value: _rememberMe,
          activeColor: const Color(0xFF5A8A5A),
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
        ),
        const Text(
          'Recordarme',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF2D2D2D),
          ),
        ),
      ],
    ),
    TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordView(),
      ),
    );
  },
  child: const Text(
    '¿Olvidaste tu contraseña?',
    style: TextStyle(
      fontSize: 13,
      color: Color(0xFF5A8A5A),
    ),
  ),
),
  ],
),

                          const SizedBox(height: 16),

                          /// Botón de iniciar sesión
                          Consumer<UserController>(
                            builder: (context, controller, child) {
                              return SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: controller.isLoading
                                      ? null
                                      : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5A8A5A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: controller.isLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Text(
                                          'Iniciar Sesión',
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

                    const SizedBox(height: 24),

                    /// Registro
                    Column(
                      children: [
                        const Text(
                          '¿No tienes una cuenta?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF888888),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RoleSelectionView(),
                              ),
                            );
                          },
                          child: const Text(
                            'Regístrate aquí',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5A8A5A),
                            ),
                          ),
                        ),
                      ],
                    ),

                    /// Términos de servicio
                    Column(
                      children: [
                        const Text(
                          'Al iniciar sesión, aceptas nuestros',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: navegar a términos de servicio
                          },
                          child: const Text(
                            'Términos de Servicio',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5A8A5A),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}