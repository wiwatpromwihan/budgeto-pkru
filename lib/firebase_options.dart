import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb) {
      throw UnsupportedError('Budgeto เวอร์ชันนี้รองรับเว็บเท่านั้น');
    }
    return const FirebaseOptions(
      apiKey: 'AIzaSyAi7vR3F0_Y2lDY6LnjHHAYne4xLuXQub0',
      appId: '1:952948709205:web:ef502b36db79fd8aba01dc',
      messagingSenderId: '952948709205',
      projectId: 'budgeto-pkru-20261031',
      authDomain: 'budgeto-pkru-20261031.firebaseapp.com',
      storageBucket: 'budgeto-pkru-20261031.firebasestorage.app',
    );
  }
}
