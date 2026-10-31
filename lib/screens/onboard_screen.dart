// ناساندنی سەرەتا (سێ پەڕە)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/settings.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';

class _Onb {
  const _Onb(this.title, this.sub, this.icon, this.pills);
  final String title, sub, icon;
  final List<List<String>> pills;
}

const _pages = [
  _Onb('تەکسی مانگانە بۆ هەموو خێزان', 'یەک جار بەشداری بکە. هەموو ڕۆژێک شۆفێرێکی ناسراو لەکاتی خۆیدا دێت.', 'calendar', [
    ['car', '٧:٣٠ بەیانی'],
    ['check', 'یەکشەممە تا پێنجشەممە'],
  ]),
  _Onb('بە لایڤ ببینە لە کوێیە', 'کاتێک منداڵەکەت سوار دەبێت و دەگات ئاگادار دەکرێیتەوە، و ڕێگاکە لەسەر نەخشە دەبینیت.', 'route', [
    ['bell', 'ئارام سوار بوو'],
    ['clock', '٥ خولەکی ماوە'],
  ]),
  _Onb('شۆفێری پشکنراو، پیاو و ئافرەت', 'هەموو شۆفێرەکان پشکنینی پێشینەیان بۆ کراوە. بۆ ئافرەتان و منداڵان شۆفێری ئافرەت هەیە.', 'shield', [
    ['woman', 'شۆفێری ئافرەت'],
    ['star', '٤.٩ هەڵسەنگاندن'],
  ]),
];

class OnboardScreen extends StatefulWidget {
  const OnboardScreen({super.key});
  @override
  State<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends State<OnboardScreen> {
  final _pc = PageController();
  int _i = 0;

  /// AuthGate خۆی دەچێتە پەڕەی چوونەژوورەوە
  void _finish() => context.read<LocalSettings>().setOnboarded();

  void _next() {
    if (_i < _pages.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [YkLink('تێپەڕاندن', onTap: _finish)]),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (c, i) => _page(c, _pages[i]),
                ),
              ),
              const SizedBox(height: 16),
              YkButton(_i < _pages.length - 1 ? 'دواتر' : 'دەست پێبکە', large: true, block: true, onPressed: _next),
            ],
          ),
        ),
      ),
    );
  }

  /// خاڵەکان لە ژێر نووسینەکەوە، وەک وەشانی وێب
  Widget _dots(BuildContext context) {
    final t = context.yk;
    return Row(
                children: [
                  for (var k = 0; k < _pages.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsetsDirectional.only(end: 5),
                      width: k == _i ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(color: k == _i ? t.act : t.line, borderRadius: BorderRadius.circular(3)),
                    ),
                ],
              );
  }

  Widget _page(BuildContext context, _Onb o) {
    final t = context.yk;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.card,
                border: Border.all(color: t.line),
                boxShadow: const [BoxShadow(color: Color(0x1210203F), blurRadius: 30, offset: Offset(0, 10))],
              ),
              alignment: Alignment.center,
              child: YkIcon(o.icon, size: 64, color: t.text, stroke: 1.4),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in o.pills)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: t.card, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    YkIcon(p[0], size: 15, color: t.brand, stroke: 2.2),
                    const SizedBox(width: 6),
                    Text(p[1], style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w700, color: t.text)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(o.title, style: Ts.h1(context)),
          const SizedBox(height: 6),
          Text(o.sub, style: Ts.muted(context)),
          const SizedBox(height: 14),
          _dots(context),
        ],
      ),
    );
  }
}
