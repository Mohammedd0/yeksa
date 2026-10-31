// شوێنەکان، دووری و نرخ (هەمان TK.place، TK.searchPlaces، TK.distance، TK.priceFor ـی core.js)
import 'dart:math' as math;

import 'cloud.dart';
import 'places_data.dart';
import 'sel.dart';

/// بۆ گەڕان: پیتە عەرەبی و کوردییەکان یەک دەخرێن و بۆشایی لادەبرێت
String normalizeText(String? t) {
  var s = t ?? '';
  const ku = '٠١٢٣٤٥٦٧٨٩';
  s = s
      .replaceAll(RegExp('[ي]'), 'ی')
      .replaceAll(RegExp('[ك]'), 'ک')
      .replaceAll(RegExp('[ةہھه]'), 'ە')
      .replaceAll(RegExp('[ؤ]'), 'و')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ڕ', 'ر')
      .replaceAll('ڵ', 'ل')
      .replaceAll('ێ', 'ی')
      .replaceAll('ۆ', 'و')
      .replaceAll(RegExp('[ً-ْ‌\\s·\\-]'), '')
      .replaceAllMapped(RegExp('[٠-٩]'), (m) => '${ku.indexOf(m[0]!)}');
  return s.toLowerCase();
}

String placeIcon(Object? kind) =>
    const {'home': 'home', 'school': 'school', 'work': 'briefcase', 'hospital': 'hospital', 'mall': 'mall', 'gym': 'dumbbell'}[kind] ?? 'pin';

int round5k(num n) => math.max(40000, (n / 5000).round() * 5000);

bool isGeo(Object? g) => g is Map && g['lat'] is num && g['lng'] is num && (g['lat'] as num).isFinite && (g['lng'] as num).isFinite;

/// دووری هێڵی ڕاست بە کیلۆمەتر
double? geoKm(Object? a, Object? b) {
  if (!isGeo(a) || !isGeo(b)) return null;
  final pa = a as Map, pb = b as Map;
  const r = 6371.0;
  double rad(num d) => d * math.pi / 180;
  final dLat = rad((pb['lat'] as num) - (pa['lat'] as num));
  final dLng = rad((pb['lng'] as num) - (pa['lng'] as num));
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(pa['lat'] as num)) * math.cos(rad(pb['lat'] as num)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

extension YkPricing on Cloud {
  List<Json> get places {
    final p = meta['places'];
    if (p is List && p.isNotEmpty) return p.map(asMap).toList();
    return kPlacesDefaults;
  }

  /// شوێنی ناو لیست، یان شوێنێکی نووسراو بە دەست (c:ناو)
  Json? place(Object? id) {
    final s = str(id);
    if (s.isEmpty) return null;
    if (s.startsWith('c:')) return {'id': s, 'name': s.substring(2), 'kind': 'custom'};
    for (final p in places) {
      if (p['id'] == s) return p;
    }
    return null;
  }

  Map<String, double>? placeGeo(Object? id) {
    final p = place(id);
    if (p == null || !isGeo(p)) return null;
    return {'lat': (p['lat'] as num).toDouble(), 'lng': (p['lng'] as num).toDouble()};
  }

  /// گەڕانی شوێن: «بەخت» ← گەڕەکی بەختیاری (تەنها شوێنەکانی شاری سەرنشین)
  List<Json> searchPlaces(String q, Object? exclude) {
    final n = normalizeText(q);
    final city = passenger['city'];
    final pool = places.where((p) => p['id'] != exclude && (city == null || (p['city'] ?? 'erbil') == city)).toList();
    if (n.isEmpty) return pool.take(6).toList();
    final scored = <(Json, int)>[];
    for (final p in pool) {
      final name = normalizeText(str(p['name']));
      final words = str(p['name']).split(' ').map(normalizeText);
      final score = name.startsWith(n)
          ? 0
          : words.any((w) => w.startsWith(n))
              ? 1
              : name.contains(n)
                  ? 2
                  : 9;
      if (score < 9) scored.add((p, score));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    return scored.map((x) => x.$1).take(6).toList();
  }

  /// دووری بە کیلۆمەتر (ڕێگای شار ≈ ١.٣ × هێڵی ڕاست)
  double distance(Object? fromId, Object? toId, [Object? ga, Object? gb]) {
    final g1 = isGeo(ga) ? ga : placeGeo(fromId);
    final g2 = isGeo(gb) ? gb : placeGeo(toId);
    final km = geoKm(g1, g2);
    if (km != null) return math.max(1.5, km * 1.3);
    final a = place(fromId), b = place(toId);
    if (a == null || b == null || a['x'] == null || b['x'] == null) return 6;
    final dx = (a['x'] as num) - (b['x'] as num);
    final dy = (a['y'] as num) - (b['y'] as num);
    return math.max(1.5, math.sqrt(dx * dx + dy * dy) * 1.3);
  }

  num _c(String k) => config[k] as num;

  /// ڕێژەی هەفتانە بەراورد بە «٥ ڕۆژ چوون و هاتنەوە»
  double weekFactor(Json d) {
    final oneWayF = _c('oneWayFactor');
    if (hasPerDay(d)) {
      final vals = asMap(d['perDay']).values.map(asMap);
      final both = vals.where((e) => e['go'] != null && e['back'] != null).length;
      final one = vals.where((e) => (e['go'] != null) != (e['back'] != null)).length;
      return math.max(0.2, (both + one * oneWayF) / 5);
    }
    final dayCount = asList(d['days']).where((x) => x == true).length;
    final oneWay = d['oneWay'] is bool ? d['oneWay'] as bool : !(d['go'] != null && d['back'] != null);
    return ((dayCount == 0 ? 1 : dayCount) / 5) * (oneWay ? oneWayF : 1);
  }

  /// نرخی پێشنیارکراوی مانگانە
  int priceFor(Json d) {
    final km = d['km'] is num ? (d['km'] as num).toDouble() : distance(d['fromId'], d['toId'], d['fromGeo'], d['toGeo']);
    var per = (_c('basePrice') + km * _c('perKm')) * weekFactor(d);
    if (d['rideType'] == 'private') per *= _c('privateFactor');
    if (d['rideType'] == 'family') per *= _c('familyFactor');
    if (d['hasChild'] == true) per *= _c('kidsFactor');
    final n = math.max(1, (d['riders'] as num?)?.toInt() ?? 1);
    final total = d['mode'] == 'separate' ? per : per * (1 + _c('extraRiderFactor') * (n - 1));
    return round5k(total);
  }

  ({int min, int max}) offerBounds(num price) {
    final r = _c('offerRange');
    return (min: round5k(price * (1 - r)), max: round5k(price * (1 + r)));
  }

  /// بڕی داشکاندنی بانگهێشت بۆ یەکەم مانگ
  int refAmount(num price) {
    if (config['refOn'] != true) return 0;
    if (config['refType'] == 'pct') {
      final v = ((price * _c('refPct')) / 250).round() * 250;
      final mx = _c('refMax');
      return math.min(price.toInt(), mx > 0 ? math.min(v, mx.toInt()) : v);
    }
    return math.min(price.toInt(), _c('refFixed').toInt());
  }

  /// ئەو بانگهێشتەی ئەم سەرنشینە پێی هاتووە
  Json? get refAsInvitee {
    for (final r in list('referrals')) {
      if (r['invitee'] == me) return r;
    }
    return null;
  }

  /// ئایا شۆفێرێک بۆ داواکارییەک دەگونجێت (sel.fits)
  bool fits(Json? d, Json r) {
    if (d == null || d['status'] != 'active') return false;
    if (r['womanOnly'] == true && d['woman'] != true) return false;
    if (r['city'] != null && d['city'] != null && r['city'] != d['city']) return false;
    if (r['hasChild'] == true && d['kidsDriver'] != true) return false;
    if (r['mode'] == 'one' && ((d['seats'] as num?) ?? 4) < ((r['riders'] as num?) ?? 1)) return false;
    if (r['target'] != 'all' && r['target'] != d['id']) return false;
    return true;
  }
}

/// ڕێکخستنی perDay: ڕۆژە بەتاڵەکان لادەبرێن، days و کاتی باوتر دروست دەکرێنەوە
({Map<String, dynamic> perDay, List<bool> days, String? go, String? back, bool empty}) normPerDay(Map pd) {
  final out = <String, dynamic>{};
  final days = List<bool>.filled(7, false);
  pd.forEach((k, v) {
    final e = asMap(v);
    final go = e['go'] as String?;
    final back = e['back'] as String?;
    if ((go ?? '').isEmpty && (back ?? '').isEmpty) return;
    out['$k'] = {'go': (go ?? '').isEmpty ? null : go, 'back': (back ?? '').isEmpty ? null : back};
    final i = int.tryParse('$k');
    if (i != null && i >= 0 && i < 7) days[i] = true;
  });
  String? mode(Iterable<Object?> arr) {
    final n = <String, int>{};
    for (final v in arr) {
      if (v is String && v.isNotEmpty) n[v] = (n[v] ?? 0) + 1;
    }
    final keys = n.keys.toList()..sort((a, b) => n[b]! != n[a]! ? n[b]!.compareTo(n[a]!) : a.compareTo(b));
    return keys.isEmpty ? null : keys.first;
  }

  final vals = out.values.map(asMap).toList();
  return (perDay: out, days: days, go: mode(vals.map((e) => e['go'])), back: mode(vals.map((e) => e['back'])), empty: vals.isEmpty);
}
