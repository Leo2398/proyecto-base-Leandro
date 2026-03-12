import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/user_controller.dart';
import 'views/auth/login_view.dart';

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
            /// Muestra loading mientras verifica la sesión
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

            /// Si hay sesión activa va al home, si no al login
            /// TODO: reemplazar LoginView por HomeView cuando esté lista
            return const LoginView();
          },
        ),
      ),
    );
  }
}