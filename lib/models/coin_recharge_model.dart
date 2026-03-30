/// Modelo de solicitud de recarga de monedas
class CoinRechargeModel {
  final int? id;
  final int userId;
  final int coinsRequested;
  final double amountPaid;
  final String? proofImage;   // URL del comprobante de pago
  final String status;        // 'pending' | 'approved' | 'rejected'
  final DateTime requestDate;
  final DateTime? resolvedDate;
  final int? adminId;

  // Campos extra del JOIN con User (no se guardan en esta tabla)
  final String? userName;
  final String? userEmail;
  final String? userImage;

  const CoinRechargeModel({
    this.id,
    required this.userId,
    required this.coinsRequested,
    required this.amountPaid,
    this.proofImage,
    this.status = 'pending',
    required this.requestDate,
    this.resolvedDate,
    this.adminId,
    this.userName,
    this.userEmail,
    this.userImage,
  });

  factory CoinRechargeModel.fromMap(Map<String, dynamic> m) {
    return CoinRechargeModel(
      id: _toInt(m['ID']),
      userId: _toInt(m['userID']) ?? 0,
      coinsRequested: _toInt(m['coinsRequested']) ?? 0,
      amountPaid: _toDouble(m['amountPaid']) ?? 0.0,
      proofImage: m['proofImage']?.toString(),
      status: m['status']?.toString() ?? 'pending',
      requestDate: _toDateTime(m['requestDate']) ?? DateTime.now(),
      resolvedDate: _toDateTime(m['resolvedDate']),
      adminId: _toInt(m['adminID']),
      userName: m['userName']?.toString(),
      userEmail: m['userEmail']?.toString(),
      userImage: m['userImage']?.toString(),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
