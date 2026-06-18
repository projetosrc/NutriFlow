// lib/firebase_options.dart
// Configurações do Firebase para Web e Android.
// Gerado originalmente com flutterfire configure — adaptado manualmente para Android.
//
// ATENÇÃO: as chaves abaixo são as mesmas do projeto flownutri-6b21e.
// Para Android, o google-services.json (não commitado no git) contém
// os mesmos valores e é injetado pelo GitHub Actions via Secret.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
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

  // ── WEB ──────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAnHpFuZX6GAJxqyqCZN_wUTq-jr1GrzG8',
    authDomain: 'flownutri-6b21e.firebaseapp.com',
    projectId: 'flownutri-6b21e',
    storageBucket: 'flownutri-6b21e.firebasestorage.app',
    messagingSenderId: '871187881393',
    appId: '1:871187881393:web:044ef11b1a8482b9e8f190',
    measurementId: 'G-WWFHNS47SL',
  );

  // ── ANDROID ──────────────────────────────────────────────────────
  // Estes valores vêm do google-services.json do Firebase Console.
  // Vá em: Firebase Console → Project Settings → Seus apps → Android
  // e copie os valores do arquivo google-services.json do seu projeto.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAnHpFuZX6GAJxqyqCZN_wUTq-jr1GrzG8', // ← mesma apiKey do Web para começar
    appId: '1:871187881393:android:SUBSTITUA_PELO_APP_ID_ANDROID', // ← copie do google-services.json
    messagingSenderId: '871187881393',
    projectId: 'flownutri-6b21e',
    storageBucket: 'flownutri-6b21e.firebasestorage.app',
  );
}
