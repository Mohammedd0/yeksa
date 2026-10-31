// ڕاکێشانی خڕەی شریتی خوارەوە بە پەنجە
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeksa/ui/bottom_nav.dart';
import 'package:yeksa/ui/theme.dart';

void main() {
  testWidgets('خڕەی nav بە پەنجە ڕادەکێشرێت و تابەکە دەگۆڕێت', (t) async {
    t.view.physicalSize = const Size(375 * 2, 812 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    var picked = -1;
    var index = 0;
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(Yk.light),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (c, set) => Scaffold(
            bottomNavigationBar: YkBottomNav(
              index: index,
              mini: false,
              onTap: (i) => set(() {
                picked = i;
                index = i;
              }),
              items: const [
                NavItem('home', 'سەرەکی'),
                NavItem('route', 'گەشتەکان'),
                NavItem('calendar', 'بەشداری'),
                NavItem('chat', 'نامەکان'),
                NavItem('user', 'پرۆفایل'),
              ],
            ),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    final home = t.getCenter(find.text('سەرەکی'));
    final prof = t.getCenter(find.text('پرۆفایل'));
    final pill = find.byType(AnimatedPositioned);
    final x0 = t.getTopLeft(pill).dx;
    final g = await t.startGesture(home, kind: PointerDeviceKind.touch);
    for (var i = 1; i <= 20; i++) {
      await g.moveTo(Offset.lerp(home, prof, i / 20)!);
      await t.pump(const Duration(milliseconds: 16));
    }
    final x1 = t.getTopLeft(pill).dx;
    expect((x1 - x0).abs(), greaterThan(150), reason: 'خڕەکە لەگەڵ پەنجە نەجووڵا x0=$x0 x1=$x1');
    await g.up();
    await t.pumpAndSettle();
    expect(picked, 4);
  });
}
