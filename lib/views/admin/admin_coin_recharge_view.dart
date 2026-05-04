import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';
import '../../models/app_config_model.dart';
import '../../models/request_model.dart';
import '../../services/request_service.dart';

/// Vista de administración de recargas de monedas.
/// Permite configurar el QR oficial, el valor de la moneda
/// y gestionar solicitudes pendientes/historial.
class AdminCoinRechargeView extends StatefulWidget {
  const AdminCoinRechargeView({super.key});

  @override
  State<AdminCoinRechargeView> createState() => _AdminCoinRechargeViewState();
}

class _AdminCoinRechargeViewState extends State<AdminCoinRechargeView> {
  final RequestService _service = RequestService();

  final TextEditingController _coinCtrl = TextEditingController();
  final TextEditingController _historySearchCtrl = TextEditingController();

  AppConfigModel _config = AppConfigModel.defaults;

  List<RequestModel> _pending = [];
  List<RequestModel> _history = [];

  bool _loadingConfig = true;
  bool _loadingRequests = true;
  bool _savingCoin = false;
  bool _uploadingQr = false;
  bool _showAllHistory = false;

  int _historyFilter = 0; // 0: todos, 1: aprobados, 2: rechazados
  int? _busyRequestId;

  static const int _historyInitialLimit = 8;

  int get _adminId {
    return Provider.of<UserController>(context, listen: false).currentUser?.id ?? 0;
  }

  int get _approvedCount => _history.where((r) => r.state == 1).length;

  int get _rejectedCount => _history.where((r) => r.state == 2).length;

  double get _pendingAmount {
    return _pending.fold<double>(0, (sum, item) => sum + item.amount);
  }

  bool get _hasQr => (_config.qrImage ?? '').trim().isNotEmpty;

  List<RequestModel> get _filteredHistory {
    final query = _historySearchCtrl.text.trim().toLowerCase();

    final filtered = _history.where((r) {
      final matchesFilter = _historyFilter == 0 ||
          (_historyFilter == 1 && r.state == 1) ||
          (_historyFilter == 2 && r.state == 2);

      final userName = (r.userName ?? '').toLowerCase();
      final userEmail = (r.userEmail ?? '').toLowerCase();
      final stateText = _requestStateLabel(r.state).toLowerCase();

      final matchesSearch = query.isEmpty ||
          userName.contains(query) ||
          userEmail.contains(query) ||
          stateText.contains(query) ||
          '${r.value}'.contains(query);

      return matchesFilter && matchesSearch;
    }).toList();

    filtered.sort(_sortByDateDesc);
    return filtered;
  }

  List<RequestModel> get _visibleHistory {
    final items = _filteredHistory;
    if (_showAllHistory || items.length <= _historyInitialLimit) return items;
    return items.take(_historyInitialLimit).toList();
  }

  @override
  void initState() {
    super.initState();
    _historySearchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _showAllHistory = false);
    });
    _load();
  }

  @override
  void dispose() {
    _coinCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _service.migrateAppConfig();
      await Future.wait([
        _loadConfig(),
        _loadRequests(),
      ]);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _loadingRequests = false;
      });
      _snack('No se pudo cargar la información. Intenta nuevamente.', error: true);
    }
  }

  Future<void> _loadConfig() async {
    if (mounted) setState(() => _loadingConfig = true);

    try {
      final config = await _service.getAppConfig();

      if (!mounted) return;
      setState(() {
        _config = config;
        _coinCtrl.text = config.bsPerCoin.toStringAsFixed(2);
        _loadingConfig = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConfig = false);
      _snack('No se pudo cargar la configuración de monedas.', error: true);
    }
  }

  Future<void> _loadRequests() async {
    if (mounted) setState(() => _loadingRequests = true);

    try {
      final all = await _service.getAllRequests();

      final pending = all.where((r) => r.state == 0).toList();
      final history = all.where((r) => r.state != 0).toList();

      pending.sort(_sortByDateDesc);
      history.sort(_sortByDateDesc);

      if (!mounted) return;
      setState(() {
        _pending = pending;
        _history = history;
        _loadingRequests = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingRequests = false);
      _snack('No se pudieron cargar las solicitudes.', error: true);
    }
  }

  int _sortByDateDesc(RequestModel a, RequestModel b) {
    final ad = a.registerDate ??
        a.processedDate ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bd = b.registerDate ??
        b.processedDate ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return bd.compareTo(ad);
  }

  Future<void> _saveCoinValue() async {
    final value = double.tryParse(_coinCtrl.text.trim().replaceAll(',', '.'));

    if (value == null || value <= 0) {
      _snack('Ingresa un valor válido mayor a 0.', error: true);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _savingCoin = true);

    try {
      final ok = await _service.updateBsPerCoin(value);

      if (!mounted) return;
      setState(() => _savingCoin = false);

      if (ok) {
        setState(() {
          _config = AppConfigModel(
            bsPerCoin: value,
            qrImage: _config.qrImage,
          );
          _coinCtrl.text = value.toStringAsFixed(2);
        });
        _snack('Valor de moneda actualizado correctamente.');
      } else {
        _snack('Error al guardar el valor de la moneda.', error: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingCoin = false);
      _snack('Error al guardar el valor de la moneda.', error: true);
    }
  }

  Future<void> _pickAndSaveQr() async {
    final source = await _selectImageSource();
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 32,
        maxWidth: 700,
        maxHeight: 700,
      );

      if (picked == null) return;

      setState(() => _uploadingQr = true);

      final base64 = await ImageHelper.toBase64(File(picked.path));

      if (base64 == null || base64.isEmpty) {
        if (!mounted) return;
        setState(() => _uploadingQr = false);
        _snack('No se pudo procesar la imagen del QR.', error: true);
        return;
      }

      final ok = await _service.updateQrImage(base64);

      if (!mounted) return;
      setState(() => _uploadingQr = false);

      if (ok) {
        setState(() {
          _config = AppConfigModel(
            bsPerCoin: _config.bsPerCoin,
            qrImage: base64,
          );
        });
        _snack('QR oficial actualizado correctamente.');
      } else {
        _snack('Error al guardar el QR.', error: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingQr = false);
      _snack('No se pudo actualizar el QR.', error: true);
    }
  }

  Future<ImageSource?> _selectImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _AdminColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _IconBubble(
                      icon: Icons.qr_code_2_rounded,
                      color: _AdminColors.primary,
                      background: _AdminColors.primarySoft,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actualizar QR oficial',
                            style: TextStyle(
                              color: _AdminColors.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Elige una imagen clara del QR de pago.',
                            style: TextStyle(
                              color: _AdminColors.textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ImageSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Elegir desde galería',
                  subtitle: 'Usa una imagen ya guardada en el celular.',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                _ImageSourceTile(
                  icon: Icons.photo_camera_rounded,
                  title: 'Tomar foto',
                  subtitle: 'Captura el QR directamente con la cámara.',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmApprove(RequestModel req) async {
    if (req.id == null) {
      _snack('La solicitud no tiene un ID válido.', error: true);
      return;
    }

    if (_busyRequestId != null) return;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          title: Row(
            children: [
              _IconBubble(
                icon: Icons.check_circle_rounded,
                color: _AdminColors.green,
                background: _AdminColors.greenSoft,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Aprobar recarga',
                  style: TextStyle(
                    color: _AdminColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Se acreditarán ${req.value} monedas a ${req.userName ?? "este usuario"}.\n\n'
                'Verifica antes que el comprobante coincida con el monto pagado.',
            style: const TextStyle(
              color: _AdminColors.textSoft,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Aprobar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AdminColors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (accepted == true) {
      await _approve(req);
    }
  }

  Future<void> _approve(RequestModel req) async {
    if (req.id == null) {
      _snack('La solicitud no tiene un ID válido.', error: true);
      return;
    }

    setState(() => _busyRequestId = req.id);

    try {
      final ok = await _service.approveRequest(
        requestID: req.id!,
        adminID: _adminId,
      );

      if (!mounted) return;
      setState(() => _busyRequestId = null);

      if (ok) {
        _snack(
          'Recarga aprobada. Se acreditaron ${req.value} monedas a ${req.userName ?? "usuario"}.',
        );
        await _loadRequests();
      } else {
        _snack('Error al aprobar la solicitud.', error: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyRequestId = null);
      _snack('No se pudo aprobar la solicitud.', error: true);
    }
  }

  Future<void> _confirmReject(RequestModel req) async {
    if (req.id == null) {
      _snack('La solicitud no tiene un ID válido.', error: true);
      return;
    }

    if (_busyRequestId != null) return;

    final first = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          title: Row(
            children: [
              _IconBubble(
                icon: Icons.cancel_rounded,
                color: _AdminColors.red,
                background: _AdminColors.redSoft,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Rechazar solicitud',
                  style: TextStyle(
                    color: _AdminColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '¿Deseas rechazar la solicitud de ${req.userName ?? "usuario"} por ${req.value} monedas?',
            style: const TextStyle(
              color: _AdminColors.textSoft,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Rechazar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _AdminColors.red,
                side: const BorderSide(color: _AdminColors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (first != true) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'Confirmar rechazo definitivo',
            style: TextStyle(
              color: _AdminColors.red,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Esta acción no se puede deshacer.\n\n'
                '${req.userName ?? "El usuario"} no recibirá las ${req.value} monedas.',
            style: const TextStyle(
              color: _AdminColors.textSoft,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AdminColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Sí, rechazar'),
            ),
          ],
        );
      },
    );

    if (second == true) {
      await _reject(req);
    }
  }

  Future<void> _reject(RequestModel req) async {
    if (req.id == null) {
      _snack('La solicitud no tiene un ID válido.', error: true);
      return;
    }

    setState(() => _busyRequestId = req.id);

    try {
      final ok = await _service.rejectRequest(
        requestID: req.id!,
        adminID: _adminId,
      );

      if (!mounted) return;
      setState(() => _busyRequestId = null);

      if (ok) {
        _snack('Solicitud rechazada correctamente.');
        await _loadRequests();
      } else {
        _snack('Error al rechazar la solicitud.', error: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyRequestId = null);
      _snack('No se pudo rechazar la solicitud.', error: true);
    }
  }

  void _showProof(RequestModel req) {
    final image = req.image;

    if (image == null || image.trim().isEmpty) {
      _snack('Esta solicitud no tiene comprobante adjunto.', error: true);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
                  child: Row(
                    children: [
                      _IconBubble(
                        icon: Icons.receipt_long_rounded,
                        color: _AdminColors.primary,
                        background: _AdminColors.primarySoft,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Comprobante de pago',
                              style: TextStyle(
                                color: _AdminColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Revisa el monto antes de aprobar.',
                              style: TextStyle(
                                color: _AdminColors.textSoft,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _AdminColors.border),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: _ProofInfoBar(req: req),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: double.infinity,
                        color: _AdminColors.input,
                        child: InteractiveViewer(
                          minScale: 0.7,
                          maxScale: 4,
                          child: AppImage(
                            src: image,
                            width: double.infinity,
                            height: 460,
                            fit: BoxFit.contain,
                            placeholder: const Padding(
                              padding: EdgeInsets.all(36),
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 52,
                                color: _AdminColors.textSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: error ? _AdminColors.red : _AdminColors.green,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Sin fecha';

    final diff = DateTime.now().difference(date);

    if (diff.inDays > 365) {
      final years = diff.inDays ~/ 365;
      return 'Hace $years año${years > 1 ? "s" : ""}';
    }

    if (diff.inDays > 30) {
      final months = diff.inDays ~/ 30;
      return 'Hace $months mes${months > 1 ? "es" : ""}';
    }

    if (diff.inDays > 0) {
      return 'Hace ${diff.inDays} día${diff.inDays > 1 ? "s" : ""}';
    }

    if (diff.inHours > 0) {
      return 'Hace ${diff.inHours} hora${diff.inHours > 1 ? "s" : ""}';
    }

    if (diff.inMinutes > 0) {
      return 'Hace ${diff.inMinutes} min';
    }

    return 'Ahora mismo';
  }

  String _formatDate(DateTime? date, {bool withHour = false}) {
    if (date == null) return 'Sin fecha';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    if (!withHour) return '$day/$month/$year';

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year · $hour:$minute';
  }

  String _requestStateLabel(int state) {
    switch (state) {
      case 0:
        return 'Pendiente';
      case 1:
        return 'Aprobado';
      case 2:
        return 'Rechazado';
      default:
        return 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _AdminColors.bg,
      appBar: AppBar(
        backgroundColor: _AdminColors.bg,
        surfaceTintColor: _AdminColors.bg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _AdminColors.text,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recarga de monedas',
              style: TextStyle(
                color: _AdminColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Administra pagos, QR y solicitudes',
              style: TextStyle(
                color: _AdminColors.textSoft,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _load,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _AdminColors.primary,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: _AdminColors.primary,
        backgroundColor: Colors.white,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomPadding),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildConfigCard(),
            const SizedBox(height: 20),
            _buildPendingSection(),
            const SizedBox(height: 20),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _AdminColors.primaryDark,
            _AdminColors.primary,
            _AdminColors.primaryLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _AdminColors.primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -28,
            child: _DecorCircle(
              size: 120,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Positioned(
            bottom: -46,
            left: -34,
            child: _DecorCircle(
              size: 110,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Positioned(
            right: 22,
            bottom: 20,
            child: Icon(
              Icons.monetization_on_rounded,
              size: 86,
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Panel de recargas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Controla los pagos de productores y el valor oficial de la moneda.',
                            style: TextStyle(
                              color: Color(0xFFFFF3D7),
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroMetric(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pendientes',
                      value: '${_pending.length}',
                    ),
                    _HeroMetric(
                      icon: Icons.payments_rounded,
                      label: 'Por verificar',
                      value: '${_pendingAmount.toStringAsFixed(0)} Bs',
                    ),
                    _HeroMetric(
                      icon: Icons.price_change_rounded,
                      label: '1 moneda',
                      value: '${_config.bsPerCoin.toStringAsFixed(2)} Bs',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return _SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.tune_rounded,
            title: 'Configuración de moneda',
            subtitle: 'Define el precio oficial y el QR que verán los productores.',
            trailing: _StatusBadge(
              label: _hasQr ? 'QR activo' : 'QR pendiente',
              color: _hasQr ? _AdminColors.green : _AdminColors.orange,
              background: _hasQr ? _AdminColors.greenSoft : _AdminColors.orangeSoft,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;

              final valueBlock = _buildCoinValueBlock();
              final qrBlock = _buildQrBlock();

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: valueBlock),
                    const SizedBox(width: 16),
                    SizedBox(width: 210, child: qrBlock),
                  ],
                );
              }

              return Column(
                children: [
                  valueBlock,
                  const SizedBox(height: 16),
                  qrBlock,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCoinValueBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AdminColors.cardSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SmallLabel(
            icon: Icons.attach_money_rounded,
            text: 'Valor de 1 moneda en bolivianos',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _coinCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveCoinValue(),
            style: const TextStyle(
              color: _AdminColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(
                Icons.savings_rounded,
                color: _AdminColors.primary,
              ),
              suffixText: 'Bs',
              suffixStyle: const TextStyle(
                color: _AdminColors.textSoft,
                fontWeight: FontWeight.w800,
              ),
              hintText: 'Ej: 100.00',
              hintStyle: const TextStyle(
                color: _AdminColors.textLight,
                fontWeight: FontWeight.w600,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _AdminColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _AdminColors.primary,
                  width: 1.4,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _AdminColors.red),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoHint(
                  icon: Icons.info_outline_rounded,
                  text: 'Este valor se usará para calcular el monto que debe pagar el productor.',
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _savingCoin ? null : _saveCoinValue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AdminColors.primary,
                  disabledBackgroundColor: _AdminColors.primary.withOpacity(0.45),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _savingCoin
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
                    : const Text(
                  'Guardar',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrBlock() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AdminColors.cardSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SmallLabel(
            icon: Icons.qr_code_2_rounded,
            text: 'QR oficial de pago',
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 174,
              height: 174,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _AdminColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _loadingConfig
                  ? const Center(
                child: CircularProgressIndicator(
                  color: _AdminColors.primary,
                ),
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AppImage(
                  src: _config.qrImage ?? '',
                  width: 158,
                  height: 158,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: _AdminColors.input,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_rounded,
                          size: 50,
                          color: _AdminColors.textLight,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Sin QR',
                          style: TextStyle(
                            color: _AdminColors.textSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Sube PNG/JPG',
                          style: TextStyle(
                            color: _AdminColors.textLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
                  strokeWidth: 2.1,
                  color: _AdminColors.primary,
                ),
              )
                  : const Icon(Icons.add_photo_alternate_rounded, size: 18),
              label: Text(_uploadingQr ? 'Procesando...' : 'Cambiar QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _AdminColors.primary,
                disabledForegroundColor: _AdminColors.primary.withOpacity(0.45),
                side: const BorderSide(color: _AdminColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.pending_actions_rounded,
          title: 'Solicitudes pendientes',
          subtitle: 'Revisa comprobantes y aprueba solo los pagos válidos.',
          trailing: _StatusBadge(
            label: '${_pending.length}',
            color: _pending.isEmpty ? _AdminColors.green : _AdminColors.orange,
            background:
            _pending.isEmpty ? _AdminColors.greenSoft : _AdminColors.orangeSoft,
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingRequests)
          const _LoadingCard(message: 'Cargando solicitudes pendientes...')
        else if (_pending.isEmpty)
          _EmptyStateCard(
            icon: Icons.verified_rounded,
            color: _AdminColors.green,
            title: 'Todo al día',
            message: 'No hay solicitudes pendientes por revisar.',
          )
        else
          ..._pending.map(
                (req) {
              final busy = _busyRequestId == req.id;

              return _PendingCard(
                req: req,
                busy: busy,
                timeAgo: _timeAgo(req.registerDate),
                dateText: _formatDate(req.registerDate, withHour: true),
                onApprove: () => _confirmApprove(req),
                onReject: () => _confirmReject(req),
                onViewProof: () => _showProof(req),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHistorySection() {
    final filtered = _filteredHistory;
    final visible = _visibleHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: Icons.history_rounded,
          title: 'Historial de recargas',
          subtitle: 'Consulta solicitudes aprobadas y rechazadas.',
          trailing: _StatusBadge(
            label: '${_history.length}',
            color: _AdminColors.primary,
            background: _AdminColors.primarySoft,
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _HistoryMiniStat(
                      label: 'Aprobadas',
                      value: '$_approvedCount',
                      icon: Icons.check_circle_rounded,
                      color: _AdminColors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HistoryMiniStat(
                      label: 'Rechazadas',
                      value: '$_rejectedCount',
                      icon: Icons.cancel_rounded,
                      color: _AdminColors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _historySearchCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _AdminColors.input,
                  hintText: 'Buscar por usuario, correo o monedas...',
                  hintStyle: const TextStyle(
                    color: _AdminColors.textLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _AdminColors.textSoft,
                  ),
                  suffixIcon: _historySearchCtrl.text.trim().isEmpty
                      ? null
                      : IconButton(
                    onPressed: () => _historySearchCtrl.clear(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _AdminColors.textSoft,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _AdminColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: _AdminColors.primary,
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _HistoryFilterChip(
                      label: 'Todos',
                      selected: _historyFilter == 0,
                      onTap: () {
                        setState(() {
                          _historyFilter = 0;
                          _showAllHistory = false;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _HistoryFilterChip(
                      label: 'Aprobados',
                      selected: _historyFilter == 1,
                      color: _AdminColors.green,
                      onTap: () {
                        setState(() {
                          _historyFilter = 1;
                          _showAllHistory = false;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _HistoryFilterChip(
                      label: 'Rechazados',
                      selected: _historyFilter == 2,
                      color: _AdminColors.red,
                      onTap: () {
                        setState(() {
                          _historyFilter = 2;
                          _showAllHistory = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingRequests)
          const _LoadingCard(message: 'Cargando historial...')
        else if (_history.isEmpty)
          _EmptyStateCard(
            icon: Icons.history_toggle_off_rounded,
            color: _AdminColors.textSoft,
            title: 'Sin historial todavía',
            message: 'Cuando apruebes o rechaces solicitudes aparecerán aquí.',
          )
        else if (filtered.isEmpty)
            _EmptyStateCard(
              icon: Icons.search_off_rounded,
              color: _AdminColors.textSoft,
              title: 'Sin resultados',
              message: 'No encontramos recargas con ese filtro o búsqueda.',
            )
          else ...[
              ...visible.map(
                    (req) => _HistoryRow(
                  req: req,
                  dateText: _formatDate(req.processedDate ?? req.registerDate, withHour: true),
                  onViewProof: () => _showProof(req),
                ),
              ),
              if (filtered.length > _historyInitialLimit)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _showAllHistory = !_showAllHistory);
                      },
                      icon: Icon(
                        _showAllHistory
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                      label: Text(
                        _showAllHistory
                            ? 'Ver menos'
                            : 'Ver ${filtered.length - _historyInitialLimit} más',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _AdminColors.primary,
                        side: const BorderSide(color: _AdminColors.border),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
            ],
      ],
    );
  }
}

class _AdminColors {
  static const Color bg = Color(0xFFF5F0E8);
  static const Color card = Colors.white;
  static const Color cardSoft = Color(0xFFFBF8F1);
  static const Color input = Color(0xFFF8F5EF);

  static const Color primary = Color(0xFFB8860B);
  static const Color primaryDark = Color(0xFF7C4F08);
  static const Color primaryLight = Color(0xFFD7A84D);
  static const Color primarySoft = Color(0xFFFFF3D7);

  static const Color green = Color(0xFF5A8A5A);
  static const Color greenSoft = Color(0xFFEAF4EA);

  static const Color orange = Color(0xFFD9822B);
  static const Color orangeSoft = Color(0xFFFFF1DD);

  static const Color red = Color(0xFFD9534F);
  static const Color redSoft = Color(0xFFFFECEA);

  static const Color text = Color(0xFF2D2D2D);
  static const Color textSoft = Color(0xFF7B756B);
  static const Color textLight = Color(0xFFB5AFA4);
  static const Color border = Color(0xFFE7DED0);
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _AdminColors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBubble(
          icon: icon,
          color: _AdminColors.primary,
          background: _AdminColors.primarySoft,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _AdminColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _AdminColors.textSoft,
                  fontSize: 11.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;

  const _IconBubble({
    required this.icon,
    required this.color,
    required this.background,
    this.size = 42,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _DecorCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _DecorCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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

class _HeroMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFF3D7),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallLabel({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _AdminColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _AdminColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoHint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _AdminColors.textSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AdminColors.textSoft,
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _AdminColors.cardSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _IconBubble(
                icon: icon,
                color: _AdminColors.primary,
                background: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _AdminColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _AdminColors.textSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _AdminColors.textLight,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final RequestModel req;
  final bool busy;
  final String timeAgo;
  final String dateText;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewProof;

  const _PendingCard({
    required this.req,
    required this.busy,
    required this.timeAgo,
    required this.dateText,
    required this.onApprove,
    required this.onReject,
    required this.onViewProof,
  });

  @override
  Widget build(BuildContext context) {
    final userName = req.userName ?? 'Usuario';
    final userEmail = req.userEmail ?? '';
    final initial = userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFFBF2),
                    Color(0xFFFFFFFF),
                  ],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _AdminColors.primarySoft,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: _AdminColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AdminColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (userEmail.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              userEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _AdminColors.textSoft,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const _StatusBadge(
                    label: 'Pendiente',
                    color: _AdminColors.orange,
                    background: _AdminColors.orangeSoft,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _RequestInfoBox(
                          icon: Icons.monetization_on_rounded,
                          label: 'Monedas',
                          value: '${req.value}',
                          color: _AdminColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RequestInfoBox(
                          icon: Icons.payments_rounded,
                          label: 'Monto pagado',
                          value: '${req.amount.toStringAsFixed(2)} Bs',
                          color: _AdminColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: _AdminColors.textSoft,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$timeAgo · $dateText',
                          style: const TextStyle(
                            color: _AdminColors.textSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onViewProof,
                      icon: const Icon(Icons.visibility_rounded, size: 17),
                      label: const Text('Ver comprobante de pago'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _AdminColors.text,
                        side: const BorderSide(color: _AdminColors.border),
                        backgroundColor: _AdminColors.input,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : onApprove,
                          icon: busy
                              ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.check_rounded, size: 17),
                          label: Text(busy ? 'Procesando...' : 'Aprobar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _AdminColors.green,
                            disabledBackgroundColor: _AdminColors.green.withOpacity(0.5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : onReject,
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text('Rechazar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _AdminColors.red,
                            disabledForegroundColor: _AdminColors.red.withOpacity(0.45),
                            side: const BorderSide(color: _AdminColors.red),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestInfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _RequestInfoBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _AdminColors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AdminColors.border),
      ),
      child: Row(
        children: [
          _IconBubble(
            icon: icon,
            color: color,
            background: color.withOpacity(0.10),
            size: 36,
            iconSize: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.textSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HistoryMiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: _AdminColors.textSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = _AdminColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : _AdminColors.input,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : _AdminColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _AdminColors.textSoft,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final RequestModel req;
  final String dateText;
  final VoidCallback onViewProof;

  const _HistoryRow({
    required this.req,
    required this.dateText,
    required this.onViewProof,
  });

  @override
  Widget build(BuildContext context) {
    final approved = req.state == 1;
    final color = approved ? _AdminColors.green : _AdminColors.red;
    final bg = approved ? _AdminColors.greenSoft : _AdminColors.redSoft;
    final label = approved ? 'Aprobado' : 'Rechazado';

    final userName = req.userName ?? 'Usuario';
    final userEmail = req.userEmail ?? '';
    final initial = userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: _AdminColors.primarySoft,
            child: Text(
              initial,
              style: const TextStyle(
                color: _AdminColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminColors.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (userEmail.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AdminColors.textSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  children: [
                    _TinyBadge(
                      icon: Icons.monetization_on_rounded,
                      label: '${req.value} monedas',
                      color: _AdminColors.primary,
                      background: _AdminColors.primarySoft,
                    ),
                    _TinyBadge(
                      icon: approved ? Icons.check_rounded : Icons.close_rounded,
                      label: label,
                      color: color,
                      background: bg,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  dateText,
                  style: const TextStyle(
                    color: _AdminColors.textLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ver comprobante',
            onPressed: onViewProof,
            style: IconButton.styleFrom(
              backgroundColor: _AdminColors.input,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(
              Icons.visibility_rounded,
              color: _AdminColors.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  const _TinyBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofInfoBar extends StatelessWidget {
  final RequestModel req;

  const _ProofInfoBar({required this.req});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _AdminColors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AdminColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProofInfoItem(
              label: 'Usuario',
              value: req.userName ?? 'Usuario',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ProofInfoItem(
              label: 'Monedas',
              value: '${req.value}',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ProofInfoItem(
              label: 'Monto',
              value: '${req.amount.toStringAsFixed(2)} Bs',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofInfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _ProofInfoItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _AdminColors.textSoft,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _AdminColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;

  const _EmptyStateCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        children: [
          _IconBubble(
            icon: icon,
            color: color,
            background: color.withOpacity(0.10),
            size: 54,
            iconSize: 28,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _AdminColors.textSoft,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String message;

  const _LoadingCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: _AdminColors.primary,
              strokeWidth: 2.4,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _AdminColors.textSoft,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}