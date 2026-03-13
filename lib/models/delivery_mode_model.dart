/// Modelo que representa la entidad DeliveryMode
/// Principio S de SOLID: solo representa los datos de modalidad de entrega
class DeliveryModeModel {
  final int? id;
  final String name;

  DeliveryModeModel({
    this.id,
    required this.name,
  });

  factory DeliveryModeModel.fromMap(Map<String, dynamic> map) {
    return DeliveryModeModel(
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