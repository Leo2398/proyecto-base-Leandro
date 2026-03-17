import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/user_controller.dart';
import 'views/auth/login_view.dart';
import 'views/client/client_dashboard_view.dart';
import 'views/admin/admin_dashboard_view.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserController()),
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
        /// Verifica la sesión antes de mostrar la pantalla inicial
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
        /// TODO: return ProducerDashboardView
        return const ClientDashboardView();
      }
      else if (role == 2) {
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