// شوێنی ئۆتۆمبێل و کاتی گەیشتن (TK.carPos، liveMinutes، sim ـی core.js و maps.js)
import 'dart:math' as math;

import 'cloud.dart';
import 'format.dart';
import 'pricing.dart';
import 'request_actions.dart';
import 'sel.dart';

const int kStaleMs = 3 * 60000; // شوێنی شۆفێر کە لەمە کۆنتر بێت پیشان نادرێت
const double kRoad = 1.35; // ڕێگای شار ≈ ١.٣٥ × هێڵی ڕاست
const double kKmh = 24; // خێرایی مامناوەندی ناو شار
const int kSegmentMs = 6 * 60000; // هەر بەشێکی ڕێگا نزیکەی ٦ خولەک (کاتێک شوێنی ڕاستەقینە نییە)
const int kDisplayMin = 6;

const Map<String, ({double lat, double lng})> kCityCenter = {
  'erbil': (lat: 36.1911, lng: 44.0092),
  'sulaimani': (lat: 35.5613, lng: 45.4304),
};

typedef Geo = ({double lat, double lng});

Geo? toGeo(Object? g) {
  if (!isGeo(g)) return null;
  final m = g as Map;
  return (lat: (m['lat'] as num).toDouble(), lng: (m['lng'] as num).toDouble());
}

double geoDist(Geo a, Geo b) => geoKm({'lat': a.lat, 'lng': a.lng}, {'lat': b.lat, 'lng': b.lng}) ?? 0;

/// شوێنی گەیشتنی سەرنشین خۆی (نەک کۆتا وێستگەی ڕۆتەکە)
int nextStopIndex(Json t) => stopsOf(t).indexWhere((x) => x['done'] != true);

extension YkLive on Cloud {
  Geo get cityCenter {
    final c = kCityCenter[str(passenger['city'])] ?? kCityCenter['erbil']!;
    return c;
  }

  /// شوێنی سوار بوون و گەیشتنی بەشدارییەک بە پێی ئاراستە
  ({Geo? from, Geo? to}) subGeo(Json? sub, String dir) {
    if (sub == null) return (from: null, to: null);
    final r = sub['reqId'] != null ? request(sub['reqId']) : null;
    final f = toGeo(sub['fromGeo']) ?? (r != null ? toGeo(placeGeo(r['fromId'])) : null);
    final t = toGeo(sub['toGeo']) ?? (r != null ? toGeo(placeGeo(r['toId'])) : null);
    return dir == 'back' ? (from: t, to: f) : (from: f, to: t);
  }

  /// شوێنی سەر نەخشەی وێستگەیەک (تەنها بۆ بەشدارییەکانی خۆی)
  Geo? stopGeo(Json t, Json st) {
    final ids = st['subIds'] is List ? asList(st['subIds']) : (t['subId'] != null ? [t['subId']] : const []);
    for (final id in ids) {
      final s = sub(id);
      if (s == null) continue;
      final g = subGeo(s, str(t['dir']));
      final x = st['kind'] == 'pickup' ? g.from : g.to;
      if (x != null) return x;
    }
    return null;
  }

  /// شوێنی ئێستای ئۆتۆمبێلی گەشتێک، ئەگەر نوێ بێت
  Geo? carPos(Json? t) {
    if (t == null || t['status'] != 'active') return null;
    final key = t['runId'] ?? t['id'];
    final l = doc('live/${t['driverId']}');
    if (l == null || l['run'] != key) return null;
    final now = nowMs();
    final rx = (l['_rx'] as num?) ?? 0;
    final at = (l['at'] as num?) ?? 0;
    if (now - rx > kStaleMs || (now - at).abs() > 30 * 60000 + kStaleMs) return null;
    return toGeo(l);
  }

  /// خولەکی ماوە لە شوێنی ڕاستەقینەی ئۆتۆمبێلەوە
  int? liveMinutes(Json t) {
    final car = carPos(t);
    if (car == null) return null;
    final stops = stopsOf(t);
    final pick = stops.indexWhere((st) => st['kind'] == 'pickup' && ownStop(t, st));
    var target = -1;
    for (var i = 0; i < stops.length; i++) {
      if (ownStop(t, stops[i])) target = i;
    }
    if (target < 0) target = stops.length - 1;
    final goal = pick >= 0 && stops[pick]['done'] != true ? pick : target;
    final next = nextStopIndex(t);
    if (next < 0 || goal < next) return null;
    if (stopGeo(t, stops[goal]) == null) return null;
    var km = 0.0;
    Geo prev = car;
    var unknown = 0, boards = 0;
    for (var i = next; i <= goal; i++) {
      final g = stopGeo(t, stops[i]);
      if (g != null) {
        km += geoDist(prev, g) * kRoad;
        prev = g;
      } else {
        unknown++;
      }
      if (i < goal) boards++;
    }
    final stopMin = (config['stopMin'] as num?) ?? 5;
    final mins = (km / kKmh) * 60 + boards * 1.5 + unknown * stopMin * 0.5;
    return math.max(1, mins.ceil());
  }

  /// خولەکی ماوە: پێش سوار بوون تا شۆفێر دەگاتە لات، دوای ئەوە تا گەیشتن
  int minutesLeft(Json t) {
    final live = liveMinutes(t);
    if (live != null) return live;
    final stops = stopsOf(t);
    final n = stops.length;
    final done = stops.where((x) => x['done'] == true).length;
    final pick = stops.indexWhere((st) => st['kind'] == 'pickup' && ownStop(t, st));
    var target = -1;
    for (var i = 0; i < n; i++) {
      if (ownStop(t, stops[i])) target = i;
    }
    if (target < 0) target = n - 1;
    final goal = pick >= 0 && stops[pick]['done'] != true ? pick : target;
    final now = nowMs();
    final started = (t['segmentStartedAt'] as num?) ?? now;
    final seg = ((now - started) / kSegmentMs).clamp(0.0, 0.92).toDouble();
    return math.max(1, ((goal - done + 1 - seg) * kDisplayMin).ceil());
  }

  /// ئایا سەرنشین هێشتا سوار نەبووە (شۆفێر بەرەو لای دێت)
  bool waiting(Json t) {
    final stops = stopsOf(t);
    final pick = stops.indexWhere((st) => st['kind'] == 'pickup' && ownStop(t, st));
    return pick >= 0 && stops[pick]['done'] != true;
  }

  /// کاتی گەیشتن «07:42»
  String eta(Json t) => Fmt.hhmm(nowMs() + minutesLeft(t) * 60000);

  /// چەند نامەی نەخوێندراو لە شۆفێرێکەوە
  int unreadFrom(Object? driverId) =>
      list('messages').where((m) => m['peer'] == me && m['driverId'] == driverId && m['fromDriver'] == true && m['readP'] != true).length;

  /// گەشتە تەواوبووەکانم (phistory)، نوێ لە سەرەوە
  List<Json> get myHistory {
    final l = list('phistory').where((h) => h['owner'] == me).toList();
    l.sort((a, b) => ((b['date'] as num?) ?? 0).compareTo((a['date'] as num?) ?? 0));
    return l;
  }
}
