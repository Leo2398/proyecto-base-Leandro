import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../controllers/user_controller.dart';
import '../../models/report_models.dart';
import '../../services/report_service.dart';

enum _DateFilter { hoy, estaSemana, esteMes, esteAnio, personalizado }

/// Vista de Reportes del Administrador
class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  // ----------------------------------------------------------------- colors
  static const _primary = Color(0xFFB8860B);
  static const _primaryLight = Color(0xFFF5EDD0);
  static const _background = Color(0xFFF5F0E8);
  static const _textPrimary = Color(0xFF2D2D2D);
  static const _textSecondary = Color(0xFF888888);

  // ----------------------------------------------------------------- state
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

  // ----------------------------------------------------------------- lifecycle
  @override
  void initState() {
    super.initState();
    _applyFilter(_DateFilter.hoy);
  }

  // ----------------------------------------------------------------- date logic
  void _computeRange(_DateFilter f) {
    final now = DateTime.now();
    switch (f) {
      case _DateFilter.hoy:
        _from = DateTime(now.year, now.month, now.day);
        _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
      case _DateFilter.estaSemana:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        _to = _from.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case _DateFilter.esteMes:
        _from = DateTime(now.year, now.month, 1);
        _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case _DateFilter.esteAnio:
        _from = DateTime(now.year, 1, 1);
        _to = DateTime(now.year, 12, 31, 23, 59, 59);
      case _DateFilter.personalizado:
        _from = _customFrom ?? DateTime(now.year, now.month, 1);
        _to = _customTo ?? DateTime(now.year, now.month, now.day, 23, 59, 59);
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

  double _growthPct(List<double> vals, int idx) {
    if (vals.isEmpty || vals[idx] == 0) return 0;
    final total = vals.fold(0.0, (a, b) => a + b);
    return total == 0 ? 0 : (vals[idx] / total) * 100;
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

  // ----------------------------------------------------------------- PDF
  Future<void> _downloadPdf({
    bool soloEmpresas = false,
    bool soloClientes = false,
    bool soloProductos = false,
    SectorReportItem? soloSector,
  }) async {
    final periodo = '${_fmtDate(_from)} - ${_fmtDate(_to)}';

    final bool noData = _empresas.isEmpty &&
        _clientes.isEmpty &&
        _productos.isEmpty &&
        _sectores.isEmpty;

    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.brown800);
    final sectionStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.brown700);
    final bodyStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey800);
    final headerStyle =
        pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold);

    if (noData ||
        (soloEmpresas && _empresas.isEmpty) ||
        (soloClientes && _clientes.isEmpty) ||
        (soloProductos && _productos.isEmpty) ||
        (soloSector != null && soloSector.totalProductos == 0)) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('AgroMarket Admin', style: headerStyle),
              pw.SizedBox(height: 10),
              pw.Text(
                soloSector != null
                    ? 'Reporte del Sector: ${soloSector.nombre}'
                    : soloEmpresas
                        ? 'Reporte de Empresas'
                        : soloClientes
                            ? 'Reporte de Clientes'
                            : soloProductos
                                ? 'Reporte de Productos'
                                : 'Reporte General',
                style: sectionStyle,
              ),
              pw.SizedBox(height: 6),
              pw.Text('Período: $periodo', style: bodyStyle),
              pw.SizedBox(height: 40),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.orange),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'No hay datos suficientes para el reporte\nen el período seleccionado.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 14, color: PdfColors.orange900),
                ),
              ),
            ],
          ),
        ),
      ));
    } else {
      final List<pw.Widget> content = [];

      // Header
      content.addAll([
        pw.Text('AgroMarket Admin — Reporte General', style: titleStyle),
        pw.SizedBox(height: 4),
        pw.Text('Período: $periodo', style: bodyStyle),
        pw.Divider(color: PdfColors.brown300, thickness: 1),
        pw.SizedBox(height: 12),
      ]);

      // Top Empresas
      if (!soloClientes && !soloProductos && soloSector == null &&
          _empresas.isNotEmpty) {
        content.add(pw.Text('Top Empresas', style: sectionStyle));
        content.add(pw.SizedBox(height: 6));
        final total = _empresas.fold(0.0, (s, e) => s + e.totalVentas);
        for (int i = 0; i < _empresas.length; i++) {
          final e = _empresas[i];
          final pct = total > 0 ? (e.totalVentas / total * 100) : 0.0;
          content.add(pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.brown50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Text('${i + 1}.',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(width: 8),
                pw.Expanded(
                    child: pw.Text(e.nombre,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11))),
                pw.Text(
                    '${_fmtMoney(e.totalVentas)}  •  ${e.totalProductos} productos  •  ↑ ${pct.toStringAsFixed(1)}%',
                    style: bodyStyle),
              ],
            ),
          ));
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
          content.add(pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.brown50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Text('${i + 1}.',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.SizedBox(width: 8),
                pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                      pw.Text(c.nombre,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text(c.email, style: bodyStyle),
                    ])),
                pw.Text('Balance: ${_fmtMoney(c.balance)}',
                    style: bodyStyle),
              ],
            ),
          ));
        }
        content.add(pw.SizedBox(height: 12));
      }

      // Productos Más Vendidos
      if (!soloEmpresas && !soloClientes && soloSector == null &&
          _productos.isNotEmpty) {
        content.add(pw.Text('Productos Más Vendidos', style: sectionStyle));
        content.add(pw.SizedBox(height: 6));
        for (final p in _productos) {
          content.add(pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.brown50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                      pw.Text(p.nombre,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text(p.empresaNombre, style: bodyStyle),
                      pw.Text('${p.stock} ${p.unidad} vendidos',
                          style: bodyStyle),
                    ])),
                pw.Text(_fmtMoney(p.precio),
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ],
            ),
          ));
        }
        content.add(pw.SizedBox(height: 12));
      }

      // Sector individual
      if (soloSector != null) {
        final pct = _sectores.isNotEmpty
            ? (soloSector.totalVentas /
                    _sectores.fold(0.0, (s, x) => s + x.totalVentas) *
                    100)
                .toStringAsFixed(1)
            : '0';
        content.addAll([
          pw.Text('Sector: ${soloSector.nombre}', style: sectionStyle),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Expanded(
                child: _pdfStatCell(
                    'Total Ventas', _fmtMoney(soloSector.totalVentas))),
            pw.Expanded(
                child:
                    _pdfStatCell('Productos', '${soloSector.totalProductos}')),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(
                child:
                    _pdfStatCell('Empresas', '${soloSector.totalEmpresas}')),
            pw.Expanded(child: _pdfStatCell('Participación', '↑ $pct%')),
          ]),
        ]);
      }

      // Rendimiento por Sector (solo en reporte general)
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
          content.add(pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.brown50,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                    child: pw.Text(s.nombre,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 11))),
                pw.Text(
                    '${_fmtMoney(s.totalVentas)}  •  ${s.totalProductos} prod  •  ${s.totalEmpresas} emp  •  ↑ $pct%',
                    style: bodyStyle),
              ],
            ),
          ));
        }
      }

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => content,
      ));
    }

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'reporte_agromarket_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  pw.Widget _pdfStatCell(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.brown50,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              fontWeight:
                  active ? FontWeight.w600 : FontWeight.normal,
              color: active ? Colors.white : _textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtrosCard() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            Expanded(child: _dateField(_customFrom ?? _from, true)),
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
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _downloadPdf,
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
              child: Text(
                _fmtDate(dt),
                style: const TextStyle(
                    fontSize: 13, color: _textPrimary),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: _textSecondary),
          ]),
        ),
      );

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

  Widget _sectionRow(String label, VoidCallback onPdf) => Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onPdf,
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
        _pdfIconBtn(onPdf),
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
    final vals = _empresas.map((e) => e.totalVentas).toList();
    final total = vals.fold(0.0, (s, v) => s + v);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        _sectionRow('Ver reporte completo',
            () => _downloadPdf(soloEmpresas: true)),
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
    final vals = _clientes.map((c) => c.balance).toList();
    final total = vals.fold(0.0, (s, v) => s + v);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        _sectionRow('Ver reporte completo',
            () => _downloadPdf(soloClientes: true)),
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
              Text(
                  '${c.balance.toStringAsFixed(0)} monedas',
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Productos Más Vendidos',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          const SizedBox(height: 12),
          if (_productos.isEmpty)
            _emptyState('No hay productos con datos en este período')
          else
            ..._productos.map((p) => _productoItem(p)),
          const SizedBox(height: 12),
          _sectionRow('Ver reporte',
              () => _downloadPdf(soloProductos: true)),
        ]),
      );

  Widget _productoItem(ProductoReportItem p) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        _sectionRow('Ver reporte del sector',
            () => _downloadPdf(soloSector: s)),
      ]),
    );
  }

  Widget _statCell(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
