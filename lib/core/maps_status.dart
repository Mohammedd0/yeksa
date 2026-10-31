// دۆخی Google Maps: ئەگەر بار نەبوو (کلیلی هەڵە، Billing نییە، بێ ئینتەرنێت) نەخشە وێنەییەکە پیشان دەدرێت
import 'package:flutter/foundation.dart';

import 'maps_watch_stub.dart' if (dart.library.js_interop) 'maps_watch_web.dart' as watch;

class MapsStatus {
  /// true = Google Maps کار ناکات
  static final ValueNotifier<bool> failed = ValueNotifier(false);
  static bool _started = false;

  /// یەک جار لە سەرەتای ئەپدا
  static void start() {
    if (_started) return;
    _started = true;
    watch.installMapsWatch((why) {
      debugPrint('Google Maps بار نەبوو: $why');
      failed.value = true;
    });
  }
}
