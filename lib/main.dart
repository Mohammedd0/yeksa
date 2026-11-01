// یەکسا، ئەپی سەرنشین (Flutter)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/auth.dart';
import 'core/cloud.dart';
import 'core/images.dart';
import 'core/invite_link.dart';
import 'core/maps_status.dart';
import 'core/settings.dart';
// ڕێکخستنی Firebase (ئێستا وێب؛ بۆ مۆبایل «flutterfire configure» نوێی دەکاتەوە)
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  captureInviteRef();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // کۆپی ناوخۆ: ئەپ بێ ئینتەرنێتیش دەکرێتەوە و دوایین زانیارییەکان پیشان دەدات
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  if (kIsWeb) debugPrint('یەکسا: وەشانی وێبی Flutter'); // i18n-keep

  MapsStatus.start();
  final settings = LocalSettings();
  await settings.load();
  final cloud = Cloud()..start();
  final auth = AuthService(cloud);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: cloud),
        Provider.value(value: auth),
        ChangeNotifierProvider(create: (_) => ImageStore(cloud)),
      ],
      child: const YeksaApp(),
    ),
  );
}
