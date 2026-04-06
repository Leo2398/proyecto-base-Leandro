import '../../models/schedule_model.dart';

abstract class IScheduleService {
  Future<List<ScheduleModel>> getSchedulesByProducerId(int producerID);

  Future<bool> createSchedule(ScheduleModel schedule);

  Future<bool> updateSchedule(ScheduleModel schedule);

  Future<bool> deleteSchedule(int scheduleId);

  Future<bool> deleteSchedulesByProducerId(int producerID);

  Future<bool> saveProducerSchedules(
      int producerID,
      List<ScheduleModel> schedules,
      );
}