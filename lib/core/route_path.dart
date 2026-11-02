// ڕێگای ڕاستەقینەی گەشت: پاشەکەوتکردن بە شێوازی «encoded polyline»ـی Google (کورت و بچووک)
// هەر خاڵێک [lat, lng]. ئەم فایلە لە هەردوو ئەپدا وەک یەکە.
import 'dart:math' as math;

/// خاڵەکان ← دەقێکی کورت (وردی ٥ ژمارە دوای خاڵ، نزیکەی ١ مەتر)
String encodePath(List<List<double>> pts) {
  final b = StringBuffer();
  var pLat = 0, pLng = 0;
  void enc(int v) {
    // نەک ~(v << 1): لە وێب (dart2js) ~ ژمارەی 32-bitـی بێ نیشانە دەداتەوە
    var s = v < 0 ? -2 * v - 1 : 2 * v;
    while (s >= 0x20) {
      b.writeCharCode((0x20 | (s & 0x1f)) + 63);
      s >>= 5;
    }
    b.writeCharCode(s + 63);
  }

  for (final p in pts) {
    final lat = (p[0] * 1e5).round(), lng = (p[1] * 1e5).round();
    enc(lat - pLat);
    enc(lng - pLng);
    pLat = lat;
    pLng = lng;
  }
  return b.toString();
}

/// دەقی کورت ← خاڵەکان
List<List<double>> decodePath(String? s) {
  final out = <List<double>>[];
  if (s == null || s.isEmpty) return out;
  var i = 0, lat = 0, lng = 0;
  int dec() {
    var shift = 0, res = 0, c = 0;
    do {
      c = s.codeUnitAt(i++) - 63;
      res |= (c & 0x1f) << shift;
      shift += 5;
    } while (c >= 0x20 && i < s.length);
    // ~(res >> 1) لە وێب هەڵەیە (ژمارەی گەورەی ئەرێنی)، بۆیە -(res >> 1) - 1
    return (res & 1) != 0 ? -(res >> 1) - 1 : (res >> 1);
  }

  try {
    while (i < s.length) {
      lat += dec();
      if (i >= s.length) break;
      lng += dec();
      out.add([lat / 1e5, lng / 1e5]);
    }
  } catch (_) {
    // دەقی تێکچوو: ئەوەی خوێندرایەوە دەگەڕێنرێتەوە
  }
  return out;
}

/// دووری نێوان دوو خاڵ بە مەتر
double pathMeters(List<double> a, List<double> b) {
  const r = 6371000.0;
  final dLat = (b[0] - a[0]) * math.pi / 180, dLng = (b[1] - a[1]) * math.pi / 180;
  final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a[0] * math.pi / 180) * math.cos(b[0] * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(x)));
}

/// کۆی دووری ڕێگا بە کیلۆمەتر (یەک ژمارە دوای خاڵ)
double pathKm(List<List<double>> pts) {
  var m = 0.0;
  for (var i = 1; i < pts.length; i++) {
    m += pathMeters(pts[i - 1], pts[i]);
  }
  return (m / 100).round() / 10;
}
