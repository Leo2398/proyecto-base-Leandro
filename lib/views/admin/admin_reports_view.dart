import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../../models/report_models.dart';
import '../../services/report_service.dart';
import 'admin_pdf_preview_view.dart';

enum _DateFilter { hoy, estaSemana, esteMes, esteAnio, personalizado }

/// Vista de Reportes del Administrador
class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  static const _primary = Color(0xFFB8860B);
  static const _primaryLight = Color(0xFFF5EDD0);
  static const _background = Color(0xFFF5F0E8);
  static const _textPrimary = Color(0xFF2D2D2D);
  static const _textSecondary = Color(0xFF888888);

  _DateFilter _filter = _DateFilter.hoy;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _loading = false;
  List<EmpresaReportItem> _empresas = [];
  List<ClienteReportItem> _clientes = [];
  List<ProductoReportItem> _productos = [];
  List<SectorReportItem> _sectores = [];

  final _service = ReportService();

  @override
  void initState() {
    super.initState();
    _applyFilter(_DateFilter.hoy);
  }

  // ----------------------------------------------------------------- date
  void _computeRange(_DateFilter f) {
    final now = DateTime.now();
    switch (f) {
      case _DateFilter.hoy:
        _from = DateTime(now.year, now.month, now.day);
        _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
      case _DateFilter.estaSemana:
        final s = now.subtract(Duration(days: now.weekday - 1));
        _from = DateTime(s.year, s.month, s.day);
        _to = _from.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case _DateFilter.esteMes:
        _from = DateTime(now.year, now.month, 1);
        _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case _DateFilter.esteAnio:
        _from = DateTime(now.year, 1, 1);
        _to = DateTime(now.year, 12, 31, 23, 59, 59);
      case _DateFilter.personalizado:
        _from = _customFrom ?? DateTime(now.year, now.month, 1);
        _to = _customTo ??
            DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  Future<void> _applyFilter(_DateFilter f) async {
    setState(() {
      _filter = f;
      _computeRange(f);
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getTopEmpresas(from: _from, to: _to),
        _service.getTopClientes(from: _from, to: _to),
        _service.getTopProductos(from: _from, to: _to),
        _service.getSectores(),
      ]);
      if (!mounted) return;
      setState(() {
        _empresas = results[0] as List<EmpresaReportItem>;
        _clientes = results[1] as List<ClienteReportItem>;
        _productos = results[2] as List<ProductoReportItem>;
        _sectores = results[3] as List<SectorReportItem>;
      });
    } catch (e) {
      print('Error cargando reportes: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ----------------------------------------------------------------- helpers
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  String _fmtMoney(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '\$${(v / 1000).toStringAsFixed(0)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _sectorEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('frut')) return '🍎';
    if (n.contains('hortal') || n.contains('vegetal')) return '🥬';
    if (n.contains('hidro')) return '💧';
    if (n.contains('grano') || n.contains('cereal')) return '🌾';
    if (n.contains('lácteo') || n.contains('lacteo')) return '🥛';
    if (n.contains('herb')) return '🌿';
    if (n.contains('carne') || n.contains('prote')) return '🥩';
    return '🌱';
  }

  String _sectorDesc(String name) {
    final n = name.toLowerCase();
    if (n.contains('frut')) return 'Sector más activo';
    if (n.contains('hortal')) return 'Alta demanda';
    if (n.contains('hidro')) return 'Tecnología avanzada';
    if (n.contains('grano')) return 'Producción estable';
    return 'Sector activo';
  }

  // ----------------------------------------------------------------- PDF building
  /// Construye el PDF y devuelve los bytes — NO abre diálogo de impresión
  Future<Uint8List> _buildPdfBytes({
    bool soloEmpresas = false,
    bool soloClientes = false,
    bool soloProductos = false,
    SectorReportItem? soloSector,
  }) async {
    // Fuente TTF con soporte Unicode completo (tildes, ñ, etc.)
    final ttfBold = await PdfGoogleFonts.nunitoBold();
    final ttfRegular = await PdfGoogleFonts.nunitoRegular();
    final ttfSemiBold = await PdfGoogleFonts.nunitoSemiBold();

    final periodo = '${_fmtDate(_from)} - ${_fmtDate(_to)}';
    final titleStyle = pw.TextStyle(
        font: ttfBold,
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.brown800);
    final sectionStyle = pw.TextStyle(
        font: ttfSemiBold,
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.brown700);
    final bodyStyle =
        pw.TextStyle(font: ttfRegular, fontSize: 10, color: PdfColors.grey800);

    final pdf = pw.Document();
    final List<pw.Widget> content = [];

    // Header
    content.addAll([
      pw.Text('AgroMarket Admin - Reporte General', style: titleStyle),
      pw.SizedBox(height: 4),
      pw.Text('Periodo: $periodo', style: bodyStyle),
      pw.Divider(color: PdfColors.brown300, thickness: 1),
      pw.SizedBox(height: 12),
    ]);

    // Top Empresas
    if (!soloClientes && !soloProductos && soloSector == null &&
        _empresas.isNotEmpty) {
      final total = _empresas.fold(0.0, (s, e) => s + e.totalVentas);
      content.add(pw.Text('Top Empresas', style: sectionStyle));
      content.add(pw.SizedBox(height: 6));
      for (int i = 0; i < _empresas.length; i++) {
        final e = _empresas[i];
        final pct = total > 0 ? (e.totalVentas / total * 100) : 0.0;
        content.add(_pdfRow(
            '${i + 1}. ${e.nombre}',
            '${_fmtMoney(e.totalVentas)} | ${e.totalProductos} prod | +${pct.toStringAsFixed(1)}%',
            bodyStyle));
      }
      content.add(pw.SizedBox(height: 12));
    }

    // Top Clientes
    if (!soloEmpresas && !soloProductos && soloSector == null &&
        _clientes.isNotEmpty) {
      content.add(pw.Text('Top Clientes', style: sectionStyle));
      content.add(pw.SizedBox(height: 6));
      for (int i = 0; i < _clientes.length; i++) {
        final c = _clientes[i];
        content.add(_pdfRow(
            '${i + 1}. ${c.nombre}',
            '${_fmtMoney(c.balance)} | ${c.email}',
            bodyStyle));
      }
      content.add(pw.SizedBox(height: 12));
    }

    // Productos Más Vendidos
    if (!soloEmpresas && !soloClientes && soloSector == null &&
        _productos.isNotEmpty) {
      content.add(pw.Text('Productos Más Vendidos', style: sectionStyle));
      content.add(pw.SizedBox(height: 6));
      for (final p in _productos) {
        content.add(_pdfRow(
            p.nombre,
            '${_fmtMoney(p.precio)} | ${p.stock} ${p.unidad} | ${p.empresaNombre}',
            bodyStyle));
      }
      content.add(pw.SizedBox(height: 12));
    }

    // Sector individual
    if (soloSector != null) {
      final totalSect =
          _sectores.fold(0.0, (s, x) => s + x.totalVentas);
      final pct = totalSect > 0
          ? (soloSector.totalVentas / totalSect * 100).toStringAsFixed(1)
          : '0';
      content.addAll([
        pw.Text('Sector: ${soloSector.nombre}', style: sectionStyle),
        pw.SizedBox(height: 8),
        _pdfRow('Total Ventas', _fmtMoney(soloSector.totalVentas), bodyStyle),
        _pdfRow('Productos', '${soloSector.totalProductos}', bodyStyle),
        _pdfRow('Empresas', '${soloSector.totalEmpresas}', bodyStyle),
        _pdfRow('Participacion de mercado', '+$pct%', bodyStyle),
      ]);
    }

    // Rendimiento por Sector (solo en general)
    if (!soloEmpresas && !soloClientes && !soloProductos &&
        soloSector == null && _sectores.isNotEmpty) {
      content.add(pw.Text('Rendimiento por Sector', style: sectionStyle));
      content.add(pw.SizedBox(height: 6));
      final totalSect =
          _sectores.fold(0.0, (s, x) => s + x.totalVentas);
      for (final s in _sectores) {
        final pct = totalSect > 0
            ? (s.totalVentas / totalSect * 100).toStringAsFixed(1)
            : '0';
        content.add(_pdfRow(
            s.nombre,
            '${_fmtMoney(s.totalVentas)} | ${s.totalProductos} prod | ${s.totalEmpresas} emp | +$pct%',
            bodyStyle));
      }
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => content,
    ));

    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value, pw.TextStyle style) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.brown50,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(label,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11))),
          pw.Text(value, style: style),
        ]),
      );

  // ----------------------------------------------------------------- preview / download

  bool _hasData({
    bool soloEmpresas = false,
    bool soloClientes = false,
    bool soloProductos = false,
    SectorReportItem? soloSector,
  }) {
    if (soloEmpresas) return _empresas.isNotEmpty;
    if (soloClientes) return _clientes.isNotEmpty;
    if (soloProductos) return _productos.isNotEmpty;
    if (soloSector != null) {
      return soloSector.totalProductos > 0 || soloSector.totalEmpresas > 0;
    }
    return _empresas.isNotEmpty ||
        _clientes.isNotEmpty ||
        _productos.isNotEmpty;
  }

  void _showNoDataSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'No hay datos registrados para este período'),
        backgroundColor: Colors.orange[800],
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// "Ver reporte" → abre preview (si hay datos) o SnackBar (si no)
  void _openPreview({
    required String title,
    bool soloEmpresas = false,
    bool soloClientes = false,
    bool soloProductos = false,
    SectorReportItem? soloSector,
  }) {
    if (!_hasData(
        soloEmpresas: soloEmpresas,
        soloClientes: soloClientes,
        soloProductos: soloProductos,
        soloSector: soloSector)) {
      _showNoDataSnack();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPdfPreviewView(
          title: title,
          buildPdf: () => _buildPdfBytes(
            soloEmpresas: soloEmpresas,
            soloClientes: soloClientes,
            soloProductos: soloProductos,
            soloSector: soloSector,
          ),
        ),
      ),
    );
  }

  /// Botón naranja PDF → guarda directo al archivo (si hay datos) o SnackBar
  Future<void> _saveToFile({
    bool soloEmpresas = false,
    bool soloClientes = false,
    bool soloProductos = false,
    SectorReportItem? soloSector,
  }) async {
    if (!_hasData(
        soloEmpresas: soloEmpresas,
        soloClientes: soloClientes,
        soloProductos: soloProductos,
        soloSector: soloSector)) {
      _showNoDataSnack();
      return;
    }

    final bytes = await _buildPdfBytes(
      soloEmpresas: soloEmpresas,
      soloClientes: soloClientes,
      soloProductos: soloProductos,
      soloSector: soloSector,
    );

    final filename =
        'reporte_agromarket_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (!mounted) return;

    if (Platform.isAndroid || Platform.isIOS) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else {
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
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ----------------------------------------------------------------- date pickers
  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_customFrom ?? _from) : (_customTo ?? _to),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _customFrom =
            DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
      } else {
        _customTo =
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
      _filter = _DateFilter.personalizado;
    });
  }

  // ----------------------------------------------------------------- build
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
        title: const Text('Reportes',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _textPrimary)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined,
                color: _textPrimary),
          ),
          Consumer<UserController>(builder: (_, ctrl, __) {
            final img = ctrl.currentUser?.image;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFFD4A017),
                backgroundImage: img != null && img.isNotEmpty
                    ? (img.startsWith('http')
                        ? NetworkImage(img) as ImageProvider
                        : FileImage(File(img)))
                    : null,
                child: (img == null || img.isEmpty)
                    ? const Icon(Icons.person,
                        color: Colors.white, size: 18)
                    : null,
              ),
            );
          }),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Column(children: [
                _filtrosCard(),
                const SizedBox(height: 16),
                _topEmpresasCard(),
                const SizedBox(height: 16),
                _topClientesCard(),
                const SizedBox(height: 16),
                _productosMasVendidosCard(),
                const SizedBox(height: 16),
                _rendimientoSectorSection(),
                const SizedBox(height: 32),
              ]),
            ),
    );
  }

  // ----------------------------------------------------------------- widgets

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
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
        child: child,
      );

  Widget _filterBtn(String label, _DateFilter f) {
    final active = _filter == f;
    return Expanded(
      child: GestureDetector(
        onTap: () => _applyFilter(f),
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? _primary : const Color(0xFFE0D9CC)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? Colors.white : _textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtrosCard() => _card(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Filtros de Fecha',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          const SizedBox(height: 12),
          Row(children: [
            _filterBtn('Hoy', _DateFilter.hoy),
            _filterBtn('Esta semana', _DateFilter.estaSemana),
          ]),
          Row(children: [
            _filterBtn('Este mes', _DateFilter.esteMes),
            _filterBtn('Este año', _DateFilter.esteAnio),
          ]),
          const SizedBox(height: 14),
          const Text('Personalizado',
              style: TextStyle(fontSize: 13, color: _textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _dateField(_customFrom ?? _from, true)),
            const SizedBox(width: 10),
            Expanded(child: _dateField(_customTo ?? _to, false)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => _applyFilter(_DateFilter.personalizado),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: const BorderSide(color: Color(0xFFD0C8B8)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Aplicar filtros',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 10),
          // "Descargar reporte general PDF" → preview general
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _openPreview(title: 'Reporte General'),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
              label: const Text('Descargar reporte general PDF',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      );

  Widget _dateField(DateTime dt, bool isFrom) => GestureDetector(
        onTap: () => _pickDate(isFrom),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE0D9CC)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              child: Text(_fmtDate(dt),
                  style: const TextStyle(
                      fontSize: 13, color: _textPrimary)),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: _textSecondary),
          ]),
        ),
      );

  /// Botón PDF naranja → guarda directo al archivo
  Widget _pdfIconBtn(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.picture_as_pdf_outlined,
              color: Colors.white, size: 20),
        ),
      );

  /// Fila "Ver reporte X" (texto) + botón PDF naranja
  /// - Texto → preview
  /// - Naranja → guardar directo
  Widget _sectionRow({
    required String label,
    required VoidCallback onPreview,
    required VoidCallback onSave,
  }) =>
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onPreview,
            style: OutlinedButton.styleFrom(
              foregroundColor: _textPrimary,
              side: const BorderSide(color: Color(0xFFE0D9CC)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(label,
                style: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        _pdfIconBtn(onSave),
      ]);

  Widget _rankBadge(int n) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: n == 1
              ? _primary
              : n == 2
                  ? const Color(0xFFD4A017)
                  : const Color(0xFFE8DEC8),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text('$n',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: n <= 2 ? Colors.white : _textPrimary)),
        ),
      );

  // ---- Top Empresas ----
  Widget _topEmpresasCard() {
    final total =
        _empresas.fold(0.0, (s, e) => s + e.totalVentas);
    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text('Top Empresas',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary)),
        const SizedBox(height: 12),
        if (_empresas.isEmpty)
          _emptyState('No hay empresas con datos en este período')
        else
          ...List.generate(_empresas.length, (i) {
            final e = _empresas[i];
            final pct =
                total > 0 ? (e.totalVentas / total * 100) : 0.0;
            return _empresaItem(e, i + 1, pct);
          }),
        const SizedBox(height: 12),
        _sectionRow(
          label: 'Ver reporte completo',
          onPreview: () => _openPreview(
              title: 'Reporte de Empresas', soloEmpresas: true),
          onSave: () => _saveToFile(soloEmpresas: true),
        ),
      ]),
    );
  }

  Widget _empresaItem(EmpresaReportItem e, int rank, double pct) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          _rankBadge(rank),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(e.nombre,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary)),
              const SizedBox(height: 2),
              Text(
                  '${_fmtMoney(e.totalVentas)}   ${e.totalProductos} productos',
                  style: const TextStyle(
                      fontSize: 12, color: _textSecondary)),
            ]),
          ),
          Row(children: [
            const Icon(Icons.arrow_upward,
                size: 14, color: Color(0xFF4CAF50)),
            Text('+${pct.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
      );

  // ---- Top Clientes ----
  Widget _topClientesCard() {
    final total =
        _clientes.fold(0.0, (s, c) => s + c.balance);
    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const Text('Top Clientes',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary)),
        const SizedBox(height: 12),
        if (_clientes.isEmpty)
          _emptyState('No hay clientes con datos en este período')
        else
          ...List.generate(_clientes.length, (i) {
            final c = _clientes[i];
            final pct =
                total > 0 ? (c.balance / total * 100) : 0.0;
            return _clienteItem(c, i + 1, pct);
          }),
        const SizedBox(height: 12),
        _sectionRow(
          label: 'Ver reporte completo',
          onPreview: () => _openPreview(
              title: 'Reporte de Clientes', soloClientes: true),
          onSave: () => _saveToFile(soloClientes: true),
        ),
      ]),
    );
  }

  Widget _clienteItem(ClienteReportItem c, int rank, double pct) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          _rankBadge(rank),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(c.nombre,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary)),
              const SizedBox(height: 2),
              Text('${c.balance.toStringAsFixed(0)} monedas',
                  style: const TextStyle(
                      fontSize: 12, color: _textSecondary)),
            ]),
          ),
          Text(_fmtMoney(c.balance),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
        ]),
      );

  // ---- Productos Más Vendidos ----
  Widget _productosMasVendidosCard() => _card(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Productos Más Vendidos',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          const SizedBox(height: 12),
          if (_productos.isEmpty)
            _emptyState(
                'No hay productos con datos en este período')
          else
            ..._productos.map((p) => _productoItem(p)),
          const SizedBox(height: 12),
          _sectionRow(
            label: 'Ver reporte',
            onPreview: () => _openPreview(
                title: 'Reporte de Productos', soloProductos: true),
            onSave: () => _saveToFile(soloProductos: true),
          ),
        ]),
      );

  Widget _productoItem(ProductoReportItem p) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child:
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(p.nombre,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary)),
              Text(p.empresaNombre,
                  style: const TextStyle(
                      fontSize: 12, color: _textSecondary)),
              Text('${p.stock} ${p.unidad} vendidos',
                  style: const TextStyle(
                      fontSize: 12, color: _textSecondary)),
            ]),
          ),
          Text(_fmtMoney(p.precio),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
        ]),
      );

  // ---- Rendimiento por Sector ----
  Widget _rendimientoSectorSection() {
    if (_sectores.isEmpty) {
      return _card(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Rendimiento por Sector',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          const SizedBox(height: 12),
          _emptyState('No hay sectores registrados'),
        ]),
      );
    }
    final totalVentas =
        _sectores.fold(0.0, (s, x) => s + x.totalVentas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rendimiento por Sector',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary)),
        const SizedBox(height: 12),
        ..._sectores.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _sectorCard(s, totalVentas),
            )),
      ],
    );
  }

  Widget _sectorCard(SectorReportItem s, double totalVentas) {
    final pct = totalVentas > 0
        ? (s.totalVentas / totalVentas * 100).toStringAsFixed(0)
        : '0';
    return _card(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(_sectorEmoji(s.nombre),
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(s.nombre,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            Text(_sectorDesc(s.nombre),
                style: const TextStyle(
                    fontSize: 12, color: _textSecondary)),
          ]),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _statCell('Total ventas', _fmtMoney(s.totalVentas)),
          _statCell('Productos', '${s.totalProductos}'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _statCell('Empresas', '${s.totalEmpresas}'),
          _statGrowthCell('Crecimiento', '↑ +$pct%'),
        ]),
        const SizedBox(height: 16),
        _sectionRow(
          label: 'Ver reporte del sector',
          onPreview: () => _openPreview(
              title: 'Sector: ${s.nombre}', soloSector: s),
          onSave: () => _saveToFile(soloSector: s),
        ),
      ]),
    );
  }

  Widget _statCell(String label, String value) => Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
        ]),
      );

  Widget _statGrowthCell(String label, String value) => Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50))),
        ]),
      );

  Widget _emptyState(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bar_chart_outlined,
                size: 40,
                color: _textSecondary.withOpacity(0.4)),
            const SizedBox(height: 8),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13)),
          ]),
        ),
      );
}
