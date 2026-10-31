// فۆرماتکردن: ژمارە، کات، بەروار، پارە (هەمان fmt ـی core.js)
import 'dart:math';

const String _ku = '٠١٢٣٤٥٦٧٨٩';

const List<String> kWeekdays = ['شەممە', 'یەکشەممە', 'دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە', 'هەینی'];
const List<String> kWeekdayShort = ['شەم', 'یەک', 'دوو', 'سێ', 'چوار', 'پێنج', 'هەینی'];
const List<String> kMonths = [
  'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
  'تەمموز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم', 'کانوونی یەکەم',
];

class Fmt {
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

  static String money(num v) => n('${group(v)} دینار');

  /// 7501234567 ← 0750 123 4567 (ژمارەی مۆبایل هەمیشە بە پیتی لاتینی)
  static String phone(String? p) {
    final d = (p ?? '').replaceAll(RegExp(r'\D'), '');
    return d.length == 10 ? '0${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}' : d;
  }

  static String period(String? hhmm) {
    final h = int.tryParse((hhmm ?? '0').split(':').first) ?? 0;
    if (h < 4 || h >= 20) return 'شەو';
    if (h < 12) return 'بەیانی';
    if (h < 15) return 'نیوەڕۆ';
    return 'ئێوارە';
  }

  static String clockBare(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '';
    final p = hhmm.split(':').map(int.parse).toList();
    final h12 = p[0] % 12 == 0 ? 12 : p[0] % 12;
    return n('$h12:${p[1].toString().padLeft(2, '0')}');
  }

  static String clock(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return '';
    return '${clockBare(hhmm)} ${period(hhmm)}';
  }

  static String hhmm(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// شەممە ١ی تشرینی دووەم
  static String date(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return n('${weekdayOf(d)} ${d.day}ی ${kMonths[d.month - 1]}');
  }

  static String today() {
    final d = DateTime.now();
    return n('${weekdayOf(d)}، ${d.day}ی ${kMonths[d.month - 1]}');
  }

  /// ناوی ڕۆژ (شەممە یەکەم ڕۆژە، وەک JS: (getDay() + 1) % 7)
  static String weekdayOf(DateTime d) => kWeekdays[weekdayIndex(d)];
  static int weekdayIndex(DateTime d) => (jsDay(d) + 1) % 7;

  /// getDay() ـی JS: یەکشەممە = ٠
  static int jsDay(DateTime d) => d.weekday % 7;

  static String ago(int at) {
    final mins = (DateTime.now().millisecondsSinceEpoch - at) ~/ 60000;
    if (mins < 1) return 'ئێستا';
    if (mins < 60) return n('$mins خولەک لەمەوبەر');
    final h = mins ~/ 60;
    if (h < 24) return n('$h کاتژمێر لەمەوبەر');
    if (h < 48) return 'دوێنێ';
    return n('${h ~/ 24} ڕۆژ لەمەوبەر');
  }

  static String names(List<String> list) {
    if (list.length <= 1) return list.isEmpty ? '' : list.first;
    return '${list.sublist(0, list.length - 1).join('، ')} و ${list.last}';
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
