// زمانی ئەپ: کوردی (بنەڕەت)، عەرەبی، ئینگلیزی
//
// دەقی کوردی خۆی کلیلەکەیە: tr('سڵاو') لە کوردیدا هەمان دەق دەگەڕێنێتەوە و لە
// عەرەبی/ئینگلیزیدا وەرگێڕانەکەی لە i18n_data.dart. بۆ دەقی گۆڕاو {0}، {1}... بەکاربهێنە:
//   tr('{0} ڕۆژ ماوە', [n])
// ئەگەر وەرگێڕان نەبوو، دەقە کوردییەکە پیشان دەدرێت (هەرگیز بەتاڵ نابێت).
import 'i18n_data.dart';

class L {
  /// 'ku' | 'ar' | 'en'
  static String lang = 'ku';

  static bool get ku => lang == 'ku';
  static bool get ar => lang == 'ar';
  static bool get en => lang == 'en';

  /// کوردی و عەرەبی لە ڕاستەوە بۆ چەپ، ئینگلیزی لە چەپەوە بۆ ڕاست
  static bool get rtl => lang != 'en';

  /// هەڵبژاردنی بەهایەک بە پێی زمان
  static T pick<T>(T ku, T ar, T en) => lang == 'ar' ? ar : lang == 'en' ? en : ku;

  /// ناوی زمانەکان (هەر زمانێک بە خۆی)
  static const List<(String, String)> options = [('ku', 'کوردی'), ('ar', 'العربية'), ('en', 'English')];
}

String _fill(String s, List<Object?> args) {
  if (args.isEmpty) return s;
  final out = s.replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) {
    final i = int.parse(m[1]!);
    return i < args.length ? '${args[i] ?? ''}' : m[0]!;
  });
  return L.en ? _enSingular(out) : out;
}

/// ئینگلیزی: «1 points» ← «1 point» (وشەی کۆ دوای ژمارەی ١)
const Map<String, String> _enOne = {
  'points': 'point', 'passengers': 'passenger', 'requests': 'request', 'ratings': 'rating', 'days': 'day',
  'seats': 'seat', 'trips': 'trip', 'stops': 'stop', 'people': 'person', 'minutes': 'minute', 'hours': 'hour',
  'riders': 'rider', 'members': 'member', 'messages': 'message', 'drivers': 'driver', 'routes': 'route',
};
final RegExp _enOneRe = RegExp(r'(^|[^\d.,])(1|١)((?: [a-z]+)?) ([a-z]+)\b');

String _enSingular(String s) => s.replaceAllMapped(_enOneRe, (m) {
      final a = m[3]!.trim(), b = m[4]!;
      // «1 new requests» ← «1 new request»
      if (_enOne[b] != null) return '${m[1]}${m[2]}${m[3]} ${_enOne[b]}';
      // «1 days ago» ← «1 day ago»
      if (a.isNotEmpty && _enOne[a] != null) return '${m[1]}${m[2]} ${_enOne[a]} $b';
      return m[0]!;
    });

/// وەرگێڕانی دەقێکی ڕووکار. [ku] دەقی کوردییە (کلیل)، [args] بۆ {0}، {1}...
String tr(String ku, [List<Object?> args = const []]) {
  if (L.lang == 'ku') return _fill(ku, args);
  final m = L.lang == 'ar' ? kTrAr : kTrEn;
  return _fill(m[ku] ?? ku, args);
}

/// دەقێک کە لە Firebase هاتووە (بۆ نموونە ناونیشانی ئاگادارکردنەوە کە بە کوردی
/// هەڵگیراوە): ئەگەر وەرگێڕانی تەواوی هەبوو پیشانی دەدات، ئەگینا وەک خۆی
String trData(Object? s) {
  final v = '${s ?? ''}';
  if (L.lang == 'ku' || v.isEmpty) return v;
  final m = L.lang == 'ar' ? kTrAr : kTrEn;
  return m[v] ?? v;
}

/// وەرگێڕانی ڕاستەوخۆ بۆ ئەو شوێنانەی هەمان دەقی کوردی دوو مانای جیاوازی هەیە
/// (بۆ نموونە «ناردن»: ناردنی پارە / ناردنی نامە)
String trc(String ku, String ar, String en, [List<Object?> args = const []]) => _fill(L.pick(ku, ar, en), args);
