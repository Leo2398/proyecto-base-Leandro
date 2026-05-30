import '../core/db_connection.dart';
import '../models/report_models.dart';

/// Servicio de reportes del administrador
/// Consulta directamente la BD para obtener métricas del marketplace
class ReportService {
  final DBConnection _db = DBConnection.instance;

  // ----------------------------------------------------------------- helpers

  String _fmt(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  // ----------------------------------------------------------------- queries

  /// Top 5 empresas (productores) por valor total de inventario activo.
  /// Filtro de fecha aplicado sobre HarvestDate de los productos.
  Future<List<EmpresaReportItem>> getTopEmpresas({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT u.ID, u.name,
               COUNT(DISTINCT p.ID) AS totalProductos,
               COALESCE(SUM(p.price * p.stock), 0) AS totalVentas
        FROM user u
        LEFT JOIN product p
          ON p.UserID = u.ID
          AND p.state = 1
          AND (p.HarvestDate IS NULL
               OR (p.HarvestDate >= :from AND p.HarvestDate <= :to))
        WHERE u.role = 1 AND u.state = 1
        GROUP BY u.ID, u.name
        HAVING totalVentas > 0
        ORDER BY totalVentas DESC
        LIMIT 5
        ''',
        {'from': _fmt(from), 'to': _fmt(to)},
      );
      return result.rows.map((row) {
        final m = row.assoc();
        return EmpresaReportItem(
          id: _toInt(m['ID']),
          nombre: m['name']?.toString() ?? '',
          totalVentas: _toDouble(m['totalVentas']),
          totalProductos: _toInt(m['totalProductos']),
        );
      }).toList();
    } catch (e) {
      print('Error en getTopEmpresas: $e');
      return [];
    }
  }

  /// Top 5 clientes por balance (mayor poder de compra).
  /// Filtro de fecha aplicado sobre registerDate del cliente.
  Future<List<ClienteReportItem>> getTopClientes({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT u.ID, u.name, u.email, u.balance
        FROM user u
        WHERE u.role = 0 AND u.state = 1
          AND (u.registerDate IS NULL
               OR (u.registerDate >= :from AND u.registerDate <= :to))
        ORDER BY u.balance DESC
        LIMIT 5
        ''',
        {'from': _fmt(from), 'to': _fmt(to)},
      );
      return result.rows.map((row) {
        final m = row.assoc();
        return ClienteReportItem(
          id: _toInt(m['ID']),
          nombre: m['name']?.toString() ?? '',
          email: m['email']?.toString() ?? '',
          balance: _toDouble(m['balance']),
        );
      }).toList();
    } catch (e) {
      print('Error en getTopClientes: $e');
      return [];
    }
  }

  /// Top 5 productos por valor de inventario (precio × stock).
  /// Filtro de fecha aplicado sobre HarvestDate.
  Future<List<ProductoReportItem>> getTopProductos({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute(
        '''
        SELECT p.name, p.price, p.stock,
               COALESCE(p.unit, 'unidades') AS unit,
               u.name AS producerName
        FROM product p
        JOIN user u ON u.ID = p.UserID AND u.state = 1
        WHERE p.state = 1
          AND (p.HarvestDate IS NULL
               OR (p.HarvestDate >= :from AND p.HarvestDate <= :to))
        ORDER BY (p.price * p.stock) DESC
        LIMIT 5
        ''',
        {'from': _fmt(from), 'to': _fmt(to)},
      );
      return result.rows.map((row) {
        final m = row.assoc();
        return ProductoReportItem(
          nombre: m['name']?.toString() ?? '',
          empresaNombre: m['producerName']?.toString() ?? '',
          precio: _toDouble(m['price']),
          stock: _toInt(m['stock']),
          unidad: m['unit']?.toString() ?? 'unidades',
        );
      }).toList();
    } catch (e) {
      print('Error en getTopProductos: $e');
      return [];
    }
  }

  /// Rendimiento por sector (ProductFamily) con totales de ventas, productos y empresas.
  Future<List<SectorReportItem>> getSectores() async {
    try {
      final conn = await _db.getConnection();
      final result = await conn.execute('''
        SELECT pf.ID, pf.name,
               COUNT(DISTINCT ppf.ProducerID) AS totalEmpresas,
               COUNT(DISTINCT p.ID)           AS totalProductos,
               COALESCE(SUM(p.price * p.stock), 0) AS totalVentas
        FROM productfamily pf
        LEFT JOIN producerproductfamily ppf ON ppf.FamilyID = pf.ID
        LEFT JOIN user u
          ON u.ID = ppf.ProducerID AND u.state = 1 AND u.role = 1
        LEFT JOIN product p
          ON p.UserID = u.ID AND p.state = 1
        GROUP BY pf.ID, pf.name
        ORDER BY totalVentas DESC
      ''');
      return result.rows.map((row) {
        final m = row.assoc();
        return SectorReportItem(
          id: _toInt(m['ID']),
          nombre: m['name']?.toString() ?? '',
          totalVentas: _toDouble(m['totalVentas']),
          totalProductos: _toInt(m['totalProductos']),
          totalEmpresas: _toInt(m['totalEmpresas']),
        );
      }).toList();
    } catch (e) {
      print('Error en getSectores: $e');
      return [];
    }
  }
}