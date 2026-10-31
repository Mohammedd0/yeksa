// وێب: Flutter نیشانەی viewport-fit=cover دانانێت، بۆیە env(safe-area-inset-bottom) هەمیشە
// صفرە. کاتێک ئەپەکە لە شاشەی سەرەکی کراوەتەوە (standalone) لە ئایفۆنێکی بێ دوگمەی ماڵ،
// هێڵی خوارەوەی ئایفۆن ٣٤ پیکسڵ دەگرێت، هەر وەک وێبەکەی یەکسا
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

double detectWebSafeBottom() {
  try {
    final nav = globalContext['navigator'] as JSObject?;
    final standalone = nav?['standalone'];
    final isStandalone = standalone != null && standalone.dartify() == true;
    final mm = globalContext.callMethod<JSObject?>('matchMedia'.toJS, '(display-mode: standalone)'.toJS);
    final pwa = isStandalone || (mm?['matches']?.dartify() == true);
    if (!pwa) return 0;
    final scr = globalContext['screen'] as JSObject?;
    final w = (scr?['width']?.dartify() as num?) ?? 0;
    final h = (scr?['height']?.dartify() as num?) ?? 0;
    final ua = ((nav?['userAgent']?.dartify()) ?? '').toString();
    final ios = RegExp('iPhone|iPad|iPod').hasMatch(ua);
    // iPhone X و نوێتر (بێ دوگمەی ماڵ): درێژی شاشە ≥ ٨١٢
    return ios && (w > h ? w : h) >= 812 ? 34 : 0;
  } catch (_) {
    return 0;
  }
}
