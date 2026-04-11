import '../../models/order_detail_model.dart';
import '../../models/order_model.dart';

abstract class IOrderService {
  Future<int?> createOrder(
      OrderModel order,
      List<OrderDetailModel> details,
      );

  Future<List<OrderModel>> getOrdersByClient(int clientID);

  Future<List<OrderModel>> getOrdersByProducer(int producerID);

  Future<List<OrderDetailModel>> getOrderDetails(int orderID);

  Future<bool> updateOrderState(int orderID, int state);
}