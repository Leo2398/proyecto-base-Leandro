import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class AdminPdfPreviewView extends StatefulWidget {
  final String title;
  final Future<Uint8List> Function() buildPdf;

  const AdminPdfPreviewView({
    super.key,
    required this.title,
    required this.buildPdf,
  });

  @override
  State<AdminPdfPreviewView> createState() => _AdminPdfPreviewViewState();
}

class _AdminPdfPreviewViewState extends State<AdminPdfPreviewView> {
  static const Color _primary = Color(0xFFB8860B);
  static const Color _primaryDark = Color(0xFF7A5607);
  static const Color _primarySoft = Color(0xFFFFF4D8);
  static const Color _accent = Color(0xFFD4A017);
  static const Color _background = Color(0xFFF5F0E8);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D2D2D);
  static const Color _textSecondary = Color(0xFF777777);
  static const Color _border = Color(0xFFE6DCCB);
  static const Color _success = Color(0xFF4F8F45);
  static const Color _danger = Color(0xFFD64545);

  late Future<Uint8List> _pdfFuture;

  bool _saving = false;
  int _reloadKey = 0;

  @override
  void initState() {
    super.initState();
    _pdfFuture = widget.buildPdf();
  }

  void _reloadPreview() {
    setState(() {
      _reloadKey++;
      _pdfFuture = widget.buildPdf();
    });

    _showSnack(
      'Vista previa actualizada',
      type: _PreviewSnackType.success,
    );
  }

  String _safeFileName(String value) {
    final clean = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü]+', caseSensitive: false), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (clean.isEmpty) return 'reporte_agromarket';
    return clean;
  }

  Future<void> _savePdf() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final bytes = await _pdfFuture;

      final filename =
          '${_safeFileName(widget.title)}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (!mounted) return;

      if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: filename,
        );

        if (!mounted) return;

        _showSnack(
          'PDF listo para guardar o compartir',
          type: _PreviewSnackType.success,
        );
      } else {
        final dir =
            await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);

        if (!mounted) return;

        _showSnack(
          'PDF guardado correctamente en Descargas',
          type: _PreviewSnackType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnack(
        'No se pudo guardar el PDF. Intenta actualizar la vista previa.',
        type: _PreviewSnackType.error,
      );

      debugPrint('Error al guardar PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: _background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar vista previa',
            onPressed: _saving ? null : _reloadPreview,
            icon: const Icon(
              Icons.refresh_rounded,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _headerCard(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _previewCard(),
                  ),
                ),
              ],
            ),
          ),
          if (_saving) _savingOverlay(),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryDark,
            _primary,
            _accent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -30,
            child: _orb(120, Colors.white.withOpacity(0.13)),
          ),
          Positioned(
            left: -30,
            bottom: -38,
            child: _orb(100, Colors.white.withOpacity(0.09)),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.17),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                        ),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vista previa del reporte',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _infoChip(
                          icon: Icons.visibility_outlined,
                          label: 'Revisar',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _infoChip(
                          icon: Icons.verified_outlined,
                          label: 'Datos reales',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _infoChip(
                          icon: Icons.save_alt_rounded,
                          label: 'PDF',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _savePdf,
                          icon: const Icon(
                            Icons.download_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'Descargar / Compartir',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white.withOpacity(0.65),
                            foregroundColor: _primaryDark,
                            disabledForegroundColor: _primaryDark.withOpacity(0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _saving ? null : _reloadPreview,
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        height: 48,
                        width: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 23,
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
    );
  }

  Widget _previewCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
            child: Row(
              children: [
                Container(
                  height: 39,
                  width: 39,
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: _primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documento generado',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Previsualiza el archivo antes de guardarlo',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'PDF',
                    style: TextStyle(
                      color: _primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: PdfPreview(
                key: ValueKey(_reloadKey),
                build: (_) => _pdfFuture,
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                scrollViewDecoration: const BoxDecoration(
                  color: Color(0xFFF9F4EA),
                ),
                pdfPreviewPageDecoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _savingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 23,
                width: 23,
                child: CircularProgressIndicator(
                  color: _primary,
                  strokeWidth: 2.7,
                ),
              ),
              SizedBox(width: 13),
              Text(
                'Preparando PDF...',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(
      String message, {
        _PreviewSnackType type = _PreviewSnackType.info,
      }) {
    Color color;
    IconData icon;

    switch (type) {
      case _PreviewSnackType.success:
        color = _success;
        icon = Icons.check_circle_outline_rounded;
        break;
      case _PreviewSnackType.error:
        color = _danger;
        icon = Icons.error_outline_rounded;
        break;
      case _PreviewSnackType.info:
        color = _primary;
        icon = Icons.info_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PreviewSnackType {
  success,
  error,
  info,
}