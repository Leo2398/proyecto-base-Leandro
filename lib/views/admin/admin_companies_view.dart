import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

/// Vista de administración de empresas/productores (solo lectura)
class AdminCompaniesView extends StatefulWidget {
  const AdminCompaniesView({super.key});

  @override
  State<AdminCompaniesView> createState() => _AdminCompaniesViewState();
}

class _AdminCompaniesViewState extends State<AdminCompaniesView> {
  static const _primary = Color(0xFFB8860B);
  static const _bg = Color(0xFFF5F0E8);
  static const _text = Color(0xFF2D2D2D);
  static const _textSub = Color(0xFF888888);

  final _service = UserService();
  final _searchCtrl = TextEditingController();

  List<UserModel> _all = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  String _filterState = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getUsersByRole(1);
    if (mounted) {
      setState(() {
        _all = list;
        _loading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = _all.where((u) {
        final matchSearch = q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.description ?? '').toLowerCase().contains(q);
        final matchState = _filterState == 'Todos' ||
            (_filterState == 'Activas' && u.state == 1) ||
            (_filterState == 'Inactivas' && u.state == 0);
        return matchSearch && matchState;
      }).toList();
    });
  }

  void _showDetail(UserModel u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyDetailSheet(user: u),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _all.where((u) => u.state == 1).length;
    final inactive = _all.length - active;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Empresas',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),

            // --- Stats ---
            Row(children: [
              _StatChip(
                  label: 'Total', value: '${_all.length}', color: _primary),
              const SizedBox(width: 10),
              _StatChip(
                  label: 'Activas',
                  value: '$active',
                  color: const Color(0xFF5A8A5A)),
              const SizedBox(width: 10),
              _StatChip(
                  label: 'Inactivas',
                  value: '$inactive',
                  color: Colors.red.shade400),
            ]),
            const SizedBox(height: 14),

            // --- Buscador ---
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar empresa...',
                hintStyle: const TextStyle(color: _textSub, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: _textSub, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),

            // --- Filtro ---
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children:
                    ['Todos', 'Activas', 'Inactivas'].map((f) {
                  final sel = _filterState == f;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _filterState = f);
                      _applyFilter();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? _primary : const Color(0xFFE0D9CC)),
                      ),
                      child: Text(f,
                          style: TextStyle(
                              color: sel ? Colors.white : _text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // --- Lista ---
            if (_loading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: _primary),
              ))
            else if (_filtered.isEmpty)
              _buildEmpty()
            else
              ..._filtered.map((u) => _CompanyCard(
                    user: u,
                    onTap: () => _showDetail(u),
                  )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Column(children: [
          Icon(Icons.store_outlined, size: 48, color: Color(0xFFCCC5B9)),
          SizedBox(height: 12),
          Text('No se encontraron empresas',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D))),
          SizedBox(height: 4),
          Text('Intenta con otra búsqueda',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ]),
      );
}

// ─── Widgets internos ────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF888888))),
          ]),
        ),
      );
}

class _CompanyCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _CompanyCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = user.state == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFF5A8A5A).withOpacity(0.15),
          backgroundImage: (user.image != null && user.image!.isNotEmpty)
              ? NetworkImage(user.image!)
              : null,
          child: (user.image == null || user.image!.isEmpty)
              ? Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'E',
                  style: const TextStyle(
                      color: Color(0xFF5A8A5A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                )
              : null,
        ),
        title: Text(user.name,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.description != null && user.description!.isNotEmpty)
              Text(
                user.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF888888)),
              ),
            Text(user.email,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFAAAAAA))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF5A8A5A).withOpacity(0.1)
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isActive ? 'Activa' : 'Inactiva',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF5A8A5A)
                        : Colors.red.shade400),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                color: Color(0xFFCCC5B9), size: 20),
          ],
        ),
      ),
    );
  }
}

class _CompanyDetailSheet extends StatelessWidget {
  final UserModel user;
  const _CompanyDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final isActive = user.state == 1;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE0D9CC),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF5A8A5A).withOpacity(0.15),
            backgroundImage:
                (user.image != null && user.image!.isNotEmpty)
                    ? NetworkImage(user.image!)
                    : null,
            child: (user.image == null || user.image!.isEmpty)
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'E',
                    style: const TextStyle(
                        color: Color(0xFF5A8A5A),
                        fontWeight: FontWeight.bold,
                        fontSize: 28),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(user.name,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF5A8A5A).withOpacity(0.1)
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Activa' : 'Inactiva',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF5A8A5A)
                      : Colors.red.shade400),
            ),
          ),
          if (user.description != null && user.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              user.description!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF888888), height: 1.4),
            ),
          ],
          const SizedBox(height: 20),
          _InfoRow(icon: Icons.email_outlined, label: 'Correo', value: user.email),
          _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: user.cellphone ?? 'No registrado'),
          _InfoRow(
              icon: Icons.monetization_on_outlined,
              label: 'Balance',
              value: '${user.balance.toStringAsFixed(0)} monedas'),
          _InfoRow(
              icon: Icons.badge_outlined,
              label: 'ID',
              value: '#${user.id ?? '-'}'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D2D2D),
                side: const BorderSide(color: Color(0xFFE0D9CC)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFB8860B)),
            const SizedBox(width: 10),
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2D2D))),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF888888))),
            ),
          ],
        ),
      );
}
