// پێکهاتەکانی سەرنشین: سەری شۆفێر، تابلۆ، بانەر و وێنەی هەواڵ، کاتی گەشت، ناوی هاوڕێکان
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/images.dart';
import '../core/sel.dart';
import 'theme.dart';
import 'widgets.dart';
import 'yk_icon.dart';

/* ---------------- ڕەنگی هەواڵ و بانەر (th-*) ---------------- */

({List<Color> colors, Color fg}) newsTheme(String? th) {
  switch (th) {
    case 'amber':
      return (colors: const [Color(0xFFF5A623), Color(0xFFF07F1B)], fg: const Color(0xFF0B1733));
    case 'violet':
      return (colors: const [Color(0xFF8B5CF6), Color(0xFF5B21B6)], fg: Colors.white);
    case 'blue':
      return (colors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)], fg: Colors.white);
    case 'green':
      return (colors: const [Color(0xFF22C55E), Color(0xFF15803D)], fg: Colors.white);
    case 'rose':
      return (colors: const [Color(0xFFF472B6), Color(0xFFBE185D)], fg: Colors.white);
    default:
      return (colors: const [Color(0xFF1C3566), Color(0xFF0B1733)], fg: Colors.white);
  }
}

LinearGradient newsGradient(String? th) =>
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: newsTheme(th).colors);

/// «10%» ← «١٠٪»؛ «50K» ← «٥٠» لەگەڵ «هەزار»ی بچووک
Widget bigText(Object? big, double size, Color color) {
  var t = Fmt.digits == 'en' ? '$big' : Fmt.n('$big').replaceAll('%', '٪');
  final m = RegExp(r'^(.*?)K$', caseSensitive: false).firstMatch(t);
  if (m != null) t = m.group(1)!;
  return Column(mainAxisSize: MainAxisSize.min, children: [
    Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, height: 1, color: color, letterSpacing: -1)),
    if (m != null) Text('هەزار', style: TextStyle(fontSize: size * .34, color: color, height: 1.4)),
  ]);
}

/// وێنەی بچووکی هەواڵ (ui.newsThumb)
class NewsThumb extends StatelessWidget {
  const NewsThumb(this.n, {super.key, this.size = 86});
  final Json n;
  final double size;
  @override
  Widget build(BuildContext context) {
    final th = newsTheme(n['theme'] as String?);
    return Container(
      width: size,
      constraints: BoxConstraints(minHeight: size),
      decoration: BoxDecoration(gradient: newsGradient(n['theme'] as String?), borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: n['big'] != null ? bigText(n['big'], size / 3.4, th.fg) : YkIcon(str(n['icon']), size: size / 2.3, color: th.fg, stroke: 1.6),
    );
  }
}

/// کارتی هەواڵ لە لیستەکان (.news-card)
class NewsCard extends StatelessWidget {
  const NewsCard(this.n, {super.key, required this.onTap, this.thumb = 86});
  final Json n;
  final VoidCallback onTap;
  final double thumb;
  @override
  Widget build(BuildContext context) {
    return YkCard(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          NewsThumb(n, size: thumb),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (str(n['tag']).isNotEmpty) YkBadge(str(n['tag']), tone: BadgeTone.note),
              const SizedBox(height: 4),
              Text(str(n['title']), style: Ts.bold(context).copyWith(fontSize: 15.2)),
              Text(str(n['sub']), style: Ts.muted(context, size: thumb < 80 ? 12.8 : 14)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// بانەری ڕێکلام (ui.banner)
class NewsBanner extends StatelessWidget {
  const NewsBanner(this.n, {super.key, required this.onTap, this.radius = Yk.rXl});
  final Json n;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final th = newsTheme(n['theme'] as String?);
    final img = str(n['image']);
    final hasImg = img.isNotEmpty && context.watch<ImageStore>().get(img) != null;
    final fg = hasImg ? Colors.white : th.fg;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(gradient: hasImg ? null : newsGradient(n['theme'] as String?)),
          child: Stack(fit: StackFit.expand, children: [
            if (hasImg) YkImage(img),
            if (hasImg && n['imageOnly'] != true)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0x9E000000), Color(0x0D000000)], stops: [0, .65]),
                ),
              ),
            if (!hasImg)
              Positioned(
                left: -6,
                bottom: -10,
                top: 0,
                width: 150,
                child: Center(
                  child: n['big'] != null
                      ? bigText(n['big'], 52, fg)
                      : Opacity(opacity: .9, child: YkIcon(str(n['icon']), size: 96, color: fg, stroke: 1.4)),
                ),
              ),
            if (!(hasImg && n['imageOnly'] == true))
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: hasImg ? MainAxisAlignment.end : MainAxisAlignment.center,
                  children: [
                    if (str(n['tag']).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: th.fg == Colors.white || hasImg ? const Color(0x47FFFFFF) : const Color(0x1F0B1733),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(str(n['tag']), style: TextStyle(color: fg, fontSize: 11.8, fontWeight: FontWeight.w700, height: 1.7)),
                      ),
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: hasImg ? .9 : .6,
                      child: Text(str(n['title']), style: TextStyle(color: fg, fontSize: 19.2, fontWeight: FontWeight.w700, height: 1.4)),
                    ),
                    FractionallySizedBox(
                      widthFactor: hasImg ? .9 : .6,
                      child: Text(str(n['sub']), style: TextStyle(color: fg.withValues(alpha: .92), fontSize: 13.8, height: 1.5)),
                    ),
                  ],
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// ڕێکلامەکانی سەرەوەی سەرەکی: بێ کۆتایی دەسوڕێنەوە (ui.carousel + bleed)
/// بانەری سەرەوەی سەرەکی: تەنها وێنە، بێ نووسین و بێ کلیک
class NewsCarousel extends StatefulWidget {
  const NewsCarousel({super.key, required this.items});
  final List<Json> items;
  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  static const _base = 10000;
  late final PageController _pc = PageController(initialPage: _base * (widget.items.isEmpty ? 1 : widget.items.length));
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pc.hasClients && widget.items.length > 1) {
        _pc.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final w = MediaQuery.of(context).size.width.clamp(0.0, 512.0);
    return Column(children: [
      SizedBox(
        height: 210,
        child: OverflowBox(
          minWidth: w,
          maxWidth: w,
          child: PageView.builder(
            controller: _pc,
            itemCount: items.length == 1 ? 1 : null,
            onPageChanged: (i) => setState(() => _page = i % items.length),
            itemBuilder: (c, i) {
              final n = items[i % items.length];
              return SizedBox.expand(child: YkImage(str(n['image']), fit: BoxFit.cover));
            },
          ),
        ),
      ),
      if (items.length > 1) ...[
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < items.length; k++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: k == _page ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(color: k == _page ? t.act : t.line, borderRadius: BorderRadius.circular(3)),
            ),
        ]),
      ],
    ]);
  }
}

/* ---------------- شۆفێر ---------------- */

/// تابلۆی ئۆتۆمبێل (ui.plate): لای IRQ KR سوور بۆ تەکسی، سپیی هێڵدار بۆ تایبەت
class Plate extends StatelessWidget {
  const Plate(this.plate, {super.key, this.type = 'taxi', this.small = false});
  final String plate;
  final String type;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final priv = type == 'private';
    final raw = plate.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}').trim();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF1C1C1E), width: 1.5), borderRadius: BorderRadius.circular(9)),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: small ? 5 : 6, vertical: small ? 3 : 4),
              decoration: BoxDecoration(
                color: priv ? const Color(0xFFEFF0F2) : const Color(0xFFE4262C),
                border: const Border(right: BorderSide(color: Color(0xFF1C1C1E), width: 1.5)),
              ),
              alignment: Alignment.center,
              child: Text('IRQ\nKR',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Arial', fontSize: small ? 8 : 10, height: 1.15, fontWeight: FontWeight.w700, color: priv ? const Color(0xFF1C1C1E) : Colors.white)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 4 : 6),
              child: Center(
                child: Text(raw, style: TextStyle(fontFamily: 'Arial', fontSize: small ? 13 : 16, fontWeight: FontWeight.w700, height: 1, color: const Color(0xFF111111), letterSpacing: .5)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ئاواتاری شۆفێر: چوارگۆشەی خڕ، نیشانەی پشکنراو (dh-av)
class DriverAvatar extends StatelessWidget {
  const DriverAvatar(this.d, {super.key, this.size = 54, this.radius = 16});
  final Json d;
  final double size, radius;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final woman = d['woman'] == true;
    final fallback = Container(
      color: woman ? const Color(0xFF7A2E5C) : t.silver,
      child: personSvg(woman ? Colors.white.withValues(alpha: .85) : t.personLine),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), border: woman ? null : Border.all(color: t.silverLine)),
            clipBehavior: Clip.antiAlias,
            child: YkImage(d['photo'] as String?, placeholder: fallback),
          ),
        ),
        if (d['status'] == 'active')
          Positioned(
            bottom: -3,
            right: -3,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.success, border: Border.all(color: t.card, width: 2.5)),
              alignment: Alignment.center,
              child: const YkIcon('check', size: 11, color: Colors.white, stroke: 3.2),
            ),
          ),
      ]),
    );
  }
}

String carText(Json d) {
  final mk = '${str(d['carMake'])} ${str(d['carModel'])}'.trim();
  return [mk.isNotEmpty ? mk : str(d['car']), str(d['carColor'])].where((x) => x.isNotEmpty).join(' · ');
}

/// سەری شۆفێر (dHead): وێنە، ناو، ئۆتۆمبێل، تابلۆ، هەڵسەنگاندن، پشکنراو
class DriverHead extends StatelessWidget {
  const DriverHead(this.d, {super.key, this.onTap, this.trailing});
  final Json d;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final row = Row(children: [
      DriverAvatar(d),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(str(d['name']), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.3, height: 1.35, color: t.text)),
          Text(carText(d), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.4, color: t.muted)),
          const SizedBox(height: 5),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (str(d['plate']).isNotEmpty) Plate(str(d['plate']), type: str(d['plateType']).isEmpty ? 'taxi' : str(d['plateType']), small: true),
            if (((d['reviews'] as num?) ?? 0) > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                YkIcon('star', size: 13, color: t.amber, stroke: 1.5, fill: t.amber),
                const SizedBox(width: 3),
                Text(Fmt.n(d['rating']), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.8, color: t.text)),
              ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: t.okBg, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                YkIcon('shield', size: 13, color: t.okText, stroke: 2.2),
                const SizedBox(width: 3),
                Text('پشکنراو', style: TextStyle(fontSize: 12.2, fontWeight: FontWeight.w700, color: t.okText)),
              ]),
            ),
          ]),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

/* ---------------- هاوڕێکانی تەکسی ---------------- */

/// ناوی یەکەم و ڕەگەز (pchip)
class PersonChip extends StatelessWidget {
  const PersonChip(this.p, {super.key});
  final Json p;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final w = p['w'];
    final kid = p['kid'] == 1 || p['kid'] == true;
    final sex = kid ? (w == 1 ? 'کچ' : w == 0 ? 'کوڕ' : 'منداڵ') : (w == 1 ? 'مێ' : w == 0 ? 'نێر' : '');
    final bg = w == 1 ? t.wBg : t.chip;
    final fg = w == 1 ? t.wText : t.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: str(p['n']), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (sex.isNotEmpty) TextSpan(text: ' $sex', style: TextStyle(color: fg.withValues(alpha: .7), fontSize: 11.5)),
        ]),
        style: TextStyle(fontSize: 13, color: fg),
      ),
    );
  }
}
