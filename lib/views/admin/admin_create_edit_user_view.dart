import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../../models/user_model.dart';

/// Vista para crear o editar un usuario administrador
/// Si [adminToEdit] es null, opera en modo creación; si no, en modo edición.
class AdminCreateEditUserView extends StatefulWidget {
  final UserModel? adminToEdit;

  const AdminCreateEditUserView({super.key, this.adminToEdit});

  @override
  State<AdminCreateEditUserView> createState() =>
      _AdminCreateEditUserViewState();
}

class _AdminCreateEditUserViewState extends State<AdminCreateEditUserView> {
  static const _primary = Color(0xFFB8860B);
  static const _background = Color(0xFFF5F0E8);
  static const _textPrimary = Color(0xFF2D2D2D);
  static const _textSecondary = Color(0xFF888888);

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

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

  InputDecoration _field(String label, String hint, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBBB0A0), fontSize: 13),
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

  void _showMsg(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _onSubmit() async {
    setState(() => _loading = true);
    final ctrl = Provider.of<UserController>(context, listen: false);
    bool ok;

    if (_isEditing) {
      ok = await ctrl.updateAdminUser(
        admin: widget.adminToEdit!,
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        cellphone: _phoneCtrl.text,
        state: _isActive ? 1 : 0,
        newPassword:
            _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
        confirmPassword:
            _confirmPassCtrl.text.isNotEmpty ? _confirmPassCtrl.text : null,
      );
    } else {
      ok = await ctrl.createAdmin(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text,
        confirmPassword: _confirmPassCtrl.text,
        state: _isActive ? 1 : 0,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      _showMsg(_isEditing
          ? 'Administrador actualizado correctamente'
          : 'Administrador creado correctamente');
      Navigator.pop(context);
    } else {
      _showMsg(
          ctrl.errorMessage ??
              (_isEditing
                  ? 'Error al actualizar'
                  : 'Error al crear el administrador'),
          error: true);
    }
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
        title: Text(
          _isEditing ? 'Editar Usuario' : 'Crear Usuario',
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _textPrimary),
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
                padding: const EdgeInsets.only(right: 10),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFD4A017),
                  backgroundImage: (img != null && img.isNotEmpty)
                      ? NetworkImage(img)
                      : null,
                  child: (img == null || img.isEmpty)
                      ? const Icon(Icons.person,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
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
              // --- Encabezado ---
              Text(
                'Información del Usuario',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isEditing
                    ? 'Modifica los datos del administrador'
                    : 'Complete los datos para crear un nuevo usuario administrador',
                style: const TextStyle(
                    fontSize: 12, color: _textSecondary),
              ),
              const SizedBox(height: 20),

              // --- Nombre ---
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _field(
                    'Nombre Completo', 'Ingrese el nombre completo'),
              ),
              const SizedBox(height: 14),

              // --- Correo ---
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    _field('Correo Electrónico', 'usuario@ejemplo.com'),
              ),
              const SizedBox(height: 14),

              // --- Teléfono (solo edición) ---
              if (_isEditing) ...[
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _field('Teléfono', '+52 55 1234 5678'),
                ),
                const SizedBox(height: 14),
              ],

              // --- Contraseña ---
              TextField(
                controller: _passCtrl,
                obscureText: !_showPass,
                decoration: _field(
                  _isEditing
                      ? 'Nueva contraseña (opcional)'
                      : 'Contraseña',
                  'Mínimo 8 caracteres',
                  suffix: IconButton(
                    icon: Icon(
                      _showPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _showPass = !_showPass),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // --- Confirmar contraseña ---
              TextField(
                controller: _confirmPassCtrl,
                obscureText: !_showConfirmPass,
                decoration: _field(
                  'Confirmar Contraseña',
                  'Confirme la contraseña',
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

              // --- Estado ---
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE0D9CC)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estado',
                            style: TextStyle(
                                fontSize: 13, color: _textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          _isActive ? 'Activo' : 'Inactivo',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeColor: Colors.white,
                      activeTrackColor: _primary,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCCC5B9),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // --- Botón principal ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _onSubmit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          _isEditing
                              ? Icons.save_outlined
                              : Icons.person_add_outlined,
                          size: 20),
                  label: Text(
                    _isEditing ? 'Guardar cambios' : 'Crear Usuario',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // --- Cancelar ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textPrimary,
                    side: const BorderSide(color: Color(0xFFD0C8B8)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
