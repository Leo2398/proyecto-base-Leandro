import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Vista de previsualización de PDF con botón de descarga a carpeta local
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
  static const _primary = Color(0xFFB8860B);
  static const _background = Color(0xFFF5F0E8);
  static const _textPrimary = Color(0xFF2D2D2D);

  bool _saving = false;

  Future<void> _savePdf() async {
    setState(() => _saving = true);
    try {
      final bytes = await widget.buildPdf();
      final filename =
          'reporte_agromarket_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (Platform.isAndroid || Platform.isIOS) {
        /// En móvil: abre el selector nativo para guardar / compartir
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } else {
        /// En desktop: guarda directamente en la carpeta de descargas
        final dir = await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF guardado en: ${file.path}'),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar PDF: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textPrimary),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: _primary, strokeWidth: 2),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: _savePdf,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Descargar',
                        style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
        ],
      ),
      body: PdfPreview(
        build: (_) => widget.buildPdf(),
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        scrollViewDecoration:
            const BoxDecoration(color: Color(0xFFF5F0E8)),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}
