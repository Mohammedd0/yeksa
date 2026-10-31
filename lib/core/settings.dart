// ڕێکخستنەکانی ئەم ئامێرە (ڕووکار، قەبارەی نووسین، ژمارە). لە Firebase هەڵناگیرێن، تەنها لەسەر ئەم مۆبایلە.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';

class LocalSettings extends ChangeNotifier {
  static const _kTheme = 'yk.theme';
  static const _kScale = 'yk.textScale';
  static const _kDigits = 'yk.digits';
  static const _kOnboarded = 'yk.onboarded';
  static const _kNotify = 'yk.notify.';

  SharedPreferences? _p;

  /// 'auto' | 'light' | 'dark'
  String theme = 'auto';

  /// 'sm' | 'md' | 'lg'
  String textScale = 'md';

  /// 'ku' | 'en'
  String digits = 'ku';

  /// ناساندنی سەرەتا بینراوە
  bool onboarded = false;

  /// جۆرەکانی ئاگادارکردنەوە (settings.notify ی وێب): ride، pay، news
  final Map<String, bool> notify = {'ride': true, 'pay': true, 'news': true};

  Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
      theme = _p!.getString(_kTheme) ?? 'auto';
      textScale = _p!.getString(_kScale) ?? 'md';
      digits = _p!.getString(_kDigits) ?? 'ku';
      onboarded = _p!.getBool(_kOnboarded) ?? false;
      for (final k in notify.keys.toList()) {
        notify[k] = _p!.getBool('$_kNotify$k') ?? true;
      }
    } catch (_) {
      // بێ بیرگە (بۆ نموونە لە هەندێک وێبگەڕ): بنەڕەت دەمێنێتەوە
    }
    Fmt.digits = digits;
  }

  ThemeMode get themeMode => theme == 'dark'
      ? ThemeMode.dark
      : theme == 'light'
          ? ThemeMode.light
          : ThemeMode.system;

  /// هەمان قەبارەکانی وێب: ١٤.٥ / ١٦ / ١٧.٥ پیکسڵ
  double get scale => textScale == 'sm' ? 14.5 / 16 : textScale == 'lg' ? 17.5 / 16 : 1.0;

  void setTheme(String v) {
    theme = v;
    _p?.setString(_kTheme, v);
    notifyListeners();
  }

  void setTextScale(String v) {
    textScale = v;
    _p?.setString(_kScale, v);
    notifyListeners();
  }

  void setDigits(String v) {
    digits = v;
    Fmt.digits = v;
    _p?.setString(_kDigits, v);
    notifyListeners();
  }

  void toggleNotify(String k) {
    notify[k] = !(notify[k] ?? true);
    _p?.setBool('$_kNotify$k', notify[k]!);
    notifyListeners();
  }

  void setOnboarded() {
    onboarded = true;
    _p?.setBool(_kOnboarded, true);
    notifyListeners();
  }
}
