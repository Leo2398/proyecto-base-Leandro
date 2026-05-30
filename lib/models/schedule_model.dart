class ScheduleModel {
  final int? id;
  final int day;
  final String openingTime;
  final String closingTime;
  final int producerID;

  ScheduleModel({
    this.id,
    required this.day,
    required this.openingTime,
    required this.closingTime,
    required this.producerID,
  });

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'] != null
          ? int.parse(map['id'].toString())
          : (map['ID'] != null ? int.parse(map['ID'].toString()) : null),
      day: map['day'] != null
          ? int.parse(map['day'].toString())
          : (map['Day'] != null ? int.parse(map['Day'].toString()) : 0),
      openingTime: map['openingTime']?.toString() ??
          map['OpeningTime']?.toString() ??
          '',
      closingTime: map['closingTime']?.toString() ??
          map['ClosingTime']?.toString() ??
          '',
      producerID: map['producerID'] != null
          ? int.parse(map['producerID'].toString())
          : (map['ProducerID'] != null
          ? int.parse(map['ProducerID'].toString())
          : 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day': day,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'producerID': producerID,
    };
  }

  ScheduleModel copyWith({
    int? id,
    int? day,
    String? openingTime,
    String? closingTime,
    int? producerID,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      day: day ?? this.day,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      producerID: producerID ?? this.producerID,
    );
  }

  String get dayName {
    switch (day) {
      case 0:
        return 'Lunes';
      case 1:
        return 'Martes';
      case 2:
        return 'Miércoles';
      case 3:
        return 'Jueves';
      case 4:
        return 'Viernes';
      case 5:
        return 'Sábado';
      case 6:
        return 'Domingo';
      default:
        return 'Desconocido';
    }
  }

  @override
  String toString() {
    return 'ScheduleModel(id: $id, day: $day, openingTime: $openingTime, closingTime: $closingTime, producerID: $producerID)';
  }
}