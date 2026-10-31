// بەشدارییەکان: داواکارییە کراوەکان و کارتی هەر بەشدارییەک (شێوازی D)، و لیستی داواکارییەکانم
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/billing.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/sel.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'nav.dart';
import 'sub_actions.dart';

class SubsScreen extends StatelessWidget {
  const SubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final open = cloud.openRequests;
    final subs = cloud.mySubs;
    return YkScreen(
      withNav: true,
      title: 'بەشدارییەکان',
      onRefresh: context.read<Cloud>().refresh,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('بەشدارییەکان', style: Ts.h1(context)),
          YkButton('نوێ', icon: 'plus', small: true, onPressed: () => openLink(context, 'new')),
        ]),
        if (open.isNotEmpty) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('داواکارییە کراوەکان', style: Ts.h3(context).copyWith(fontSize: 16)),
            YkLink('هەمووی', pill: true, onTap: () => push(context, const RequestsScreen())),
          ]),
          for (final r in open) RequestCard(r),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('بەشدارییە چالاکەکان', style: Ts.h3(context).copyWith(fontSize: 16)),
          if (subs.isNotEmpty) CountPill(Fmt.n(subs.length), section: true),
        ]),
        if (subs.isEmpty)
          YkEmpty(
            icon: 'calendar',
            title: 'هێشتا هیچ بەشدارییەکت نییە',
            text: 'شوێن و کات دیاری بکە و شۆفێرەکان نرخت بۆ دەنێرن',
            button: YkButton('یەکەم بەشداری', onPressed: () => openLink(context, 'new')),
          ),
        for (var i = 0; i < subs.length; i++) ...[
          if (subs.length > 1) _SubSection(index: i, total: subs.length, names: Fmt.names(cloud.names(asList(subs[i]['memberIds'])))),
          SubCard(subs[i]),
        ],
        // گەڕان بەناو شۆفێرەکاندا (.sfind)
        GestureDetector(
          onTap: () => openLink(context, 'drivers'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.glass, borderRadius: BorderRadius.circular(26), border: Border.all(color: t.glassLine)),
            child: Row(children: [
              // ئایکۆن لە چوارگۆشەیەکی زیوی (.sf-ic)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.silverLine)),
                alignment: Alignment.center,
                child: YkIcon('search', size: 24, color: t.act, stroke: 2.4),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('گەڕان بەناو شۆفێرەکاندا', style: Ts.bold(context).copyWith(fontSize: 16.8)),
                  Text('دۆزینەوەی شۆفێری نوێ بەپێی گەڕەک و کاتەکەت', style: Ts.muted(context, size: 13.1)),
                ]),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: YkIcon('forward', size: 18, color: t.muted),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SubSection extends StatelessWidget {
  const _SubSection({required this.index, required this.total, required this.names});
  final int index, total;
  final String names;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: LayoutBuilder(builder: (context, box) => Row(children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: t.act, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(Fmt.n(index + 1), style: TextStyle(color: t.actText, fontSize: 12, fontWeight: FontWeight.w700, height: 1)),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * .45),
          child: Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: t.text, fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: t.silverLine)),
        const SizedBox(width: 8),
        Text(Fmt.n('بەشداری ${index + 1} لە $total'), style: Ts.muted(context, size: 12.8)),
      ])),
    );
  }
}

/// کارتی بەشداری: ڕێگای گەشت، شۆفێر، نرخ و کردارەکان
class SubCard extends StatefulWidget {
  const SubCard(this.sub, {super.key});
  final Json sub;
  @override
  State<SubCard> createState() => _SubCardState();
}

class _SubCardState extends State<SubCard> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final sub = widget.sub;
    final d = cloud.driver(sub['driverId']) ?? const <String, dynamic>{};
    final ids = asList(sub['memberIds']);
    final names = cloud.names(ids);
    final paused = sub['status'] == 'paused';
    final per = hasPerDay(sub);
    String place(Object? x) => str(x).split('، ').first;

    Widget timeChip(Object? tm, String k) {
      if (per) return const SizedBox.shrink();
      final s = str(tm);
      if (s.isEmpty) {
        // .ds-t.off: هەمان چوارگۆشەی زیوی، نووسینی کاڵ
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
          decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(12)),
          child: Text(k == 'چوون' ? 'بێ چوون' : 'بێ هاتنەوە', style: TextStyle(fontSize: 12.5, color: t.muted, fontWeight: FontWeight.w600)),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
        decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(12)),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$k ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.muted)),
            TextSpan(text: Fmt.clock(s)),
          ]),
          style: TextStyle(fontSize: 14.7, fontWeight: FontWeight.w700, color: t.silverText),
        ),
      );
    }

    Widget dot(bool end) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle, color: end ? t.act : t.card, border: Border.all(color: t.act, width: 3)),
        );

    return Opacity(
      opacity: paused ? .75 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.glass, borderRadius: BorderRadius.circular(Yk.rXl), border: Border.all(color: t.glassLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // سەرەوە: ئەندامان، ڕۆژەکان، دۆخ
          Row(children: [
            PersonAvatar(size: 52, imageId: ids.isEmpty ? null : cloud.memberPhoto(ids.first)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Fmt.names(names), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17.3, fontWeight: FontWeight.w700, color: t.text)),
                Text(fmtDays(asList(sub['days'])), style: Ts.muted(context, size: 12.8)),
              ]),
            ),
            // جزدان: ئەگەر پارەی ئەم مانگە نەدرابێت «چاوەڕێی پارەدانە» و دەچێتە پارەدانی مانگ
            if (!paused && cloud.walletOn && !cloud.subPaid(sub))
              GestureDetector(onTap: () => openLink(context, 'paymonth'), child: const _StateBadge(paused: false, due: true))
            else
              _StateBadge(paused: paused),
          ]),
          const SizedBox(height: 14),
          // ڕێگا: دەستپێک ← مەبەست
          Row(children: [
            SizedBox(width: 16, child: Center(child: dot(false))),
            const SizedBox(width: 12),
            Expanded(child: Text(place(sub['from']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.7, fontWeight: FontWeight.w700, color: t.text))),
            timeChip(sub['go'], 'چوون'),
          ]),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 16,
              height: 22,
              child: Center(child: CustomPaint(size: const Size(2, 22), painter: _DashPainter(t.dark ? t.silverLine : const Color(0xFFC9CFD9)))),
            ),
          ),
          Row(children: [
            SizedBox(width: 16, child: Center(child: dot(true))),
            const SizedBox(width: 12),
            Expanded(child: Text(place(sub['to']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.7, fontWeight: FontWeight.w700, color: t.text))),
            timeChip(sub['back'], 'هاتنەوە'),
          ]),
          if (per) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                YkIcon('calendar', size: 16, color: t.text, stroke: 2),
                const SizedBox(width: 8),
                Text('کاتی جیاواز بۆ هەر ڕۆژێک', style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: t.text)),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: t.silverLine),
          InkWell(
            onTap: () => setState(() => _more = !_more),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                YkIcon('doc', size: 16, color: t.muted, stroke: 2),
                const SizedBox(width: 8),
                Expanded(child: Text('وردەکاری زیاتر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.muted))),
                AnimatedRotation(turns: _more ? .5 : 0, duration: const Duration(milliseconds: 200), child: YkIcon('down', size: 16, color: t.muted, stroke: 2.4)),
              ]),
            ),
          ),
          if (_more) _SubDetails(sub: sub),
          const SizedBox(height: 4),
          // شۆفێر
          GestureDetector(
            onTap: () => openLink(context, 'driver/${d['id']}'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.glassLine)),
              child: Row(children: [
                DriverAvatar(d, size: 56, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(str(d['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.bold(context))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          YkIcon('star', size: 13, color: t.amber, stroke: 1.5, fill: t.amber),
                          const SizedBox(width: 3),
                          Text(Fmt.n(((d['reviews'] as num?) ?? 0) > 0 ? ((d['rating'] as num?) ?? 0).toStringAsFixed(1) : '0.0'),
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: t.text)),
                        ]),
                      ),
                    ]),
                    _CarLine(d),
                  ]),
                ),
                if (str(d['plate']).isNotEmpty) Plate(str(d['plate']), type: str(d['plateType']).isEmpty ? 'taxi' : str(d['plateType']), small: true),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          // نرخ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.dark ? const Color(0x14FFFFFF) : t.act,
              borderRadius: BorderRadius.circular(18),
              boxShadow: t.dark ? null : const [BoxShadow(color: Color(0x291C1C1E), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('نرخی مانگانە', style: TextStyle(color: t.dark ? const Color(0xFFF2F4F7) : t.actText, fontWeight: FontWeight.w700)),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: Fmt.n(Fmt.group((sub['price'] as num?) ?? 0))),
                  const TextSpan(text: ' دینار', style: TextStyle(fontSize: 12.8)),
                ]),
                style: TextStyle(color: t.dark ? const Color(0xFFF2F4F7) : t.actText, fontWeight: FontWeight.w700, fontSize: 20),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _ActBtn(icon: paused ? 'play' : 'pause', label: paused ? 'دەستپێکردنەوە' : 'ڕاگرتنی کاتی', onTap: () => pauseSub(context, str(sub['id'])))),
            const SizedBox(width: 8),
            Expanded(child: _ActBtn(icon: 'sliders', label: 'گۆڕانکاری', onTap: () => editSub(context, str(sub['id'])))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => openLink(context, 'chat/${d['id']}'),
              child: Container(
                width: 56,
                height: 52,
                decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.silverLine)),
                alignment: Alignment.center,
                child: YkIcon('chat', size: 22, color: t.act, stroke: 2.2),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  const _ActBtn({required this.icon, required this.label, required this.onTap});
  final String icon, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.silverLine)),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          YkIcon(icon, size: 18, color: t.silverText),
          const SizedBox(width: 8),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: t.silverText))),
        ]),
      ),
    );
  }
}

/// چالاک / ڕاگیراوە (.ts-state)
class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.paused, this.due = false});
  final bool paused;
  final bool due;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final fg = paused ? (t.dark ? const Color(0xFFFCA5A5) : const Color(0xFFB42318)) : (t.dark ? const Color(0xFF34D399) : const Color(0xFF047857));
    final bg = paused ? const Color(0x26EF4444) : (t.dark ? const Color(0x2610B981) : const Color(0x1F10B981));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: fg.withValues(alpha: .35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: fg)),
        const SizedBox(width: 6),
        Text(due ? 'چاوەڕێی پارەدانە' : paused ? 'ڕاگیراوە' : 'چالاک', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12.8)),
      ]),
    );
  }
}

/// وردەکاری زیاتری بەشداری (کورتەی ui.requestSummary)
class _SubDetails extends StatelessWidget {
  const _SubDetails({required this.sub});
  final Json sub;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final ride = sub['rideType'] == 'private'
        ? 'تەکسی تایبەت'
        : sub['rideType'] == 'family'
            ? 'خێزان بە تەنها'
            : sub['rideType'] == 'kids'
                ? 'گەشتی منداڵان'
                : 'تەکسی هاوبەش';
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 92, child: Text(k, style: Ts.muted(context, size: 13.6))),
            Expanded(child: Text(v, style: TextStyle(fontSize: 14, color: t.text, fontWeight: FontWeight.w600))),
          ]),
        );
    final pd = asMap(sub['perDay']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row('لە', str(sub['from'])),
        row('بۆ', str(sub['to'])),
        row('کات', fmtSchedule(sub)),
        row('ڕۆژەکان', fmtDays(asList(sub['days']))),
        row('جۆر', ride),
        if (sub['womanOnly'] == true) row('تێبینی', 'تەنها ئافرەت'),
        if (str(sub['note']).isNotEmpty) row('تێبینی', str(sub['note'])),
        if (pd.isNotEmpty)
          for (var i = 0; i < 7; i++)
            if (asMap(pd['$i']).isNotEmpty)
              row(
                kWeekdays[i],
                [
                  str(asMap(pd['$i'])['go']).isEmpty ? 'بێ چوون' : 'چوون ${Fmt.clock(str(asMap(pd['$i'])['go']))}',
                  str(asMap(pd['$i'])['back']).isEmpty ? 'بێ هاتنەوە' : 'هاتنەوە ${Fmt.clock(str(asMap(pd['$i'])['back']))}',
                ].join('، '),
              ),
      ]),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, (y + 3).clamp(0.0, size.height).toDouble()), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/* ---------------- داواکارییەکان ---------------- */

/// دۆخی داواکاری (reqStatus)
Widget requestStatus(Json r) {
  if (r['status'] == 'matched') return const YkBadge('ڕێککەوتن', tone: BadgeTone.ok);
  if (r['status'] == 'closed') {
    final why = r['closedReason'] == 'expired' ? 'کاتی تەواو بوو' : r['closedReason'] == 'declined' ? 'ڕەتکرایەوە' : 'هەڵوەشێنرایەوە';
    return YkBadge(why, tone: BadgeTone.danger);
  }
  final n = asList(r['offers']).where((o) => asMap(o)['status'] == 'pending').length;
  return n > 0 ? YkBadge(Fmt.n('$n نرخ هات'), tone: BadgeTone.danger) : const YkBadge('چاوەڕێ', tone: BadgeTone.note);
}

class RequestCard extends StatelessWidget {
  const RequestCard(this.r, {super.key});
  final Json r;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final all = r['target'] == 'all';
    final tgt = all ? 'بڵاوکراوە بۆ هەمووان' : 'ڕاستەوخۆ بۆ ${str(cloud.driver(r['target'])?['name'])}';
    final open = r['status'] == 'open';
    final boxBg = open ? t.silver : r['status'] == 'matched' ? t.okBg : t.dangerBg;
    return YkCard(
      onTap: () => openLink(context, 'request/${r['id']}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: boxBg, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: YkIcon(all ? 'megaphone' : 'send', size: 20, color: t.brand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${str(r['riderNames'])}، ${str(r['to'])}', style: Ts.bold(context)),
              Text('$tgt${open && r['expiresAt'] is num ? '، ${fmtLeft(r['expiresAt'] as num)}' : ''}', style: Ts.muted(context, size: 12.8)),
            ]),
          ),
          requestStatus(r),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('${fmtSchedule(r)}، ${fmtDays(asList(r['days']))}', style: Ts.muted(context, size: 14))),
          Text(Fmt.money((r['price'] as num?) ?? 0), style: TextStyle(fontWeight: FontWeight.w700, color: t.brand)),
        ]),
      ]),
    );
  }
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  String _tab = 'open';
  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final all = cloud.list('requests').where((r) => r['owner'] == cloud.me).toList();
    bool inTab(Json r, String k) => k == 'open' ? r['status'] == 'open' : k == 'matched' ? r['status'] == 'matched' : r['status'] == 'closed';
    final list = all.where((r) => inTab(r, _tab)).toList();
    return Scaffold(
      body: YkScreen(onRefresh: context.read<Cloud>().refresh, children: [
        YkHeader('داواکارییەکانم',
            right: IconButton(
              tooltip: 'نوێ',
              onPressed: () => openLink(context, 'new'),
              icon: YkIcon('plus', size: 22, color: context.yk.text),
            )),
        YkSeg<String>(
          options: [
            for (final k in const [('open', 'کراوە'), ('matched', 'ڕێککەوتوو'), ('closed', 'داخراو')])
              (k.$1, Fmt.n('${k.$2} (${all.where((r) => inTab(r, k.$1)).length})')),
          ],
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        if (list.isEmpty)
          YkEmpty(
            icon: 'megaphone',
            title: 'هیچ داواکارییەک نییە',
            text: 'بەشدارییەکی نوێ دروست بکە و بۆ شۆفێرەکان بڵاوی بکەرەوە',
            button: _tab == 'open' ? YkButton('بەشداری نوێ', onPressed: () => openLink(context, 'new')) : null,
          ),
        for (final r in list) RequestCard(r),
      ]),
    );
  }
}

/// ئۆتۆمبێل و ڕەنگ (.ts-car): ناوی ئۆتۆمبێل کورت دەکرێتەوە، ڕەنگەکە هەمیشە دیارە
class _CarLine extends StatelessWidget {
  const _CarLine(this.d);
  final Json d;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final mk = '${str(d['carMake'])} ${str(d['carModel'])}'.trim();
    final car = mk.isNotEmpty ? mk : str(d['car']);
    final color = str(d['carColor']);
    final style = Ts.muted(context, size: 13.6);
    return Row(children: [
      if (car.isNotEmpty) Flexible(child: Text(car, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: style)),
      if (car.isNotEmpty && color.isNotEmpty)
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(shape: BoxShape.circle, color: t.muted.withValues(alpha: .6)),
        ),
      if (color.isNotEmpty) Text(color, maxLines: 1, style: style),
    ]);
  }
}
