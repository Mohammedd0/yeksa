// لیستی شۆفێرەکان و پرۆفایلی شۆفێر (هەمان وەشانی وێب)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/cloud.dart';
import '../core/draft.dart';
import '../core/format.dart';
import '../core/images.dart';
import '../core/pricing.dart';
import '../core/sel.dart';
import '../ui/form_parts.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'nav.dart';
import 'new_sub_screen.dart';
import 'request_screen.dart' show pickOffer;

/// پەیوەندی تەلەفۆنی بە شۆفێر
Future<void> callPhone(String? phone) async {
  final p = str(phone).replaceAll(RegExp(r'\D'), '');
  if (p.isEmpty) return;
  await launchUrl(Uri.parse('tel:${p.startsWith('0') ? p : '0$p'}'));
}

/// کارتی شۆفێر لە لیست (driverRow)
class DriverRow extends StatelessWidget {
  const DriverRow(this.d, {super.key, this.action, this.reqId});
  final Json d;
  final Widget? action;
  final String? reqId;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final area = str(d['area']);
    return YkCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DriverHead(d, onTap: () => push(context, DriverScreen(id: str(d['id']), reqId: reqId)), trailing: YkIcon('forward', size: 18, color: t.muted)),
        if (d['woman'] == true || d['kidsDriver'] == true || area.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (d['woman'] == true) const YkBadge('شۆفێری ئافرەت', tone: BadgeTone.woman),
            if (d['kidsDriver'] == true) const YkBadge('شۆفێری منداڵان', tone: BadgeTone.note),
            if (area.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                YkIcon('pin', size: 14, color: t.muted),
                const SizedBox(width: 4),
                Text(area, style: Ts.muted(context, size: 12.8)),
              ]),
          ]),
        ],
        if (action != null) ...[const SizedBox(height: 10), action!],
      ]),
    );
  }
}

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});
  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  String _f = 'all';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final dr = DraftHolder.current;
    var list = cloud.drivers.where((d) => d['status'] == 'active').toList();
    if (dr != null) list = list.where((d) => cloud.fits(d, cloud.draftAsReq(dr))).toList();
    if (_f == 'woman') list = list.where((d) => d['woman'] == true).toList();
    if (_f == 'kids') list = list.where((d) => d['kidsDriver'] == true).toList();
    list.sort((a, b) => ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0));
    final all = list.length;
    final q = normalizeText(_q);
    if (q.isNotEmpty) {
      list = list.where((d) {
        final hay = [d['name'], d['car'], d['carMake'], d['carModel'], d['area'], d['woman'] == true ? 'ئافرەت' : '', d['kidsDriver'] == true ? 'منداڵ' : ''].map(str).join(' ');
        return normalizeText(hay).contains(q);
      }).toList();
    }
    return Scaffold(
      body: YkScreen(children: [
        YkHeader(dr != null ? 'هەڵبژاردنی شۆفێر' : 'شۆفێرەکان', sub: dr != null ? 'تەنها ئەو شۆفێرانەی بۆ گەشتەکەت دەگونجێن' : 'هەموو شۆفێرەکان پشکنراون'),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          autocorrect: false,
          decoration: ykInput(context,
              hint: 'گەڕان: ناو، ئۆتۆمبێل یان ناوچە', prefix: Padding(padding: const EdgeInsets.all(14), child: YkIcon('search', size: 20, color: context.yk.muted))),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in const [('all', 'هەمووی'), ('woman', 'شۆفێری ئافرەت'), ('kids', 'شۆفێری منداڵان')]) ...[
              YkChip(f.$2, on: _f == f.$1, onTap: () => setState(() => _f = f.$1)),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        if (all == 0)
          YkEmpty(
            icon: 'search',
            title: 'هیچ شۆفێرێکی گونجاو نییە',
            text: 'داواکارییەکەت بڵاو بکەرەوە، شۆفێری نوێ دەیبینن',
            button: dr != null ? YkButton('بڵاوکردنەوە', onPressed: () => broadcast(context)) : null,
          )
        else if (list.isEmpty)
          const YkEmpty(icon: 'search', title: 'هیچ شۆفێرێک نەدۆزرایەوە', text: 'وشەیەکی تر تاقی بکەرەوە'),
        for (final d in list)
          DriverRow(
            d,
            action: dr != null
                ? YkButton('ناردنی داواکاری بۆ ${str(d['name']).split(' ').first}',
                    icon: 'send', small: true, block: true, kind: BtnKind.secondary, onPressed: () => sendDirect(context, str(d['id'])))
                : null,
          ),
      ]),
    );
  }
}

/// پرۆفایلی شۆفێر
class DriverScreen extends StatelessWidget {
  const DriverScreen({super.key, required this.id, this.reqId});
  final String id;
  final String? reqId;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final d = cloud.driver(id);
    if (d == null) {
      return const Scaffold(body: YkScreen(children: [YkHeader('شۆفێر'), YkEmpty(icon: 'user', title: 'نەدۆزرایەوە')]));
    }
    final joined = d['joinedAt'] is num ? DateTime.fromMillisecondsSinceEpoch((d['joinedAt'] as num).toInt()) : null;
    final tags = asList(d['tags']).map(asMap).toList();
    final review = asMap(d['review']);
    Widget stat(String big, String small, {Color? color}) => Expanded(
          child: YkCard(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(children: [
              Text(Fmt.n(big), style: TextStyle(fontSize: 18.4, fontWeight: FontWeight.w700, color: color ?? t.text)),
              Text(small, style: Ts.muted(context, size: 12.8)),
            ]),
          ),
        );
    return Scaffold(
      body: YkScreen(children: [
        const YkHeader('پرۆفایلی شۆفێر'),
        if (str(d['phone']).isNotEmpty)
          InkWell(
            onTap: () => callPhone(str(d['phone'])),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
              child: Row(children: [
                YkIcon('phone', size: 16, color: t.muted),
                const SizedBox(width: 8),
                Expanded(child: Text('ژمارەی شۆفێر', style: Ts.sm(context))),
                Text(Fmt.phone(str(d['phone'])), textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w700, color: t.brand)),
              ]),
            ),
          ),
        YkCard(
          big: true,
          child: Column(children: [
            PersonAvatar(size: 84, imageId: str(d['photo']).isEmpty ? null : str(d['photo'])),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(str(d['name']), style: Ts.h2(context))),
              const SizedBox(width: 6),
              YkIcon('shield', size: 20, color: t.success, stroke: 2.2),
            ]),
            Text(carText(d), textAlign: TextAlign.center, style: Ts.muted(context, size: 14)),
            const SizedBox(height: 6),
            if (str(d['plate']).isNotEmpty) Plate(str(d['plate']), type: str(d['plateType']).isEmpty ? 'taxi' : str(d['plateType'])),
            const SizedBox(height: 8),
            Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
              const YkBadge('پشکنراو', tone: BadgeTone.ok),
              if (d['woman'] == true) const YkBadge('شۆفێری ئافرەت', tone: BadgeTone.woman),
              if (d['kidsDriver'] == true) const YkBadge('شۆفێری منداڵان', tone: BadgeTone.note),
              if (joined != null) YkBadge(Fmt.n('لەگەڵ یەکسا لە ${kMonths[joined.month - 1]}ی ${joined.year}ەوە')),
            ]),
          ]),
        ),
        Row(children: [
          stat('★ ${d['rating'] ?? 0}', Fmt.n('${d['reviews'] ?? 0} هەڵسەنگاندن'), color: t.brand),
          const SizedBox(width: 8),
          stat('${d['trips'] ?? 0}', 'گەشت'),
          const SizedBox(width: 8),
          stat('${d['onTime'] ?? 0}٪', 'لەکاتی خۆیدا'),
        ]),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            IconLine('pin', 'ناوچەکانی کار: ${str(d['area'])}'),
            IconLine('seat', Fmt.n('${d['seats'] ?? 4} کورسی بۆ سەرنشین')),
          ]),
        ),
        if (tags.isNotEmpty) ...[
          Text('سەرنشینەکان چی دەڵێن', style: Ts.h3(context)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final tg in tags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.line, width: 1.5)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${str(tg['label'])}، '),
                  TextSpan(text: Fmt.n(tg['count']), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]), style: Ts.sm(context)),
              ),
          ]),
        ],
        if (review.isNotEmpty)
          YkCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const PersonAvatar(size: 32),
                const SizedBox(width: 8),
                Expanded(child: Text(str(review['by']), style: Ts.sm(context).copyWith(fontWeight: FontWeight.w700))),
                Text(str(review['ago']), style: Ts.muted(context, size: 12.8)),
              ]),
              const SizedBox(height: 6),
              Text('«${str(review['text'])}»', style: Ts.sm(context)),
            ]),
          ),
        ..._actions(context, cloud, d),
        ..._carPhotos(context, d),
      ]),
    );
  }

  /// دوگمەکانی خوارەوە بە پێی دۆخ (profileActions)
  List<Widget> _actions(BuildContext context, Cloud cloud, Json d) {
    final t = context.yk;
    final first = str(d['name']).split(' ').first;
    final did = str(d['id']);
    final msg = Row(children: [
      Expanded(child: YkButton('نامە', icon: 'chat', kind: BtnKind.secondary, block: true, onPressed: () => openLink(context, 'chat/$did'))),
      const SizedBox(width: 10),
      Expanded(child: YkButton('پەیوەندی', icon: 'phone', kind: BtnKind.secondary, block: true, onPressed: () => callPhone(str(d['phone'])))),
    ]);
    // ئەگەر ئەم شۆفێرە نرخی بۆ یەکێک لە داواکارییەکانت ناردووە، ڕاستەوخۆ هەڵیبژێرە
    final offers = <(Json, Json)>[];
    for (final r in cloud.openRequests) {
      for (final o in asList(r['offers']).map(asMap)) {
        if (o['driverId'] == did && o['status'] == 'pending') offers.add((r, o));
      }
    }
    offers.sort((a, b) => a.$1['id'] == reqId ? -1 : b.$1['id'] == reqId ? 1 : 0);
    if (offers.isNotEmpty) {
      return [
        for (final (r, o) in offers)
          YkCard(
            tone: CardTone.note,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: '$first نرخی ناردووە بۆ '),
                TextSpan(text: '${str(r['riderNames'])}، ${str(r['to']).split('، ').first}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]), style: Ts.sm(context)),
              Row(children: [
                Expanded(child: Text(Fmt.money(o['price'] as num), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.brand))),
                Text('مانگانە', style: Ts.muted(context, size: 12.8)),
              ]),
              if (str(o['note']).isNotEmpty) Text('«${str(o['note'])}»', style: Ts.sm(context)),
              const SizedBox(height: 8),
              YkButton('هەڵبژاردنی $first', icon: 'check', block: true, onPressed: () => pickOffer(context, str(r['id']), did)),
            ]),
          ),
        msg,
      ];
    }
    final dr = DraftHolder.current;
    if (dr != null && dr.ready && dr.step == 3) {
      final ok = cloud.fits(d, cloud.draftAsReq(dr, did));
      return [
        YkButton('ناردنی داواکاری بۆ $first', icon: 'send', block: true, onPressed: ok ? () => sendDirect(context, did) : null),
        if (!ok) YkError('$first بۆ ئەم گەشتە ناگونجێت'),
        msg,
      ];
    }
    return [
      YkButton('بەشداری لەگەڵ $first', block: true, onPressed: () => startSub(context, prefDriver: did)),
      msg,
    ];
  }

  /// وێنەی ئۆتۆمبێل (پەنجەنان بە تەواوی شاشە دەیکاتەوە)
  List<Widget> _carPhotos(BuildContext context, Json d) {
    final ids = asList(d['showPhotos']).map(str).where((x) => x.isNotEmpty).toList();
    if (ids.isEmpty) return const [];
    final one = ids.length == 1;
    return [
      Text('ئۆتۆمبێلەکە', style: Ts.h3(context)),
      GridView.count(
        crossAxisCount: one ? 1 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: one ? 16 / 9 : 4 / 3,
        children: [
          for (var i = 0; i < ids.length; i++)
            GestureDetector(
              onTap: () => Navigator.of(context).push(PageRouteBuilder(
                opaque: false,
                barrierColor: Colors.black,
                pageBuilder: (_, __, ___) => _CarViewer(ids: ids, start: i),
                transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(fit: StackFit.expand, children: [
                  YkImage(ids[i], fit: BoxFit.cover),
                  const Positioned(bottom: 8, left: 8, child: YkIcon('eye', size: 16, color: Colors.white, stroke: 2.2)),
                ]),
              ),
            ),
        ],
      ),
    ];
  }
}

/// پیشاندانی وێنەی ئۆتۆمبێل بە تەواوی شاشە
class _CarViewer extends StatefulWidget {
  const _CarViewer({required this.ids, required this.start});
  final List<String> ids;
  final int start;
  @override
  State<_CarViewer> createState() => _CarViewerState();
}

class _CarViewerState extends State<_CarViewer> {
  late final PageController _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.ids.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          PageView.builder(
            controller: _pc,
            itemCount: n,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => InteractiveViewer(child: Center(child: YkImage(widget.ids[i], fit: BoxFit.contain))),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'داخستن',
              onPressed: () => Navigator.pop(context),
              icon: const YkIcon('x', size: 26, color: Colors.white, stroke: 2.4),
            ),
          ),
          if (n > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Text(Fmt.n('${_i + 1} / $n'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}
