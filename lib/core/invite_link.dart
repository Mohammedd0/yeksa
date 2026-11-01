// کۆدی بانگهێشت لە لینکی هاوبەش یان QR: https://…/yeksa/#/register?ref=CODE
// کاتی کردنەوەی ئەپ یەک جار دەخوێنرێتەوە و پەڕەی تۆمارکردن پێی دەکرێتەوە
import 'package:flutter/foundation.dart' show kIsWeb;

String? _pending;

/// پێش runApp بانگ دەکرێت، چونکە دوای ئەوە Flutter ناونیشانەکە دەگۆڕێت و بەشی دوای # ون دەبێت
void captureInviteRef() {
  if (kIsWeb) _pending = refFromUri(Uri.base);
}

/// کۆدەکە لە ناونیشانی وێب (لە دوای # یان لە ?ref=)
String? refFromUri(Uri u) {
  String? pick(Map<String, String> q) {
    final v = (q['ref'] ?? '').trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return v.isEmpty ? null : v;
  }

  final f = u.fragment;
  final i = f.indexOf('?');
  if (i >= 0) {
    try {
      final r = pick(Uri.splitQueryString(f.substring(i + 1)));
      if (r != null) return r;
    } catch (_) {}
  }
  return pick(u.queryParameters);
}

/// کۆدی چاوەڕوانکراو، تەنها یەک جار دەدرێتەوە
String? takePendingRef() {
  final r = _pending;
  _pending = null;
  return r;
}
