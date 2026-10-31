// ئەپی سەرنشین: ڕووکار، ئاڕاستەی ڕاست بۆ چەپ و دەروازەی چوونەژوورەوە
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/auth.dart';
import 'core/cloud.dart';
import 'core/settings.dart';
import 'core/web_safe_stub.dart' if (dart.library.js_interop) 'core/web_safe_web.dart';
import 'screens/login_screen.dart';
import 'screens/onboard_screen.dart';
import 'screens/shell.dart';
import 'ui/logo.dart';
import 'ui/theme.dart';

final double _webSafe = kIsWeb ? detectWebSafeBottom() : 0;

MediaQueryData _withWebSafe(MediaQueryData mq) {
  if (_webSafe <= 0 || mq.viewPadding.bottom > 0) return mq;
  // کاتێک کیبۆرد کراوەتەوە بۆشاییەکە پێویست نییە
  final pad = mq.viewInsets.bottom > 0 ? 0.0 : _webSafe;
  return mq.copyWith(
    padding: mq.padding.copyWith(bottom: pad),
    viewPadding: mq.viewPadding.copyWith(bottom: _webSafe),
  );
}

class YeksaApp extends StatelessWidget {
  const YeksaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<LocalSettings>();
    return MaterialApp(
      title: 'یەکسا',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const YkScrollBehavior(),
      theme: buildTheme(Yk.light),
      darkTheme: buildTheme(Yk.darkTheme),
      themeMode: st.themeMode,
      // کوردی (سۆرانی) بە ڕاست بۆ چەپ. Flutter وەرگێڕانی کوردی نییە، بۆیە دوگمە بنەڕەتییەکان بە عەرەبی دەبن
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            // قەبارەی نووسین لە ڕێکخستنەکانی ئەپەوە (لەگەڵ ڕێکخستنی مۆبایل)
            // لە وێبی ئایفۆن (شاشەی سەرەکی) بۆشایی هێڵی خوارەوە زیاد دەکرێت، وەک env(safe-area-inset-bottom)
            data: _withWebSafe(mq).copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * st.scale)),
            child: child!,
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}

/// بە پێی دۆخی چوونەژوورەوە: ناساندن، چوونەژوورەوە، یان ئەپەکە
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final st = context.watch<LocalSettings>();
    return ValueListenableBuilder<bool>(
      valueListenable: context.read<AuthService>().busy,
      builder: (context, busy, _) => _pick(cloud, st, busy),
    );
  }

  Widget _pick(Cloud cloud, LocalSettings st, bool busy) {
    Widget child;
    if (busy) {
      // لە کاتی چوونەژوورەوە یان تۆمارکردندا هەمان پەڕە دەمێنێتەوە
      child = const LoginScreen();
    } else if (!cloud.authKnown || (cloud.me != null && !cloud.ready)) {
      child = const _Splash();
    } else if (cloud.me == null) {
      child = st.onboarded ? const LoginScreen() : const OnboardScreen();
    } else {
      child = const Shell();
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child));
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: YLogo.big()));
  }
}

/// هەموو پەڕەکان وەک وێب و ئایفۆن سکرۆڵ دەبن: ئەگەر ناوەڕۆکیش کەم بێت، پەڕەکە
/// سەرو خوار دەکرێت و لە کۆتاییدا دەلەرێتەوە (لە جیاتی قفڵبوون)
class YkScrollBehavior extends MaterialScrollBehavior {
  const YkScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

  // لەرینەوەی ئایفۆن جێگەی بازنەی شینی ئەندرۆید دەگرێتەوە
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
