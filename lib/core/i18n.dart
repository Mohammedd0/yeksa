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
  return s.replaceAllMapped(RegExp(r'\{(\d+)\}'), (m) {
    final i = int.parse(m[1]!);
    return i < args.length ? '${args[i] ?? ''}' : m[0]!;
  });
}

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
