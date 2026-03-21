// lib/firebase_options.dart
// IMPORTANTE: Reemplaza los valores YOUR_* con los de tu proyecto Firebase.
// Puedes generarlo automáticamente con: flutterfire configure

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
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no están configuradas para Linux. '
          'Ejecuta FlutterFire CLI para configurar.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soportan esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAkurghCRgc4qrjPeOMyj9xHc-ssi5D4MU',
    appId: '1:594291783071:web:b5e26b6aa39fe0c75ff9aa',
    messagingSenderId: '594291783071',
    projectId: 'loteria-55688',
    authDomain: 'loteria-55688.firebaseapp.com',
    storageBucket: 'loteria-55688.firebasestorage.app',
    measurementId: 'G-2JCG02BPL1',
  );

  // ── WEB ──────────────────────────────────────────────────────────────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZUNJ9mD9KM4aI-qMa5yEClAAr8uT2_6M',
    appId: '1:594291783071:android:6daad3f68f67831c5ff9aa',
    messagingSenderId: '594291783071',
    projectId: 'loteria-55688',
    storageBucket: 'loteria-55688.firebasestorage.app',
  );

  // ── ANDROID ──────────────────────────────────────────────────────────────────

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBSpubUX4RBeF9CP8l6y_7-U-eyj_6DoTE',
    appId: '1:594291783071:ios:dde800d76452d90e5ff9aa',
    messagingSenderId: '594291783071',
    projectId: 'loteria-55688',
    storageBucket: 'loteria-55688.firebasestorage.app',
    iosBundleId: 'com.example.lotoHonduras',
  );

  // ── iOS ───────────────────────────────────────────────────────────────────────

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBSpubUX4RBeF9CP8l6y_7-U-eyj_6DoTE',
    appId: '1:594291783071:ios:dde800d76452d90e5ff9aa',
    messagingSenderId: '594291783071',
    projectId: 'loteria-55688',
    storageBucket: 'loteria-55688.firebasestorage.app',
    iosBundleId: 'com.example.lotoHonduras',
  );

  // ── macOS ────────────────────────────────────────────────────────────────────

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAkurghCRgc4qrjPeOMyj9xHc-ssi5D4MU',
    appId: '1:594291783071:web:aa81c96bba0990b25ff9aa',
    messagingSenderId: '594291783071',
    projectId: 'loteria-55688',
    authDomain: 'loteria-55688.firebaseapp.com',
    storageBucket: 'loteria-55688.firebasestorage.app',
    measurementId: 'G-9RLW67JM4X',
  );

  // ── WINDOWS ──────────────────────────────────────────────────────────────────
}