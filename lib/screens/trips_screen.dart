// گەشتەکانی ئەمڕۆ («نایەم» / «دەیەم») و گەشتە کۆنەکان (مێژوو)
import 'dart:collection'; // firstOrNull / lastOrNull
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/actions.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/live.dart';
import '../core/route_path.dart';
import '../core/sel.dart';
import '../core/trips.dart';
import '../ui/help.dart';
import '../ui/form_parts.dart';
import '../ui/theme.dart';
import '../ui/trip_map.dart' show RouteMap, RouteMark;
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'nav.dart';
import 'request_screen.dart' show askConfirm;
import 'trip_actions.dart';

/// نیشانەی دۆخی گەشت
Widget tripStatusBadge(Json t) {
  switch (t['status']) {
    case 'active':
      return YkBadge(tr('لە ڕێگەیە'), tone: BadgeTone.ok);
    case 'done':
      return YkBadge(tr('تەواو بوو'), tone: BadgeTone.ok);
    case 'skipped':
      return YkBadge(tr('نایەن'), tone: BadgeTone.danger);
    case 'noshow':
      return YkBadge(tr('شۆفێر نەهات'), tone: BadgeTone.danger);
    case 'absent':
      return YkBadge(tr('سوار نەبوون'), tone: BadgeTone.danger);
    case 'missed':
      return YkBadge(tr('نەکرا'), tone: BadgeTone.danger);
  }
  return _DirBadge(back: t['dir'] == 'back');
}

/// .badge.dir: زیوی بە خاڵێک؛ پڕ بۆ چوون، بەتاڵ بۆ هاتنەوە
class _DirBadge extends StatelessWidget {
  const _DirBadge({required this.back});
  final bool back;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: back ? Colors.transparent : t.text, border: Border.all(color: t.text, width: 1.6)),
        ),
        const SizedBox(width: 6),
        Text(back ? tr('هاتنەوە') : tr('چوون'), style: TextStyle(fontSize: 12.2, fontWeight: FontWeight.w700, color: t.text, height: 1.4)),
      ]),
    );
  }
}

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final cutoff = (cloud.config['skipCutoffMin'] as num).toInt();
    final trips = [...cloud.myTrips]..sort((a, b) => str(a['time']).compareTo(str(b['time'])));
    final pending = trips.where((x) => x['status'] == 'scheduled').toList();
    final hasSubs = cloud.mySubs.isNotEmpty;

    Widget chatBtn(String did) => Semantics(
          button: true,
          label: tr('نامە'),
          child: InkWell(
            onTap: () => openLink(context, 'chat/$did'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 46,
              height: 38,
              decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.silverLine)),
              alignment: Alignment.center,
              child: YkIcon('chat', size: 16, color: t.silverText),
            ),
          ),
        );

    return YkScreen(withNav: true, title: tr('گەشتەکانی ئەمڕۆ'), onRefresh: context.read<Cloud>().refresh, children: [
      // (؟) لە ئاستی ناونیشانەکەیە، نەک لە ناوەڕاستی ناونیشان و بەروار (وەک نامەکان)
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('گەشتەکانی ئەمڕۆ'), style: Ts.h1(context)),
            Text(Fmt.today(), style: Ts.muted(context, size: 14)),
          ]),
        ),
        const HelpButton('trips'),
      ]),
      if (trips.isEmpty)
        cloud.walletOn && hasSubs
            ? YkEmpty(
                icon: 'calendar',
                title: tr('پارەی مانگ چاوەڕێیە'),
                text: tr('گەشتەکان دوای پارەدانی ئەم مانگە دەست پێدەکەن'),
                button: YkButton(tr('پارەدانی مانگ'), onPressed: () => openLink(context, 'paymonth')),
              )
            : YkEmpty(
                icon: 'calendar',
                title: tr('ئەمڕۆ هیچ گەشتێکت نییە'),
                text: hasSubs ? tr('گەشتەکانی بەیانی لە سەرەکی دەبینیت') : tr('بەشدارییەکی مانگانە دروست بکە و هەموو ڕۆژێک شۆفێرەکەت دێت'),
                button: hasSubs
                    ? YkButton(tr('سەرەکی'), kind: BtnKind.secondary, onPressed: () => openLink(context, 'home'))
                    : YkButton(tr('بەشداری نوێ'), onPressed: () => openLink(context, 'new')),
              ),
      for (final x in trips)
        Builder(builder: (context) {
          final did = str(x['driverId']);
          final d = cloud.driver(did) ?? const {};
          final names = Fmt.names(cloud.names(asList(x['memberIds'])));
          final skipped = x['status'] == 'skipped';
          return YkCard(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openLink(context, 'track/${x['id']}'),
                child: Row(children: [
                  // .tripcard .ico-box: ٥٢×٥٢؛ گەشتی «نایەن» سوور
                  IcoBox(x['dir'] == 'back' ? 'home' : x['kind'] == 'kids' ? 'school' : 'car',
                      size: 52, iconSize: 22, bg: skipped ? t.dangerBg : t.silver, color: skipped ? t.dangerText : null),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('{0}، {1}', [names, tripDest(x)]), style: Ts.bold(context)),
                      Text(
                        [Fmt.clock(str(x['time'])), x['originalDriverId'] != null ? tr('{0} (جێگرەوە)', [str(d['name'])]) : str(d['name']), if (x['runId'] != null) tr('تەکسی هاوبەش')].join(tr('، ')),
                        style: Ts.muted(context, size: 12.8),
                      ),
                    ]),
                  ),
                  tripStatusBadge(x),
                ]),
              ),
              if (x['status'] == 'scheduled') ...[
                const SizedBox(height: 10),
                if (canSkip(x, cutoff))
                  Row(children: [
                    Expanded(child: YkButton(tr('نایەم'), icon: 'x', small: true, block: true, kind: BtnKind.secondary, onPressed: () => showSkipSheet(context, str(x['id'])))),
                    const SizedBox(width: 8),
                    chatBtn(did),
                  ])
                else
                  Row(children: [
                    Expanded(child: Text(Fmt.n(tr('کەمتر لە {0} خولەک ماوە، «نایەم» ناکرێت. نامە بۆ شۆفێر بنێرە.', [cutoff])), style: Ts.muted(context, size: 12.8))),
                    const SizedBox(width: 8),
                    chatBtn(did),
                  ]),
              ],
              if (skipped) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(str(x['skipReason']).isNotEmpty ? trData(str(x['skipReason'])) : tr('شۆفێر ئاگادار کرایەوە'), style: Ts.muted(context, size: 12.8))),
                  YkButton(tr('دەیەم'), small: true, kind: BtnKind.secondary, onPressed: () async {
                    final err = await cloud.unskipTrip(str(x['id']));
                    if (context.mounted) toast(context, err ?? tr('شۆفێر ئاگادار کرایەوە کە دێن'));
                  }),
                ]),
              ],
            ]),
          );
        }),
      if (pending.length > 1)
        YkButton(tr('ئەمڕۆ هیچ کەسێک نایەت'), kind: BtnKind.ghost, block: true, onPressed: () async {
          if (!await askConfirm(context, tr('هەموو گەشتە ماوەکانی ئەمڕۆ هەڵدەوەشێنرێنەوە و شۆفێرەکان ئاگادار دەکرێنەوە.'))) return;
          final bySub = <String, List<String>>{};
          for (final x in cloud.myTrips.where((x) => x['status'] == 'scheduled')) {
            bySub.putIfAbsent(str(x['subId'] ?? x['id']), () => []).add(str(x['id']));
          }
          for (final ids in bySub.values) {
            await cloud.skipTrips(ids, '');
          }
          if (context.mounted) toast(context, tr('هەموو شۆفێرەکان ئاگادار کرانەوە'));
        }),
      Text(Fmt.n(tr('«نایەم» تا {0} خولەک پێش کاتی گەشت دەکرێت.', [cutoff])), textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8)),
      YkCard(
        onTap: () => push(context, const HistoryScreen()),
        child: Row(children: [
          YkIcon('clock', size: 20, color: t.brand),
          const SizedBox(width: 10),
          Expanded(child: Text(tr('گەشتە کۆنەکان'), style: Ts.bold(context))),
          YkIcon(L.rtl ? 'forward' : 'back', size: 18, color: t.muted),
        ]),
      ),
    ]);
  }
}

/* ---------------- گەشتە کۆنەکان ---------------- */

String _hm(Object? at) => at is num ? Fmt.clock(Fmt.hhmm(at.toInt())) : '';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final list = cloud.myHistory;
    final rows = <Widget>[];
    var lastDay = '';
    for (final h in list) {
      final d = cloud.driver(h['driverId']) ?? const {};
      final day = h['date'] is num ? Fmt.date((h['date'] as num).toInt()) : '';
      if (day != lastDay) {
        rows.add(Text(day, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.muted)));
        lastDay = day;
      }
      final stops = asList(h['stops']).map(asMap).toList();
      final first = stops.isEmpty ? const <String, dynamic>{} : stops.first;
      final last = stops.isEmpty ? const <String, dynamic>{} : stops.last;
      final names = Fmt.names(cloud.names(asList(h['memberIds'])));
      final title = names.isNotEmpty ? names : str(h['tripTitle']);
      final absent = h['absent'] == true;
      rows.add(YkCard(
        onTap: () => push(context, HistoryDetailScreen(id: str(h['id']))),
        child: Row(children: [
          IcoBox(absent ? 'x' : 'check', bg: absent ? t.dangerBg : t.okBg, color: absent ? t.dangerText : t.okText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Ts.bold(context)),
              if (absent) ...[
                Text(tr('سوار نەبوون، حیساب کرا'), style: TextStyle(fontSize: 12.8, color: t.dangerText)),
                Text(Fmt.n(tr('{0} {1} خولەک لە {2} چاوەڕێی کرد', [str(d['name']), h['waited'] ?? '', str(first['place'])])), style: Ts.muted(context, size: 12.8)),
              ] else ...[
                Text(tr('{0} ← {1}', [str(first['place']), str(last['place'])]), style: Ts.muted(context, size: 12.8)),
                Text(tr('{0}، سوار بوون {1}، گەیشتن {2}', [str(d['name']), _hm(first['doneAt']), _hm(last['doneAt'])]), style: Ts.muted(context, size: 12.8)),
              ],
            ]),
          ),
          YkIcon(L.rtl ? 'forward' : 'back', size: 18, color: t.muted),
        ]),
      ));
    }
    return Scaffold(
      body: YkScreen(children: [
        YkHeader(tr('گەشتەکانم'), sub: Fmt.n(tr('{0} گەشتی تەواوبوو', [list.length]))),
        if (list.isEmpty) YkEmpty(icon: 'clock', title: tr('هێشتا هیچ گەشتێکت نییە'), text: tr('دوای هەر گەشتێک لێرە دەبینیت کەی سوار بوون و کەی گەیشتن')),
        ...rows,
      ]),
    );
  }
}

class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final h = cloud.myHistory.where((x) => x['id'] == id).firstOrNull;
    if (h == null) return Scaffold(body: YkScreen(children: [YkHeader(tr('گەشت')), YkEmpty(icon: 'clock', title: tr('نەدۆزرایەوە'))]));
    final did = str(h['driverId']);
    final d = cloud.driver(did) ?? {'id': did};
    final orig = h['originalDriverId'] != null ? cloud.driver(h['originalDriverId']) : null;
    final stops = asList(h['stops']).map(asMap).toList();
    final first = stops.isEmpty ? const <String, dynamic>{} : stops.first;
    final last = stops.isEmpty ? const <String, dynamic>{} : stops.last;
    final a = (first['doneAt'] as num?) ?? 0, b = (last['doneAt'] as num?) ?? 0;
    final dur = ((b - a) / 60000).round().clamp(1, 1 << 20);
    final ev = <(num, String, String)>[];
    if (h['startedAt'] is num) ev.add((h['startedAt'] as num, tr('{0} دەستی بە گەشت کرد', [str(d['name'])]), 'route'));
    for (final x in stops) {
      if (x['arrivedAt'] is num) ev.add((x['arrivedAt'] as num, tr('تەکسی گەیشتە {0}', [str(x['place'])]), 'pin'));
      if (x['absent'] == true) {
        ev.add(((x['doneAt'] as num?) ?? 0, tr('کەس نەهات، شۆفێر ڕۆیشت'), 'x'));
        continue;
      }
      ev.add((
        (x['doneAt'] as num?) ?? 0,
        x['kind'] == 'pickup' ? tr('{0} سوار بوون، {1}', [str(x['riders']), str(x['place'])]) : tr('{0} دابەزین، {1}', [str(x['riders']), str(x['place'])]),
        x['kind'] == 'pickup' ? 'car' : 'check',
      ));
    }
    ev.sort((x, y) => x.$1.compareTo(y.$1));
    // ڕێگای ڕاستەقینە (تەنها بەشی خۆی: لە سوار بوونەوە تا دابەزین)
    final path = decodePath(str(h['path']));
    final gs = stops.where((x) => x['g'] is List && (x['g'] as List).length == 2).toList();
    final marks = <RouteMark>[
      for (var i = 0; i < gs.length; i++)
        RouteMark(
          ((gs[i]['g'] as List)[0] as num).toDouble(),
          ((gs[i]['g'] as List)[1] as num).toDouble(),
          kind: i == gs.length - 1 && gs.length > 1 ? 'end' : 'stop',
          label: Fmt.n(i + 1),
        ),
    ];
    final km = h['km'] is num ? (h['km'] as num).toDouble() : null;
    Widget stat(String big, String small) => Expanded(
          child: YkCard(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(children: [
              Text(big, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.text)),
              Text(small, style: Ts.muted(context, size: 12.8)),
            ]),
          ),
        );
    return Scaffold(
      body: YkScreen(children: [
        YkHeader(str(h['tripTitle']), sub: h['date'] is num ? Fmt.date((h['date'] as num).toInt()) : null),
        YkCard(
          child: Row(children: [
            PersonAvatar(size: 48, imageId: str(d['photo']).isEmpty ? null : str(d['photo'])),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(d['name']), style: Ts.bold(context)),
                Text(tr('{0}، {1}', [str(d['car']), str(d['plate'])]), style: Ts.muted(context, size: 12.8)),
                if (orig != null) Text(tr('جێگرەوەی {0}', [str(orig['name'])]), style: TextStyle(fontSize: 12.8, color: t.brand)),
              ]),
            ),
            YkButton('', icon: 'chat', small: true, kind: BtnKind.secondary, onPressed: () => openLink(context, 'chat/$did')),
          ]),
        ),
        if (path.length > 1) RouteMap(path: path, marks: marks, height: 280),
        if (h['absent'] == true)
          YkCard(
            tone: CardTone.danger,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('سوار نەبوون'), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(Fmt.n(tr('شۆفێر {0} خولەک چاوەڕێی کرد. چونکە پێشتر «نایەم» نەکرابوو، ئەم گەشتە وەک کراو حیساب کرا.', [h['waited'] ?? ''])), style: const TextStyle(fontSize: 14)),
            ]),
          )
        else
          Row(children: [
            stat(_hm(first['doneAt']), tr('سوار بوون')),
            const SizedBox(width: 8),
            stat(_hm(last['doneAt']), tr('گەیشتن')),
            const SizedBox(width: 8),
            stat(Fmt.n(dur), tr('خولەک')),
            if (km != null) ...[
              const SizedBox(width: 8),
              stat(Fmt.n(km.toStringAsFixed(1)), tr('کیلۆمەتر')),
            ],
          ]),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('ڕووداوەکان'), style: Ts.h3(context)),
            const SizedBox(height: 10),
            Timeline(items: [
              for (final e in ev)
                TimelineItem(
                  state: TlState.done,
                  child: Row(children: [
                    Expanded(child: Text(e.$2, style: Ts.sm(context))),
                    Text(_hm(e.$1), style: Ts.sm(context).copyWith(fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ]),
        ),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('سەرنشینەکان'), style: Ts.muted(context, size: 14)),
            Text(Fmt.names(cloud.names(asList(h['memberIds']))), style: Ts.bold(context)),
          ]),
        ),
        YkButton(tr('کێشەیەک لەم گەشتەدا هەبوو؟'), icon: 'help', kind: BtnKind.ghost, block: true, onPressed: () => openLink(context, 'support')),
      ]),
    );
  }
}

/* ---------------- هێڵی کات (.timeline) ---------------- */

enum TlState { normal, done, now, other }

class TimelineItem {
  const TimelineItem({required this.child, this.state = TlState.normal});
  final Widget child;
  final TlState state;
}

class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.items});
  final List<TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 22,
              child: Column(children: [
                const SizedBox(height: 5),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: items[i].state == TlState.done
                        ? t.success
                        : items[i].state == TlState.now
                            ? t.act
                            : t.card,
                    border: Border.all(
                        color: items[i].state == TlState.done
                            ? t.success
                            : items[i].state == TlState.now
                                ? t.act
                                : t.line,
                        width: 3),
                    boxShadow: items[i].state == TlState.now ? [BoxShadow(color: t.silver, spreadRadius: 5)] : null,
                  ),
                ),
                if (i < items.length - 1)
                  Expanded(child: Container(width: 2, color: items[i].state == TlState.done ? t.success : t.line)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(child: Padding(padding: EdgeInsets.only(bottom: i < items.length - 1 ? 14 : 0), child: items[i].child)),
          ]),
        ),
    ]);
  }
}
