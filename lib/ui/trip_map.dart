// نەخشەی گەشت: Google Maps کاتێک شوێنی ڕاستەقینە هەیە، ئەگەرنا نەخشە وێنەییەکەی وەشانی وێب (ui.map)
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../core/cloud.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/live.dart';
import '../core/maps_status.dart';
import '../core/sel.dart';
import 'theme.dart';

const kAmber = Color(0xFFF5A623);
const kGreen = Color(0xFF22C55E);

// ڕەنگی نەخشە: ڕووناک (کەم ڕەنگ) و تاریک، هەمان maps.js
const String kMapStyleLight = '['
    '{"featureType":"poi","elementType":"labels.icon","stylers":[{"visibility":"off"}]},'
    '{"featureType":"poi.business","stylers":[{"visibility":"off"}]},'
    '{"featureType":"transit","stylers":[{"visibility":"off"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"lightness":20}]}]';
const String kMapStyleDark = '['
    '{"elementType":"geometry","stylers":[{"color":"#14213d"}]},'
    '{"elementType":"labels.text.fill","stylers":[{"color":"#9aa7c2"}]},'
    '{"elementType":"labels.text.stroke","stylers":[{"color":"#0b1733"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#22345c"}]},'
    '{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c4373"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#0b1733"}]},'
    '{"featureType":"poi","stylers":[{"visibility":"off"}]},'
    '{"featureType":"transit","stylers":[{"visibility":"off"}]}]';

LatLng ll(Geo g) => LatLng(g.lat, g.lng);

/* ---------------- ئایکۆنی سەر نەخشە (وێستگە و ئۆتۆمبێل) ---------------- */

final Map<String, BitmapDescriptor> _iconCache = {};

/// بازنەی وێستگە بە ژمارە یان بەتاڵ، کێشراو بە Canvas
Future<BitmapDescriptor> _circleIcon({
  required String key,
  required double r,
  required Color fill,
  required Color stroke,
  String label = '',
  Color text = const Color(0xFF0B1733),
  bool halo = false,
  bool car = false,
}) async {
  final hit = _iconCache[key];
  if (hit != null) return hit;
  const scale = 3.0;
  final pad = halo || car ? r * .55 : 3.0;
  final size = (r + pad) * 2;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, size * scale, size * scale))..scale(scale);
  final o = Offset(size / 2, size / 2);
  if (halo || car) c.drawCircle(o, r + pad - 1, Paint()..color = kAmber.withValues(alpha: .25));
  c.drawCircle(o, r, Paint()..color = fill);
  c.drawCircle(o, r, Paint()
    ..color = stroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = car ? 2.5 : 3);
  if (car) {
    // ئۆتۆمبێلێکی سادە: لاشە و دوو تایە
    final p = Paint()
      ..color = kAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = r * .95, h = r * .5;
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: o.translate(0, 1), width: w, height: h), const Radius.circular(3));
    c.drawRRect(body, p);
    final roof = Path()
      ..moveTo(o.dx - w * .32, o.dy - h * .5 + 1)
      ..lineTo(o.dx - w * .18, o.dy - h * 1.05)
      ..lineTo(o.dx + w * .18, o.dy - h * 1.05)
      ..lineTo(o.dx + w * .32, o.dy - h * .5 + 1);
    c.drawPath(roof, p);
    c.drawCircle(o.translate(-w * .28, h * .62), 1.6, Paint()..color = kAmber);
    c.drawCircle(o.translate(w * .28, h * .62), 1.6, Paint()..color = kAmber);
  } else if (label.isNotEmpty) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(fontSize: r * .95, fontWeight: FontWeight.w700, color: text, fontFamily: kFont)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }
  final img = await rec.endRecording().toImage((size * scale).round(), (size * scale).round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final d = BitmapDescriptor.bytes(bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), width: size, height: size);
  _iconCache[key] = d;
  return d;
}

/// نەخشەی گەشت
class TripMap extends StatelessWidget {
  const TripMap({super.key, required this.trip, this.height = 220, this.mine = true, this.live = false, this.radius = Yk.rMd});
  final Json trip;
  final double height;
  final bool mine;
  final bool live;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final car = cloud.carPos(trip);
    final stops = stopsOf(trip);
    final pts = <(int, Json, Geo)>[];
    for (var i = 0; i < stops.length; i++) {
      final g = cloud.stopGeo(trip, stops[i]);
      if (g != null) pts.add((i, stops[i], g));
    }
    final real = car != null || pts.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: MapsStatus.failed,
              builder: (_, failed, __) => real && !failed
                  ? _LiveMap(trip: trip, car: car, pts: pts, mine: mine, center: cloud.cityCenter)
                  : CustomPaint(painter: FakeMapPainter(trip: trip, t: t, mine: mine)),
            ),
          ),
          if (live)
            PositionedDirectional(
              top: 10,
              start: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(999), boxShadow: t.shadow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const _LiveDot(),
                  const SizedBox(width: 6),
                  Text(tr('لایڤ'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.text)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .35, end: 1.0).animate(_c),
        child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE5484D))),
      );
}

/// Google Maps بە وێستگەکان، ئۆتۆمبێل و هێڵی ڕێگا
class _LiveMap extends StatefulWidget {
  const _LiveMap({required this.trip, required this.car, required this.pts, required this.mine, required this.center});
  final Json trip;
  final Geo? car;
  final List<(int, Json, Geo)> pts;
  final bool mine;
  final Geo center;
  @override
  State<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<_LiveMap> {
  GoogleMapController? _ctrl;
  Set<Marker> _markers = {};
  bool _moved = false;
  int _fitN = -1;
  String _sig = '';
  int _gen = 0; // تەنها دوا نوێکردنەوە نەخشەکە دەگۆڕێت (ئایکۆنەکان بە ناڕێکی دروست دەکرێن)

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(covariant _LiveMap old) {
    super.didUpdateWidget(old);
    _build();
  }

  /// ئایکۆنەکان بە ناڕێکی دروست دەکرێن، پاشان نەخشەکە نوێ دەکرێتەوە
  Future<void> _build() async {
    final w = widget;
    final stops = stopsOf(w.trip);
    final many = stops.length > 2;
    final sig = '${w.pts.map((p) => '${p.$1}${p.$2['done']}${p.$3.lat}${p.$3.lng}').join('|')}|${w.car?.lat},${w.car?.lng}';
    if (sig == _sig) return;
    _sig = sig;
    final gen = ++_gen;
    final ms = <Marker>{};
    for (final (i, st, g) in w.pts) {
      final done = st['done'] == true;
      final own = ownStop(w.trip, st);
      final mineStop = (w.mine && own) || (!many && st['kind'] == 'dropoff');
      final fill = done ? kGreen : mineStop ? kAmber : Colors.white;
      final stroke = done || mineStop ? Colors.white : const Color(0xFF1C1C1E);
      final label = many ? Fmt.n(i + 1) : '';
      final r = many ? (mineStop ? 13.0 : 10.0) : (st['kind'] == 'dropoff' ? 10.0 : 8.0);
      final icon = await _circleIcon(
        key: 'st$label${fill.toARGB32()}$r${mineStop && !done}',
        r: r,
        fill: fill,
        stroke: stroke,
        label: label,
        halo: mineStop && !done,
      );
      ms.add(Marker(markerId: MarkerId('s$i'), position: ll(g), icon: icon, anchor: const Offset(.5, .5), consumeTapEvents: true));
    }
    if (w.car != null) {
      final icon = await _circleIcon(key: 'car', r: 15, fill: const Color(0xFF13254A), stroke: Colors.white, car: true);
      ms.add(Marker(markerId: const MarkerId('car'), position: ll(w.car!), icon: icon, anchor: const Offset(.5, .5)));
    }
    if (!mounted || gen != _gen) return;
    setState(() => _markers = ms);
    _fit();
  }

  /// نیشاندانی هەموو خاڵەکان (تەنها کاتێک ژمارەیان گۆڕا و بەکارهێنەر نەخشەکەی نەجووڵاندووە)
  void _fit() {
    final c = _ctrl;
    if (c == null || _moved) return;
    final all = [...widget.pts.map((p) => p.$3), if (widget.car != null) widget.car!];
    final n = all.length + (widget.car != null ? 100 : 0);
    if (all.isEmpty || n == _fitN) return;
    _fitN = n;
    if (all.length == 1) {
      _fitting = true;
      c.moveCamera(CameraUpdate.newLatLngZoom(ll(all.first), 15));
      return;
    }
    var s = all.first.lat, wst = all.first.lng, nth = all.first.lat, e = all.first.lng;
    for (final g in all) {
      s = math.min(s, g.lat);
      nth = math.max(nth, g.lat);
      wst = math.min(wst, g.lng);
      e = math.max(e, g.lng);
    }
    if (nth - s < 0.002 && e - wst < 0.002) {
      _fitting = true;
      c.moveCamera(CameraUpdate.newLatLngZoom(LatLng((s + nth) / 2, (wst + e) / 2), 15));
      return;
    }
    _fitting = true;
    c.moveCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(s, wst), northeast: LatLng(nth, e)), 48));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final dark = context.yk.dark;
    final active = w.trip['status'] == 'active';
    final rest = w.pts.where((p) => p.$2['done'] != true).map((p) => ll(p.$3)).toList();
    final path = [if (w.car != null && active) ll(w.car!), ...rest];
    final donePath = w.pts.where((p) => p.$2['done'] == true).map((p) => ll(p.$3)).toList();
    final first = w.car ?? (w.pts.isNotEmpty ? w.pts.first.$3 : w.center);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: ll(first), zoom: 13),
      style: dark ? kMapStyleDark : kMapStyleLight,
      markers: _markers,
      polylines: {
        if (path.length > 1)
          Polyline(
            polylineId: const PolylineId('route'),
            points: path,
            color: kAmber,
            width: 5,
            patterns: active ? const [] : [PatternItem.dash(14), PatternItem.gap(10)],
          ),
        if (donePath.length > 1) Polyline(polylineId: const PolylineId('done'), points: donePath, color: kGreen.withValues(alpha: .7), width: 4),
      },
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      buildingsEnabled: false,
      gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
      onMapCreated: (c) {
        _ctrl = c;
        Future.delayed(const Duration(milliseconds: 250), _fit);
      },
      onCameraMoveStarted: () {
        // تەنها جووڵاندنی بەکارهێنەر (نەک fit) ڕێگری لە fitی داهاتوو دەکات
        if (_fitN >= 0 && !_fitting) _moved = true;
      },
      onCameraIdle: () => _fitting = false,
    );
  }

  bool _fitting = true;
}

/// نەخشە وێنەییەکەی وەشانی وێب (کاتێک هیچ شوێنێکی ڕاستەقینە دیاری نەکراوە)
class FakeMapPainter extends CustomPainter {
  FakeMapPainter({required this.trip, required this.t, required this.mine});
  final Json? trip;
  final Yk t;
  final bool mine;

  static const _route = [Offset(70, 300), Offset(70, 190), Offset(180, 190), Offset(180, 80), Offset(320, 80)];
  static const _blocks = [
    [10, 10, 45, 60], [100, 10, 60, 55], [205, 10, 95, 55], [345, 10, 40, 55],
    [10, 100, 45, 70], [100, 100, 60, 70], [205, 100, 90, 70], [320, 100, 65, 70],
    [10, 210, 45, 70], [100, 210, 60, 70], [205, 210, 95, 70], [320, 210, 65, 70],
    [100, 315, 60, 50], [205, 315, 95, 50],
  ];

  Offset _at(double p) {
    final lens = <double>[];
    var total = 0.0;
    for (var i = 1; i < _route.length; i++) {
      final l = (_route[i] - _route[i - 1]).distance;
      lens.add(l);
      total += l;
    }
    var d = p.clamp(0.0, 1.0).toDouble() * total;
    for (var i = 0; i < lens.length; i++) {
      if (d <= lens[i]) return Offset.lerp(_route[i], _route[i + 1], lens[i] == 0 ? 0.0 : d / lens[i])!;
      d -= lens[i];
    }
    return _route.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dark = t.dark;
    final road = dark ? const Color(0xFF2E3440) : Colors.white;
    final bg = dark ? const Color(0xFF20252F) : const Color(0xFFEEF1F5);
    final park = dark ? const Color(0xFF24322A) : const Color(0xFFDCEFE2);
    // viewBox 0 10 390 320 بە شێوەی «slice»
    const vw = 390.0, vh = 320.0, vy = 10.0;
    final sc = math.max(size.width / vw, size.height / vh);
    canvas.save();
    canvas.translate((size.width - vw * sc) / 2, (size.height - vh * sc) / 2);
    canvas.scale(sc);
    canvas.translate(0, -vy);
    canvas.drawRect(const Rect.fromLTWH(-50, -50, 500, 460), Paint()..color = road);
    for (final b in _blocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(b[0].toDouble(), b[1].toDouble(), b[2].toDouble(), b[3].toDouble()), const Radius.circular(6)), Paint()..color = bg);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(215, 112, 70, 46), const Radius.circular(8)), Paint()..color = park);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(15, 220, 35, 50), const Radius.circular(6)), Paint()..color = park);
    final path = Path()..moveTo(_route.first.dx, _route.first.dy);
    for (final p in _route.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()
      ..color = kAmber.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
    final line = Paint()
      ..color = kAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final active = trip?['status'] == 'active';
    if (active) {
      canvas.drawPath(path, line);
    } else {
      for (final m in path.computeMetrics()) {
        var d = 0.0;
        while (d < m.length) {
          canvas.drawPath(m.extractPath(d, d + 8), line);
          d += 15;
        }
      }
    }
    final stops = trip == null ? <Json>[] : stopsOf(trip!);
    final n = stops.isEmpty ? 2 : stops.length;
    final done = stops.where((x) => x['done'] == true).length;
    final many = n > 2;
    for (var i = 0; i < n; i++) {
      final p = _at(i / math.max(1, n - 1));
      final st = stops.isEmpty ? null : stops[i];
      final isEnd = i == n - 1;
      final isDone = i < done;
      final mineStop = mine && st != null && trip != null && ownStop(trip!, st);
      final r = many ? (mineStop ? 13.0 : 10.0) : (isEnd ? 10.0 : 8.0);
      final fill = isDone ? kGreen : mineStop || (!many && isEnd) ? kAmber : t.card;
      final stroke = isDone || mineStop || (!many && isEnd) ? Colors.white : const Color(0xFF1C1C1E);
      if (mineStop && !isDone) canvas.drawCircle(p, r + 7, Paint()..color = kAmber.withValues(alpha: .25));
      canvas.drawCircle(p, r, Paint()..color = fill);
      canvas.drawCircle(p, r, Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      if (many) {
        final tp = TextPainter(
          text: TextSpan(text: Fmt.n(i + 1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDone || mineStop ? const Color(0xFF0B1733) : t.text, fontFamily: kFont)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }
    if (active && trip != null) {
      // شوێنی مەزەندەکراوی ئۆتۆمبێل بە پێی وێستگە تەواوبووەکان
      final seg = ((nowMs() - ((trip!['segmentStartedAt'] as num?) ?? nowMs())) / kSegmentMs).clamp(0.0, .92).toDouble();
      final prog = done == 0 ? 0.0 : math.min(1.0, (done - 1 + seg) / math.max(1, n - 1));
      final c = _at(prog);
      canvas.drawCircle(c, 20, Paint()..color = kAmber.withValues(alpha: .22));
      canvas.drawCircle(c, 15, Paint()..color = const Color(0xFF13254A));
      canvas.drawCircle(c, 15, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
      canvas.drawCircle(c, 5, Paint()..color = kAmber);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FakeMapPainter old) => true;
}

/// ماوەی نوێکردنەوەی شاشەی لایڤ (کاتی گەیشتن)
class LiveTicker extends StatefulWidget {
  const LiveTicker({super.key, required this.builder, this.every = const Duration(seconds: 20)});
  final WidgetBuilder builder;
  final Duration every;
  @override
  State<LiveTicker> createState() => _TickerState();
}

class _TickerState extends State<LiveTicker> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.every, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
