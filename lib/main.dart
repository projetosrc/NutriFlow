
// main.dart
// Ponto de entrada do aplicativo Flutter.
// Responsável por inicializar o Firebase antes de rodar o app.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Configurações do Firebase por plataforma
import 'login_page.dart';       // Tela inicial: Login

void main() async {
  // Garante que os bindings do Flutter estejam prontos antes de
  // qualquer operação assíncrona (obrigatório antes do Firebase.initializeApp)
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase com as opções da plataforma atual (Web, Android, etc.)
  // Deve ser chamado antes de qualquer uso do Firebase no app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicia o app após o Firebase estar pronto
  runApp(const NutriFlowApp());
}

/// Widget raiz do aplicativo.
/// Define o tema global e a tela inicial.
class NutriFlowApp extends StatelessWidget {
  const NutriFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove o banner "DEBUG" da tela
      theme: ThemeData(
        fontFamily: 'Roboto', // Fonte padrão do app
      ),
      home: const LoginPage(), // Tela inicial é o Login
    );
  }
}
