// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart'; // Generado por FlutterFire CLI
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializar locale en español para fechas
  await initializeDateFormatting('es', null);

  runApp(const LotoHondurasApp());
}

class LotoHondurasApp extends StatelessWidget {
  const LotoHondurasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loto Honduras - La Diaria',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
