import 'package:flutter/material.dart';
import 'package:myapp/dao/configurations.dart';
import 'package:myapp/vista/loginpage.dart';
import 'package:myapp/widget/dashboard_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Asegurarse de que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: Configurations.mSupabaseUrl,
    anonKey: Configurations.mSupabaseKey, 
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Agua',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0085FF),
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}