import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../../core/cloudinary_helper.dart';
import '../../models/coin_recharge_model.dart';
import '../../services/app_config_service.dart';
import '../../services/coin_recharge_service.dart';

/// Vista del cliente para recargar monedas
/// Muestra el QR de pago, permite enviar solicitud con comprobante y ver historial
class ClientCoinRechargeView extends StatefulWidget {
  const ClientCoinRechargeView({super.key});

  @override
  State<ClientCoinRechargeView> createState() =>
      _ClientCoinRechargeViewState();
}

class _ClientCoinRechargeViewState extends State<ClientCoinRechargeView> {
  static const _green = Color(0xFF5A8A5A);
  static const _gold = Color(0xFFB8860B);
  static const _bg = Color(0xFFF5F0E8);
  static const _text = Color(0xFF2D2D2D);
  static const _textSub = Color(0xFF888888);

  final _configService = AppConfigService();
  final _rechargeService = CoinRechargeService();
  final _coinsCtrl = TextEditingController();

  String? _qrImageUrl;
  double _coinValueBs = 1.0;
  String? _proofImageUrl;
  File? _proofFile;
  List<CoinRechargeModel> _history = [];
  bool _loadingConfig = true;
  bool _loadingHistory = true;
  bool _submitting = false;
  bool _uploadingProof = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _coinsCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([
      _configService.initTable(),
      _rechargeService.initTable(),
    ]);
    await _loadConfig();
    await _loadHistory();
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingConfig = true);
    final qr = await _configService.getQrImageUrl();
    final val = await _configService.getCoinValueBs();
    if (mounted) {
      setState(() {
        _qrImageUrl = qr;
        _coinValueBs = val;
        _loadingConfig = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    final user =
        Provider.of<UserController>(context, listen: false).currentUser;
    if (user?.id == null) {
      setState(() => _loadingHistory = false);
      return;
    }
    final list = await _rechargeService.getRequestsByUser(user!.id!);
    if (mounted) setState(() {
      _history = list;
      _loadingHistory = false;
    });
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      _proofFile = File(picked.path);
      _uploadingProof = true;
    });

    final url = await CloudinaryHelper.uploadImage(_proofFile!);
    if (mounted) {
      setState(() {
        _proofImageUrl = url;
        _uploadingProof = false;
      });
      if (url == null) _snack('Error al subir el comprobante', error: true);
    }
  }

  Future<void> _submit() async {
    final user =
        Provider.of<UserController>(context, listen: false).currentUser;
    if (user?.id == null) return;

    final coins = int.tryParse(_coinsCtrl.text.trim());
    if (coins == null || coins <= 0) {
      _snack('Ingresa una cantidad válida de monedas', error: true);
      return;
    }
    if (_proofImageUrl == null) {
      _snack('Debes subir el comprobante de pago', error: true);
      return;
    }

    setState(() => _submitting = true);
    final amountBs = coins * _coinValueBs;
    final ok = await _rechargeService.createRequest(
      userId: user!.id!,
      coinsRequested: coins,
      amountPaid: amountBs,
      proofImage: _proofImageUrl,
    );
    if (mounted) {
      setState(() {
        _submitting = false;
        if (ok) {
          _coinsCtrl.clear();
          _proofFile = null;
          _proofImageUrl = null;
        }
      });
      _snack(ok
          ? 'Solicitud enviada. El administrador la revisara pronto.'
          : 'Error al enviar la solicitud',
          error: !ok);
      if (ok) _loadHistory();
    }
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
    if (diff.inDays > 0)
      return 'Hace ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}';
    if (diff.inHours > 0)
      return 'Hace ${diff.inHours} hora${diff.inHours > 1 ? 's' : ''}';
    return 'Hace unos minutos';
  }

  @override
  Widget build(BuildContext context) {
    final coins = int.tryParse(_coinsCtrl.text.trim()) ?? 0;
    final total = (coins * _coinValueBs).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Recargar Monedas',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
      ),
      body: RefreshIndicator(
        color: _green,
        onRefresh: () async {
          await _loadConfig();
          await _loadHistory();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),

            // ─── Tasa de cambio ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.monetization_on,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tasa de cambio',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    Text('1 moneda = ${_coinValueBs.toStringAsFixed(2)} Bs',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ─── QR de pago ───────────────────────────────────────────────
            Container(
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
              child: Column(children: [
                const Text('Escanea este QR para pagar',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _text)),
                const SizedBox(height: 12),
                _loadingConfig
                    ? const CircularProgressIndicator(color: _green)
                    : _qrImageUrl != null && _qrImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _qrImageUrl!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.qr_code,
                                  size: 80,
                                  color: _textSub),
                            ),
                          )
                        : Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF8F5EF),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code,
                                    size: 64, color: Color(0xFFCCC5B9)),
                                SizedBox(height: 8),
                                Text('QR no disponible',
                                    style: TextStyle(
                                        fontSize: 12, color: _textSub)),
                              ],
                            ),
                          ),
                const SizedBox(height: 8),
                const Text('Realiza la transferencia y luego sube el comprobante',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: _textSub)),
              ]),
            ),
            const SizedBox(height: 16),

            // ─── Formulario de solicitud ──────────────────────────────────
            Container(
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
                  const Text('Nueva solicitud de recarga',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _text)),
                  const SizedBox(height: 14),

                  // Cantidad de monedas
                  const Text('Cantidad de monedas',
                      style: TextStyle(fontSize: 13, color: _textSub)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _coinsCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ej: 100',
                      prefixIcon: const Icon(Icons.monetization_on_outlined,
                          color: _gold, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8F5EF),
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
                  if (coins > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: _green),
                        const SizedBox(width: 6),
                        Text(
                          'Debes pagar $total Bs por $coins monedas',
                          style: const TextStyle(
                              fontSize: 12,
                              color: _green,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Comprobante
                  const Text('Comprobante de pago',
                      style: TextStyle(fontSize: 13, color: _textSub)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _uploadingProof ? null : _pickProof,
                    child: Container(
                      width: double.infinity,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5EF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _proofFile != null
                                ? _green
                                : const Color(0xFFE0D9CC)),
                      ),
                      child: _uploadingProof
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: _green))
                          : _proofFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Image.file(_proofFile!,
                                      fit: BoxFit.cover),
                                )
                              : const Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.upload_file_outlined,
                                        size: 32, color: Color(0xFFCCC5B9)),
                                    SizedBox(height: 6),
                                    Text('Toca para subir comprobante',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF888888))),
                                    Text('PNG o JPG',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFCCC5B9))),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón enviar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        disabledBackgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Enviar solicitud',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Historial ────────────────────────────────────────────────
            const Text('Mis solicitudes',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _text)),
            const SizedBox(height: 10),
            if (_loadingHistory)
              const Center(child: CircularProgressIndicator(color: _green))
            else if (_history.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14)),
                child: const Center(
                  child: Text('Aun no tienes solicitudes',
                      style:
                          TextStyle(fontSize: 13, color: _textSub)),
                ),
              )
            else
              ..._history.map((r) => _HistoryItem(
                    req: r,
                    timeAgo: _timeAgo(r.requestDate),
                  )),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final CoinRechargeModel req;
  final String timeAgo;
  const _HistoryItem({required this.req, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final isPending = req.status == 'pending';
    final isApproved = req.status == 'approved';

    Color statusColor;
    String statusLabel;
    if (isPending) {
      statusColor = Colors.orange.shade600;
      statusLabel = 'Pendiente';
    } else if (isApproved) {
      statusColor = const Color(0xFF5A8A5A);
      statusLabel = 'Aprobado';
    } else {
      statusColor = Colors.red.shade500;
      statusLabel = 'Rechazado';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: statusColor.withOpacity(0.12),
          child: Icon(
            isApproved
                ? Icons.check_circle_outline
                : isPending
                    ? Icons.hourglass_empty_outlined
                    : Icons.cancel_outlined,
            size: 18,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${req.coinsRequested} monedas',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D))),
              Text('${req.amountPaid.toStringAsFixed(0)} Bs  •  $timeAgo',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(statusLabel,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor)),
        ),
      ]),
    );
  }
}
