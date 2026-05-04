import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../../models/user_model.dart';

/// Vista para crear o editar un usuario administrador.
/// Si [adminToEdit] es null, opera en modo creación; si no, en modo edición.
class AdminCreateEditUserView extends StatefulWidget {
  final UserModel? adminToEdit;

  const AdminCreateEditUserView({super.key, this.adminToEdit});

  @override
  State<AdminCreateEditUserView> createState() =>
      _AdminCreateEditUserViewState();
}

class _AdminCreateEditUserViewState extends State<AdminCreateEditUserView> {
  static const Color _primary = Color(0xFFB8860B);
  static const Color _primaryDark = Color(0xFF7A5500);
  static const Color _primarySoft = Color(0xFFFFF4D6);
  static const Color _background = Color(0xFFF5F0E8);
  static const Color _card = Color(0xFFFFFCF7);
  static const Color _textPrimary = Color(0xFF2D2418);
  static const Color _textSecondary = Color(0xFF8B7D6B);
  static const Color _border = Color(0xFFE6D9C5);
  static const Color _success = Color(0xFF2E7D32);
  static const Color _danger = Color(0xFFC62828);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  bool _showPass = false;
  bool _showConfirmPass = false;
  bool _isActive = true;
  bool _loading = false;

  bool get _isEditing => widget.adminToEdit != null;

  @override
  void initState() {
    super.initState();

    final admin = widget.adminToEdit;
    if (admin != null) {
      _nameCtrl.text = admin.name;
      _emailCtrl.text = admin.email;
      _phoneCtrl.text = admin.cellphone ?? '';
      _isActive = admin.state == 1;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String _clean(String value) => value.trim();

  ImageProvider? _buildImageProvider(String? image) {
    if (image == null || image.trim().isEmpty) return null;

    final raw = image.trim();

    try {
      if (raw.startsWith('http')) {
        return NetworkImage(raw);
      }

      final file = File(raw);
      if (file.existsSync()) {
        return FileImage(file);
      }

      final base64Value =
      raw.contains(',') ? raw.split(',').last.trim() : raw;
      return MemoryImage(base64Decode(base64Value));
    } catch (_) {
      return null;
    }
  }

  void _showMsg(String msg, {bool error = false}) {
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
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _primaryDark, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(
        minWidth: 58,
        minHeight: 52,
      ),
      suffixIcon: suffix,
      labelStyle: const TextStyle(
        color: _textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFFC2B5A2),
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
      errorStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String? _validateName(String? value) {
    final text = _clean(value ?? '');
    if (text.isEmpty) return 'Ingrese el nombre completo';
    if (text.length < 3) return 'El nombre es demasiado corto';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = _clean(value ?? '');
    if (text.isEmpty) return 'Ingrese el correo electrónico';

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

  String? _validatePassword(String? value) {
    final text = value ?? '';
    final confirm = _confirmPassCtrl.text;

    if (!_isEditing && text.trim().isEmpty) {
      return 'Ingrese una contraseña';
    }

    if (_isEditing && text.trim().isEmpty && confirm.trim().isEmpty) {
      return null;
    }

    if (text.length < 8) {
      return 'La contraseña debe tener mínimo 8 caracteres';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = value ?? '';
    final pass = _passCtrl.text;

    if (!_isEditing && text.trim().isEmpty) {
      return 'Confirme la contraseña';
    }

    if (_isEditing && pass.trim().isEmpty && text.trim().isEmpty) {
      return null;
    }

    if (text != pass) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showMsg('Revise los campos marcados antes de continuar', error: true);
      return;
    }

    setState(() => _loading = true);

    final ctrl = Provider.of<UserController>(context, listen: false);
    bool ok;

    if (_isEditing) {
      final hasNewPassword = _passCtrl.text.trim().isNotEmpty;

      ok = await ctrl.updateAdminUser(
        admin: widget.adminToEdit!,
        name: _clean(_nameCtrl.text),
        email: _clean(_emailCtrl.text),
        cellphone: _clean(_phoneCtrl.text),
        state: _isActive ? 1 : 0,
        newPassword: hasNewPassword ? _passCtrl.text : null,
        confirmPassword: hasNewPassword ? _confirmPassCtrl.text : null,
      );
    } else {
      ok = await ctrl.createAdmin(
        name: _clean(_nameCtrl.text),
        email: _clean(_emailCtrl.text),
        password: _passCtrl.text,
        confirmPassword: _confirmPassCtrl.text,
        state: _isActive ? 1 : 0,
      );
    }

    if (!mounted) return;

    setState(() => _loading = false);

    if (ok) {
      _showMsg(
        _isEditing
            ? 'Administrador actualizado correctamente'
            : 'Administrador creado correctamente',
      );

      Navigator.pop(context, true);
    } else {
      _showMsg(
        ctrl.errorMessage ??
            (_isEditing
                ? 'Error al actualizar el administrador'
                : 'Error al crear el administrador'),
        error: true,
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_loading) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar administrador' : 'Nuevo administrador';
    final subtitle = _isEditing
        ? 'Actualiza los datos, estado y acceso del usuario administrador.'
        : 'Registra un nuevo usuario con permisos administrativos.';

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
                  _buildTopBar(title),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroCard(title, subtitle),
                            const SizedBox(height: 18),
                            _buildFormCard(),
                            const SizedBox(height: 18),
                            _buildStatusCard(),
                            const SizedBox(height: 22),
                            _buildActions(),
                          ],
                        ),
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

  Widget _buildTopBar(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 6),
      child: Row(
        children: [
          Material(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: _loading ? null : () => Navigator.pop(context),
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
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildCurrentUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildCurrentUserAvatar() {
    return Consumer<UserController>(
      builder: (_, ctrl, __) {
        final imageProvider = _buildImageProvider(ctrl.currentUser?.image);

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
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(
              Icons.admin_panel_settings_rounded,
              color: _primaryDark,
              size: 21,
            )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
            right: -28,
            top: -30,
            child: _circleDecoration(100, Colors.white.withOpacity(0.10)),
          ),
          Positioned(
            right: 38,
            bottom: -42,
            child: _circleDecoration(82, Colors.white.withOpacity(0.08)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: Icon(
                  _isEditing
                      ? Icons.manage_accounts_rounded
                      : Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 31,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Text(
                        _isEditing ? 'Modo edición' : 'Registro administrativo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.86),
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.badge_rounded,
            title: 'Información del usuario',
            subtitle: _isEditing
                ? 'Modifica los datos personales del administrador.'
                : 'Completa los datos básicos del nuevo administrador.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _nameCtrl,
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
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
            decoration: _inputDecoration(
              label: 'Correo electrónico',
              hint: 'usuario@ejemplo.com',
              icon: Icons.alternate_email_rounded,
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: _validatePhone,
              decoration: _inputDecoration(
                label: 'Teléfono',
                hint: 'Ej: 71234567',
                icon: Icons.phone_rounded,
              ),
            ),
          ],
          const SizedBox(height: 22),
          _SectionHeader(
            icon: Icons.lock_rounded,
            title: 'Seguridad de acceso',
            subtitle: _isEditing
                ? 'Déjalo vacío si no deseas cambiar la contraseña.'
                : 'Define una contraseña segura para el nuevo acceso.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _passCtrl,
            obscureText: !_showPass,
            textInputAction: TextInputAction.next,
            validator: _validatePassword,
            decoration: _inputDecoration(
              label: _isEditing ? 'Nueva contraseña opcional' : 'Contraseña',
              hint: 'Mínimo 8 caracteres',
              icon: Icons.password_rounded,
              suffix: IconButton(
                tooltip: _showPass ? 'Ocultar contraseña' : 'Ver contraseña',
                onPressed: () => setState(() => _showPass = !_showPass),
                icon: Icon(
                  _showPass
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
            controller: _confirmPassCtrl,
            obscureText: !_showConfirmPass,
            textInputAction: TextInputAction.done,
            validator: _validateConfirmPassword,
            onFieldSubmitted: (_) {
              if (!_loading) _onSubmit();
            },
            decoration: _inputDecoration(
              label: 'Confirmar contraseña',
              hint: 'Repita la contraseña',
              icon: Icons.verified_user_rounded,
              suffix: IconButton(
                tooltip: _showConfirmPass
                    ? 'Ocultar confirmación'
                    : 'Ver confirmación',
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
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final Color stateColor = _isActive ? _success : _danger;
    final IconData stateIcon =
    _isActive ? Icons.check_circle_rounded : Icons.block_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isActive
              ? _success.withOpacity(0.18)
              : _danger.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: stateColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(stateIcon, color: stateColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado del administrador',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isActive
                      ? 'El usuario podrá ingresar y gestionar el sistema.'
                      : 'El usuario quedará bloqueado para iniciar sesión.',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isActive,
            activeColor: _primary,
            onChanged: _loading
                ? null
                : (value) {
              setState(() => _isActive = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _onSubmit,
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
              child: _loading
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
                  Icon(
                    _isEditing
                        ? Icons.save_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing
                        ? 'Guardar cambios'
                        : 'Crear administrador',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, size: 20),
            label: const Text(
              'Cancelar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              disabledForegroundColor: _textSecondary,
              side: const BorderSide(color: _border, width: 1.2),
              backgroundColor: Colors.white.withOpacity(0.72),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  static const Color _primary = Color(0xFFB8860B);
  static const Color _primarySoft = Color(0xFFFFF4D6);
  static const Color _textPrimary = Color(0xFF2D2418);
  static const Color _textSecondary = Color(0xFF8B7D6B);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: _primary, size: 22),
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
                  fontSize: 15,
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
          top: -85,
          right: -65,
          child: _blurCircle(
            size: 190,
            color: const Color(0xFFD8A31D).withOpacity(0.19),
          ),
        ),
        Positioned(
          top: 160,
          left: -80,
          child: _blurCircle(
            size: 170,
            color: const Color(0xFFB8860B).withOpacity(0.11),
          ),
        ),
        Positioned(
          bottom: -90,
          right: -50,
          child: _blurCircle(
            size: 210,
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