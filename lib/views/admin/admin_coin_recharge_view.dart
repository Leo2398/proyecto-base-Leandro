import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';
import '../../models/app_config_model.dart';
import '../../models/request_model.dart';
import '../../services/request_service.dart';

/// Vista de administración de recargas de monedas
/// Solo lado admin: configurar QR, valor de moneda y gestionar solicitudes
class AdminCoinRechargeView extends StatefulWidget {
  const AdminCoinRechargeView({super.key});

  @override
  State<AdminCoinRechargeView> createState() => _AdminCoinRechargeViewState();
}

class _AdminCoinRechargeViewState extends State<AdminCoinRechargeView> {
  static const _primary = Color(0xFFB8860B);
  static const _bg = Color(0xFFF5F0E8);
  static const _text = Color(0xFF2D2D2D);
  static const _textSub = Color(0xFF888888);
  static const _green = Color(0xFF5A8A5A);

  final _service = RequestService();
  final _coinCtrl = TextEditingController();

  AppConfigModel _config = AppConfigModel.defaults;
  List<RequestModel> _pending = [];
  List<RequestModel> _history = [];
  bool _loadingConfig = true;
  bool _loadingRequests = true;
  bool _savingCoin = false;
  bool _uploadingQr = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadConfig(), _loadRequests()]);
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingConfig = true);
    final config = await _service.getAppConfig();
    if (mounted) {
      setState(() {
        _config = config;
        _coinCtrl.text = config.bsPerCoin.toStringAsFixed(2);
        _loadingConfig = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    final all = await _service.getAllRequests();
    if (mounted) {
      setState(() {
        _pending = all.where((r) => r.state == 0).toList();
        _history = all.where((r) => r.state != 0).toList();
        _loadingRequests = false;
      });
    }
  }

  Future<void> _saveCoinValue() async {
    final val = double.tryParse(_coinCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) {
      _snack('Ingresa un valor válido mayor a 0', error: true);
      return;
    }
    setState(() => _savingCoin = true);
    final ok = await _service.updateBsPerCoin(val);
    if (mounted) {
      setState(() => _savingCoin = false);
      if (ok) {
        setState(() => _config = AppConfigModel(bsPerCoin: val, qrImage: _config.qrImage));
        _snack('Valor actualizado correctamente');
      } else {
        _snack('Error al guardar el valor', error: true);
      }
    }
  }

  Future<void> _pickAndSaveQr() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingQr = true);
    final base64 = await ImageHelper.toBase64(File(picked.path));
    if (base64 == null) {
      if (mounted) {
        setState(() => _uploadingQr = false);
        _snack('Error al procesar la imagen', error: true);
      }
      return;
    }
    final ok = await _service.updateQrImage(base64);
    if (mounted) {
      setState(() => _uploadingQr = false);
      if (ok) {
        setState(() => _config = AppConfigModel(bsPerCoin: _config.bsPerCoin, qrImage: base64));
        _snack('QR actualizado correctamente');
      } else {
        _snack('Error al guardar el QR', error: true);
      }
    }
  }

  int get _adminId =>
      Provider.of<UserController>(context, listen: false).currentUser?.id ?? 0;

  Future<void> _approve(RequestModel req) async {
    final ok = await _service.approveRequest(
      requestID: req.id!,
      adminID: _adminId,
    );
    if (mounted) {
      _snack(ok
          ? 'Recarga aprobada. Se acreditaron ${req.value} monedas a ${req.userName ?? "usuario"}'
          : 'Error al aprobar la solicitud',
          error: !ok);
      if (ok) _loadRequests();
    }
  }

  Future<void> _confirmReject(RequestModel req) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rechazar solicitud',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            '¿Deseas rechazar la solicitud de ${req.userName ?? "usuario"} por ${req.value} monedas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (first != true) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar rechazo',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
            '¿Estas seguro? Esta accion NO se puede deshacer.\n\n'
            '"${req.userName ?? "Usuario"}" NO recibira las ${req.value} monedas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Si, rechazar definitivamente'),
          ),
        ],
      ),
    );
    if (second != true) return;

    final ok = await _service.rejectRequest(requestID: req.id!, adminID: _adminId);
    if (mounted) {
      _snack(ok ? 'Solicitud rechazada' : 'Error al rechazar', error: !ok);
      if (ok) _loadRequests();
    }
  }

  void _showProof(String? image) {
    if (image == null || image.isEmpty) {
      _snack('No hay comprobante adjunto');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Comprobante de pago',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: AppImage(
                src: image,
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image_outlined,
                      size: 48, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red[700] : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return 'Hace ${diff.inDays} dia${diff.inDays > 1 ? "s" : ""}';
    if (diff.inHours > 0) return 'Hace ${diff.inHours} hora${diff.inHours > 1 ? "s" : ""}';
    if (diff.inMinutes > 0) return 'Hace ${diff.inMinutes} min';
    return 'Ahora mismo';
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
        title: const Text('Recarga de Monedas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),
            _buildConfigCard(),
            const SizedBox(height: 20),
            _buildPendingSection(),
            const SizedBox(height: 20),
            _buildHistorySection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Tarjeta de configuración ─────────────────────────────────────────────

  Widget _buildConfigCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configuracion de Moneda',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 16),

          // Valor de la moneda
          const Text('Valor de 1 moneda en Bs',
              style: TextStyle(fontSize: 13, color: _textSub)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _coinCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: 'Bs',
                  filled: true,
                  fillColor: const Color(0xFFF8F5EF),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0D9CC))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0D9CC))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _savingCoin ? null : _saveCoinValue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _savingCoin
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Actualizar valor'),
            ),
          ]),
          const SizedBox(height: 20),

          // QR
          const Text('QR oficial para recargas',
              style: TextStyle(fontSize: 13, color: _textSub)),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0D9CC)),
              ),
              child: _loadingConfig
                  ? const Center(
                      child: CircularProgressIndicator(color: _primary))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: AppImage(
                        src: _config.qrImage,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                        placeholder: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code,
                                size: 48, color: Color(0xFFCCC5B9)),
                            SizedBox(height: 6),
                            Text('Subir QR oficial',
                                style: TextStyle(
                                    fontSize: 11, color: _textSub)),
                            Text('PNG, JPG',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFCCC5B9))),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploadingQr ? null : _pickAndSaveQr,
              icon: _uploadingQr
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary))
                  : const Icon(Icons.upload_outlined, size: 18),
              label: Text(_uploadingQr ? 'Procesando...' : 'Actualizar QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Solicitudes pendientes ───────────────────────────────────────────────

  Widget _buildPendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Solicitudes pendientes',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
          const Spacer(),
          if (_pending.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_pending.length} pendiente${_pending.length > 1 ? "s" : ""}',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        if (_loadingRequests)
          const Center(child: CircularProgressIndicator(color: _primary))
        else if (_pending.isEmpty)
          _emptyCard(Icons.check_circle_outline, _green, 'Sin solicitudes pendientes')
        else
          ..._pending.map((r) => _PendingCard(
                req: r,
                timeAgo: _timeAgo(r.registerDate),
                onApprove: () => _approve(r),
                onReject: () => _confirmReject(r),
                onViewProof: () => _showProof(r.image),
              )),
      ],
    );
  }

  // ─── Historial ────────────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Historial de Recargas',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _text)),
        const SizedBox(height: 12),
        if (_loadingRequests)
          const SizedBox()
        else if (_history.isEmpty)
          _emptyCard(Icons.history, _textSub, 'Sin historial aun')
        else
          ..._history.map((r) => _HistoryRow(
                req: r,
                onViewProof: () => _showProof(r.image),
              )),
      ],
    );
  }

  Widget _emptyCard(IconData icon, Color color, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Icon(icon, size: 36, color: color),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D))),
      ]),
    );
  }
}

// ─── Card de solicitud pendiente ──────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final RequestModel req;
  final String timeAgo;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewProof;

  const _PendingCard({
    required this.req,
    required this.timeAgo,
    required this.onApprove,
    required this.onReject,
    required this.onViewProof,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header usuario
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  const Color(0xFFB8860B).withOpacity(0.15),
              child: Text(
                req.userName?.isNotEmpty == true
                    ? req.userName![0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                    color: Color(0xFFB8860B),
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.userName ?? 'Usuario',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D))),
                  Text(req.userEmail ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF888888))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Pendiente',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),

          // Info monedas y monto
          Row(children: [
            _InfoBadge(label: 'Monedas', value: '${req.value}'),
            const SizedBox(width: 20),
            _InfoBadge(
                label: 'Monto pagado',
                value: '${req.amount.toStringAsFixed(0)} Bs'),
          ]),
          const SizedBox(height: 6),
          Text(timeAgo,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
          const SizedBox(height: 12),

          // Ver comprobante
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewProof,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Ver comprobante'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D2D2D),
                side: const BorderSide(color: Color(0xFFE0D9CC)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Aprobar / Rechazar
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Aprobar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A8A5A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Rechazar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D))),
        ],
      );
}

// ─── Fila de historial ────────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final RequestModel req;
  final VoidCallback onViewProof;
  const _HistoryRow({required this.req, required this.onViewProof});

  @override
  Widget build(BuildContext context) {
    final approved = req.state == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFB8860B).withOpacity(0.12),
          child: Text(
            req.userName?.isNotEmpty == true
                ? req.userName![0].toUpperCase()
                : 'U',
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFB8860B),
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(req.userName ?? 'Usuario',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D2D2D))),
              if (req.processedDate != null)
                Text(
                  '${req.processedDate!.day}/${req.processedDate!.month}/${req.processedDate!.year}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888)),
                ),
            ],
          ),
        ),
        Text('${req.value} monedas',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D))),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: approved
                ? const Color(0xFF5A8A5A).withOpacity(0.1)
                : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            approved ? 'Aprobado' : 'Rechazado',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: approved
                    ? const Color(0xFF5A8A5A)
                    : Colors.red.shade500),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onViewProof,
          child: const Icon(Icons.visibility_outlined,
              size: 18, color: Color(0xFFB8860B)),
        ),
      ]),
    );
  }
}
