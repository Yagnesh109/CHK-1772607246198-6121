import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'FirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD7J10jhosE4WNlQCUR9NSOY1A1mtsueW8',
    authDomain: 'medimind-fa553.firebaseapp.com',
    projectId: 'medimind-fa553',
    storageBucket: 'medimind-fa553.firebasestorage.app',
    messagingSenderId: '532671483408',
    appId: '1:532671483408:web:2e96fb2e62c1c23d108495',
    measurementId: 'G-N1XDZJDS0N',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC2XRquHs4SGXGbZLVPUaVYpnwu9FZAzic',
    appId: '1:532671483408:android:7db1c026412fc003108495',
    messagingSenderId: '532671483408',
    projectId: 'medimind-fa553',
    storageBucket: 'medimind-fa553.firebasestorage.app',
  );
}
