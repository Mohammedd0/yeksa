// ئاگادارکردنەوەکان: وەک فەیسبووک (نوێ، ئەمڕۆ، دوێنێ، پێشتر) بە چوار تاب
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/actions.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/sel.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'nav.dart';

/// ئایکۆن و ڕەنگی هەر جۆرێک (ui.noticeIcon)
(String, String) noticeIcon(Object? kind) {
  const m = {
    'ride': ('car', 'ok'), 'drop': ('check', 'ok'), 'swap': ('swap', ''), 'pay': ('wallet', 'info'), 'info': ('bell', 'navy'),
    'driver': ('route', ''), 'offer': ('tag', ''), 'chat': ('chat', 'info'), 'ok': ('check', 'ok'), 'self': ('check', 'navy'),
  };
  return m[kind] ?? ('bell', 'navy');
}

/// کاتی ئاگادارکردنەوە: ئێستا، ٥ خولەک، ٣ کاتژمێر، دوێنێ ٩:١٥ بەیانی، ٣ ڕۆژ، یان بەروار
String noticeWhen(int at) {
  final now = DateTime.now();
  final mins = (now.millisecondsSinceEpoch - at) ~/ 60000;
  final day0 = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  if (mins < 1) return tr('ئێستا');
  if (mins < 60) return Fmt.n(tr('{0} خولەک لەمەوبەر', [mins]));
  if (at >= day0) return Fmt.n(tr('{0} کاتژمێر لەمەوبەر', [mins ~/ 60]));
  if (at >= day0 - 86400000) return tr('دوێنێ، {0}', [Fmt.clock(Fmt.hhmm(at))]);
  final days = ((day0 - at) / 86400000).ceil();
  if (days < 7) return Fmt.n(tr('{0} ڕۆژ لەمەوبەر', [days]));
  return Fmt.date(at);
}

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  String _tab = 'all';
  late num _readAt;
  final Set<String> _opened = {};

  @override
  void initState() {
    super.initState();
    final cloud = context.read<Cloud>();
    // ئەوەی لە کاتی کردنەوەدا نوێ بوو، تا داخستنی پەڕەکە بە نوێ دەمێنێتەوە
    _readAt = cloud.readNoticesAt;
    if (cloud.unreadNotices > 0) {
      Future.delayed(const Duration(milliseconds: 400), () => cloud.markNoticesRead());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    const groups = {
      'trips': ['ride', 'drop', 'driver', 'swap'],
      'offers': ['offer', 'info'],
      'pay': ['pay'],
    };
    final all = cloud.myNotices;
    final list = groups[_tab] == null ? all : all.where((n) => groups[_tab]!.contains(n['kind'])).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final yest = today - 86400000;
    final g = <String, List<Json>>{'نوێ': [], 'ئەمڕۆ': [], 'دوێنێ': [], 'پێشتر': []}; // i18n-keep
    for (final n in list) {
      final at = ((n['at'] as num?) ?? 0).toInt();
      final fresh = at > _readAt && !_opened.contains(n['id']);
      g[fresh ? 'نوێ' : at >= today ? 'ئەمڕۆ' : at >= yest ? 'دوێنێ' : 'پێشتر']!.add(n); // i18n-keep
    }

    Widget row(Json n, bool fresh, int count) {
      final (ic, tone) = noticeIcon(n['kind']);
      final link = str(n['link']);
      final boxBg = tone == 'ok' ? t.okBg : t.silver;
      return Material(
        color: fresh ? t.infoBg : Colors.transparent,
        child: InkWell(
          onTap: link.isEmpty
              ? null
              : () {
                  setState(() => _opened.add(str(n['id'])));
                  openLink(context, link);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: boxBg, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: YkIcon(ic, size: 20, color: tone == 'ok' ? t.okText : t.act),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(Fmt.n(trData(str(n['title']))), style: Ts.bold(context).copyWith(fontSize: 15.2))),
                    // ئاگادارکردنەوەی وەک یەک کۆ دەکرێنەوە
                    if (count > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.silverLine)),
                        child: Text(Fmt.n('×$count'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.text)),
                      ),
                    ],
                  ]),
                  if (str(n['body']).isNotEmpty) Text(Fmt.n(trData(str(n['body']))), style: Ts.muted(context, size: 14)),
                  const SizedBox(height: 3),
                  Text(noticeWhen(((n['at'] as num?) ?? 0).toInt()),
                      style: TextStyle(fontSize: 12.8, color: fresh ? t.infoText : t.muted, fontWeight: fresh ? FontWeight.w700 : FontWeight.w400)),
                ]),
              ),
              if (fresh)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 14, end: 8),
                  child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: t.infoText)),
                ),
            ]),
          ),
        ),
      );
    }

    final body = <Widget>[];
    g.forEach((title, raw) {
      if (raw.isEmpty) return;
      // ئاگادارکردنەوەی هەمان ناونیشان و ناوەڕۆک لە یەک بەشدا یەک دێڕن (نوێترینیان)، لەگەڵ ژمارە
      final items = <Json>[];
      final counts = <int>[];
      final index = <String, int>{};
      for (final n in raw) {
        final key = '${n['kind']}|${n['title']}|${n['body']}|${n['link']}';
        final at = index[key];
        if (at == null) {
          index[key] = items.length;
          items.add(n);
          counts.add(1);
        } else {
          counts[at]++;
        }
      }
      body.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        child: Text(tr(title), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: t.text)),
      ));
      body.add(Container(
        decoration: BoxDecoration(color: t.glass, borderRadius: BorderRadius.circular(Yk.rLg), border: Border.all(color: t.glassLine)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
            row(items[i], title == 'نوێ', counts[i]), // i18n-keep
          ],
        ]),
      ));
    });

    return Scaffold(
      body: YkScreen(
        onRefresh: context.read<Cloud>().refresh,
        children: [
          YkHeader(tr('ئاگادارکردنەوەکان'),
              right: g['نوێ']!.isEmpty // i18n-keep
                  ? null
                  : YkLink(tr('هەمووی خوێندرایەوە'), pill: true, onTap: () {
                      cloud.markNoticesRead();
                      setState(() => _readAt = nowMs());
                    })),
          YkSeg<String>(
            options: [('all', tr('هەمووی')), ('trips', trc('گەشت', 'الرحلات', 'Trips')), ('offers', tr('داواکاری')), ('pay', trc('پارەدان', 'الدفع', 'Payments'))],
            value: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
          if (list.isEmpty)
            YkEmpty(icon: 'bell', title: tr('هیچ ئاگادارکردنەوەیەک نییە'), text: tr('کاتێک شتێکی نوێ ڕوو بدات لێرە دەردەکەوێت')),
          ...body,
        ],
      ),
    );
  }
}
