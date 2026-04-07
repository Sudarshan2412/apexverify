import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => windows;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDqRuMeedpUFPu6iNXVl_47_2XPuaUntiM',
    appId: '1:249442016032:web:6bdd9dc5b058f7dab51545',
    messagingSenderId: '249442016032',
    projectId: 'apexverify-2026',
    storageBucket: 'apexverify-2026.firebasestorage.app',
  );
}