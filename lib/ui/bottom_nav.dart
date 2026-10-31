// شریتی خوارەوە (.bottom-nav): شریتێکی خڕی سەرپێی وەک وەشانی وێب
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import 'theme.dart';
import 'yk_icon.dart';

class NavItem {
  const NavItem(this.icon, this.label, {this.badge = 0});
  final String icon;
  final String label;
  final int badge;
}

class YkBottomNav extends StatefulWidget {
  const YkBottomNav({super.key, required this.items, required this.index, required this.onTap, this.mini = false});
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  /// کاتێک بەکارهێنەر دێتە خوارەوە شریتەکە بچووک دەبێتەوە (html.nav-mini ی وێب)
  final bool mini;

  @override
  State<YkBottomNav> createState() => _YkBottomNavState();
}

class _YkBottomNavState extends State<YkBottomNav> {
  List<NavItem> get items => widget.items;
  int get index => widget.index;
  bool get mini => widget.mini;

  // خڕەی هەڵبژێردراو بە پەنجە ڕادەکێشرێت (وەک واتسئاپ / navFx ـی وێب)
  double? _dragX;
  int _hover = -1;

  static const _ease = Cubic(.2, .8, .2, 1);

  /// بۆشایی ژێر شریتەکە. لە ئایفۆنی بێ دوگمە (هێڵی خوارەوە ٣٤) وەک واتسئاپ نزیک لە خوارەوە
  /// دادەنرێت: ٢٠ پیکسڵ (بچووک: ١٦)، نەک ١٢ + ٣٤
  static double _gap(double base, double safe) => safe > 0 ? (safe - 26 + base).clamp(base, double.infinity) : base;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    // قەبارەی شوێنی شریتەکە نەگۆڕە، تا ناوەڕۆکی پەڕە لە کاتی بچووکبوونەوەدا نەجوڵێت
    return SizedBox(
      height: 72 + _gap(12, bottom),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: mini ? 1 : 0),
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 420),
        curve: _ease,
        builder: (context, k, _) => _bar(context, k, bottom),
      ),
    );
  }

  Widget _bar(BuildContext context, double k, double bottom) {
    final t = context.yk;
    final w = MediaQuery.of(context).size.width;
    double lerp(double a, double b) => a + (b - a) * k;
    final maxW = lerp((w - 24).clamp(0.0, 456.0), (w - 84).clamp(0.0, 380.0));
    final radius = lerp(36, 28);
    final bar = Container(
      height: lerp(72, 56),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: kIsWeb ? t.bg : t.nav,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.dark ? const Color(0x0FFFFFFF) : t.glassLine),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final n = items.length;
        final slot = box.maxWidth / n;
        final pillH = lerp(60, 44);
        final rtl = Directionality.of(context) == TextDirection.rtl;
        double leftOf(int i) => (rtl ? n - 1 - i : i) * slot;
        int nearest(double x) {
          final c = ((x + slot / 2) / slot).floor().clamp(0, n - 1);
          return rtl ? n - 1 - c : c;
        }

        void drag(double dx) {
          final x = (dx - slot / 2).clamp(0.0, box.maxWidth - slot);
          final h = nearest(x);
          if (h != _hover) {
            _hover = h;
            HapticFeedback.selectionClick();
          }
          setState(() => _dragX = x);
        }

        void end() {
          if (_dragX == null) return;
          final h = nearest(_dragX!);
          setState(() => _dragX = null);
          _hover = -1;
          if (h != index) widget.onTap(h);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => drag(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => drag(d.localPosition.dx),
          onHorizontalDragEnd: (_) => end(),
          onHorizontalDragCancel: end,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedPositioned(
              duration: _dragX != null || MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 400),
              curve: const Cubic(.3, 1.25, .4, 1),
              left: _dragX ?? leftOf(index),
              top: (box.maxHeight - pillH) / 2,
              width: slot,
              height: pillH,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: t.dark ? const Color(0x1FFFFFFF) : const Color(0x1713254A),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < n; i++) Expanded(child: _tab(context, i, k)),
            ]),
          ]),
        );
      }),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: _gap(lerp(12, 8), bottom)),
        child: SizedBox(
          width: maxW,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(color: t.dark ? const Color(0x59000000) : const Color(0x1A101828), blurRadius: t.dark ? 30 : 24, offset: Offset(0, t.dark ? 10 : 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              // تەڵخی پشت تەنها لە ئەپی ڕاستەقینە: لە وێبی Flutter (بەتایبەتی Safari) سکرۆڵ زۆر قورس دەکات
              child: kIsWeb ? bar : BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: bar),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i, double k) {
    double lerp(double a, double b) => a + (b - a) * k;
    final t = context.yk;
    final it = items[i];
    final on = i == index;
    return Semantics(
      selected: on,
      button: true,
      label: it.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!on) HapticFeedback.selectionClick();
          widget.onTap(i);
        },
        child: SizedBox(
          height: lerp(60, 44),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            // باکگراوندی هەڵبژێردراو لە خڕە جووڵاوەکەوە دێت
            color: Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: on ? 1.06 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: YkIcon(it.icon, size: lerp(25, 22), color: t.text, stroke: on ? 2.3 : 1.9),
                  ),
                  if (it.badge > 0)
                    Positioned(
                      top: lerp(-8, -6),
                      right: lerp(-15, -12),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.danger,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.bg, width: 2),
                        ),
                        child: Text(Fmt.n(it.badge), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, height: 1)),
                      ),
                    ),
                ],
              ),
              // ناوەکە لە شریتی بچووکدا ون دەبێت (.nl)
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 1 - k,
                  child: Opacity(
                    opacity: (1 - k * 1.9).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(it.label,
                          maxLines: 1,
                          style: TextStyle(fontSize: 12.2, height: 1.4, color: t.text, fontWeight: on ? FontWeight.w700 : FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
