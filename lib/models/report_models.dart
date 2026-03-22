/// Modelos de datos para los reportes del administrador

class EmpresaReportItem {
  final int id;
  final String nombre;
  final double totalVentas;
  final int totalProductos;

  const EmpresaReportItem({
    required this.id,
    required this.nombre,
    required this.totalVentas,
    required this.totalProductos,
  });
}

class ClienteReportItem {
  final int id;
  final String nombre;
  final String email;
  final double balance;

  const ClienteReportItem({
    required this.id,
    required this.nombre,
    required this.email,
    required this.balance,
  });
}

class ProductoReportItem {
  final String nombre;
  final String empresaNombre;
  final double precio;
  final int stock;
  final String unidad;

  const ProductoReportItem({
    required this.nombre,
    required this.empresaNombre,
    required this.precio,
    required this.stock,
    required this.unidad,
  });
}

class TopProductItem {
  final int id;
  final String nombre;
  final String producerName;
  final double precio;
  final int stock;
  final String unidad;
  final String? picture;

  const TopProductItem({
    required this.id,
    required this.nombre,
    required this.producerName,
    required this.precio,
    required this.stock,
    required this.unidad,
    this.picture,
  });
}

class SectorReportItem {
  final int id;
  final String nombre;
  final double totalVentas;
  final int totalProductos;
  final int totalEmpresas;

  const SectorReportItem({
    required this.id,
    required this.nombre,
    required this.totalVentas,
    required this.totalProductos,
    required this.totalEmpresas,
  });
}
