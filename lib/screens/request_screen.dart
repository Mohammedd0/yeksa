// داواکاری و نرخەکانی شۆفێران: هەڵبژاردن، هەڵوەشاندنەوە، بڵاوکردنەوە بۆ هەمووان
import 'dart:collection'; // firstOrNull / lastOrNull
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cloud.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/pricing.dart';
import '../core/request_actions.dart';
import '../core/sel.dart';
import '../ui/form_parts.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'drivers_screen.dart';
import 'nav.dart';
import 'subs_screen.dart' show requestStatus;

/// پرسیاری پشتڕاستکردنەوە (TK.ask)
Future<bool> askConfirm(BuildContext context, String text, {String? yes, bool danger = true}) async {
  final r = await showYkSheet<bool>(context, builder: (c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('دڵنیایت؟'), style: Ts.h2(c)),
      const SizedBox(height: 6),
      Text(text, style: Ts.muted(c, size: 15)),
      const SizedBox(height: 16),
      YkButton(yes ?? tr('بەڵێ'), block: true, kind: danger ? BtnKind.danger : BtnKind.primary, onPressed: () => Navigator.pop(c, true)),
      const SizedBox(height: 8),
      YkButton(tr('نەخێر'), block: true, kind: BtnKind.ghost, onPressed: () => Navigator.pop(c, false)),
    ]);
  });
  return r == true;
}

/// داشکاندنی بانگهێشت بۆ یەکەم بەشداری (تەنها پێش بەشداری کردن)
int refDealAmount(Cloud cloud, num price) {
  final r = cloud.refAsInvitee;
  if (r == null || r['status'] != 'joined' || cloud.config['refOn'] != true) return 0;
  return cloud.refAmount(price);
}

/// پێشنیاری یەکسا: باشترین هەڵسەنگاندن (٤.٥ یان زیاتر) کە هەرزانترینیشە، ئەگەرنا باشترین هەڵسەنگاندن
Json? recommendedOffer(Cloud cloud, List<Json> all) {
  if (all.length < 2) return null;
  num rating(Json o) => (cloud.driver(o['driverId'])?['rating'] as num?) ?? 0;
  final good = all.where((o) => rating(o) >= 4.5).toList()..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
  if (good.isNotEmpty) return good.first;
  final byRate = [...all]..sort((a, b) => rating(b).compareTo(rating(a)));
  return byRate.first;
}

/// پەسەندکردنی شۆفێر (pickOffer + confirmOffer)
Future<void> pickOffer(BuildContext context, String reqId, String driverId) async {
  final cloud = context.read<Cloud>();
  final r = cloud.request(reqId);
  final o = asList(r?['offers']).map(asMap).where((x) => x['driverId'] == driverId).firstOrNull;
  if (r == null || o == null || r['status'] != 'open') return;
  final d = cloud.driver(driverId) ?? {'name': tr('شۆفێر')};
  final price = o['price'] as num;
  final deal = refDealAmount(cloud, price);
  final ok = await showYkSheet<bool>(context, builder: (c) {
    final t = c.yk;
    Widget row(String k, Widget v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [Text(k, style: Ts.muted(c, size: 14)), const SizedBox(width: 10), Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: v))]),
        );
    Text b(String s, {double size = 15}) => Text(s, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w700, fontSize: size, color: t.text));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('پەسەندکردنی {0}', [str(d['name'])]), style: Ts.h2(c)),
      const SizedBox(height: 12),
      YkCard(
        child: Column(children: [
          row(tr('سەرنشین'), b(str(r['riderNames']))),
          row(tr('ڕێگا'), b('${str(r['from']).split('، ').first} ${L.rtl ? '←' : '→'} ${str(r['to']).split('، ').first}', size: 14)), // i18n-keep
          row(tr('کات'), b(fmtSchedule(r))),
          row(tr('ڕۆژەکان'), b(fmtDays(asList(r['days'])), size: 14)),
          const YkHr(),
          row(tr('نرخی مانگانە'), Text(Fmt.money(price), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, color: t.brand))),
          if (deal > 0) ...[
            row(tr('داشکاندنی بانگهێشتی هاوڕێ'), Text(Fmt.n(Fmt.group(-deal)), style: TextStyle(fontWeight: FontWeight.w700, color: t.okText))),
            row(
              tr('یەکەم مانگ'),
              Text.rich(TextSpan(children: [
                TextSpan(text: Fmt.n(Fmt.group(price)), style: TextStyle(decoration: TextDecoration.lineThrough, color: t.muted, fontWeight: FontWeight.w400)),
                TextSpan(text: '  ${Fmt.money(price - deal)}'),
              ]), style: TextStyle(fontWeight: FontWeight.w700, color: t.text)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Text(
        cloud.walletOn
            ? tr('پارەی مانگ پێش یەکەم گەشت لە جزدانەکەتەوە دەدرێت. دەتوانیت هەر کاتێک بەشدارییەکە ڕابگریت.')
            : tr('پارەدان لە کۆتایی هەر مانگێک لە ڕێگەی ئەپەوە دەبێت. دەتوانیت هەر کاتێک بەشدارییەکە ڕابگریت.'),
        style: Ts.muted(c, size: 12.8),
      ),
      const SizedBox(height: 14),
      YkButton(tr('پەسەندکردن و دەستپێکردن'), block: true, onPressed: () => Navigator.pop(c, true)),
      const SizedBox(height: 8),
      YkButton(tr('پاشگەزبوونەوە'), block: true, kind: BtnKind.ghost, onPressed: () => Navigator.pop(c, false)),
    ]);
  });
  if (ok != true || !context.mounted) return;
  final id = await cloud.chooseOffer(reqId, driverId);
  if (!context.mounted) return;
  if (id == null) {
    toast(context, tr('ئەم داواکارییە ئیتر کراوە نییە'));
    return;
  }
  toast(context, tr('بەشدارییەکەت چالاک کرا'));
  openLink(context, 'subs');
}

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key, required this.id});
  final String id;
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f, String msg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) toast(context, msg);
    } catch (_) {
      if (mounted) toast(context, tr('هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final r = cloud.request(widget.id);
    if (r == null) {
      return Scaffold(body: YkScreen(children: [YkHeader(tr('داواکاری')), YkEmpty(icon: 'megaphone', title: tr('نەدۆزرایەوە'))]));
    }
    final offers = asList(r['offers']).map(asMap).toList()..sort((a, b) => ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0));
    final pending = offers.where((o) => o['status'] == 'pending').toList();
    final chosen = offers.where((o) => o['status'] == 'chosen').firstOrNull;
    final all = r['target'] == 'all';
    final status = r['status'];
    final body = <Widget>[];
    if (status == 'open') {
      if (pending.isNotEmpty) {
        body.add(Row(children: [
          Expanded(child: Text(tr('ئەو شۆفێرانەی قبووڵیان کرد'), style: Ts.h3(context))),
          Text(tr('هەرزانترین لە سەرەوە'), style: Ts.muted(context, size: 12.8)),
        ]));
        final reco = recommendedOffer(cloud, pending);
        for (final o in pending) {
          body.add(OfferCard(r: r, o: o, all: pending, reco: reco != null && reco['driverId'] == o['driverId']));
        }
      } else {
        body.add(YkCard(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            IcoBox('hourglass', size: 64, iconSize: 32, bg: t.chip, color: t.muted),
            const SizedBox(height: 10),
            Text(tr('چاوەڕێی وەڵامی شۆفێرەکانین'), style: Ts.h3(context), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              all
                  ? tr('داواکارییەکەت بۆ هەموو شۆفێرە گونجاوەکان نیشان دراوە. کاتێک یەکێکیان قبووڵی بکات ئاگادار دەکرێیتەوە.')
                  : tr('داواکارییەکەت بۆ شۆفێرەکە نێردرا. کاتێک وەڵام بداتەوە ئاگادار دەکرێیتەوە.'),
              textAlign: TextAlign.center,
              style: Ts.muted(context, size: 14),
            ),
            const SizedBox(height: 10),
            const _Shimmer(),
          ]),
        ));
      }
      if (!all) {
        body.add(YkButton(tr('بڵاوکردنەوە بۆ هەموو شۆفێرەکان'),
            icon: 'megaphone',
            kind: BtnKind.secondary,
            block: true,
            busy: _busy,
            onPressed: () => _run(() => cloud.rebroadcast(widget.id), tr('بۆ هەموو شۆفێرەکان بڵاو کرایەوە'))));
      }
      body.add(YkButton(tr('هەڵوەشاندنەوەی داواکاری'), kind: BtnKind.ghost, block: true, onPressed: () async {
        if (!await askConfirm(context, tr('ئەم داواکارییە هەڵدەوەشێنرێتەوە.'), yes: tr('هەڵوەشاندنەوە'))) return;
        await _run(() => cloud.cancelRequest(widget.id), tr('داواکارییەکە هەڵوەشێنرایەوە'));
      }));
    } else if (status == 'matched' && chosen != null) {
      final d = cloud.driver(chosen['driverId']);
      body.add(YkCard(
        tone: CardTone.ok,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            YkIcon('check', size: 22, color: t.okText, stroke: 2.6),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('ڕێککەوتن لەگەڵ {0}', [str(d?['name'])]), style: Ts.bold(context).copyWith(color: t.okText))),
          ]),
          Builder(builder: (_) {
            final parts = tr('نرخی مانگانە: {0}. گەشتەکان لە بەشی سەرەکی دەردەکەون.').split('{0}');
            return Text.rich(TextSpan(children: [
              TextSpan(text: parts.first),
              TextSpan(text: Fmt.money(chosen['price'] as num), style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: parts.length > 1 ? parts[1] : ''),
            ]), style: TextStyle(fontSize: 14, color: t.okText));
          }),
        ]),
      ));
      if (d != null) body.add(DriverRow(d));
      body.add(YkButton(tr('بینینی بەشدارییەکان'), block: true, onPressed: () => openLink(context, 'subs')));
    } else {
      final why = r['closedReason'] == 'expired'
          ? tr('کاتی ئەم داواکارییە تەواو بوو و هیچ شۆفێرێک هەڵنەبژێردرا.')
          : r['closedReason'] == 'declined'
              ? tr('شۆفێرەکە نەیتوانی ئەم گەشتە وەربگرێت.')
              : tr('ئەم داواکارییە هەڵوەشێنرایەوە.');
      body.add(YkCard(tone: CardTone.danger, child: Text(why, style: TextStyle(fontSize: 14, color: t.dangerText))));
      body.add(YkButton(tr('دووبارە بڵاوکردنەوە بۆ هەمووان'),
          icon: 'megaphone', block: true, busy: _busy, onPressed: () => _run(() => cloud.rebroadcast(widget.id), tr('بۆ هەموو شۆفێرەکان بڵاو کرایەوە'))));
    }

    return Scaffold(
      body: YkScreen(children: [
        YkHeader(tr('داواکاری'), right: requestStatus(r)),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(str(r['riderNames']), style: Ts.bold(context))),
              if (r['createdAt'] is num) Text(Fmt.ago((r['createdAt'] as num).toInt()), style: Ts.muted(context, size: 12.8)),
            ]),
            RequestSummary(r),
            const SizedBox(height: 6),
            RequestTags(r),
            const YkHr(),
            Row(children: [
              Expanded(child: Text(tr('نرخی پێشنیارکراو'), style: Ts.muted(context, size: 14))),
              Text(Fmt.money((r['price'] as num?) ?? 0), style: TextStyle(fontWeight: FontWeight.w700, color: t.brand)),
            ]),
            if (status == 'open')
              Row(children: [
                Expanded(child: Text(all ? tr('بڵاوکراوە بۆ هەمووان') : tr('ڕاستەوخۆ بۆ {0}', [str(cloud.driver(r['target'])?['name'])]), style: Ts.muted(context, size: 14))),
                if (r['expiresAt'] is num) Text(fmtLeft(r['expiresAt'] as num), style: Ts.muted(context, size: 12.8)),
              ]),
            if (str(r['note']).isNotEmpty) IconLine('chat', trData(str(r['note']))),
          ]),
        ),
        ...body,
      ]),
    );
  }
}

/// کارتی نرخی شۆفێرێک (offerCard)
class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.r, required this.o, required this.all, this.reco = false});
  final Json r, o;
  final List<Json> all;
  final bool reco;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final did = str(o['driverId']);
    final d = cloud.driver(did) ?? {'id': did, 'name': tr('شۆفێر'), 'car': '', 'rating': 0, 'reviews': 0};
    final price = (o['price'] as num?) ?? 0;
    final diff = price - ((r['price'] as num?) ?? 0);
    num rating(Json x) => (cloud.driver(x['driverId'])?['rating'] as num?) ?? 0;
    final tags = <Widget>[
      if (all.length > 1 && price == all.map((x) => (x['price'] as num?) ?? 0).reduce((a, b) => a < b ? a : b)) YkBadge(tr('هەرزانترین'), tone: BadgeTone.ok),
      if (all.length > 1 && ((d['rating'] as num?) ?? 0) == all.map(rating).reduce((a, b) => a > b ? a : b)) YkBadge(tr('باشترین هەڵسەنگاندن'), tone: BadgeTone.note),
      if (d['woman'] == true) YkBadge(tr('شۆفێری ئافرەت'), tone: BadgeTone.woman),
    ];
    final deal = refDealAmount(cloud, price);
    void profile() => push(context, DriverScreen(id: did, reqId: str(r['id'])));
    final first = str(d['name']).split(' ').first;
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: EdgeInsets.fromLTRB(14, reco ? 22 : 14, 14, 14),
        decoration: BoxDecoration(
          color: t.glass,
          borderRadius: BorderRadius.circular(Yk.rLg),
          border: Border.all(color: reco ? t.act : t.glassLine, width: reco ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DriverHead(d, onTap: profile),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (deal > 0) ...[
                  Text.rich(TextSpan(children: [
                    TextSpan(text: Fmt.n(Fmt.group(price)), style: TextStyle(decoration: TextDecoration.lineThrough, color: t.muted, fontSize: 15, fontWeight: FontWeight.w400)),
                    TextSpan(text: ' ${Fmt.n(Fmt.group(price - deal))} '),
                    TextSpan(text: tr('دینار یەکەم مانگ'), style: TextStyle(fontSize: 12.8, color: t.muted, fontWeight: FontWeight.w400)),
                  ]), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.text)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    YkIcon('gift', size: 14, color: t.okText),
                    const SizedBox(width: 4),
                    Flexible(child: Text(tr('{0} داشکاندنی بانگهێشتی هاوڕێ، یەکەم مانگ', [Fmt.money(deal)]), style: TextStyle(fontSize: 12.8, color: t.okText))),
                  ]),
                ] else
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${Fmt.n(Fmt.group(price))} '),
                    TextSpan(text: tr('دینار مانگانە'), style: TextStyle(fontSize: 12.8, color: t.muted, fontWeight: FontWeight.w400)),
                  ]), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.text)),
                if (diff != 0)
                  Text(Fmt.n(diff < 0 ? tr('{0} کەمتر لە پێشنیارکراو', [Fmt.group(-diff)]) : tr('{0} زیاتر لە پێشنیارکراو', [Fmt.group(diff)])),
                      style: TextStyle(fontSize: 12.8, color: diff < 0 ? t.okText : t.dangerText))
                else
                  Text(tr('نرخی پێشنیارکراو'), style: Ts.muted(context, size: 12.8)),
              ]),
            ),
            Text(Fmt.n(tr('{0} گەشت', [d['trips'] ?? 0])), style: Ts.muted(context, size: 12.8)),
          ]),
          if (tags.isNotEmpty) ...[const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: tags)],
          if (str(o['note']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(12)),
              child: Text('«${str(o['note'])}»', style: Ts.sm(context)),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            YkButton(tr('پرۆفایل'), small: true, kind: BtnKind.secondary, onPressed: profile),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: tr('نامە'),
              child: InkWell(
                onTap: () => openLink(context, 'chat/$did'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 38,
                  decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.silverLine)),
                  alignment: Alignment.center,
                  child: YkIcon('chat', size: 16, color: t.silverText),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: YkButton(tr('هەڵبژاردنی {0}', [first]), icon: 'check', small: true, block: true, onPressed: () => pickOffer(context, str(r['id']), did))),
          ]),
        ]),
      ),
      if (reco)
        PositionedDirectional(
          top: -11,
          start: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: t.act, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              YkIcon('star', size: 13, color: t.amber, stroke: 1.5, fill: t.amber),
              const SizedBox(width: 4),
              Text(tr('پێشنیاری یەکسا'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.actText)),
            ]),
          ),
        ),
    ]);
  }
}

/// شوێنی چاوەڕێ (.skeleton)
class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return FadeTransition(
      opacity: Tween(begin: .45, end: 1.0).animate(_c),
      child: Container(height: 64, decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(16))),
    );
  }
}
