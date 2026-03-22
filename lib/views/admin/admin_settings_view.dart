import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../auth/login_view.dart';

/// Vista de Configuraciones del Administrador
/// Permite actualizar perfil, cambiar contraseña y cerrar sesión
class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  static const _primary = Color(0xFFB8860B);
  static const _background = Color(0xFFF5F0E8);
  static const _textPrimary = Color(0xFF2D2D2D);
  static const _textSecondary = Color(0xFF888888);

  // --- Perfil ---
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // --- Contraseña ---
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
        _emailController.text = user.email;
        _phoneController.text = user.cellphone ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ helpers

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

  Widget _sectionCard({required String title, required List<Widget> children}) {
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ----------------------------------------------------------------- actions

  Future<void> _onSaveProfile() async {
    setState(() => _savingProfile = true);
    final controller = Provider.of<UserController>(context, listen: false);

    final ok = await controller.updateProfile(
      name: _nameController.text,
      email: _emailController.text,
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

  Future<void> _onLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  void _onChangePhoto() {
    showDialog(
      context: context,
      builder: (ctx) {
        final urlCtrl = TextEditingController(
          text: Provider.of<UserController>(context, listen: false)
                  .currentUser
                  ?.image ??
              '',
        );
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('URL de la foto'),
          content: TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: _textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final controller =
                    Provider.of<UserController>(context, listen: false);
                final user = controller.currentUser;
                if (user == null) return;
                await controller.updateProfile(
                  name: user.name,
                  email: user.email,
                  cellphone: user.cellphone ?? '',
                  image: urlCtrl.text.trim().isEmpty
                      ? null
                      : urlCtrl.text.trim(),
                );
                if (mounted) {
                  _showMessage('Foto actualizada');
                }
              },
              child: const Text('Guardar',
                  style: TextStyle(color: _primary)),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------- build

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
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined,
                color: _textPrimary),
          ),
          Consumer<UserController>(
            builder: (_, ctrl, __) {
              final img = ctrl.currentUser?.image;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFD4A017),
                  backgroundImage:
                      (img != null && img.isNotEmpty) ? NetworkImage(img) : null,
                  child: (img == null || img.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white, size: 18)
                      : null,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // ---- SECCIÓN PERFIL ----
            _sectionCard(
              title: 'Información del Perfil',
              children: [
                // Avatar
                Center(
                  child: Stack(
                    children: [
                      Consumer<UserController>(
                        builder: (_, ctrl, __) {
                          final img = ctrl.currentUser?.image;
                          return CircleAvatar(
                            radius: 46,
                            backgroundColor: const Color(0xFFD4A017),
                            backgroundImage: (img != null && img.isNotEmpty)
                                ? NetworkImage(img)
                                : null,
                            child: (img == null || img.isEmpty)
                                ? const Icon(Icons.person,
                                    color: Colors.white, size: 44)
                                : null,
                          );
                        },
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _onChangePhoto,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _onChangePhoto,
                    child: const Text(
                      'Cambiar foto',
                      style: TextStyle(color: _primary, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Nombre
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Nombre completo'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),

                // Correo
                TextField(
                  controller: _emailController,
                  decoration: _inputDecoration('Correo electrónico'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),

                // Teléfono
                TextField(
                  controller: _phoneController,
                  decoration: _inputDecoration('Teléfono'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // Cargo (solo lectura)
                TextField(
                  enabled: false,
                  decoration: _inputDecoration('Cargo').copyWith(
                    hintText: 'Super Administrador',
                    filled: true,
                    fillColor: const Color(0xFFF5F0E8),
                  ),
                  controller:
                      TextEditingController(text: 'Super Administrador'),
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

            // ---- SECCIÓN CONTRASEÑA ----
            _sectionCard(
              title: 'Cambiar Contraseña',
              children: [
                // Contraseña actual
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

                // Nueva contraseña
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

                // Confirmar nueva contraseña
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

            // ---- SECCIÓN SESIÓN ----
            Container(
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
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: const Text(
                  'Cerrar sesión en todos los dispositivos',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary),
                ),
                subtitle: const Text(
                  'Cierre todas las sesiones activas',
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: _textSecondary),
                onTap: _onLogout,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const SizedBox(height: 16),

            // ---- BOTÓN CERRAR SESIÓN ----
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
