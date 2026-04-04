import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

/// Vista de administración de empresas/productores (role=1) — solo lectura
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
  static const _green = Color(0xFF5A8A5A);

  final _service = UserService();
  List<UserModel> _all = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  String _search = '';
  int _stateFilter = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _service.getUsersByRole(1);
    if (mounted) {
      setState(() {
        _all = data;
        _loading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all.where((u) {
        final matchSearch = _search.isEmpty ||
            u.name.toLowerCase().contains(_search.toLowerCase()) ||
            u.email.toLowerCase().contains(_search.toLowerCase());
        final matchState = _stateFilter == -1 || u.state == _stateFilter;
        return matchSearch && matchState;
      }).toList();
    });
  }

  int get _activas => _all.where((u) => u.state == 1).length;
  int get _inactivas => _all.where((u) => u.state == 0).length;

  void _showDetail(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyDetailSheet(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Row(children: [
                    _StatChip(label: 'Total', value: '${_all.length}', color: _primary),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Activas', value: '$_activas', color: _green),
                    const SizedBox(width: 8),
                    _StatChip(label: 'Inactivas', value: '$_inactivas', color: Colors.red.shade400),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) { _search = v; _applyFilter(); },
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o email...',
                      hintStyle: const TextStyle(fontSize: 13, color: _textSub),
                      prefixIcon: const Icon(Icons.search, color: _textSub, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _FilterBtn(label: 'Todos', selected: _stateFilter == -1,
                        onTap: () { _stateFilter = -1; _applyFilter(); }),
                    const SizedBox(width: 8),
                    _FilterBtn(label: 'Activas', selected: _stateFilter == 1,
                        onTap: () { _stateFilter = 1; _applyFilter(); }),
                    const SizedBox(width: 8),
                    _FilterBtn(label: 'Inactivas', selected: _stateFilter == 0,
                        onTap: () { _stateFilter = 0; _applyFilter(); }),
                  ]),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _filtered.isEmpty
                      ? const Center(child: Text('Sin resultados',
                          style: TextStyle(color: _textSub)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _CompanyCard(
                            user: _filtered[i],
                            onTap: () => _showDetail(_filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ]),
      );
}

class _FilterBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFB8860B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF888888))),
        ),
      );
}

class _CompanyCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  const _CompanyCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = user.state == 1;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFB8860B).withOpacity(0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'E',
              style: const TextStyle(
                  color: Color(0xFFB8860B), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
              const SizedBox(height: 2),
              Text(user.email,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              if (user.description != null && user.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(user.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF5A8A5A).withOpacity(0.1)
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              active ? 'Activa' : 'Inactiva',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? const Color(0xFF5A8A5A) : Colors.red.shade500),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CompanyDetailSheet extends StatelessWidget {
  final UserModel user;
  const _CompanyDetailSheet({required this.user});

  @override
  Widget build(BuildContext context) {
    final active = user.state == 1;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFB8860B).withOpacity(0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'E',
              style: const TextStyle(
                  color: Color(0xFFB8860B), fontWeight: FontWeight.bold, fontSize: 28),
            ),
          ),
          const SizedBox(height: 12),
          Text(user.name,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF5A8A5A).withOpacity(0.1) : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(active ? 'Activa' : 'Inactiva',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: active ? const Color(0xFF5A8A5A) : Colors.red.shade500)),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          _DetailRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
          _DetailRow(
              icon: Icons.phone_outlined,
              label: 'Telefono',
              value: (user.cellphone != null && user.cellphone!.isNotEmpty)
                  ? user.cellphone!
                  : 'Sin telefono'),
          if (user.description != null && user.description!.isNotEmpty)
            _DetailRow(
                icon: Icons.info_outline,
                label: 'Descripcion',
                value: user.description!),
          if (user.registerDate != null)
            _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Registro',
                value:
                    '${user.registerDate!.day.toString().padLeft(2, '0')}/${user.registerDate!.month.toString().padLeft(2, '0')}/${user.registerDate!.year}'),
          _DetailRow(icon: Icons.badge_outlined, label: 'ID', value: '#${user.id ?? "-"}'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 18, color: const Color(0xFFB8860B)),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF2D2D2D), fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
