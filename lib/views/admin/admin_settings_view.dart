import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../auth/login_view.dart';

/// Vista de Configuraciones del Administrador.
/// Permite actualizar perfil, cambiar contraseña, cambiar foto y cerrar sesión.
class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  static const Color _primary = Color(0xFFB8860B);
  static const Color _primaryDark = Color(0xFF6F4C00);
  static const Color _primarySoft = Color(0xFFFFF3D4);
  static const Color _background = Color(0xFFF5F0E8);
  static const Color _card = Color(0xFFFFFCF7);
  static const Color _textPrimary = Color(0xFF2D2418);
  static const Color _textSecondary = Color(0xFF8B7D6B);
  static const Color _border = Color(0xFFE5D8C5);
  static const Color _success = Color(0xFF2E7D32);
  static const Color _danger = Color(0xFFC62828);

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  // Perfil
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Contraseña
  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _showCurrentPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _savingPhoto = false;

  bool get _busy => _savingProfile || _savingPassword || _savingPhoto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
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

  void _loadUserData() {
    final user = Provider.of<UserController>(context, listen: false).currentUser;
    if (user == null) return;

    _nameController.text = user.name;
    _emailController.text = user.email;
    _phoneController.text = user.cellphone ?? '';
  }

  String _clean(String value) => value.trim();

  ImageProvider? _imageProvider(String? img) {
    if (img == null || img.trim().isEmpty) return null;

    final raw = img.trim();

    try {
      if (raw.startsWith('http')) {
        return NetworkImage(raw);
      }

      final file = File(raw);
      if (file.existsSync()) {
        return FileImage(file);
      }

      final base64Value = raw.contains(',') ? raw.split(',').last.trim() : raw;
      return MemoryImage(base64Decode(base64Value));
    } catch (_) {
      return null;
    }
  }

  void _showMessage(String msg, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: error ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    final text = _clean(value ?? '');
    if (text.isEmpty) return 'Ingrese su nombre completo';
    if (text.length < 3) return 'El nombre es demasiado corto';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = _clean(value ?? '');
    if (text.isEmpty) return 'Ingrese su correo electrónico';

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(text)) {
      return 'Ingrese un correo válido';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final text = _clean(value ?? '');
    if (text.isEmpty) return null;
    if (text.length < 7) return 'Ingrese un teléfono válido';
    return null;
  }

  String? _validateCurrentPassword(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Ingrese su contraseña actual';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) return 'Ingrese la nueva contraseña';
    if (text.length < 8) return 'Debe tener mínimo 8 caracteres';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) return 'Confirme la nueva contraseña';
    if (text != _newPassController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 10, right: 8),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _primarySoft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _primaryDark, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(
        minWidth: 58,
        minHeight: 54,
      ),
      suffixIcon: suffix,
      labelStyle: const TextStyle(
        color: _textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFFC3B7A6),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _danger, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _border),
      ),
      errorStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _onSaveProfile() async {
    FocusScope.of(context).unfocus();

    final valid = _profileFormKey.currentState?.validate() ?? false;
    if (!valid) {
      _showMessage('Revise los datos del perfil', error: true);
      return;
    }

    setState(() => _savingProfile = true);

    final controller = Provider.of<UserController>(context, listen: false);

    final ok = await controller.updateProfile(
      name: _clean(_nameController.text),
      email: _clean(_emailController.text),
      cellphone: _clean(_phoneController.text),
    );

    if (!mounted) return;
    setState(() => _savingProfile = false);

    if (ok) {
      _showMessage('Perfil actualizado correctamente');
    } else {
      _showMessage(
        controller.errorMessage ?? 'Error al guardar cambios',
        error: true,
      );
    }
  }

  Future<void> _onChangePassword() async {
    FocusScope.of(context).unfocus();

    final valid = _passwordFormKey.currentState?.validate() ?? false;
    if (!valid) {
      _showMessage('Revise los datos de la contraseña', error: true);
      return;
    }

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
      _passwordFormKey.currentState?.reset();
      _showMessage('Contraseña actualizada correctamente');
    } else {
      _showMessage(
        controller.errorMessage ?? 'Error al cambiar la contraseña',
        error: true,
      );
    }
  }

  Future<void> _onChangePhoto() async {
    if (_busy) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSourceSheet(
        primary: _primary,
        primarySoft: _primarySoft,
        textPrimary: _textPrimary,
        textSecondary: _textSecondary,
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (picked == null || !mounted) return;

    setState(() => _savingPhoto = true);

    final controller = Provider.of<UserController>(context, listen: false);
    final user = controller.currentUser;

    if (user == null) {
      setState(() => _savingPhoto = false);
      _showMessage('No se encontró el usuario actual', error: true);
      return;
    }

    final ok = await controller.updateProfile(
      name: _clean(_nameController.text.isNotEmpty ? _nameController.text : user.name),
      email: _clean(_emailController.text.isNotEmpty ? _emailController.text : user.email),
      cellphone: _clean(
        _phoneController.text.isNotEmpty
            ? _phoneController.text
            : (user.cellphone ?? ''),
      ),
      image: picked.path,
    );

    if (!mounted) return;
    setState(() => _savingPhoto = false);

    _showMessage(
      ok ? 'Foto actualizada correctamente' : controller.errorMessage ?? 'Error al actualizar la foto',
      error: !ok,
    );
  }

  Future<void> _onLogout() async {
    if (_busy) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _danger.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cerrar sesión',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Estás seguro de que quieres salir de tu cuenta administrativa?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Salir',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Future<bool> _onWillPop() async {
    if (_busy) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _background,
        body: Stack(
          children: [
            const _BackgroundDecoration(),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      child: Column(
                        children: [
                          _buildProfileHero(),
                          const SizedBox(height: 18),
                          _buildProfileSection(),
                          const SizedBox(height: 18),
                          _buildPasswordSection(),
                          const SizedBox(height: 18),
                          _buildSecuritySection(),
                          const SizedBox(height: 14),
                          _buildLogoutButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 6),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: _busy ? null : () => Navigator.pop(context),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _textPrimary,
                  size: 19,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Configuraciones',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Consumer<UserController>(
            builder: (_, ctrl, __) {
              final imgProvider = _imageProvider(ctrl.currentUser?.image);

              return Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_primary, Color(0xFFFFD978)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  backgroundImage: imgProvider,
                  child: imgProvider == null
                      ? const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: _primaryDark,
                    size: 21,
                  )
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHero() {
    return Consumer<UserController>(
      builder: (_, ctrl, __) {
        final user = ctrl.currentUser;
        final imgProvider = _imageProvider(user?.image);
        final name = user?.name ?? 'Administrador';
        final email = user?.email ?? 'Sin correo registrado';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF3B2A12),
                Color(0xFF9B6B05),
                Color(0xFFD8A31D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryDark.withOpacity(0.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -34,
                top: -40,
                child: _circleDecoration(118, Colors.white.withOpacity(0.10)),
              ),
              Positioned(
                left: -26,
                bottom: -55,
                child: _circleDecoration(112, Colors.white.withOpacity(0.07)),
              ),
              Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.30),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          backgroundImage: imgProvider,
                          child: imgProvider == null
                              ? const Icon(
                            Icons.person_rounded,
                            color: _primaryDark,
                            size: 50,
                          )
                              : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: _busy ? null : _onChangePhoto,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFE0A0),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: _savingPhoto
                              ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                              : const Icon(
                            Icons.photo_camera_rounded,
                            color: _primaryDark,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.84),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: const [
                      _HeroBadge(
                        icon: Icons.verified_user_rounded,
                        label: 'Administrador',
                      ),
                      _HeroBadge(
                        icon: Icons.shield_rounded,
                        label: 'Acceso seguro',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSection() {
    return _SectionCard(
      icon: Icons.manage_accounts_rounded,
      title: 'Información del perfil',
      subtitle: 'Actualiza tus datos personales y datos de contacto.',
      child: Form(
        key: _profileFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: _validateName,
              decoration: _inputDecoration(
                label: 'Nombre completo',
                hint: 'Ej: Juan Pérez',
                icon: Icons.person_rounded,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              decoration: _inputDecoration(
                label: 'Correo electrónico',
                hint: 'usuario@ejemplo.com',
                icon: Icons.alternate_email_rounded,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: _validatePhone,
              decoration: _inputDecoration(
                label: 'Teléfono',
                hint: 'Ej: 71234567',
                icon: Icons.phone_rounded,
              ),
            ),
            const SizedBox(height: 14),
            _ReadOnlyInfoTile(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Cargo',
              value: 'Super Administrador',
            ),
            const SizedBox(height: 20),
            _PrimaryButton(
              label: 'Guardar cambios',
              icon: Icons.save_rounded,
              loading: _savingProfile,
              onPressed: _busy && !_savingProfile ? null : _onSaveProfile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return _SectionCard(
      icon: Icons.lock_rounded,
      title: 'Cambiar contraseña',
      subtitle: 'Usa una contraseña segura para proteger tu cuenta.',
      child: Form(
        key: _passwordFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _currentPassController,
              obscureText: !_showCurrentPass,
              textInputAction: TextInputAction.next,
              validator: _validateCurrentPassword,
              decoration: _inputDecoration(
                label: 'Contraseña actual',
                hint: 'Ingrese su contraseña actual',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  onPressed: () {
                    setState(() => _showCurrentPass = !_showCurrentPass);
                  },
                  icon: Icon(
                    _showCurrentPass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _textSecondary,
                    size: 21,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPassController,
              obscureText: !_showNewPass,
              textInputAction: TextInputAction.next,
              validator: _validateNewPassword,
              decoration: _inputDecoration(
                label: 'Nueva contraseña',
                hint: 'Mínimo 8 caracteres',
                icon: Icons.password_rounded,
                suffix: IconButton(
                  onPressed: () {
                    setState(() => _showNewPass = !_showNewPass);
                  },
                  icon: Icon(
                    _showNewPass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _textSecondary,
                    size: 21,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPassController,
              obscureText: !_showConfirmPass,
              textInputAction: TextInputAction.done,
              validator: _validateConfirmPassword,
              onFieldSubmitted: (_) {
                if (!_busy) _onChangePassword();
              },
              decoration: _inputDecoration(
                label: 'Confirmar nueva contraseña',
                hint: 'Repita la nueva contraseña',
                icon: Icons.verified_user_rounded,
                suffix: IconButton(
                  onPressed: () {
                    setState(() => _showConfirmPass = !_showConfirmPass);
                  },
                  icon: Icon(
                    _showConfirmPass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _textSecondary,
                    size: 21,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _PrimaryButton(
              label: 'Actualizar contraseña',
              icon: Icons.security_rounded,
              loading: _savingPassword,
              onPressed: _busy && !_savingPassword ? null : _onChangePassword,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return _SectionCard(
      icon: Icons.privacy_tip_rounded,
      title: 'Seguridad de la cuenta',
      subtitle: 'Controla el acceso a tu sesión administrativa.',
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.devices_rounded,
            title: 'Sesión administrativa',
            subtitle: 'Cierra tu cuenta en este dispositivo.',
            color: _primary,
            onTap: _busy ? null : _onLogout,
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.info_outline_rounded,
            title: 'Recomendación',
            subtitle: 'Cambia tu contraseña periódicamente para mayor seguridad.',
            color: _success,
            onTap: null,
            showArrow: false,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _onLogout,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Cerrar sesión',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _danger,
          disabledForegroundColor: _textSecondary,
          backgroundColor: Colors.white.withOpacity(0.72),
          side: BorderSide(color: _danger.withOpacity(0.25), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _circleDecoration(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  final Color primary;
  final Color primarySoft;
  final Color textPrimary;
  final Color textSecondary;

  const _PhotoSourceSheet({
    required this.primary,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5D8C5),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.add_a_photo_rounded, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambiar foto de perfil',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Elige una opción para actualizar tu imagen.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _PhotoOption(
                    icon: Icons.photo_library_rounded,
                    title: 'Galería',
                    subtitle: 'Elegir imagen',
                    color: primary,
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PhotoOption(
                    icon: Icons.camera_alt_rounded,
                    title: 'Cámara',
                    subtitle: 'Tomar foto',
                    color: primary,
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PhotoOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2D2418),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8B7D6B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  static const Color _primary = Color(0xFFB8860B);
  static const Color _primarySoft = Color(0xFFFFF3D4);
  static const Color _card = Color(0xFFFFFCF7);
  static const Color _textPrimary = Color(0xFF2D2418);
  static const Color _textSecondary = Color(0xFF8B7D6B);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: _primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  static const Color _primary = Color(0xFFB8860B);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.45),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: loading
              ? const Row(
            key: ValueKey('loading'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Guardando...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          )
              : Row(
            key: const ValueKey('normal'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ReadOnlyInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const Color _primaryDark = Color(0xFF6F4C00);
  static const Color _primarySoft = Color(0xFFFFF3D4);
  static const Color _textPrimary = Color(0xFF2D2418);
  static const Color _textSecondary = Color(0xFF8B7D6B);
  static const Color _border = Color(0xFFE5D8C5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _primaryDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_rounded,
            color: _textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool showArrow;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.showArrow = true,
  });

  static const Color _textPrimary = Color(0xFF2D2418);
  static const Color _textSecondary = Color(0xFF8B7D6B);
  static const Color _border = Color(0xFFE5D8C5);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showArrow)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _textSecondary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF8F1E6),
                  Color(0xFFF5F0E8),
                  Color(0xFFFFFAF1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -65,
          child: _blurCircle(
            size: 195,
            color: const Color(0xFFD8A31D).withOpacity(0.19),
          ),
        ),
        Positioned(
          top: 180,
          left: -85,
          child: _blurCircle(
            size: 175,
            color: const Color(0xFFB8860B).withOpacity(0.11),
          ),
        ),
        Positioned(
          bottom: -95,
          right: -55,
          child: _blurCircle(
            size: 215,
            color: const Color(0xFF7A5500).withOpacity(0.08),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}