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
  File? _receiptImage;
  String? _uploadedBase64;
  bool _isUploading = false;
  bool _isSubmitting = false;

  static const Color _bg = Color(0xFFF8F2EA);
  static const Color _surface = Colors.white;
  static const Color _surfaceSoft = Color(0xFFFFFCF8);

  static const Color _primary = Color(0xFFC69A5B);
  static const Color _primaryDark = Color(0xFF8B6B4A);
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
      context.read<RequestController>().loadConfig();
    });
  }

  Future<void> _pickReceipt() async {
    final source = await _showSourceDialog();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
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
  }

  Future<ImageSource?> _showSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
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
                const SizedBox(height: 16),
                const Text(
                  'Subir comprobante',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 14),
                _sourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Galería',
                  subtitle: 'Elegir una imagen guardada',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                _sourceTile(
                  icon: Icons.photo_camera_back_outlined,
                  title: 'Cámara',
                  subtitle: 'Tomar una foto al comprobante',
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
    return ListTile(
      onTap: onTap,
      tileColor: const Color(0xFFFFFCF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: _primaryDark),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: _text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: _textSoft,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_uploadedBase64 == null || _uploadedBase64!.trim().isEmpty) {
      _showSnack('Primero adjunta tu comprobante de pago.', error: true);
      return;
    }

    final userCtrl = context.read<UserController>();
    final requestCtrl = context.read<RequestController>();
    final userId = userCtrl.currentUser?.id;

    if (userId == null || userId <= 0) {
      _showSnack('No se encontró un productor válido.', error: true);
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    bool success = false;

    try {
      success = await requestCtrl.submitRequest(
        userID: userId,
        coins: widget.coins,
        amount: widget.totalBs,
        imageUrl: _uploadedBase64!,
      );

      if (success) {
        await userCtrl.reloadCurrentUser();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
      return;
    }

    _showSnack(
      requestCtrl.errorMessage ?? 'No se pudo enviar la solicitud.',
      error: true,
    );
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: _green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '¡Solicitud enviada!',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu solicitud de ${widget.coins} monedas fue registrada correctamente. El administrador deberá aprobarla para que se acrediten en tu saldo.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: _textSoft,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0D8A0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: _gold,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La recarga no es instantánea. Primero queda pendiente y luego el administrador la aprueba o rechaza.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _textSoft,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _danger : _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RequestController>(
      builder: (context, requestCtrl, _) {
        final qrImage = requestCtrl.config.qrImage;
        final bsPerCoin =
        requestCtrl.config.bsPerCoin > 0 ? requestCtrl.config.bsPerCoin : widget.bsPerCoin;
        final totalBs = (widget.coins * bsPerCoin).toStringAsFixed(2);

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(widget.coins, totalBs),
                        const SizedBox(height: 18),
                        _buildSectionCard(
                          title: 'Resumen del pago',
                          subtitle:
                          'Confirma el monto, realiza el pago con QR y luego sube tu comprobante.',
                          child: _buildSummary(bsPerCoin, totalBs),
                        ),
                        const SizedBox(height: 18),
                        _buildSectionCard(
                          title: 'Pago por QR',
                          subtitle:
                          'Escanea el QR desde tu banco o billetera y paga exactamente el monto indicado.',
                          child: _buildQrCard(qrImage, bsPerCoin),
                        ),
                        const SizedBox(height: 18),
                        _buildSectionCard(
                          title: 'Comprobante',
                          subtitle:
                          'Adjunta una foto o captura clara del pago para que el administrador pueda revisarlo.',
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
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _text,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: _surface,
              padding: const EdgeInsets.all(10),
              elevation: 2,
              shadowColor: Colors.black12,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmar pago',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Último paso para enviar tu solicitud',
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
    );
  }

  Widget _buildHero(int coins, String totalBs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF554941),
            Color(0xFF403732),
            Color(0xFF2E2926),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -12,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _heroChip(Icons.qr_code_2_rounded, 'QR'),
                  _heroChip(Icons.receipt_long_outlined, 'Comprobante'),
                  _heroChip(Icons.verified_outlined, 'Revisión admin'),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Solicitud de recarga',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$coins monedas · Bs $totalBs',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Text(
                  'Haz el pago, sube tu comprobante y envía la solicitud. Las monedas aparecerán en tu saldo cuando el administrador la apruebe.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.3,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
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
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(99),
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
                        fontWeight: FontWeight.w800,
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

  Widget _buildSummary(double bsPerCoin, String totalBs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _divider),
      ),
      child: Column(
        children: [
          _summaryRow('Monedas', '${widget.coins}'),
          const SizedBox(height: 8),
          _summaryRow('Bs por moneda', bsPerCoin.toStringAsFixed(2)),
          const SizedBox(height: 8),
          _summaryRow('Total a pagar', 'Bs $totalBs', highlight: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: _textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            color: highlight ? _primaryDark : _text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard(String? qrImage, double bsPerCoin) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 620;

        final qrBox = Container(
          width: vertical ? double.infinity : 180,
          constraints: const BoxConstraints(minHeight: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _divider),
          ),
          child: qrImage != null && qrImage.trim().isNotEmpty
              ? AppImage(
            src: qrImage,
            fit: BoxFit.contain,
            borderRadius: 14,
            placeholder: const Center(
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 74,
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
                  size: 74,
                  color: _primaryDark,
                ),
                SizedBox(height: 10),
                Text(
                  'QR no configurado',
                  style: TextStyle(
                    color: _textSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );

        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escanea y paga Bs ${widget.totalBs.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: _text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Referencia actual: 1 moneda = Bs ${bsPerCoin.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 13.2,
                fontWeight: FontWeight.w700,
                color: _primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            _miniStep('1', 'Escanea el QR desde tu banco o billetera.'),
            _miniStep('2', 'Paga exactamente el monto que se muestra arriba.'),
            _miniStep('3', 'Sube el comprobante y envía tu solicitud.'),
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
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: _textSoft,
                height: 1.35,
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
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _receiptImage != null ? _primary.withOpacity(0.45) : _divider,
            ),
          ),
          child: _buildReceiptContent(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_isUploading || _isSubmitting) ? null : _pickReceipt,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              _receiptImage == null ? 'Seleccionar comprobante' : 'Cambiar comprobante',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: _primaryDark,
              side: const BorderSide(color: _border),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptContent() {
    if (_isUploading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primary, strokeWidth: 2.6),
          SizedBox(height: 14),
          Text(
            'Procesando comprobante...',
            style: TextStyle(
              color: _primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Espera un momento mientras preparamos la imagen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textSoft,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      );
    }

    if (_receiptImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          _receiptImage!,
          width: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) {
            return Container(
              height: 220,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_rounded,
                color: _primaryDark,
                size: 42,
              ),
            );
          },
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: _primaryDark,
            size: 32,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Aún no subiste un comprobante',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sube una foto o captura clara del pago realizado.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.8,
            color: _textSoft,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote() {
    return Container(
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
          Icon(Icons.access_time_rounded, color: _gold, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las monedas no se acreditan al instante. Tu solicitud quedará pendiente hasta que el administrador confirme el pago.',
              style: TextStyle(
                fontSize: 12.8,
                color: _textSoft,
                height: 1.38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final disabled = _isUploading || _isSubmitting;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: disabled ? null : _submitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primary.withOpacity(0.40),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
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
                : const Icon(Icons.send_rounded),
            label: Text(
              _isSubmitting ? 'Enviando solicitud...' : 'Enviar solicitud',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}