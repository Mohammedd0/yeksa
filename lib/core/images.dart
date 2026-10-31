// وێنەکان (img/{id} لە Firestore، خانەی «d» = data URL). هەمان TK.img ـی core.js
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'cloud.dart';
import 'format.dart';

class ImageStore extends ChangeNotifier {
  ImageStore(this.cloud);
  final Cloud cloud;

  final Map<String, Uint8List> _cache = {};
  final Map<String, int> _tried = {};

  /// وێنەکە ئەگەر بار کرابێت، ئەگەر نا null و لە پشتەوە باری دەکات
  Uint8List? get(String? id) {
    if (id == null || id.isEmpty) return null;
    final v = _cache[id];
    if (v != null) return v;
    final last = _tried[id] ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last > 20000) {
      _tried[id] = now;
      _load(id);
    }
    return null;
  }

  /// وێنەیەکی نوێ: بۆ img/{id} دەنووسرێت و دەستبەجێ پیشان دەدرێت. pub = هەمووان دەیبینن (بۆ نموونە شۆفێرەکەت)
  Future<String> save(Uint8List jpeg, {bool pub = true}) async {
    final id = 'i${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${shortId()}';
    final url = Uri.dataFromBytes(jpeg, mimeType: 'image/jpeg').toString();
    _cache[id] = jpeg;
    notifyListeners();
    await cloud.set('img/$id', {'d': url, 'o': cloud.me, 'pub': pub, 'at': DateTime.now().millisecondsSinceEpoch});
    return id;
  }

  Future<void> remove(String? id) async {
    if (id == null || id.isEmpty) return;
    _cache.remove(id);
    try {
      await cloud.delete('img/$id');
    } catch (_) {}
  }

  Future<void> _load(String id) async {
    try {
      final d = await cloud.get('img/$id');
      final url = d?['d'];
      if (url is String && url.startsWith('data:')) {
        _cache[id] = UriData.parse(url).contentAsBytes();
        notifyListeners();
      }
    } catch (_) {
      // دەستمان پێی ناگات یان هێشتا بار نەکراوە
    }
  }
}

/// وێنەیەک لە img/{id}. تا بار دەبێت [placeholder] پیشان دەدرێت
class YkImage extends StatelessWidget {
  const YkImage(this.id, {super.key, this.fit = BoxFit.cover, this.placeholder, this.width, this.height});
  final String? id;
  final BoxFit fit;
  final Widget? placeholder;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    final bytes = context.watch<ImageStore>().get(id);
    if (bytes == null) return placeholder ?? SizedBox(width: width, height: height);
    return Image.memory(bytes, fit: fit, width: width, height: height, gaplessPlayback: true);
  }
}
