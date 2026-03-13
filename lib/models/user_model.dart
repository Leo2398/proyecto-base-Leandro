/// Modelo que representa la entidad User de la base de datos
/// Principio S de SOLID: esta clase solo se encarga de representar
/// los datos de un usuario
class UserModel {
  final int? id;
  final String name;
  final String? image;
  final double balance;
  final String email;
  final String password;
  final String? description;
  final int role; // 0=cliente, 1=productor, 2=admin
  final String? cellphone;
  final int? deliveryModeID;
  final int? pickUpLocationID;
  final DateTime? registerDate;
  final int state; // 0=inactivo, 1=activo

  /// Constructor principal
  UserModel({
    this.id,
    required this.name,
    this.image,
    this.balance = 0.00,
    required this.email,
    required this.password,
    this.description,
    required this.role,
    this.cellphone,
    this.deliveryModeID,
    this.pickUpLocationID,
    this.registerDate,
    this.state = 1,
  });

  /// Convierte un Map (resultado de la BD) a un objeto UserModel
factory UserModel.fromMap(Map<String, dynamic> map) {
  return UserModel(
    id: map['ID'] != null ? int.parse(map['ID'].toString()) : null,
    name: map['name']?.toString() ?? '',
    image: map['image']?.toString(),
    balance: map['balance'] != null
        ? double.parse(map['balance'].toString())
        : 0.0,
    email: map['email']?.toString() ?? '',
    password: map['password']?.toString() ?? '',
    description: map['description']?.toString(),
    role: map['role'] != null ? int.parse(map['role'].toString()) : 0,
    cellphone: map['cellphone']?.toString(),
    deliveryModeID: map['deliveryModeID'] != null
        ? int.parse(map['deliveryModeID'].toString())
        : null,
    pickUpLocationID: map['pickUpLocationID'] != null
        ? int.parse(map['pickUpLocationID'].toString())
        : null,
    state: map['state'] != null ? int.parse(map['state'].toString()) : 1,
  );
}
  /// Convierte el objeto UserModel a un Map para insertar en la BD
  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'name': name,
      'image': image,
      'balance': balance,
      'email': email,
      'password': password,
      'description': description,
      'role': role,
      'cellphone': cellphone,
      'deliveryModeID': deliveryModeID,
      'pickUpLocationID': pickUpLocationID,
      'registerDate': registerDate?.toIso8601String(),
      'state': state,
    };
  }
}