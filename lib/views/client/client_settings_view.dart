import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../auth/login_view.dart';

/// Vista de configuraciones del cliente
/// Principio S de SOLID: solo maneja la UI de configuraciones del cliente
class ClientSettingsView extends StatefulWidget {
  const ClientSettingsView({super.key});

  @override
  State<ClientSettingsView> createState() => _ClientSettingsViewState();
}

class _ClientSettingsViewState extends State<ClientSettingsView> {
  static const _primary = Color(0xFF5A8A5A);
  static const _background = Color(0xFFF5F0E8);
  static const _textPrimary = Color(0xFF2D2D2D);
  static const _textSecondary = Color(0xFF888888);

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _showCurrentPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;
  bool _savingProfile = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user =
          Provider.of<UserController>(context, listen: false).currentUser;
      if (user != null) {
        _nameController.text = user.name;
        _phoneController.text = user.cellphone ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0D9CC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _sectionCard(
      {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  void _showMessage(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Guarda los cambios del perfil
  Future<void> _onSaveProfile() async {
    setState(() => _savingProfile = true);
    final controller = Provider.of<UserController>(context, listen: false);

    final ok = await controller.updateProfile(
      name: _nameController.text,
      email: controller.currentUser!.email,
      cellphone: _phoneController.text,
    );

    if (!mounted) return;
    setState(() => _savingProfile = false);

    if (ok) {
      _showMessage('Perfil actualizado correctamente');
    } else {
      _showMessage(
          controller.errorMessage ?? 'Error al guardar cambios',
          error: true);
    }
  }

  /// Cambia la contraseña verificando la actual
  Future<void> _onChangePassword() async {
    setState(() => _savingPassword = true);
    final controller = Provider.of<UserController>(context, listen: false);

    final ok = await controller.changePasswordWithVerification(
      currentPassword: _currentPassController.text,
      newPassword: _newPassController.text,
      confirmPassword: _confirmPassController.text,
    );

    if (!mounted) return;
    setState(() => _savingPassword = false);

    if (ok) {
      _currentPassController.clear();
      _newPassController.clear();
      _confirmPassController.clear();
      _showMessage('Contraseña actualizada correctamente');
    } else {
      _showMessage(
          controller.errorMessage ?? 'Error al cambiar la contraseña',
          error: true);
    }
  }

  /// Cierra sesión con confirmación
  Future<void> _onLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión'),
        content:
            const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final controller = Provider.of<UserController>(context, listen: false);
    await controller.logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configuraciones',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            /// Sección perfil
            _sectionCard(
              title: 'Información del Perfil',
              children: [
                /// Avatar con inicial del nombre
                Consumer<UserController>(
                  builder: (_, ctrl, __) {
                    final name = ctrl.currentUser?.name ?? '';
                    final initial =
                        name.isNotEmpty ? name[0].toUpperCase() : '?';
                    return Center(
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: _primary,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                /// Nombre
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Nombre completo'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),

                /// Teléfono
                TextField(
                  controller: _phoneController,
                  decoration: _inputDecoration('Teléfono'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                /// Email solo lectura
                Consumer<UserController>(
                  builder: (_, ctrl, __) {
                    return TextField(
                      enabled: false,
                      decoration:
                          _inputDecoration('Correo electrónico').copyWith(
                        filled: true,
                        fillColor: const Color(0xFFF5F0E8),
                      ),
                      controller: TextEditingController(
                          text: ctrl.currentUser?.email ?? ''),
                    );
                  },
                ),

                const SizedBox(height: 20),

                _primaryButton(
                  label: 'Guardar cambios',
                  loading: _savingProfile,
                  onPressed: _onSaveProfile,
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// Sección contraseña
            _sectionCard(
              title: 'Cambiar Contraseña',
              children: [
                TextField(
                  controller: _currentPassController,
                  obscureText: !_showCurrentPass,
                  decoration: _inputDecoration(
                    'Contraseña actual',
                    suffix: IconButton(
                      icon: Icon(
                        _showCurrentPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _showCurrentPass = !_showCurrentPass),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _newPassController,
                  obscureText: !_showNewPass,
                  decoration: _inputDecoration(
                    'Nueva contraseña',
                    suffix: IconButton(
                      icon: Icon(
                        _showNewPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _showNewPass = !_showNewPass),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _confirmPassController,
                  obscureText: !_showConfirmPass,
                  decoration: _inputDecoration(
                    'Confirmar nueva contraseña',
                    suffix: IconButton(
                      icon: Icon(
                        _showConfirmPass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _showConfirmPass = !_showConfirmPass),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _primaryButton(
                  label: 'Actualizar contraseña',
                  loading: _savingPassword,
                  onPressed: _onChangePassword,
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// Botón cerrar sesión
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _onLogout,
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Cerrar sesión',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  side: const BorderSide(color: Color(0xFFD0C8B8)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}