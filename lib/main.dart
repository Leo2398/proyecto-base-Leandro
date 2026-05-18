import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/cart_controller.dart';
import 'controllers/coin_movement_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/order_controller.dart';
import 'controllers/product_controller.dart';
import 'controllers/request_controller.dart';
import 'controllers/review_controller.dart';
import 'controllers/user_controller.dart';

import 'services/coin_movement_service.dart';
import 'services/product_service.dart';

import 'views/admin/admin_dashboard_view.dart';
import 'views/auth/login_view.dart';
import 'views/client/client_dashboard_view.dart';
import 'views/producer/producer_dashboard_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserController>(
          create: (_) => UserController(),
        ),
        ChangeNotifierProvider<ProductController>(
          create: (_) => ProductController(
            productService: ProductService(),
          ),
        ),
        ChangeNotifierProvider<CartController>(
          create: (_) => CartController(),
        ),
        ChangeNotifierProvider<RequestController>(
          create: (_) => RequestController(),
        ),
        ChangeNotifierProvider<CoinMovementController>(
          create: (_) => CoinMovementController(
            coinMovementService: CoinMovementService(),
          ),
        ),
        ChangeNotifierProvider<OrderController>(
          create: (_) => OrderController(),
        ),
        ChangeNotifierProvider<NotificationController>(
          create: (_) => NotificationController(),
        ),
        ChangeNotifierProvider<ReviewController>(
          create: (_) => ReviewController(),
        ),
      ],
      child: MaterialApp(
        title: 'Agro App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5A8A5A),
          ),
          useMaterial3: true,
        ),
        home: Consumer<UserController>(
          builder: (context, controller, child) {
            if (!controller.sessionChecked) {
              return const Scaffold(
                backgroundColor: Color(0xFFF5F0E8),
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF5A8A5A),
                  ),
                ),
              );
            }

            if (controller.isLoggedIn && controller.currentUser != null) {
              final role = controller.currentUser!.role;

              if (role == 0) {
                return const ClientDashboardView();
              } else if (role == 1) {
                return const ProducerDashboardView();
              } else if (role == 2) {
                return const AdminDashboardView();
              }
            }

            return const LoginView();
          },
        ),
      ),
    );
  }
}