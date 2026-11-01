// هەڵبژێرەرەکان (sel ـی core.js) و یاسا بچووکەکانی گەشت و بەشداری بۆ سەرنشینی ئێستا
import 'cloud.dart';
import 'format.dart';
import 'i18n.dart';

typedef Json = Map<String, dynamic>;

Json asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
List<dynamic> asList(Object? v) => v is List ? v : const [];
String str(Object? v) => v == null ? '' : '$v';

/// دەقی هەڵگیراو (Firestore، شۆفێر، بەڕێوەبەر) هەمیشە بە کوردی دروست دەکرێت:
/// [f] بە زمانی کوردی جێبەجێ دەکرێت (Fmt.weekday، Fmt.clock، fmtDays... هەموو کوردی دەبن)
/// تەنها بۆ کۆدی هاوکات (بێ await).
T inKu<T>(T Function() f) {
  final prev = L.lang;
  L.lang = 'ku';
  try {
    return f();
  } finally {
    L.lang = prev;
  }
}

/// «07:30» ← خولەک لە سەرەتای ڕۆژ
int toMin(String hhmm) => (int.tryParse(hhmm.substring(0, 2)) ?? 0) * 60 + (int.tryParse(hhmm.substring(3, 5)) ?? 0);

String addMin(String hhmm, int mins) {
  final t = (toMin(hhmm) + mins + 1440) % 1440;
  return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

/// چەند خولەک ماوە تا کاتێکی ئەمڕۆ (نێگەتیڤ = تێپەڕیوە)
int minutesUntil(String hhmm) {
  final d = DateTime.now();
  return toMin(hhmm) - (d.hour * 60 + d.minute);
}

/// هەموو ڕۆژەکان: ناوی ڕۆژەکان بە کورتی (fmt.days)
String fmtDays(List<dynamic> days) {
  final on = <int>[];
  for (var i = 0; i < days.length; i++) {
    if (days[i] == true) on.add(i);
  }
  if (on.length == 7) return tr('هەموو ڕۆژێک');
  var range = on.length > 2;
  for (var i = 1; i < on.length; i++) {
    if (on[i] != on[i - 1] + 1) range = false;
  }
  if (range) return tr('{0} تا {1}', [Fmt.weekday(on.first), Fmt.weekday(on.last)]);
  return on.map((i) => Fmt.weekday(i)).join(tr('، '));
}

bool hasPerDay(Json x) => asMap(x['perDay']).isNotEmpty;

extension YkSel on Cloud {
  /* ---------------- شۆفێر و ئەندامان ---------------- */

  /// شۆفێرەکان (بەشی گشتی dpub)
  List<Json> get drivers => list('dpub');

  Json? driver(Object? id) {
    if (id == null) return null;
    final d = doc('dpub/$id');
    if (d == null) return null;
    return {...d, 'id': d['id'] ?? id};
  }

  List<Json> get members => asList(asMap(pax['family'])['members']).map(asMap).toList();

  Json? member(Object? id) {
    for (final m in members) {
      if (m['id'] == id) return m;
    }
    return null;
  }

  List<String> names(List<dynamic> ids) => ids.map((id) => str(member(id)?['name'])).where((x) => x.isNotEmpty).toList();

  /// وێنەی خاوەنی ئەکاونت ئەگەر ئەندامەکە خۆی بێت
  String? memberPhoto(Object? memberId) {
    final m = members;
    if (m.isNotEmpty && m.first['id'] == memberId) return passenger['photo'] as String?;
    return null;
  }

  /* ---------------- بەشداری و گەشت ---------------- */

  List<Json> get mySubs => list('subscriptions').where((x) => x['owner'] == me).toList();

  Json? sub(Object? id) {
    for (final x in list('subscriptions')) {
      if (x['id'] == id) return x;
    }
    return null;
  }

  Json? trip(Object? id) {
    for (final t in list('trips')) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  bool paused(Json t) => t['subId'] != null && sub(t['subId'])?['status'] == 'paused';

  static bool isToday(Json t) => t['day'] == null || t['day'] == Fmt.todayIso() || t['status'] == 'active';

  /// گەشتەکانی ئەمڕۆی سەرنشینی ئێستا
  List<Json> get myTrips => list('trips')
      .where((t) => t['owner'] == me && asList(t['memberIds']).isNotEmpty && !paused(t) && isToday(t))
      .toList();

  List<Json> get openRequests => list('requests').where((r) => r['owner'] == me && r['status'] == 'open').toList();

  /* ---------------- ئاگادارکردنەوە و هەواڵ ---------------- */

  /// ئاگادارکردنەوەکانی خۆم (بێ نامە)، نوێ لە سەرەتا
  List<Json> get myNotices {
    final l = list('pnotices').where((n) => n['owner'] == me && n['kind'] != 'chat').toList();
    l.sort((a, b) => ((b['at'] as num?) ?? 0).compareTo((a['at'] as num?) ?? 0));
    return l;
  }

  num get readNoticesAt => (pax['readNoticesAt'] as num?) ?? 0;

  int get unreadNotices => myNotices.where((n) => ((n['at'] as num?) ?? 0) > readNoticesAt).length;

  int get unreadMsgs => list('messages').where((m) => m['peer'] == me && m['fromDriver'] == true && m['readP'] != true).length;

  List<Json> newsFor(String aud) => list('news').where((n) => n['hidden'] != true && (n['aud'] == aud || n['aud'] == 'all')).toList();

  /// «ad» = ڕێکلام و هەواڵ (بانەری سەرەوە)، «offer» = ئۆفەر
  static String newsKind(Json n) {
    final k = n['kind'];
    if (k is String && k.isNotEmpty) return k;
    return (str(n['code']).isNotEmpty || str(n['tag']).contains('ئۆفەر')) ? 'offer' : 'ad'; // i18n-keep
  }
}

/* ---------------- یاساکانی بەشداری (dayApplies، dayTime، subLeg) ---------------- */

/// ئایا بەشدارییەک لەو ڕۆژەدا گەشتی هەیە
bool dayApplies(Json sub, [DateTime? date]) {
  date ??= DateTime.now();
  final wd = Fmt.weekdayIndex(date);
  if (hasPerDay(sub)) {
    final e = asMap(asMap(sub['perDay'])['$wd']);
    if (e.isEmpty || (e['go'] == null && e['back'] == null)) return false;
  } else {
    final days = asList(sub['days']);
    if (wd >= days.length || days[wd] != true) return false;
  }
  final start = sub['startDate'];
  return start == null || str(start).compareTo(Fmt.todayIso(date)) <= 0;
}

/// کاتی چوون یان هاتنەوەی ڕۆژێک. null = ئەو ڕۆژە ئەو بەشەی نییە
String? dayTime(Json? sub, String dir, [DateTime? date]) {
  if (sub == null) return null;
  date ??= DateTime.now();
  if (hasPerDay(sub)) {
    final e = asMap(asMap(sub['perDay'])['${Fmt.weekdayIndex(date)}']);
    final v = dir == 'back' ? e['back'] : e['go'];
    return v is String && v.isNotEmpty ? v : null;
  }
  final v = dir == 'back' ? sub['back'] : sub['go'];
  return v is String && v.isNotEmpty ? v : null;
}

String? subTime(Json sub, String dir) {
  final v = dir == 'back' ? sub['back'] : sub['go'];
  return v is String && v.isNotEmpty ? v : null;
}

({String from, String to}) subLeg(Json sub, String dir) =>
    dir == 'back' ? (from: str(sub['to']), to: str(sub['from'])) : (from: str(sub['from']), to: str(sub['to']));

/// ئایا بەشدارییەک لەو ڕۆژەدا لەگەڵ ڕۆتەکەی دەڕوات (کاتی جیاواز بۆ هەر ڕۆژێک)
bool inRouteOn(Json? sub, String dir, int poolWindowMin, [DateTime? date]) {
  if (sub == null || !hasPerDay(sub)) return true;
  final tm = dayTime(sub, dir, date);
  final base = subTime(sub, dir);
  return tm != null && base != null && (toMin(tm) - toMin(base)).abs() <= poolWindowMin;
}

/// کاتی سوارکردنی بەشدارییەک لە ڕۆتێکدا (runStops ـی core.js بە کورتی: هەمان شوێن بە دوای یەکدا = یەک وێستگە)
String? routePickTime(Json route, List<Json> subs, String subId, int stopMin) {
  final order = asList(route['subIds']).where((id) => subs.any((x) => x['id'] == id)).toList();
  final dir = str(route['dir']);
  var idx = -1;
  String? lastPlace;
  for (final id in order) {
    final x = subs.firstWhere((y) => y['id'] == id);
    final place = subLeg(x, dir).from;
    if (place != lastPlace) idx++;
    lastPlace = place;
    if (id == subId) return addMin(str(route['time']), idx * stopMin);
  }
  return null;
}

/* ---------------- یاساکانی گەشت ---------------- */

/// «نایەم» تەنها تا ماوەیەک پێش گەشت ڕێگەپێدراوە
bool canSkip(Json t, int cutoffMin) {
  final m = minutesUntil(str(t['time']));
  return !(m >= 0 && m < cutoffMin);
}

List<Json> stopsOf(Json t) => asList(t['stops']).map(asMap).toList();

/// ئایا وێستگەیەک هی ئەم گەشتەیە (بۆ سەرنشین)
bool ownStop(Json t, Json st) => st['subIds'] == null || t['subId'] == null || asList(st['subIds']).contains(t['subId']);

/// شوێنی گەیشتنی سەرنشین خۆی (نەک کۆتا وێستگەی ڕۆتەکە)
String tripDest(Json t) {
  final stops = stopsOf(t);
  final own = stops.where((st) => st['kind'] == 'dropoff' && ownStop(t, st)).toList();
  if (own.isNotEmpty) return str(own.last['place']);
  return stops.isEmpty ? '' : str(stops.last['place']);
}

/// هاوڕێکانی تەکسی: تەنها ناوی یەکەم و ڕەگەز، بە ڕیزی سوارکردن
List<Json> coRiders(Json t) {
  if (t['runId'] == null) return const [];
  final out = <Json>[];
  var i = 0;
  for (final st in stopsOf(t).where((s) => s['kind'] == 'pickup')) {
    i++;
    for (final p in asList(st['parts']).map(asMap)) {
      out.add({
        'order': i,
        'mine': p['subId'] == t['subId'],
        'people': asList(p['people']).map(asMap).toList(),
        'absent': st['absent'] == true && asList(st['absentIds']).contains(p['subId']),
        'done': st['done'] == true,
      });
    }
  }
  return out;
}

int coRidersOthers(Json t) => coRiders(t).where((c) => c['mine'] != true).fold(0, (n, c) => n + (c['people'] as List).length);

/// کاتەکانی چوون و هاتنەوە بە دەق (fmt.schedule)
String fmtSchedule(Json x) {
  if (hasPerDay(x)) return tr('کاتی جیاواز بۆ هەر ڕۆژێک');
  final go = x['go'] as String?, back = x['back'] as String?;
  if ((go ?? '').isNotEmpty && (back ?? '').isNotEmpty) return tr('{0}، هاتنەوە {1}', [Fmt.clock(go), Fmt.clock(back)]);
  if ((go ?? '').isNotEmpty) return tr('{0}، تەنها چوون', [Fmt.clock(go)]);
  if ((back ?? '').isNotEmpty) return tr('تەنها هاتنەوە، {0}', [Fmt.clock(back)]);
  return '';
}

/// چەند ماوە (fmt.left)
String fmtLeft(num until) {
  final mins = ((until - DateTime.now().millisecondsSinceEpoch) / 60000).floor().clamp(0, 1 << 30);
  if (mins < 60) return Fmt.n(tr('{0} خولەک ماوە', [mins]));
  return Fmt.n(tr('{0} کاتژمێر ماوە', [mins ~/ 60]));
}
