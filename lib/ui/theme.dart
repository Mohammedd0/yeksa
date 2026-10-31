// ڕەنگ و قەبارەکانی یەکسا: هەمان tokens ـی shared/core.css (ڕووناک و تاریک)
// بۆ گۆڕینی ڕەنگی ئەپەکە تەنها لێرە دەستکاری بکە.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

@immutable
class Yk extends ThemeExtension<Yk> {
  const Yk({
    required this.dark,
    required this.bg,
    required this.card,
    required this.line,
    required this.chip,
    required this.text,
    required this.muted,
    required this.brand,
    required this.nav,
    required this.act,
    required this.actText,
    required this.silver,
    required this.silverLine,
    required this.silverText,
    required this.personLine,
    required this.amber,
    required this.success,
    required this.danger,
    required this.okBg,
    required this.okText,
    required this.dangerBg,
    required this.dangerText,
    required this.noteBg,
    required this.noteLine,
    required this.infoBg,
    required this.infoText,
    required this.wBg,
    required this.wText,
    required this.glass,
    required this.glassLine,
    required this.shadow,
  });

  final bool dark;
  final Color bg, card, line, chip, text, muted, brand, nav;
  final Color act, actText; // دوگمەی سەرەکی
  final Color silver, silverLine, silverText, personLine; // دوگمەی دووەم، سندوقی ئایکۆن، وێنەی کەس
  final Color amber, success, danger, okBg, okText, dangerBg, dangerText;
  final Color noteBg, noteLine, infoBg, infoText, wBg, wText;
  final Color glass, glassLine;
  final List<BoxShadow> shadow;

  // گۆشەی خڕ: --r-md، --r-lg، --r-xl
  static const double rMd = 18;
  static const double rLg = 24;
  static const double rXl = 28;

  static const light = Yk(
    dark: false,
    bg: Color(0xFFFFFFFF),
    card: Color(0xFFF7F8FA),
    line: Color(0xFFE6E8EC),
    chip: Color(0xFFF2F3F5),
    text: Color(0xFF101828),
    muted: Color(0xFF475467),
    brand: Color(0xFF1C1C1E),
    nav: Color(0xF0FFFFFF),
    act: Color(0xFF1C1C1E),
    actText: Color(0xFFFFFFFF),
    silver: Color(0xFFF2F2F4),
    silverLine: Color(0xFFE6E6EA),
    silverText: Color(0xFF1C1C1E),
    personLine: Color(0xFF6B7280),
    amber: Color(0xFFF5A623),
    success: Color(0xFF22C55E),
    danger: Color(0xFFD92D20),
    okBg: Color(0xFFDCFCE7),
    okText: Color(0xFF166534),
    dangerBg: Color(0xFFFEE4E2),
    dangerText: Color(0xFFB42318),
    noteBg: Color(0xFFFFF6E5),
    noteLine: Color(0xFFF5D9A3),
    infoBg: Color(0xFFE0ECFF),
    infoText: Color(0xFF1E40AF),
    wBg: Color(0xFFF3E8FF),
    wText: Color(0xFF6B21A8),
    glass: Color(0xFFF7F8FA),
    glassLine: Color(0xFFEEF0F3),
    shadow: [BoxShadow(color: Color(0x0F101828), blurRadius: 20, offset: Offset(0, 6))],
  );

  static const darkTheme = Yk(
    dark: true,
    bg: Color(0xFF16181D),
    card: Color(0xFF1F2228),
    line: Color(0xFF2C3038),
    chip: Color(0xFF262A31),
    text: Color(0xFFE4E7EC),
    muted: Color(0xFF9AA3B2),
    brand: Color(0xFFE4E7EC),
    nav: Color(0xF01F2228),
    act: Color(0xFFF2F2F7),
    actText: Color(0xFF1C1C1E),
    silver: Color(0x14FFFFFF),
    silverLine: Color(0x0FFFFFFF),
    silverText: Color(0xFFE4E7EC),
    personLine: Color(0xFF9AA3B2),
    amber: Color(0xFFF0A929),
    success: Color(0xFF22C55E),
    danger: Color(0xFFE8857D),
    okBg: Color(0xFF1D3A2D),
    okText: Color(0xFF75E0A7),
    dangerBg: Color(0xFF3B2427),
    dangerText: Color(0xFFF1A9A2),
    noteBg: Color(0xFF2D291E),
    noteLine: Color(0xFF574A25),
    infoBg: Color(0xFF1F2B40),
    infoText: Color(0xFFB4C8F0),
    wBg: Color(0xFF33283F),
    wText: Color(0xFFE9D5FF),
    glass: Color(0xFF1F2228),
    glassLine: Color(0xFF2C3038),
    shadow: [BoxShadow(color: Color(0x38000000), blurRadius: 18, offset: Offset(0, 6))],
  );

  @override
  Yk copyWith() => this;

  @override
  Yk lerp(ThemeExtension<Yk>? other, double t) => t < .5 ? this : (other as Yk? ?? this);
}

extension YkContext on BuildContext {
  Yk get yk => Theme.of(this).extension<Yk>() ?? Yk.light;
}

const String kFont = 'NotoNaskhArabic';

ThemeData buildTheme(Yk t) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: t.dark ? Brightness.dark : Brightness.light,
    fontFamily: kFont,
    scaffoldBackgroundColor: t.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.act,
      brightness: t.dark ? Brightness.dark : Brightness.light,
      surface: t.bg,
      primary: t.act,
      onPrimary: t.actText,
      error: t.danger,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [t],
  );
  return base.copyWith(
    // line-height: 1.6 وەک وێب
    textTheme: base.textTheme.apply(bodyColor: t.text, displayColor: t.text, fontFamily: kFont).copyWith(
          bodyMedium: TextStyle(fontSize: 16, height: 1.6, color: t.text, fontFamily: kFont),
        ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      // هەستی ئایفۆن: پەڕەی نوێ لە لاوە دێت و بە ڕاکێشانی پەنجە دەگەڕێتەوە
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    }),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.act,
      contentTextStyle: TextStyle(color: t.actText, fontFamily: kFont, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Yk.rXl))),
    ),
  );
}

/// ستایلە باوەکانی نووسین (h1، h2، sm، xs، muted)
class Ts {
  static TextStyle h1(BuildContext c) => TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.4, color: c.yk.text);
  static TextStyle h2(BuildContext c) => TextStyle(fontSize: 19.2, fontWeight: FontWeight.w700, height: 1.45, color: c.yk.text);
  static TextStyle h3(BuildContext c) => TextStyle(fontSize: 16.3, fontWeight: FontWeight.w700, color: c.yk.text);
  static TextStyle body(BuildContext c) => TextStyle(fontSize: 16, height: 1.6, color: c.yk.text);
  static TextStyle bold(BuildContext c) => TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w700, color: c.yk.text);
  static TextStyle sm(BuildContext c) => TextStyle(fontSize: 14, height: 1.6, color: c.yk.text);
  static TextStyle xs(BuildContext c) => TextStyle(fontSize: 12.8, height: 1.6, color: c.yk.text);
  static TextStyle muted(BuildContext c, {double size = 16}) => TextStyle(fontSize: size, height: 1.6, color: c.yk.muted);
}
