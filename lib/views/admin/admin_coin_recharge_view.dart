import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/cloudinary_helper.dart';
import '../../models/coin_recharge_model.dart';
import '../../services/app_config_service.dart';
import '../../services/coin_recharge_service.dart';

/// Vista de administración de recargas de monedas
/// Permite configurar el QR, el valor de la moneda y gestionar solicitudes
class AdminCoinRechargeView extends StatefulWidget {
  const AdminCoinRechargeView({super.key});

  @override
  State<AdminCoinRechargeView> createState() =>
      _AdminCoinRechargeViewState();
}

class _AdminCoinRechargeViewState extends State<AdminCoinRechargeView> {
  static const _primary = Color(0xFFB8860B);
  static const _bg = Color(0xFFF5F0E8);
  static const _text = Color(0xFF2D2D2D);
  static const _textSub = Color(0xFF888888);
  static const _green = Color(0xFF5A8A5A);

  final _configService = AppConfigService();
  final _rechargeService = CoinRechargeService();
  final _coinValueCtrl = TextEditingController();

  String? _qrImageUrl;
  double _coinValueBs = 1.0;
  List<CoinRechargeModel> _pending = [];
  List<CoinRechargeModel> _history = [];
  bool _loadingConfig = true;
  bool _loadingRequests = true;
  bool _savingValue = false;
  bool _uploadingQr = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _coinValueCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([
      _configService.initTable(),
      _rechargeService.initTable(),
    ]);
    await _loadConfig();
    await _loadRequests();
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingConfig = true);
    final qr = await _configService.getQrImageUrl();
    final val = await _configService.getCoinValueBs();
    if (mounted) {
      setState(() {
        _qrImageUrl = qr;
        _coinValueBs = val;
        _coinValueCtrl.text = val.toStringAsFixed(2);
        _loadingConfig = false;
      });
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    final pending = await _rechargeService.getPendingRequests();
    final all = await _rechargeService.getAllRequests();
    if (mounted) {
      setState(() {
        _pending = pending;
        _history = all.where((r) => r.status != 'pending').toList();
        _loadingRequests = false;
      });
    }
  }

  Future<void> _saveCoinValue() async {
    final val = double.tryParse(_coinValueCtrl.text.replaceAll(',', '.'));
    if (val == null || val <= 0) {
      _snack('Ingresa un valor válido mayor a 0', error: true);
      return;
    }
    setState(() => _savingValue = true);
    final ok = await _configService.setCoinValueBs(val);
    if (mounted) {
      setState(() {
        _savingValue = false;
        if (ok) _coinValueBs = val;
      });
      _snack(ok ? 'Valor actualizado correctamente' : 'Error al guardar',
          error: !ok);
    }
  }

  Future<void> _pickAndUploadQr() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingQr = true);
    final url = await CloudinaryHelper.uploadImage(File(picked.path));
    if (url != null) {
      final saved = await _configService.setQrImageUrl(url);
      if (mounted) {
        setState(() {
          if (saved) _qrImageUrl = url;
          _uploadingQr = false;
        });
        _snack(saved ? 'QR actualizado correctamente' : 'Error al guardar QR',
            error: !saved);
      }
    } else {
      if (mounted) {
        setState(() => _uploadingQr = false);
        _snack('Error al subir la imagen', error: true);
      }
    }
  }

  Future<void> _approve(CoinRechargeModel req) async {
    final ok = await _rechargeService.approveRequest(req.id!);
    if (mounted) {
      _snack(ok
          ? 'Recarga aprobada. Se acreditaron ${req.coinsRequested} monedas a ${req.userName}'
          : 'Error al aprobar');
      if (ok) _loadRequests();
    }
  }

  Future<void> _confirmReject(CoinRechargeModel req) async {
    // Primera confirmación
    final first = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rechazar solicitud',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            '¿Deseas rechazar la solicitud de ${req.userName} por ${req.coinsRequested} monedas?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (first != true) return;

    // Segunda confirmación
    final second = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar rechazo',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
            '¿Estás seguro? Esta acción NO se puede deshacer.\n\nEl usuario "${req.userName}" NO recibirá las ${req.coinsRequested} monedas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Sí, rechazar definitivamente'),
          ),
        ],
      ),
    );
    if (second != true) return;

    final ok = await _rechargeService.rejectRequest(req.id!);
    if (mounted) {
      _snack(ok ? 'Solicitud rechazada' : 'Error al rechazar', error: !ok);
      if (ok) _loadRequests();
    }
  }

  void _showProof(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      _snack('No hay comprobante adjunto');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: const Text('Comprobante de pago',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                errorBuilder: (_, __, ___) => const Padding(
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

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return 'Hace ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}';
    if (diff.inHours > 0)
      return 'Hace ${diff.inHours} hora${diff.inHours > 1 ? 's' : ''}';
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
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () async {
          await _loadConfig();
          await _loadRequests();
        },
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

  // ─── Configuración de moneda y QR ────────────────────────────────────────
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _text)),
          const SizedBox(height: 16),

          // Valor de la moneda
          const Text('Valor de 1 moneda en Bs',
              style: TextStyle(fontSize: 13, color: _textSub)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _coinValueCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  suffixText: 'Bs',
                  filled: true,
                  fillColor: const Color(0xFFF8F5EF),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0D9CC))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0D9CC))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _savingValue ? null : _saveCoinValue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _savingValue
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
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0D9CC)),
              ),
              child: _loadingConfig
                  ? const Center(
                      child: CircularProgressIndicator(color: _primary))
                  : _qrImageUrl != null && _qrImageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.network(_qrImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.qr_code,
                                  size: 60,
                                  color: _textSub)),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code,
                                size: 48, color: Color(0xFFCCC5B9)),
                            SizedBox(height: 6),
                            Text('Subir QR oficial',
                                style: TextStyle(
                                    fontSize: 11, color: _textSub)),
                            Text('PNG, JPG hasta 5MB',
                                style: TextStyle(
                                    fontSize: 10, color: Color(0xFFCCC5B9))),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploadingQr ? null : _pickAndUploadQr,
              icon: _uploadingQr
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary))
                  : const Icon(Icons.upload_outlined, size: 18),
              label: Text(_uploadingQr ? 'Subiendo...' : 'Actualizar QR'),
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
          const Text('Solicitudes de Recarga',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _text)),
          const Spacer(),
          if (_pending.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${_pending.length} pendiente${_pending.length > 1 ? 's' : ''}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 12),
        if (_loadingRequests)
          const Center(child: CircularProgressIndicator(color: _primary))
        else if (_pending.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14)),
            child: const Column(children: [
              Icon(Icons.check_circle_outline,
                  size: 36, color: Color(0xFF5A8A5A)),
              SizedBox(height: 8),
              Text('Sin solicitudes pendientes',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D))),
            ]),
          )
        else
          ..._pending.map((r) => _PendingCard(
                req: r,
                timeAgo: _timeAgo(r.requestDate),
                coinValueBs: _coinValueBs,
                onApprove: () => _approve(r),
                onReject: () => _confirmReject(r),
                onViewProof: () => _showProof(r.proofImage),
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _text)),
        const SizedBox(height: 12),
        if (_loadingRequests)
          const SizedBox()
        else if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14)),
            child: const Center(
              child: Text('Sin historial aún',
                  style: TextStyle(fontSize: 13, color: _textSub)),
            ),
          )
        else
          ..._history.map((r) => _HistoryRow(
                req: r,
                onViewProof: () => _showProof(r.proofImage),
              )),
      ],
    );
  }
}

// ─── Card de solicitud pendiente ─────────────────────────────────────────────
class _PendingCard extends StatelessWidget {
  final CoinRechargeModel req;
  final String timeAgo;
  final double coinValueBs;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewProof;

  const _PendingCard({
    required this.req,
    required this.timeAgo,
    required this.coinValueBs,
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
          // Header
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFB8860B).withOpacity(0.15),
              backgroundImage:
                  (req.userImage != null && req.userImage!.isNotEmpty)
                      ? NetworkImage(req.userImage!)
                      : null,
              child: (req.userImage == null || req.userImage!.isEmpty)
                  ? Text(
                      req.userName?.isNotEmpty == true
                          ? req.userName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Color(0xFFB8860B),
                          fontWeight: FontWeight.bold))
                  : null,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

          // Info
          Row(children: [
            _InfoBadge(
                label: 'Monedas solicitadas', value: '${req.coinsRequested}'),
            const SizedBox(width: 12),
            _InfoBadge(
                label: 'Monto pagado',
                value: '${req.amountPaid.toStringAsFixed(0)} Bs'),
          ]),
          const SizedBox(height: 6),
          Text(timeAgo,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFFAAAAAA))),
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
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF888888))),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D))),
        ],
      );
}

// ─── Fila de historial ───────────────────────────────────────────────────────
class _HistoryRow extends StatelessWidget {
  final CoinRechargeModel req;
  final VoidCallback onViewProof;
  const _HistoryRow({required this.req, required this.onViewProof});

  @override
  Widget build(BuildContext context) {
    final approved = req.status == 'approved';
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
          backgroundImage:
              (req.userImage != null && req.userImage!.isNotEmpty)
                  ? NetworkImage(req.userImage!)
                  : null,
          child: (req.userImage == null || req.userImage!.isEmpty)
              ? Text(
                  req.userName?.isNotEmpty == true
                      ? req.userName![0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB8860B),
                      fontWeight: FontWeight.bold))
              : null,
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
              Text(
                '${req.resolvedDate != null ? "${req.resolvedDate!.day}/${req.resolvedDate!.month}/${req.resolvedDate!.year}" : "-"}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF888888)),
              ),
            ],
          ),
        ),
        Text('${req.coinsRequested}',
            style: const TextStyle(
                fontSize: 15,
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
