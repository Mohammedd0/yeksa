// ڕاکێشان و لەرینەوەی پەڕە کورتەکان و ڕاکێشان بۆ نوێکردنەوە (تاچ)
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeksa/app.dart';
import 'package:yeksa/ui/theme.dart';
import 'package:yeksa/ui/widgets.dart';

const _k = ValueKey('top');
Widget _app(Widget screen) => MaterialApp(
      scrollBehavior: const YkScrollBehavior(),
      theme: buildTheme(Yk.light),
      home: Directionality(textDirection: TextDirection.rtl, child: screen),
    );

Future<void> _check(WidgetTester tester, Widget Function(Future<void> Function()) build) async {
  var refreshed = 0;
  await tester.pumpWidget(_app(build(() async => refreshed++)));
  await tester.pump();
  final y0 = tester.getTopLeft(find.byKey(_k)).dy;
  final g = await tester.startGesture(const Offset(200, 300), kind: PointerDeviceKind.touch);
  for (var i = 0; i < 20; i++) {
    await g.moveBy(const Offset(0, 15));
    await tester.pump(const Duration(milliseconds: 16));
  }
  final y1 = tester.getTopLeft(find.byKey(_k)).dy;
  expect(y1 - y0, greaterThan(40), reason: 'پەڕەکە لەگەڵ پەنجە نەهاتە خوارەوە (y0=$y0 y1=$y1)');
  expect(find.text('بەری بدە بۆ نوێکردنەوە'), findsOneWidget);
  await g.up();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  expect(refreshed, 1, reason: 'نوێکردنەوە نەکرا');
  expect(tester.getTopLeft(find.byKey(_k)).dy, closeTo(y0, 1), reason: 'نەگەڕایەوە شوێنی خۆی');
}

void main() {
  testWidgets('پەڕەی کورت', (t) async {
    await _check(t, (r) => Scaffold(body: YkScreen(onRefresh: r, children: const [KeyedSubtree(key: _k, child: YkHeader('سەردێڕ')), Text('یەک دێڕ')])));
  });
  testWidgets('پەڕەی بەتاڵ (YkEmpty)', (t) async {
    await _check(
        t,
        (r) => Scaffold(
            body: YkScreen(onRefresh: r, children: const [KeyedSubtree(key: _k, child: YkHeader('سەردێڕ')), YkEmpty(icon: 'megaphone', title: 'هیچ نییە')])));
  });
  testWidgets('پەڕەی ناو شریتی خوارەوە (withNav)', (t) async {
    await _check(
        t,
        (r) => Scaffold(
            extendBody: true,
            body: IndexedStack(index: 0, children: [
              YkScreen(withNav: true, title: 'سەرەتا', onRefresh: r, children: const [Text('سەرەتا', key: _k), Text('یەک')]),
              const SizedBox(),
            ])));
  });
}
