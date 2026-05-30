import '../core/db_connection.dart';
import '../models/schedule_model.dart';
import 'interfaces/i_schedule_service.dart';

class ScheduleService implements IScheduleService {
  final DBConnection _db = DBConnection.instance;

  @override
  Future<List<ScheduleModel>> getSchedulesByProducerId(int producerID) async {
    try {
      final conn = await _db.getConnection();

      final result = await conn.execute(
        '''
        SELECT id, day, openingTime, closingTime, producerID
        FROM schedule
        WHERE producerID = :producerID
        ORDER BY day ASC, openingTime ASC
        ''',
        {
          'producerID': producerID,
        },
      );

      return result.rows.map((row) {
        final map = row.assoc();
        return ScheduleModel.fromMap(map);
      }).toList();
    } catch (e) {
      print('Error en getSchedulesByProducerId: $e');
      return [];
    }
  }

  @override
  Future<bool> createSchedule(ScheduleModel schedule) async {
    try {
      final conn = await _db.getConnection();

      await conn.execute(
        '''
        INSERT INTO schedule (day, openingTime, closingTime, producerID)
        VALUES (:day, :openingTime, :closingTime, :producerID)
        ''',
        {
          'day': schedule.day,
          'openingTime': _normalizeTime(schedule.openingTime),
          'closingTime': _normalizeTime(schedule.closingTime),
          'producerID': schedule.producerID,
        },
      );

      print('✓ Horario creado correctamente');
      return true;
    } catch (e) {
      print('Error en createSchedule: $e');
      return false;
    }
  }

  @override
  Future<bool> updateSchedule(ScheduleModel schedule) async {
    try {
      if (schedule.id == null) {
        print('Error en updateSchedule: el id del horario es null');
        return false;
      }

      final conn = await _db.getConnection();

      await conn.execute(
        '''
        UPDATE schedule SET
          day = :day,
          openingTime = :openingTime,
          closingTime = :closingTime,
          producerID = :producerID
        WHERE id = :id
        ''',
        {
          'id': schedule.id,
          'day': schedule.day,
          'openingTime': _normalizeTime(schedule.openingTime),
          'closingTime': _normalizeTime(schedule.closingTime),
          'producerID': schedule.producerID,
        },
      );

      print('✓ Horario actualizado correctamente');
      return true;
    } catch (e) {
      print('Error en updateSchedule: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteSchedule(int scheduleId) async {
    try {
      final conn = await _db.getConnection();

      await conn.execute(
        '''
        DELETE FROM schedule
        WHERE id = :id
        ''',
        {
          'id': scheduleId,
        },
      );

      print('✓ Horario eliminado correctamente');
      return true;
    } catch (e) {
      print('Error en deleteSchedule: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteSchedulesByProducerId(int producerID) async {
    try {
      final conn = await _db.getConnection();

      await conn.execute(
        '''
        DELETE FROM schedule
        WHERE producerID = :producerID
        ''',
        {
          'producerID': producerID,
        },
      );

      print('✓ Horarios del productor eliminados correctamente');
      return true;
    } catch (e) {
      print('Error en deleteSchedulesByProducerId: $e');
      return false;
    }
  }

  @override
  Future<bool> saveProducerSchedules(
      int producerID,
      List<ScheduleModel> schedules,
      ) async {
    try {
      final conn = await _db.getConnection();

      /// Elimina primero todos los horarios actuales del productor
      await conn.execute(
        '''
        DELETE FROM schedule
        WHERE producerID = :producerID
        ''',
        {
          'producerID': producerID,
        },
      );

      /// Inserta los nuevos horarios
      for (final schedule in schedules) {
        await conn.execute(
          '''
          INSERT INTO schedule (day, openingTime, closingTime, producerID)
          VALUES (:day, :openingTime, :closingTime, :producerID)
          ''',
          {
            'day': schedule.day,
            'openingTime': _normalizeTime(schedule.openingTime),
            'closingTime': _normalizeTime(schedule.closingTime),
            'producerID': producerID,
          },
        );
      }

      print('✓ Horarios del productor guardados correctamente');
      return true;
    } catch (e) {
      print('Error en saveProducerSchedules: $e');
      return false;
    }
  }

  String _normalizeTime(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) return '00:00:00';

    /// Si viene como HH:mm, lo convierte a HH:mm:ss
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(trimmed)) {
      return '$trimmed:00';
    }

    /// Si ya viene como HH:mm:ss, lo deja tal cual
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(trimmed)) {
      return trimmed;
    }

    return trimmed;
  }
}