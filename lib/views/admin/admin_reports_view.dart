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

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({super.key});

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  static const Color _primary = Color(0xFFB8860B);
  static const Color _primaryDark = Color(0xFF7A5607);
  static const Color _primarySoft = Color(0xFFFFF4D8);
  static const Color _accent = Color(0xFFD4A017);
  static const Color _green = Color(0xFF4F8F45);
  static const Color _background = Color(0xFFF5F0E8);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _textPrimary = Color(0xFF2D2D2D);
  static const Color _textSecondary = Color(0xFF777777);
  static const Color _border = Color(0xFFE6DCCB);

  final ReportService _service = ReportService();

  _DateFilter _filter = _DateFilter.hoy;

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _loading = true;
  bool _savingPdf = false;

  List<EmpresaReportItem> _empresas = [];
  List<ClienteReportItem> _clientes = [];
  List<ProductoReportItem> _productos = [];
  List<SectorReportItem> _sectores = [];

  @override
  void initState() {
    super.initState();
    _computeRange(_DateFilter.hoy);
    _loadData();
  }

  // ---------------------------------------------------------------------------
  // FECHAS
  // ---------------------------------------------------------------------------

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  void _computeRange(_DateFilter filter) {
    final now = DateTime.now();

    switch (filter) {
      case _DateFilter.hoy:
        _from = _startOfDay(now);
        _to = _endOfDay(now);
        break;

      case _DateFilter.estaSemana:
        final start = now.subtract(Duration(days: now.weekday - 1));
        _from = _startOfDay(start);
        _to = _endOfDay(_from.add(const Duration(days: 6)));
        break;

      case _DateFilter.esteMes:
        _from = DateTime(now.year, now.month, 1);
        _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;

      case _DateFilter.esteAnio:
        _from = DateTime(now.year, 1, 1);
        _to = DateTime(now.year, 12, 31, 23, 59, 59);
        break;

      case _DateFilter.personalizado:
        _from = _customFrom ?? DateTime(now.year, now.month, 1);
        _to = _customTo ?? _endOfDay(now);
        break;
    }
  }

  Future<void> _applyFilter(_DateFilter filter) async {
    if (filter == _DateFilter.personalizado &&
        _customFrom != null &&
        _customTo != null &&
        _customFrom!.isAfter(_customTo!)) {
      _showSnack(
        'La fecha inicial no puede ser mayor a la fecha final',
        type: _SnackType.warning,
      );
      return;
    }

    setState(() {
      _filter = filter;
      _computeRange(filter);
    });

    await _loadData();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? (_customFrom ?? _from) : (_customTo ?? _to);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: isFrom ? 'Selecciona fecha inicial' : 'Selecciona fecha final',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _customFrom = _startOfDay(picked);
      } else {
        _customTo = _endOfDay(picked);
      }

      _filter = _DateFilter.personalizado;
      _computeRange(_DateFilter.personalizado);
    });
  }

  // ---------------------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------------------

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loading = true);
    }

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
      if (!mounted) return;
      _showSnack(
        'No se pudieron cargar los reportes. Revisa tu conexión o la base de datos.',
        type: _SnackType.error,
      );
      debugPrint('Error cargando reportes: $e');
    } finally {
      if (mounted && showLoader) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FORMATO
  // ---------------------------------------------------------------------------

  String _fmtDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _fmtMoney(double value) {
    if (value >= 1000000) {
      return 'Bs ${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (value >= 1000) {
      return 'Bs ${(value / 1000).toStringAsFixed(1)}K';
    }

    return 'Bs ${value.toStringAsFixed(0)}';
  }

  String _fmtNumber(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _periodLabel() {
    return '${_fmtDate(_from)} - ${_fmtDate(_to)}';
  }

  String _filterLabel(_DateFilter filter) {
    switch (filter) {
      case _DateFilter.hoy:
        return 'Hoy';
      case _DateFilter.estaSemana:
        return 'Semana';
      case _DateFilter.esteMes:
        return 'Mes';
      case _DateFilter.esteAnio:
        return 'Año';
      case _DateFilter.personalizado:
        return 'Personalizado';
    }
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
    if (n.contains('tubérculo') || n.contains('tuberculo')) return '🥔';

    return '🌱';
  }

  String _sectorDesc(String name) {
    final n = name.toLowerCase();

    if (n.contains('frut')) return 'Productos frescos de alta rotación';
    if (n.contains('hortal') || n.contains('vegetal')) {
      return 'Alta demanda en restaurantes';
    }
    if (n.contains('hidro')) return 'Producción tecnificada';
    if (n.contains('grano') || n.contains('cereal')) {
      return 'Abastecimiento estable';
    }
    if (n.contains('lácteo') || n.contains('lacteo')) {
      return 'Sector de consumo frecuente';
    }

    return 'Sector activo dentro del marketplace';
  }

  String _initials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'A';

    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  double get _totalVentasEmpresas {
    return _empresas.fold(0.0, (sum, item) => sum + item.totalVentas);
  }

  double get _totalBalanceClientes {
    return _clientes.fold(0.0, (sum, item) => sum + item.balance);
  }

  int get _totalProductos {
    return _productos.fold(0, (sum, item) => sum + item.stock);
  }

  double get _totalVentasSectores {
    return _sectores.fold(0.0, (sum, item) => sum + item.totalVentas);
  }

  int get _visibleLimit => 5;

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  Future<Uint8List> _buildPdfBytes({
    bool soloEmpresas = false,
    bool soloClientes = false,
    bool soloProductos = false,
    SectorReportItem? soloSector,
  }) async {
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontSemiBold = await PdfGoogleFonts.nunitoSemiBold();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 21,
      color: PdfColors.brown800,
    );

    final subtitleStyle = pw.TextStyle(
      font: fontRegular,
      fontSize: 10,
      color: PdfColors.grey700,
    );

    final sectionStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 14,
      color: PdfColors.brown800,
    );

    final bodyStyle = pw.TextStyle(
      font: fontRegular,
      fontSize: 9,
      color: PdfColors.grey800,
    );

    final tableHeaderStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 9,
      color: PdfColors.white,
    );

    final tableCellStyle = pw.TextStyle(
      font: fontRegular,
      fontSize: 8.5,
      color: PdfColors.grey800,
    );

    final List<pw.Widget> content = [];

    content.add(
      _pdfHeader(
        title: _pdfTitle(
          soloEmpresas: soloEmpresas,
          soloClientes: soloClientes,
          soloProductos: soloProductos,
          soloSector: soloSector,
        ),
        period: _periodLabel(),
        titleStyle: titleStyle,
        subtitleStyle: subtitleStyle,
      ),
    );

    content.add(pw.SizedBox(height: 14));

    if (soloSector == null &&
        !soloEmpresas &&
        !soloClientes &&
        !soloProductos) {
      content.add(
        pw.Row(
          children: [
            pw.Expanded(
              child: _pdfSummaryBox(
                label: 'Ventas empresas',
                value: _fmtMoney(_totalVentasEmpresas),
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _pdfSummaryBox(
                label: 'Clientes destacados',
                value: '${_clientes.length}',
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _pdfSummaryBox(
                label: 'Productos reportados',
                value: '${_productos.length}',
                fontBold: fontBold,
                fontRegular: fontRegular,
              ),
            ),
          ],
        ),
      );

      content.add(pw.SizedBox(height: 16));
    }

    if (!soloClientes &&
        !soloProductos &&
        soloSector == null &&
        _empresas.isNotEmpty) {
      content.add(pw.Text('Top empresas', style: sectionStyle));
      content.add(pw.SizedBox(height: 6));
      content.add(
        _pdfTable(
          headers: const ['#', 'Empresa', 'Ventas', 'Productos', 'Participación'],
          rows: List.generate(_empresas.length, (index) {
            final item = _empresas[index];
            final pct = _totalVentasEmpresas > 0
                ? (item.totalVentas / _totalVentasEmpresas * 100)
                : 0.0;

            return [
              '${index + 1}',
              item.nombre,
              _fmtMoney(item.totalVentas),
              '${item.totalProductos}',
              '${pct.toStringAsFixed(1)}%',
            ];
          }),
          headerStyle: tableHeaderStyle,
          cellStyle: tableCellStyle,
        ),
      );
      content.add(pw.SizedBox(height: 14));
    }

    if (!soloEmpresas &&
        !soloProductos &&
        soloSector == null &&
        _clientes.isNotEmpty) {
      content.add(pw.Text('Top clientes', style: sectionStyle));
      content.add(pw.SizedBox(height: 6));
      content.add(
        _pdfTable(
          headers: const ['#', 'Cliente', 'Email', 'Balance'],
          rows: List.generate(_clientes.length, (index) {
            final item = _clientes[index];

            return [
              '${index + 1}',
              item.nombre,
              item.email,
              _fmtMoney(item.balance),
            ];
          }),
          headerStyle: tableHeaderStyle,
          cellStyle: tableCellStyle,
        ),
      );
      content.add(pw.SizedBox(height: 14));
    }

    if (!soloEmpresas &&
        !soloClientes &&
        soloSector == null &&
        _productos.isNotEmpty) {
      content.add(pw.Text('Productos más vendidos', style: sectionStyle));
      content.add(pw.SizedBox(height: 6));
      content.add(
        _pdfTable(
          headers: const ['Producto', 'Empresa', 'Precio', 'Cantidad', 'Unidad'],
          rows: _productos.map((item) {
            return [
              item.nombre,
              item.empresaNombre,
              _fmtMoney(item.precio),
              '${item.stock}',
              item.unidad,
            ];
          }).toList(),
          headerStyle: tableHeaderStyle,
          cellStyle: tableCellStyle,
        ),
      );
      content.add(pw.SizedBox(height: 14));
    }

    if (soloSector != null) {
      final totalSector = _totalVentasSectores;
      final pct = totalSector > 0
          ? (soloSector.totalVentas / totalSector * 100).toStringAsFixed(1)
          : '0.0';

      content.add(pw.Text('Detalle del sector', style: sectionStyle));
      content.add(pw.SizedBox(height: 8));

      content.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.brown50,
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColors.brown200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                soloSector.nombre,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.brown800,
                ),
              ),
              pw.SizedBox(height: 8),
              _pdfDetailRow(
                'Total ventas',
                _fmtMoney(soloSector.totalVentas),
                bodyStyle,
                fontSemiBold,
              ),
              _pdfDetailRow(
                'Productos',
                '${soloSector.totalProductos}',
                bodyStyle,
                fontSemiBold,
              ),
              _pdfDetailRow(
                'Empresas',
                '${soloSector.totalEmpresas}',
                bodyStyle,
                fontSemiBold,
              ),
              _pdfDetailRow(
                'Participación estimada',
                '$pct%',
                bodyStyle,
                fontSemiBold,
              ),
            ],
          ),
        ),
      );
    }

    if (!soloEmpresas &&
        !soloClientes &&
        !soloProductos &&
        soloSector == null &&
        _sectores.isNotEmpty) {
      content.add(pw.Text('Rendimiento por sector', style: sectionStyle));
      content.add(pw.SizedBox(height: 6));
      content.add(
        _pdfTable(
          headers: const ['Sector', 'Ventas', 'Productos', 'Empresas', 'Participación'],
          rows: _sectores.map((item) {
            final pct = _totalVentasSectores > 0
                ? (item.totalVentas / _totalVentasSectores * 100)
                : 0.0;

            return [
              item.nombre,
              _fmtMoney(item.totalVentas),
              '${item.totalProductos}',
              '${item.totalEmpresas}',
              '${pct.toStringAsFixed(1)}%',
            ];
          }).toList(),
          headerStyle: tableHeaderStyle,
          cellStyle: tableCellStyle,
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'AgroMarket Admin · Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          );
        },
        build: (_) => content,
      ),
    );

    return pdf.save();
  }

  String _pdfTitle({
    required bool soloEmpresas,
    required bool soloClientes,
    required bool soloProductos,
    required SectorReportItem? soloSector,
  }) {
    if (soloEmpresas) return 'Reporte de empresas';
    if (soloClientes) return 'Reporte de clientes';
    if (soloProductos) return 'Reporte de productos';
    if (soloSector != null) return 'Reporte del sector ${soloSector.nombre}';
    return 'Reporte general';
  }

  pw.Widget _pdfHeader({
    required String title,
    required String period,
    required pw.TextStyle titleStyle,
    required pw.TextStyle subtitleStyle,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.brown50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.brown200),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 42,
            height: 42,
            decoration: pw.BoxDecoration(
              color: PdfColors.brown700,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Center(
              child: pw.Text(
                'A',
                style: pw.TextStyle(
                  fontSize: 22,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: titleStyle),
                pw.SizedBox(height: 3),
                pw.Text('Periodo: $period', style: subtitleStyle),
                pw.Text(
                  'Generado el ${_fmtDate(DateTime.now())}',
                  style: subtitleStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryBox({
    required String label,
    required String value,
    required pw.Font fontBold,
    required pw.Font fontRegular,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 13,
              color: PdfColors.brown800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfTable({
    required List<String> headers,
    required List<List<String>> rows,
    required pw.TextStyle headerStyle,
    required pw.TextStyle cellStyle,
  }) {
    return pw.Table.fromTextArray(
      headers: headers,
      data: rows,
      border: null,
      headerStyle: headerStyle,
      cellStyle: cellStyle,
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.brown700,
      ),
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
      ),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 6,
      ),
      headerPadding: const pw.EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 7,
      ),
    );
  }

  pw.Widget _pdfDetailRow(
      String label,
      String value,
      pw.TextStyle bodyStyle,
      pw.Font fontSemiBold,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                font: fontSemiBold,
                fontSize: 10,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Text(value, style: bodyStyle),
        ],
      ),
    );
  }

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
      return soloSector.totalProductos > 0 ||
          soloSector.totalEmpresas > 0 ||
          soloSector.totalVentas > 0;
    }

    return _empresas.isNotEmpty ||
        _clientes.isNotEmpty ||
        _productos.isNotEmpty ||
        _sectores.isNotEmpty;
  }

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
      soloSector: soloSector,
    )) {
      _showSnack('No hay datos registrados para este período',
          type: _SnackType.warning);
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

  Future<void> _saveToFile({
    bool soloEmpresas = false,
    bool soloClientes = false,
    bool soloProductos = false,
    SectorReportItem? soloSector,
  }) async {
    if (_savingPdf) return;

    if (!_hasData(
      soloEmpresas: soloEmpresas,
      soloClientes: soloClientes,
      soloProductos: soloProductos,
      soloSector: soloSector,
    )) {
      _showSnack('No hay datos para generar este PDF',
          type: _SnackType.warning);
      return;
    }

    setState(() => _savingPdf = true);

    try {
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
        final dir =
            await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);

        if (!mounted) return;

        _showSnack(
          'PDF guardado correctamente',
          type: _SnackType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('No se pudo generar el PDF', type: _SnackType.error);
      debugPrint('Error guardando PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _savingPdf = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        surfaceTintColor: _background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reportes',
          style: TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => _loadData(showLoader: false),
            icon: const Icon(
              Icons.refresh_rounded,
              color: _textPrimary,
            ),
          ),
          Consumer<UserController>(
            builder: (_, ctrl, __) {
              final image = ctrl.currentUser?.image;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _adminAvatar(image),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          else
            RefreshIndicator(
              color: _primary,
              backgroundColor: Colors.white,
              onRefresh: () => _loadData(showLoader: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  _heroHeader(),
                  const SizedBox(height: 14),
                  _summaryGrid(),
                  const SizedBox(height: 14),
                  _filtersCard(),
                  const SizedBox(height: 14),
                  _topEmpresasCard(),
                  const SizedBox(height: 14),
                  _topClientesCard(),
                  const SizedBox(height: 14),
                  _productosMasVendidosCard(),
                  const SizedBox(height: 14),
                  _rendimientoSectorSection(),
                  const SizedBox(height: 12),
                  _footerNote(),
                ],
              ),
            ),
          if (_savingPdf) _savingOverlay(),
        ],
      ),
    );
  }

  Widget _adminAvatar(String? image) {
    ImageProvider? provider;

    if (image != null && image.trim().isNotEmpty) {
      final value = image.trim();

      if (value.startsWith('http')) {
        provider = NetworkImage(value);
      } else {
        provider = FileImage(File(value));
      }
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent.withOpacity(0.35), width: 2),
      ),
      child: CircleAvatar(
        radius: 17,
        backgroundColor: _primary,
        backgroundImage: provider,
        child: provider == null
            ? const Icon(Icons.admin_panel_settings_rounded,
            color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  Widget _heroHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
            color: _primary.withOpacity(0.26),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -26,
            child: _orb(120, Colors.white.withOpacity(0.12)),
          ),
          Positioned(
            left: -32,
            bottom: -36,
            child: _orb(100, Colors.white.withOpacity(0.10)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Centro de reportes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Resumen administrativo de AgroMarket',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _periodLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _filterLabel(_filter),
                          style: const TextStyle(
                            color: _primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _heroActionButton(
                        label: 'Vista previa general',
                        icon: Icons.visibility_outlined,
                        onTap: () => _openPreview(title: 'Reporte General'),
                        filled: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _heroIconButton(
                      icon: Icons.picture_as_pdf_outlined,
                      onTap: () => _saveToFile(),
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

  Widget _orb(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _heroActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? Colors.white : Colors.white.withOpacity(0.2),
          foregroundColor: filled ? _primaryDark : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _heroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 48,
        width: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _summaryGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                label: 'Ventas',
                value: _fmtMoney(_totalVentasEmpresas),
                icon: Icons.payments_outlined,
                color: _green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                label: 'Empresas',
                value: '${_empresas.length}',
                icon: Icons.storefront_outlined,
                color: _primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                label: 'Clientes',
                value: '${_clientes.length}',
                icon: Icons.groups_2_outlined,
                color: const Color(0xFF4D7CFE),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                label: 'Productos',
                value: '${_productos.length}',
                icon: Icons.shopping_basket_outlined,
                color: const Color(0xFFE58634),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
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

  Widget _filtersCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            title: 'Filtros de fecha',
            subtitle: 'Controla el período usado en los reportes',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('Hoy', _DateFilter.hoy, Icons.today_outlined),
              _filterChip(
                'Semana',
                _DateFilter.estaSemana,
                Icons.view_week_outlined,
              ),
              _filterChip(
                'Mes',
                _DateFilter.esteMes,
                Icons.calendar_month_outlined,
              ),
              _filterChip(
                'Año',
                _DateFilter.esteAnio,
                Icons.event_available_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _primarySoft.withOpacity(0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rango personalizado',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        label: 'Desde',
                        date: _customFrom ?? _from,
                        isFrom: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateField(
                        label: 'Hasta',
                        date: _customTo ?? _to,
                        isFrom: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _applyFilter(_DateFilter.personalizado),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
                    label: const Text(
                      'Aplicar rango personalizado',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryDark,
                      side: const BorderSide(color: _primary),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
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

  Widget _filterChip(String label, _DateFilter filter, IconData icon) {
    final active = _filter == filter;

    return InkWell(
      onTap: () => _applyFilter(filter),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? _primary : _border,
          ),
          boxShadow: active
              ? [
            BoxShadow(
              color: _primary.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : _primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime date,
    required bool isFrom,
  }) {
    return InkWell(
      onTap: () => _pickDate(isFrom),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fmtDate(date),
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: _primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topEmpresasCard() {
    final visibleItems = _empresas.take(_visibleLimit).toList();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTop(
            title: 'Top empresas',
            subtitle: _empresas.isEmpty
                ? 'Sin ventas registradas'
                : 'Mostrando ${visibleItems.length} de ${_empresas.length}',
            icon: Icons.storefront_rounded,
            color: _primary,
          ),
          const SizedBox(height: 14),
          if (_empresas.isEmpty)
            _emptyState(
              icon: Icons.store_mall_directory_outlined,
              title: 'Aún no hay empresas con ventas',
              message: 'Cuando existan pedidos en este período aparecerán aquí.',
            )
          else
            ...List.generate(visibleItems.length, (index) {
              final item = visibleItems[index];
              final pct = _totalVentasEmpresas > 0
                  ? item.totalVentas / _totalVentasEmpresas
                  : 0.0;

              return _empresaItem(
                item: item,
                rank: index + 1,
                pct: pct,
              );
            }),
          const SizedBox(height: 12),
          _reportActions(
            previewLabel: 'Ver reporte de empresas',
            onPreview: () => _openPreview(
              title: 'Reporte de Empresas',
              soloEmpresas: true,
            ),
            onSave: () => _saveToFile(soloEmpresas: true),
          ),
        ],
      ),
    );
  }

  Widget _empresaItem({
    required EmpresaReportItem item,
    required int rank,
    required double pct,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border.withOpacity(0.65)),
      ),
      child: Row(
        children: [
          _rankBadge(rank),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.totalProductos} productos · ${_fmtMoney(item.totalVentas)}',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: pct.clamp(0.0, 1.0),
                    backgroundColor: _primarySoft,
                    valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _percentPill(pct * 100),
        ],
      ),
    );
  }

  Widget _topClientesCard() {
    final visibleItems = _clientes.take(_visibleLimit).toList();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTop(
            title: 'Top clientes',
            subtitle: _clientes.isEmpty
                ? 'Sin clientes destacados'
                : 'Balance total: ${_fmtMoney(_totalBalanceClientes)}',
            icon: Icons.groups_2_rounded,
            color: const Color(0xFF4D7CFE),
          ),
          const SizedBox(height: 14),
          if (_clientes.isEmpty)
            _emptyState(
              icon: Icons.person_search_outlined,
              title: 'No hay clientes en este período',
              message: 'Los clientes con mayor movimiento aparecerán aquí.',
            )
          else
            ...List.generate(visibleItems.length, (index) {
              return _clienteItem(
                item: visibleItems[index],
                rank: index + 1,
              );
            }),
          const SizedBox(height: 12),
          _reportActions(
            previewLabel: 'Ver reporte de clientes',
            onPreview: () => _openPreview(
              title: 'Reporte de Clientes',
              soloClientes: true,
            ),
            onSave: () => _saveToFile(soloClientes: true),
          ),
        ],
      ),
    );
  }

  Widget _clienteItem({
    required ClienteReportItem item,
    required int rank,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8FF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF4D7CFE).withOpacity(0.12),
            child: Text(
              _initials(item.nombre),
              style: const TextStyle(
                color: Color(0xFF4D7CFE),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _miniRank(rank),
              const SizedBox(height: 5),
              Text(
                _fmtMoney(item.balance),
                style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productosMasVendidosCard() {
    final visibleItems = _productos.take(_visibleLimit).toList();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTop(
            title: 'Productos más vendidos',
            subtitle: _productos.isEmpty
                ? 'Sin productos vendidos'
                : '${_fmtNumber(_totalProductos)} unidades registradas',
            icon: Icons.shopping_basket_rounded,
            color: const Color(0xFFE58634),
          ),
          const SizedBox(height: 14),
          if (_productos.isEmpty)
            _emptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No hay productos con ventas',
              message: 'Los productos vendidos aparecerán ordenados aquí.',
            )
          else
            ...visibleItems.map(_productoItem),
          const SizedBox(height: 12),
          _reportActions(
            previewLabel: 'Ver reporte de productos',
            onPreview: () => _openPreview(
              title: 'Reporte de Productos',
              soloProductos: true,
            ),
            onSave: () => _saveToFile(soloProductos: true),
          ),
        ],
      ),
    );
  }

  Widget _productoItem(ProductoReportItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE2C4)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE58634).withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: Color(0xFFE58634),
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.empresaNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.stock} ${item.unidad} vendidos',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtMoney(item.precio),
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rendimientoSectorSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTop(
            title: 'Rendimiento por sector',
            subtitle: _sectores.isEmpty
                ? 'Sin sectores registrados'
                : '${_sectores.length} sectores activos',
            icon: Icons.pie_chart_outline_rounded,
            color: _green,
          ),
          const SizedBox(height: 14),
          if (_sectores.isEmpty)
            _emptyState(
              icon: Icons.category_outlined,
              title: 'No hay sectores registrados',
              message: 'Cuando existan familias o sectores se mostrarán aquí.',
            )
          else
            ..._sectores.map(
                  (item) => _sectorCard(
                item: item,
                totalVentas: _totalVentasSectores,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectorCard({
    required SectorReportItem item,
    required double totalVentas,
  }) {
    final percent = totalVentas > 0 ? item.totalVentas / totalVentas : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFFF7),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFDDEFD8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    _sectorEmoji(item.nombre),
                    style: const TextStyle(fontSize: 23),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _sectorDesc(item.nombre),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              _percentPill(percent * 100),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0xFFEAF4E7),
              valueColor: const AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statCell('Ventas', _fmtMoney(item.totalVentas)),
              _verticalDivider(),
              _statCell('Productos', '${item.totalProductos}'),
              _verticalDivider(),
              _statCell('Empresas', '${item.totalEmpresas}'),
            ],
          ),
          const SizedBox(height: 14),
          _reportActions(
            previewLabel: 'Ver reporte del sector',
            onPreview: () => _openPreview(
              title: 'Sector: ${item.nombre}',
              soloSector: item,
            ),
            onSave: () => _saveToFile(soloSector: item),
          ),
        ],
      ),
    );
  }

  Widget _reportActions({
    required String previewLabel,
    required VoidCallback onPreview,
    required VoidCallback onSave,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: Text(
                previewLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryDark,
                side: const BorderSide(color: _border),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: onSave,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            height: 46,
            width: 49,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ],
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: _primary, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTop({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rankBadge(int rank) {
    final bool first = rank == 1;
    final bool second = rank == 2;
    final bool third = rank == 3;

    Color color = const Color(0xFFE8DEC8);
    Color text = _textPrimary;
    IconData? icon;

    if (first) {
      color = _primary;
      text = Colors.white;
      icon = Icons.emoji_events_rounded;
    } else if (second) {
      color = _accent;
      text = Colors.white;
      icon = Icons.military_tech_rounded;
    } else if (third) {
      color = const Color(0xFFC48A44);
      text = Colors.white;
      icon = Icons.workspace_premium_rounded;
    }

    return Container(
      height: 35,
      width: 35,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(
        child: icon == null
            ? Text(
          '$rank',
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        )
            : Icon(icon, color: text, size: 18),
      ),
    );
  }

  Widget _miniRank(int rank) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '#$rank',
        style: const TextStyle(
          color: _primaryDark,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _percentPill(double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up_rounded, size: 14, color: _green),
          const SizedBox(width: 3),
          Text(
            '${value.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: _green,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 34,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: _border,
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: _textSecondary.withOpacity(0.45),
            size: 38,
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primarySoft.withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _primaryDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Los reportes se generan con datos reales del período seleccionado.',
              style: TextStyle(
                color: _primaryDark.withOpacity(0.86),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: _primary,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Generando PDF...',
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

  // ---------------------------------------------------------------------------
  // SNACKS
  // ---------------------------------------------------------------------------

  void _showSnack(String message, {_SnackType type = _SnackType.info}) {
    Color color;
    IconData icon;

    switch (type) {
      case _SnackType.success:
        color = _green;
        icon = Icons.check_circle_outline_rounded;
        break;
      case _SnackType.warning:
        color = const Color(0xFFE08A1E);
        icon = Icons.warning_amber_rounded;
        break;
      case _SnackType.error:
        color = const Color(0xFFD64545);
        icon = Icons.error_outline_rounded;
        break;
      case _SnackType.info:
        color = _primary;
        icon = Icons.info_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        elevation: 0,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SnackType { success, warning, error, info }