import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/request_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';

class ProducerPaymentView extends StatefulWidget {
  final int coins;
  final double totalBs;
  final double bsPerCoin;

  const ProducerPaymentView({
    super.key,
    required this.coins,
    required this.totalBs,
    required this.bsPerCoin,
  });

  @override
  State<ProducerPaymentView> createState() => _ProducerPaymentViewState();
}

class _ProducerPaymentViewState extends State<ProducerPaymentView> {
  final ImagePicker _picker = ImagePicker();

  File? _receiptImage;
  String? _uploadedBase64;

  bool _isUploading = false;
  bool _isSubmitting = false;

  static const Color _bg = Color(0xFFF8F2EA);
  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8B6B4A);
  static const Color _brownDark = Color(0xFF3B2F2A);
  static const Color _gold = Color(0xFFE0B56E);

  static const Color _green = Color(0xFF3F7D58);
  static const Color _orange = Color(0xFFD96C2F);
  static const Color _danger = Color(0xFFD85B5B);

  static const Color _text = Color(0xFF4E3426);
  static const Color _textSoft = Color(0xFF8C7B6B);
  static const Color _border = Color(0xFFF0E8DC);
  static const Color _divider = Color(0xFFE7DACA);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RequestController>().loadConfig();
    });
  }

  double _effectiveBsPerCoin(RequestController requestCtrl) {
    final configValue = requestCtrl.config.bsPerCoin;

    if (configValue > 0) return configValue;
    if (widget.bsPerCoin > 0) return widget.bsPerCoin;

    return 0;
  }

  double _effectiveTotalBs(RequestController requestCtrl) {
    final bsPerCoin = _effectiveBsPerCoin(requestCtrl);
    final calculatedTotal = widget.coins * bsPerCoin;

    if (calculatedTotal > 0) return calculatedTotal;
    return widget.totalBs;
  }

  String _money(double value) {
    return value.toStringAsFixed(2);
  }

  bool get _hasReceiptReady {
    return _uploadedBase64 != null && _uploadedBase64!.trim().isNotEmpty;
  }

  Future<void> _pickReceipt() async {
    final source = await _showSourceDialog();
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (picked == null) return;

      setState(() {
        _receiptImage = File(picked.path);
        _uploadedBase64 = null;
        _isUploading = true;
      });

      final base64 = await ImageHelper.toBase64(_receiptImage!);

      if (!mounted) return;

      setState(() {
        _uploadedBase64 = base64;
        _isUploading = false;
      });

      if (base64 == null || base64.trim().isEmpty) {
        _showSnack(
          'No se pudo procesar el comprobante. Intenta nuevamente.',
          error: true,
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      _showSnack(
        'No se pudo abrir la imagen. Revisa los permisos e intenta nuevamente.',
        error: true,
      );
    }
  }

  void _removeReceipt() {
    if (_isUploading || _isSubmitting) return;

    setState(() {
      _receiptImage = null;
      _uploadedBase64 = null;
    });
  }

  Future<ImageSource?> _showSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _divider,
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
                        color: _primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.receipt_long_outlined,
                        color: _primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subir comprobante',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _text,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Elige cómo quieres adjuntar tu pago',
                            style: TextStyle(
                              fontSize: 12.8,
                              color: _textSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Elegir desde galería',
                  subtitle: 'Usa una captura o foto guardada',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                _sourceTile(
                  icon: Icons.photo_camera_back_outlined,
                  title: 'Tomar una foto',
                  subtitle: 'Abre la cámara y fotografía el comprobante',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surfaceSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _text,
                        fontSize: 14.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSoft,
                        fontSize: 12.3,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: _textSoft,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_isUploading) {
      _showSnack('Espera a que termine de procesarse el comprobante.', error: true);
      return;
    }

    if (!_hasReceiptReady) {
      _showSnack('Primero adjunta tu comprobante de pago.', error: true);
      return;
    }

    final userCtrl = context.read<UserController>();
    final requestCtrl = context.read<RequestController>();

    final userId = userCtrl.currentUser?.id;
    final amount = _effectiveTotalBs(requestCtrl);

    if (userId == null || userId <= 0) {
      _showSnack('No se encontró un productor válido.', error: true);
      return;
    }

    if (amount <= 0) {
      _showSnack('No se pudo calcular el monto de la recarga.', error: true);
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await requestCtrl.submitRequest(
        userID: userId,
        coins: widget.coins,
        amount: amount,
        imageUrl: _uploadedBase64!,
      );

      if (!mounted) return;

      if (success) {
        await userCtrl.reloadCurrentUser();

        if (!mounted) return;

        await _showSuccessDialog(amount);
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      _showSnack(
        requestCtrl.errorMessage ?? 'No se pudo enviar la solicitud.',
        error: true,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showSnack(
        'No se pudo enviar la solicitud. Intenta nuevamente.',
        error: true,
      );
    }
  }

  Future<void> _showSuccessDialog(double totalBs) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFEAF7EF),
                        Color(0xFFDDF3E6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: _green,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Solicitud enviada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Registramos tu solicitud de ${widget.coins} monedas por Bs ${_money(totalBs)}. El administrador revisará tu comprobante antes de acreditar el saldo.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.4,
                    color: _textSoft,
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0D8A0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: _gold,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'La recarga quedará pendiente. Cuando el administrador la apruebe, las monedas aparecerán en tu saldo.',
                          style: TextStyle(
                            fontSize: 12.6,
                            color: _textSoft,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: error ? _danger : _green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestCtrl = context.watch<RequestController>();

    final config = requestCtrl.config;
    final qrImage = config.qrImage;

    final bsPerCoin = _effectiveBsPerCoin(requestCtrl);
    final totalBs = _effectiveTotalBs(requestCtrl);

    final totalText = _money(totalBs);
    final bsPerCoinText = _money(bsPerCoin);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(
                      coins: widget.coins,
                      totalBs: totalText,
                    ),
                    const SizedBox(height: 18),
                    _buildPaymentProgress(),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      icon: Icons.payments_outlined,
                      title: 'Resumen del pago',
                      subtitle: 'Revisa el monto antes de realizar la transferencia.',
                      child: _buildSummary(
                        bsPerCoin: bsPerCoinText,
                        totalBs: totalText,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      icon: Icons.qr_code_2_rounded,
                      title: 'Pago por QR',
                      subtitle: 'Escanea el QR desde tu banco o billetera.',
                      child: _buildQrCard(
                        qrImage: qrImage,
                        bsPerCoin: bsPerCoinText,
                        totalBs: totalText,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Comprobante',
                      subtitle: 'Adjunta una foto o captura clara del pago realizado.',
                      child: _buildReceiptPicker(),
                    ),
                    const SizedBox(height: 18),
                    _buildInfoNote(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _text,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmar pago',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _text,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Último paso para enviar tu solicitud',
                  style: TextStyle(
                    fontSize: 12.8,
                    color: _textSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: _primaryDark,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero({
    required int coins,
    required String totalBs,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5B4B41),
            Color(0xFF40352F),
            Color(0xFF2B2522),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -22,
            child: _heroOrb(112, Colors.white.withOpacity(0.055)),
          ),
          Positioned(
            bottom: -34,
            left: -30,
            child: _heroOrb(96, _gold.withOpacity(0.10)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip(Icons.qr_code_2_rounded, 'Pago QR'),
                  _heroChip(Icons.receipt_long_outlined, 'Comprobante'),
                  _heroChip(Icons.verified_user_outlined, 'Revisión segura'),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Recarga de monedas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$coins monedas para publicar tus productos',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14.2,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total a pagar',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bs $totalBs',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Realiza el pago, sube tu comprobante y espera la aprobación del administrador.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.8,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProgress() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
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
          _progressStep(
            icon: Icons.qr_code_2_rounded,
            label: 'Pagar',
            active: true,
          ),
          _progressLine(active: true),
          _progressStep(
            icon: Icons.receipt_long_outlined,
            label: 'Subir',
            active: _receiptImage != null,
          ),
          _progressLine(active: _hasReceiptReady),
          _progressStep(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Revisión',
            active: false,
          ),
        ],
      ),
    );
  }

  Widget _progressStep({
    required IconData icon,
    required String label,
    required bool active,
  }) {
    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? _primary : _surfaceSoft,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: active ? _primary : _divider,
              ),
            ),
            child: Icon(
              icon,
              color: active ? Colors.white : _textSoft,
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: active ? _primaryDark : _textSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressLine({required bool active}) {
    return Container(
      width: 28,
      height: 2,
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: active ? _primary.withOpacity(0.55) : _divider,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: _primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.8,
                        color: _textSoft,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSummary({
    required String bsPerCoin,
    required String totalBs,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          _summaryRow(
            icon: Icons.monetization_on_outlined,
            label: 'Monedas solicitadas',
            value: '${widget.coins}',
          ),
          const SizedBox(height: 10),
          _summaryRow(
            icon: Icons.sell_outlined,
            label: 'Precio por moneda',
            value: 'Bs $bsPerCoin',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _primary.withOpacity(0.22)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: _primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Total a pagar',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Bs $totalBs',
                  style: const TextStyle(
                    fontSize: 18,
                    color: _primaryDark,
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

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: _primaryDark,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: _textSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14.5,
            color: _text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard({
    required String? qrImage,
    required String bsPerCoin,
    required String totalBs,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 620;

        final qrBox = Container(
          width: vertical ? double.infinity : 190,
          constraints: const BoxConstraints(minHeight: 190),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: qrImage != null && qrImage.trim().isNotEmpty
              ? AppImage(
            src: qrImage,
            fit: BoxFit.contain,
            borderRadius: 16,
            placeholder: const Center(
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 76,
                color: _primaryDark,
              ),
            ),
          )
              : const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 76,
                  color: _primaryDark,
                ),
                SizedBox(height: 10),
                Text(
                  'QR no configurado',
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'El administrador debe registrar el QR.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSoft,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );

        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _brownDark.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 39,
                    height: 39,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: _primaryDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Paga exactamente Bs $totalBs',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _text,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Referencia actual: 1 moneda = Bs $bsPerCoin',
              style: const TextStyle(
                fontSize: 13.1,
                fontWeight: FontWeight.w800,
                color: _primaryDark,
              ),
            ),
            const SizedBox(height: 14),
            _miniStep('1', 'Escanea el QR desde tu banco o billetera.'),
            _miniStep('2', 'Verifica que el monto sea exactamente Bs $totalBs.'),
            _miniStep('3', 'Guarda la captura o foto del comprobante.'),
          ],
        );

        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              qrBox,
              const SizedBox(height: 14),
              info,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            qrBox,
            const SizedBox(width: 16),
            Expanded(child: info),
          ],
        );
      },
    );
  }

  Widget _miniStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: _textSoft,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 230),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceSoft,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: _receiptImage != null
                  ? _primary.withOpacity(0.48)
                  : _divider,
              width: _receiptImage != null ? 1.3 : 1,
            ),
          ),
          child: _buildReceiptContent(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_isUploading || _isSubmitting) ? null : _pickReceipt,
                icon: Icon(
                  _receiptImage == null
                      ? Icons.upload_file_rounded
                      : Icons.change_circle_outlined,
                ),
                label: Text(
                  _receiptImage == null
                      ? 'Seleccionar comprobante'
                      : 'Cambiar comprobante',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: _primaryDark,
                  side: const BorderSide(color: _border),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (_receiptImage != null) ...[
              const SizedBox(width: 10),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFFFD5D5)),
                ),
                child: IconButton(
                  onPressed: (_isUploading || _isSubmitting) ? null : _removeReceipt,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: _danger,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildReceiptContent() {
    if (_isUploading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: _primary,
            strokeWidth: 2.7,
          ),
          SizedBox(height: 14),
          Text(
            'Procesando comprobante...',
            style: TextStyle(
              color: _primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Espera un momento mientras preparamos la imagen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 12.6,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (_receiptImage != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GestureDetector(
              onTap: _openReceiptPreview,
              child: Image.file(
                _receiptImage!,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 230,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: _primaryDark,
                      size: 44,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _hasReceiptReady ? _green : _orange,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasReceiptReady
                        ? Icons.check_circle_outline_rounded
                        : Icons.hourglass_top_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _hasReceiptReady ? 'Listo' : 'Procesando',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_in_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Tocar para ampliar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: _primaryDark,
            size: 34,
          ),
        ),
        const SizedBox(height: 13),
        const Text(
          'Aún no subiste un comprobante',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: _text,
          ),
        ),
        const SizedBox(height: 7),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Sube una captura o foto clara donde se vea el monto pagado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.9,
              color: _textSoft,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _openReceiptPreview() {
    if (_receiptImage == null) return;

    showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(
                      _receiptImage!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.58),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0D8A0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _gold,
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las monedas no se acreditan al instante. Tu solicitud quedará pendiente hasta que el administrador confirme el pago.',
              style: TextStyle(
                fontSize: 12.9,
                color: _textSoft,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final disabled = _isUploading || _isSubmitting || !_hasReceiptReady;

    String buttonText = 'Enviar solicitud';
    IconData buttonIcon = Icons.send_rounded;

    if (_isUploading) {
      buttonText = 'Procesando comprobante...';
      buttonIcon = Icons.hourglass_top_rounded;
    } else if (_isSubmitting) {
      buttonText = 'Enviando solicitud...';
      buttonIcon = Icons.sync_rounded;
    } else if (!_hasReceiptReady) {
      buttonText = 'Adjunta el comprobante';
      buttonIcon = Icons.receipt_long_outlined;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: disabled ? null : _submitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primary.withOpacity(0.40),
              disabledForegroundColor: Colors.white.withOpacity(0.92),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
            ),
            icon: _isSubmitting
                ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
                : Icon(buttonIcon),
            label: Text(
              buttonText,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}