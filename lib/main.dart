// main.dart
// Ponto de entrada do app. Primeiro arquivo que roda.
// Precisamos inicializar o Firebase antes de qualquer coisa,
// por isso o main é async.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_page.dart';

void main() async {
  // Isso é obrigatório quando usamos async no main
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase — sem isso nada funciona
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NutriFlowApp());
}

class NutriFlowApp extends StatelessWidget {
  const NutriFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto'),
      home: const LoginPage(), // começa sempre pelo login
    );
  }
}
