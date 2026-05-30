import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/request_controller.dart';
import '../../controllers/user_controller.dart';
import '../../core/image_helper.dart';

/// Pantalla donde el cliente ve el QR, sube el comprobante y confirma el pago
class ClientPaymentView extends StatefulWidget {
  final int coins;
  final double totalBs;
  final double bsPerCoin;

  const ClientPaymentView({
    super.key,
    required this.coins,
    required this.totalBs,
    required this.bsPerCoin,
  });

  @override
  State<ClientPaymentView> createState() => _ClientPaymentViewState();
}

class _ClientPaymentViewState extends State<ClientPaymentView> {
  File? _receiptImage;
  String? _uploadedUrl;
  bool _isUploading = false;

  Future<void> _pickReceipt() async {
    final source = await _showSourceDialog();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _receiptImage = File(picked.path);
      _isUploading = true;
      _uploadedUrl = null;
    });

    final url = await ImageHelper.toBase64(_receiptImage!);

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _uploadedUrl = url;
    });

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al subir la imagen. Intenta de nuevo.'),
          backgroundColor: Color(0xFFD96C2F),
        ),
      );
    }
  }

  Future<ImageSource?> _showSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D8CE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Text(
                'Subir comprobante',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF4EA),
                  child: Icon(Icons.photo_library_outlined,
                      color: Color(0xFF5A8A5A)),
                ),
                title: const Text('Galería de fotos'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF4EA),
                  child: Icon(Icons.camera_alt_outlined,
                      color: Color(0xFF5A8A5A)),
                ),
                title: const Text('Cámara'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (_uploadedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero sube tu comprobante de pago'),
          backgroundColor: Color(0xFFD96C2F),
        ),
      );
      return;
    }

    final userCtrl = context.read<UserController>();
    final reqCtrl = context.read<RequestController>();
    final userId = userCtrl.currentUser?.id;

    if (userId == null) return;

    // Registra el callback de notificación antes de enviar
    reqCtrl.onRequestStatusChanged = (request) {
      if (mounted) _showStatusNotification(request.state);
      // Recarga el balance del usuario en el UserController
      if (request.state == 1) {
        userCtrl.reloadCurrentUser();
      }
    };

    final success = await reqCtrl.submitRequest(
      userID: userId,
      coins: widget.coins,
      amount: widget.totalBs,
      imageUrl: _uploadedUrl!,
    );

    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reqCtrl.errorMessage ?? 'Error al enviar la solicitud'),
          backgroundColor: const Color(0xFFD96C2F),
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4EA),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF5A8A5A), size: 38),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Solicitud enviada!',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu solicitud de ${widget.coins} monedas está pendiente de aprobación. '
              'Te notificaremos cuando el administrador la procese.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5, color: Colors.grey.shade600, height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0D8A0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: Color(0xFFB8860B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este proceso puede tomar entre 15 minutos y 2 horas.',
                      style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade700,
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
                  Navigator.pop(context); // cierra dialog
                  Navigator.pop(context); // vuelve a paquetes
                  Navigator.pop(context); // vuelve al dashboard
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A8A5A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Entendido',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Notificación in-app cuando el admin aprueba/rechaza (polling)
  void _showStatusNotification(int state) {
    if (!mounted) return;

    final isApproved = state == 1;
    final color =
        isApproved ? const Color(0xFF5A8A5A) : const Color(0xFFD96C2F);
    final icon = isApproved
        ? Icons.check_circle_outline_rounded
        : Icons.cancel_outlined;
    final title =
        isApproved ? '¡Monedas acreditadas!' : 'Solicitud rechazada';
    final body = isApproved
        ? 'Se acreditaron ${widget.coins} monedas a tu cuenta.'
        : 'Tu solicitud fue rechazada. Contacta al administrador.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: color, size: 38),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5, color: Colors.grey.shade600, height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Aceptar',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    _buildQRCard(),
                    const SizedBox(height: 20),
                    _buildReceiptCard(),
                    const SizedBox(height: 16),
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

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF2D2D2D), size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
              elevation: 2,
              shadowColor: Colors.black12,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Completar pago',
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
        ],
      ),
    );
  }

  // ── QR Card ────────────────────────────────────────────────────────────────

  Widget _buildQRCard() {
    final config = context.read<RequestController>().config;
    final hasQr = config.qrImage != null && config.qrImage!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Escanea el QR para realizar el depósito',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 16),

          // QR
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E0D4)),
            ),
            child: hasQr
    ? AppImage(
        src: config.qrImage,
        fit: BoxFit.cover,
        borderRadius: 16,
        width: 200,
        height: 200,
        placeholder: _qrPlaceholder(),
      )
    : _qrPlaceholder(),
          ),

          const SizedBox(height: 16),

          // Monto
          Text(
            'Monto a pagar',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.totalBs.toStringAsFixed(0)} Bs',
            style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF5A8A5A), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Incluye el número de referencia en tu comprobante para agilizar la verificación',
                    style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code_2_rounded,
            size: 80, color: Color(0xFFCCC4B8)),
        const SizedBox(height: 8),
        Text(
          'QR pendiente de\nconfigración',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  // ── Receipt Card ───────────────────────────────────────────────────────────

  Widget _buildReceiptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sube tu comprobante de pago',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 14),

          GestureDetector(
            onTap: _isUploading ? null : _pickReceipt,
            child: Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _uploadedUrl != null
                      ? const Color(0xFF5A8A5A)
                      : const Color(0xFFDDD5C8),
                  width: _uploadedUrl != null ? 2 : 1.5,
                  style: _uploadedUrl == null && _receiptImage == null
                      ? BorderStyle.solid
                      : BorderStyle.solid,
                ),
              ),
              child: _buildReceiptContent(),
            ),
          ),

          if (_uploadedUrl != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF5A8A5A), size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Comprobante subido correctamente',
                    style: TextStyle(
                      color: Color(0xFF5A8A5A),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isUploading ? null : _pickReceipt,
                  child: const Text('Cambiar',
                      style: TextStyle(
                          color: Color(0xFF5A8A5A),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'PNG, JPG hasta 5MB',
                style: TextStyle(
                  fontSize: 11.5, color: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptContent() {
    if (_isUploading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              color: Color(0xFF5A8A5A), strokeWidth: 2.5),
          SizedBox(height: 12),
          Text('Subiendo comprobante...',
              style: TextStyle(
                  color: Color(0xFF8A6A45), fontWeight: FontWeight.w600)),
        ],
      );
    }

    if (_receiptImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.file(_receiptImage!, fit: BoxFit.cover,
            width: double.infinity),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4EA),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.cloud_upload_outlined,
              color: Color(0xFF5A8A5A), size: 30),
        ),
        const SizedBox(height: 10),
        const Text(
          'Arrastra tu imagen aquí',
          style: TextStyle(
            color: Color(0xFF4A4A4A), fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: _pickReceipt,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF5A8A5A),
            side: const BorderSide(color: Color(0xFF5A8A5A)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          child: const Text('Seleccionar imagen',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ── Info note ──────────────────────────────────────────────────────────────

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEED9A0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.access_time_rounded,
              color: Color(0xFFB8860B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Las monedas se acreditarán a tu cuenta una vez que el administrador confirme y verifique la transacción. Este proceso puede tomar entre 15 minutos y 2 horas.',
              style: TextStyle(
                fontSize: 12.5, color: Colors.grey.shade700, height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Consumer<RequestController>(
      builder: (_, reqCtrl, __) {
        final isDisabled = reqCtrl.isLoading || _isUploading;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isDisabled ? null : _submitRequest,
              icon: isDisabled
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                isDisabled ? 'Enviando...' : 'Enviar comprobante',
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A8A5A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCCCCCC),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        );
      },
    );
  }
}