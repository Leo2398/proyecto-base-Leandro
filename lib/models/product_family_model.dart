/// Modelo que representa la entidad ProductFamily
/// Principio S de SOLID: solo representa los datos de familia de productos
class ProductFamilyModel {
  final int? id;
  final String name;

  ProductFamilyModel({
    this.id,
    required this.name,
  });

  factory ProductFamilyModel.fromMap(Map<String, dynamic> map) {
    return ProductFamilyModel(
      id: map['ID'],
      name: map['name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'name': name,
    };
  }
}