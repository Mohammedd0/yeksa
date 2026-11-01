// ڕێکخستنی Firebase بۆ یەکسا
// ئێستا تەنها وەشانی وێبی تێدایە (هەمان کلیلەکانی shared/firebase-config.js)، بۆیە لە Chrome و Safari کار دەکات.
// بۆ ئەندرۆید و ئایفۆن: فەرمانی «flutterfire configure» لێبدە. ئەم فایلە بە وەشانێکی تەواو دەگۆڕێت.
// ئەم کلیلانە نهێنی نین؛ پاراستنی زانیارییەکان بە firestore.rules دەکرێت.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('بۆ ئەندرۆید و ئایفۆن سەرەتا فەرمانی «flutterfire configure» لێبدە'); // i18n-keep
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA42RbHHo2l5fRlox7SxHIIZvG_cn3t4bo',
    appId: '1:1079497273725:web:8b406617bb5dd1633c1c14',
    messagingSenderId: '1079497273725',
    projectId: 'taxiakam-6d28f',
    authDomain: 'taxiakam-6d28f.firebaseapp.com',
    storageBucket: 'taxiakam-6d28f.firebasestorage.app',
  );
}
