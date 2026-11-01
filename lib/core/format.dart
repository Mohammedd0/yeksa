// فۆرماتکردن: ژمارە، کات، بەروار، پارە (هەمان fmt ـی core.js)
// i18n-keep-file: ناوە کوردی/عەرەبییەکانی ئێرە بە ئەنقەست لێرەن
import 'dart:math';

import 'i18n.dart';

const String _ku = '٠١٢٣٤٥٦٧٨٩';

/// ناوە کوردییەکان وەک داتا هەڵدەگیرێن (بۆ نموونە مانگی پارەدان). بۆ پیشاندان Fmt.weekday و Fmt.month بەکاربهێنە
const List<String> kWeekdays = ['شەممە', 'یەکشەممە', 'دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە', 'هەینی'];
const List<String> kWeekdayShort = ['شەم', 'یەک', 'دوو', 'سێ', 'چوار', 'پێنج', 'هەینی'];
const List<String> kMonths = [
  'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
  'تەمموز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم', 'کانوونی یەکەم',
];

const List<String> _arWeekdays = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
const List<String> _arWeekdayShort = ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];
const List<String> _arMonths = [
  'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
  'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
];
const List<String> _enWeekdays = ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const List<String> _enWeekdayShort = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const List<String> _enMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class Fmt {
  /// ناوی ڕۆژ بە زمانی ئەپ (٠ = شەممە)
  static String weekday(int i) => L.pick(kWeekdays, _arWeekdays, _enWeekdays)[i];
  static String weekdayShort(int i) => L.pick(kWeekdayShort, _arWeekdayShort, _enWeekdayShort)[i];

  /// ناوی مانگ بە زمانی ئەپ (٠ = کانوونی دووەم)
  static String month(int i) => L.pick(kMonths, _arMonths, _enMonths)[i];

  /// ناوی مانگێکی هەڵگیراو (بە کوردی لە داتادا) بە زمانی ئەپ
  static String monthName(String ku) {
    final i = kMonths.indexOf(ku);
    return i < 0 ? ku : month(i);
  }

  /// 'ku' = ١٢٣، 'en' = 123 (لە ڕێکخستنەکاندا دەگۆڕدرێت)
  static String digits = 'ku';

  /// ژمارەکان بە پێی ڕێکخستن
  static String n(Object? v) {
    final s = '${v ?? ''}';
    if (digits == 'en') {
      return s.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${_ku.indexOf(m[0]!)}');
    }
    return s
        .replaceAllMapped(RegExp('[0-9]'), (m) => _ku[int.parse(m[0]!)])
        .replaceAllMapped(RegExp('([٠-٩]),(?=[٠-٩])'), (m) => '${m[1]}٬');
  }

  static String group(num v) {
    final s = v.round().toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  static String money(num v) => n(L.en ? '${group(v)} IQD' : '${group(v)} ${L.ar ? 'دينار' : 'دینار'}');

  /// 7501234567 ← 0750 123 4567 (ژمارەی مۆبایل هەمیشە بە پیتی لاتینی)
  static String phone(String? p) {
    final d = (p ?? '').replaceAll(RegExp(r'\D'), '');
    return d.length == 10 ? '0${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}' : d;
  }

  static String period(String? hhmm) {
    final h = int.tryParse((hhmm ?? '0').split(':').first) ?? 0;
    if (L.en) return h < 12 ? 'AM' : 'PM';
    if (h < 4 || h >= 20) return L.ar ? 'ليلاً' : 'شەو';
    if (h < 12) return L.ar ? 'صباحاً' : 'بەیانی';
    if (h < 15) return L.ar ? 'ظهراً' : 'نیوەڕۆ';
    return L.ar ? 'مساءً' : 'ئێوارە';
  }

  static String clockBare(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '';
    final p = hhmm.split(':').map(int.parse).toList();
    final h12 = p[0] % 12 == 0 ? 12 : p[0] % 12;
    return n('$h12:${p[1].toString().padLeft(2, '0')}');
  }

  static String clock(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '';
    // LRM: لە ئینگلیزی کاتەکە بە ناوێکی کوردی پێش خۆیەوە نالکێت («تاقی · 7:30 AM»)
    return '${L.en ? '\u200E' : ''}${clockBare(hhmm)} ${period(hhmm)}';
  }

  static String hhmm(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// شەممە ١ی تشرینی دووەم
  static String date(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final wd = weekdayOf(d), m = month(d.month - 1);
    return n(L.pick('$wd ${d.day}ی $m', '$wd ${d.day} $m', '$wd, ${d.day} $m'));
  }

  static String today() {
    final d = DateTime.now();
    final wd = weekdayOf(d), m = month(d.month - 1);
    return n(L.pick('$wd، ${d.day}ی $m', '$wd، ${d.day} $m', '$wd, ${d.day} $m'));
  }

  /// ناوی ڕۆژ (شەممە یەکەم ڕۆژە، وەک JS: (getDay() + 1) % 7)
  static String weekdayOf(DateTime d) => weekday(weekdayIndex(d));
  static int weekdayIndex(DateTime d) => (jsDay(d) + 1) % 7;

  /// getDay() ـی JS: یەکشەممە = ٠
  static int jsDay(DateTime d) => d.weekday % 7;

  static String ago(int at) {
    final mins = (DateTime.now().millisecondsSinceEpoch - at) ~/ 60000;
    if (mins < 1) return tr('ئێستا');
    if (mins < 60) return n(tr('{0} خولەک لەمەوبەر', [mins]));
    final h = mins ~/ 60;
    if (h < 24) return n(tr('{0} کاتژمێر لەمەوبەر', [h]));
    if (h < 48) return tr('دوێنێ');
    return n(tr('{0} ڕۆژ لەمەوبەر', [h ~/ 24]));
  }

  static String names(List<String> list) {
    if (list.length <= 1) return list.isEmpty ? '' : list.first;
    final head = list.sublist(0, list.length - 1).join(L.en ? ', ' : '، ');
    return L.pick('$head و ${list.last}', '$head و${list.last}', '$head and ${list.last}');
  }

  static String monthKey([DateTime? d]) {
    d ??= DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static String todayIso([DateTime? d]) {
    d ??= DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

/// ژمارەی مۆبایل: ژمارەی کوردی دەگۆڕێت، 964 و 0 لادەبات ← 7501234567
String cleanPhone(String? phone) {
  return (phone ?? '')
      .replaceAllMapped(RegExp('[٠-٩]'), (m) => '${_ku.indexOf(m[0]!)}')
      .replaceAll(RegExp(r'\D'), '')
      .replaceFirst(RegExp(r'^964'), '')
      .replaceFirst(RegExp(r'^0'), '');
}

final Random _rnd = Random();

/// ناسنامەی کورت (وەک uid() ـی core.js: ٧ پیتی base36)
String shortId() {
  const abc = '0123456789abcdefghijklmnopqrstuvwxyz';
  return List.generate(7, (_) => abc[_rnd.nextInt(abc.length)]).join();
}

/// کۆدی بانگهێشت وەک YK7Q4M
String newRefCode() {
  const abc = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  return 'YK${List.generate(4, (_) => abc[_rnd.nextInt(abc.length)]).join()}';
}

int nowMs() => DateTime.now().millisecondsSinceEpoch;
