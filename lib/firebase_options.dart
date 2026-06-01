

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;


class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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
