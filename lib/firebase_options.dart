// firebase_options.dart
// Arquivo gerado com as configurações do projeto Firebase.
// Este arquivo é usado pelo Firebase.initializeApp() no main.dart
// para conectar o app ao projeto correto no Firebase.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Classe que fornece as opções de configuração do Firebase
/// de acordo com a plataforma em que o app está rodando.
class DefaultFirebaseOptions {
  /// Retorna as opções corretas para a plataforma atual.
  /// Lança um [UnsupportedError] se a plataforma não for suportada.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Se estiver rodando no navegador (Web), usa as configs Web
      return web;
    }

    // Para outras plataformas (Android, iOS, etc.), lança erro
    // pois ainda não foram configuradas
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'Android não configurado. Adicione o google-services.json '
          'e rode flutterfire configure para gerar as opções Android.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS não configurado. Adicione o GoogleService-Info.plist '
          'e rode flutterfire configure para gerar as opções iOS.',
        );
      default:
        throw UnsupportedError(
          'Plataforma não suportada: $defaultTargetPlatform',
        );
    }
  }

  /// Configurações do Firebase para a plataforma Web.
  /// Obtidas no Firebase Console em: Project Settings → Seus apps → Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAnHpFuZX6GAJxqyqCZN_wUTq-jr1GrzG8',
    authDomain: 'flownutri-6b21e.firebaseapp.com',
    projectId: 'flownutri-6b21e',
    storageBucket: 'flownutri-6b21e.firebasestorage.app',
    messagingSenderId: '871187881393',
    appId: '1:871187881393:web:044ef11b1a8482b9e8f190',
    measurementId: 'G-WWFHNS47SL',
  );
}
