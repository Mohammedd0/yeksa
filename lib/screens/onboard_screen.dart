// ناساندنی سەرەتا (سێ پەڕە)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/settings.dart';
import '../ui/empty_art.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';

class _Onb {
  const _Onb(this.title, this.sub, this.icon, this.pills);
  final String title, sub, icon;
  final List<List<String>> pills;
}

// getter، بۆ ئەوەی لەگەڵ گۆڕینی زمان نوێ ببێتەوە
List<_Onb> get _pages => [
  _Onb(tr('تەکسی مانگانە بۆ هەموو خێزان'), tr('یەک جار بەشداری بکە. هەموو ڕۆژێک شۆفێرێکی ناسراو لەکاتی خۆیدا دێت.'), 'onbCal', [
    ['car', tr('٧:٣٠ بەیانی')],
    ['check', tr('یەکشەممە تا پێنجشەممە')],
  ]),
  _Onb(tr('بە لایڤ ببینە لە کوێیە'), tr('کاتێک منداڵەکەت سوار دەبێت و دەگات ئاگادار دەکرێیتەوە، و ڕێگاکە لەسەر نەخشە دەبینیت.'), 'onbLive', [
    ['bell', tr('ئارام سوار بوو')],
    ['clock', tr('٥ خولەکی ماوە')],
  ]),
  _Onb(tr('شۆفێری پشکنراو، پیاو و ئافرەت'), tr('هەموو شۆفێرەکان پشکنینی پێشینەیان بۆ کراوە. بۆ ئافرەتان و منداڵان شۆفێری ئافرەت هەیە.'), 'onbSafe', [
    ['woman', tr('شۆفێری ئافرەت')],
    ['star', tr('٤.٩ هەڵسەنگاندن')],
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
    final st = context.watch<LocalSettings>();
    final pages = _pages;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                // هەڵبژاردنی زمان پێش چوونەژوورەوە
                YkLangPill(value: st.lang, onChanged: st.setLang),
                const Spacer(),
                YkLink(tr('تێپەڕاندن'), onTap: _finish),
              ]),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _i = i),
                  itemBuilder: (c, i) => _page(c, pages[i]),
                ),
              ),
              const SizedBox(height: 16),
              YkButton(_i < pages.length - 1 ? tr('دواتر') : tr('دەست پێبکە'), large: true, block: true, onPressed: _next),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var k = 0; k < _pages.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
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
          const SizedBox(height: 72),
          // وێنەی خۆڵەمێشی (هەمان شێوازی پەڕە بەتاڵەکان)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: AspectRatio(
                aspectRatio: 220 / 180,
                child: SvgPicture.string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 180">${YkEmpty.art(kEmptyBg + (kEmptyArt[o.icon] ?? ''), t.dark)}</svg>'),
              ),
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
          Text(o.title, textAlign: TextAlign.center, style: Ts.h1(context)),
          const SizedBox(height: 6),
          Text(o.sub, textAlign: TextAlign.center, style: Ts.muted(context).copyWith(height: 1.8)),
          const SizedBox(height: 14),
          _dots(context),
        ],
      ),
    );
  }
}
