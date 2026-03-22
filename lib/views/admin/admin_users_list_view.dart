import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../../models/user_model.dart';
import 'admin_create_edit_user_view.dart';

/// Vista de listado de administradores con opciones de crear, editar y eliminar
class AdminUsersListView extends StatefulWidget {
  const AdminUsersListView({super.key});

  @override
  State<AdminUsersListView> createState() => _AdminUsersListViewState();
}

class _AdminUsersListViewState extends State<AdminUsersListView> {
  static const _primary = Color(0xFFB8860B);
  static const _background = Color(0xFFF5F0E8);
  static const _textPrimary = Color(0xFF2D2D2D);
  static const _textSecondary = Color(0xFF888888);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserController>(context, listen: false).loadAdmins();
    });
  }

  Future<void> _confirmDelete(UserModel admin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar administrador'),
        content: Text(
          '¿Estás seguro de eliminar al usuario "${admin.name}"?\n\nEsta acción desactivará su acceso al sistema.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final controller = Provider.of<UserController>(context, listen: false);
    final ok = await controller.deleteAdminUser(admin.id!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Administrador "${admin.name}" eliminado'
            : controller.errorMessage ?? 'Error al eliminar'),
        backgroundColor: ok ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _goToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const AdminCreateEditUserView()),
    ).then((_) {
      if (mounted) {
        Provider.of<UserController>(context, listen: false).loadAdmins();
      }
    });
  }

  void _goToEdit(UserModel admin) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AdminCreateEditUserView(adminToEdit: admin)),
    ).then((_) {
      if (mounted) {
        Provider.of<UserController>(context, listen: false).loadAdmins();
      }
    });
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
          'Administradores',
          style: TextStyle(
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
                  backgroundImage:
                      (img != null && img.isNotEmpty) ? NetworkImage(img) : null,
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
      body: Column(
        children: [
          // --- Botón Crear Admin ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _goToCreate,
                icon: const Icon(Icons.person_add_outlined, size: 20),
                label: const Text(
                  'Crear Usuario Admin',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),

          // --- Lista ---
          Expanded(
            child: Consumer<UserController>(
              builder: (_, ctrl, __) {
                if (ctrl.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                final admins = ctrl.admins;

                if (admins.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.manage_accounts_outlined,
                            size: 64,
                            color: _textSecondary.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay administradores registrados',
                          style: TextStyle(
                              color: _textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  itemCount: admins.length,
                  itemBuilder: (_, i) => _AdminCard(
                    admin: admins[i],
                    onEdit: () => _goToEdit(admins[i]),
                    onDelete: () => _confirmDelete(admins[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final UserModel admin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _primary = Color(0xFFB8860B);
  static const _textPrimary = Color(0xFF2D2D2D);
  static const _textSecondary = Color(0xFF888888);

  const _AdminCard({
    required this.admin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = admin.state == 1;
    final img = admin.image;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFD4A017),
            backgroundImage:
                (img != null && img.isNotEmpty) ? NetworkImage(img) : null,
            child: (img == null || img.isEmpty)
                ? Text(
                    admin.name.isNotEmpty
                        ? admin.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  admin.email,
                  style: const TextStyle(
                      fontSize: 12, color: _textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? const Color(0xFF388E3C)
                          : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Acciones
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    color: _primary, size: 22),
                tooltip: 'Editar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 8),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline,
                    color: Colors.red[400], size: 22),
                tooltip: 'Eliminar',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
