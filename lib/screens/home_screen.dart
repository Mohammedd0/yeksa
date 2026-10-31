// سەرەکی: ڕێکلام، نرخی شۆفێرەکان، گەشتی لایڤ یان گەشتی داهاتوو، هەڵسەنگاندن، ئۆفەرەکان
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/billing.dart';
import '../core/cloud.dart';
import '../core/maps_status.dart';
import '../core/format.dart';
import '../core/live.dart';
import '../core/sel.dart';
import '../ui/logo.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import '../ui/trip_map.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'nav.dart';
import 'notices_screen.dart';
import 'trip_actions.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final allNews = cloud.newsFor('passenger');
    final ads = allNews.where((n) => YkSel.newsKind(n) == 'ad').toList();
    final offerList = allNews.where((n) => YkSel.newsKind(n) == 'offer').toList();
    final openReqs = cloud.openRequests;
    final offers = openReqs.fold<int>(0, (n, r) => n + asList(r['offers']).where((o) => asMap(o)['status'] == 'pending').length);
    final unread = cloud.unreadNotices;
    Json? swap;
    for (final n in cloud.myNotices) {
      if (n['kind'] == 'swap') {
        swap = n;
        break;
      }
    }
    final subs = cloud.mySubs;
    final isEmpty = subs.isEmpty && openReqs.isEmpty;
    final trips = cloud.myTrips;
    final active = trips.where((x) => x['status'] == 'active').toList();

    return YkScreen(
      withNav: true,
      onRefresh: context.read<Cloud>().refresh,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const YLogo(),
            _BellButton(count: unread, onTap: () => push(context, const NoticesScreen())),
          ],
        ),
        if (ads.isNotEmpty) NewsCarousel(items: ads, onOpen: (n) => openLink(context, 'news/${n['id']}')),
        if (offers > 0)
          YkCard(
            tone: CardTone.note,
            onTap: () => openLink(context, openReqs.length == 1 ? 'request/${openReqs.first['id']}' : 'requests'),
            child: Row(children: [
              _icoBox(context, 'tag', bg: t.amber, fg: const Color(0xFF0B1733)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Fmt.n('$offers شۆفێر نرخیان بۆ ناردوویت'), style: Ts.bold(context)),
                  Text('بیانبینە و یەکێکیان هەڵبژێرە', style: Ts.muted(context, size: 14)),
                ]),
              ),
              YkIcon('forward', size: 20, color: t.text),
            ]),
          )
        else if (openReqs.isNotEmpty)
          YkCard(
            onTap: () => openLink(context, 'requests'),
            child: Row(children: [
              _icoBox(context, 'hourglass'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('داواکارییەکەت بڵاو کراوەتەوە', style: Ts.bold(context)),
                  Text('چاوەڕێی وەڵامی شۆفێرەکانین', style: Ts.muted(context, size: 14)),
                ]),
              ),
              YkIcon('forward', size: 20, color: t.text),
            ]),
          ),
        if (isEmpty)
          YkCard(
            big: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('هێشتا هیچ گەشتێکت نییە!', style: Ts.h3(context)),
                    const SizedBox(height: 4),
                    Text('یەکەم بەشداری مانگانەت دروست بکە. شوێن و کات دیاری بکە، و شۆفێرەکان نرخت بۆ دەنێرن.', style: Ts.muted(context, size: 14)),
                  ]),
                ),
                const SizedBox(width: 10),
                _icoBox(context, 'car', size: 64, iconSize: 34, radius: 20, stroke: 1.6),
              ]),
              const SizedBox(height: 12),
              YkButton('یەکەم بەشداری', icon: 'plus', block: true, onPressed: () => openLink(context, 'new')),
            ]),
          ),
        // گەشتی لایڤ (کاتێک شۆفێر بەڕێ کەوتووە) یان گەشتی داهاتوو
        if (active.isNotEmpty) ...active.map((x) => _ActiveTripCard(trip: x)) else _NextCard(cloud: cloud),
        _RateNudge(cloud: cloud),
        if (!isEmpty && subs.isEmpty) YkButton('بەشداری نوێ', icon: 'plus', block: true, large: true, onPressed: () => openLink(context, 'new')),
        Row(children: [
          Expanded(child: _tile(context, 'wallet', cloud.walletOn ? 'جزدانەکەم' : 'پارەدان', () => openLink(context, cloud.walletOn ? 'wallet' : 'billing'))),
          const SizedBox(width: 10),
          Expanded(child: _tile(context, 'tag', 'ئۆفەرەکان', () => openLink(context, 'offers'))),
        ]),
        if (swap != null && subs.isNotEmpty)
          YkCard(
            tone: CardTone.note,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              YkIcon('swap', size: 20, color: t.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(str(swap['title']), style: Ts.bold(context).copyWith(fontSize: 14)),
                  Text(str(swap['body']), style: Ts.sm(context)),
                ]),
              ),
            ]),
          ),
        // جزدان: پارەی ئەم مانگە هێشتا نەدراوە (هاوتای کارتی paymonth ـی وێب)
        if (cloud.walletOn && cloud.invoice(due: true).lines.isNotEmpty)
          YkCard(
            onTap: () => openLink(context, 'paymonth'),
            child: Row(children: [
              _icoBox(context, 'wallet', bg: t.amber, fg: const Color(0xFF0B1733)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('پارەی ${str(cloud.billing['month'])} ئامادە بکە', style: Ts.bold(context)),
                  Text('${Fmt.money(cloud.invoice(due: true).total)}، گەشتەکان دوای پارەدان دەست پێدەکەن', style: Ts.muted(context, size: 14)),
                ]),
              ),
              YkIcon('forward', size: 20, color: t.muted),
            ]),
          ),
        // بێ جزدان: فاتورەی ئەم مانگە ئامادەیە و نەدراوە
        if (!cloud.walletOn && cloud.billing['paid'] != true && cloud.invoice().total > 0)
          YkCard(
            onTap: () => openLink(context, 'billing'),
            child: Row(children: [
              _icoBox(context, 'wallet', bg: t.infoBg, fg: t.infoText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('فاتورەی ${str(cloud.billing['month'])} ئامادەیە', style: Ts.bold(context)),
                  Text(Fmt.money(cloud.invoice().total), style: Ts.muted(context, size: 14)),
                ]),
              ),
              YkIcon('forward', size: 20, color: t.muted),
            ]),
          ),
        if (offerList.isNotEmpty)
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('ئۆفەرەکان', style: Ts.h3(context).copyWith(fontSize: 16)),
            YkLink('هەمووی', pill: true, onTap: () => openLink(context, 'offers')),
          ]),
        for (final n in offerList.take(3)) NewsCard(n, thumb: 72, onTap: () => openLink(context, 'news/${n['id']}')),
      ],
    );
  }

  /// کارتی بچووک (.qtile)
  Widget _tile(BuildContext context, String icon, String label, VoidCallback onTap) {
    final t = context.yk;
    return YkCard(
      onTap: onTap,
      child: Row(children: [
        YkIcon(icon, size: 22, color: t.text),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Ts.bold(context).copyWith(fontSize: 15))),
        YkIcon('forward', size: 16, color: t.muted),
      ]),
    );
  }
}

/// سندوقی ئایکۆن (.ico-box)
Widget _icoBox(BuildContext context, String icon,
    {Color? bg, Color? fg, double size = 40, double iconSize = 20, double radius = 12, double stroke = 1.9}) {
  final t = context.yk;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: bg ?? t.silver, borderRadius: BorderRadius.circular(radius)),
    alignment: Alignment.center,
    child: YkIcon(icon, size: iconSize, color: fg ?? t.act, stroke: stroke),
  );
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Semantics(
      button: true,
      label: 'ئاگادارکردنەوەکان',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, color: t.glass, border: Border.all(color: t.glassLine)),
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            YkIcon('bell', size: 22, color: t.text),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(9), border: Border.all(color: t.bg, width: 2)),
                  child: Text(Fmt.n(count), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// گەشتی لایڤ: شۆفێر بەڕێ کەوتووە (نەخشە و کاتی گەیشتن لە قۆناغی سێیەمدا)
class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip});
  final Json trip;
  @override
  Widget build(BuildContext context) => LiveTicker(builder: _card);

  Widget _card(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final d = cloud.driver(trip['driverId']) ?? const {};
    final names = cloud.names(asList(trip['memberIds']));
    final kind = trip['kind'] == 'kids' ? 'گەشتی منداڵان' : trip['kind'] == 'private' ? 'تایبەت' : 'هاوبەش';
    final ids = asList(trip['memberIds']);
    final co = coRiders(trip).where((c) => c['mine'] != true).expand((c) => (c['people'] as List).cast<Json>()).toList();
    return YkCard(
      big: true,
      onTap: () => openLink(context, 'track/${trip['id']}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          PersonAvatar(size: 44, imageId: ids.isEmpty ? null : cloud.memberPhoto(ids.first)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${Fmt.names(names)}، بۆ ${tripDest(trip)}', style: Ts.bold(context)),
              Text('${str(d['name'])}، $kind', style: Ts.muted(context, size: 14)),
            ]),
          ),
          const YkBadge('لە ڕێگەیە', tone: BadgeTone.ok),
        ]),
        const SizedBox(height: 12),
        TripMap(trip: trip, height: MapsStatus.failed.value ? 200 : 260, live: true),
        if (co.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            YkIcon('users', size: 16, color: t.muted),
            Text('لەگەڵت:', style: Ts.muted(context, size: 14)),
            for (final p in co) PersonChip(p),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Builder(builder: (context) {
              final stops = stopsOf(trip);
              final ni = nextStopIndex(trip);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (ni >= 0)
                  ownStop(trip, stops[ni])
                      ? Text.rich(TextSpan(children: [
                          const TextSpan(text: 'داهاتوو: '),
                          TextSpan(text: str(stops[ni]['place']), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]), style: Ts.sm(context))
                      : Text('شۆفێر لای هاوڕێکانتە', style: Ts.sm(context)),
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${cloud.waiting(trip) ? 'دەگاتە لات' : 'گەیشتن'}: '),
                  TextSpan(text: Fmt.clock(cloud.eta(trip)), style: TextStyle(fontWeight: FontWeight.w700, color: t.brand)),
                  TextSpan(text: Fmt.n('، ${cloud.minutesLeft(trip)} خولەک')),
                ]), style: Ts.muted(context, size: 14)),
              ]);
            }),
          ),
          YkButton('بینینی لایڤ', small: true, onPressed: () => openLink(context, 'track/${trip['id']}')),
        ]),
      ]),
    );
  }
}

/// کارتی گەشتی داهاتوو (ئەمڕۆ یان بەیانی)، گرنگترین شت بۆ سەرنشین
class _NextCard extends StatelessWidget {
  const _NextCard({required this.cloud});
  final Cloud cloud;

  ({String when, String time, Json? trip, Json sub, String dir, bool pooled})? _upcoming() {
    final now = Fmt.hhmm(nowMs());
    final today = cloud.myTrips.where((x) => x['status'] == 'scheduled').toList()
      ..sort((a, b) => str(a['time']).compareTo(str(b['time'])));
    for (final x in today) {
      if (str(x['time']).compareTo(now) >= 0) {
        final s = cloud.sub(x['subId']);
        if (s == null) continue;
        return (when: 'today', time: str(x['time']), trip: x, sub: s, dir: str(x['dir']), pooled: x['runId'] != null);
      }
    }
    final d = DateTime.now().add(const Duration(days: 1));
    final pool = (cloud.config['poolWindowMin'] as num).toInt();
    final stopMin = (cloud.config['stopMin'] as num).toInt();
    final routes = cloud.list('routes');
    final out = <({String when, String time, Json? trip, Json sub, String dir, bool pooled})>[];
    for (final x in cloud.mySubs.where((x) => x['status'] == 'active' && dayApplies(x, d))) {
      for (final dir in const ['go', 'back']) {
        final base = dayTime(x, dir, d);
        if (base == null) continue;
        var time = base;
        Json? r;
        if (inRouteOn(x, dir, pool, d)) {
          for (final y in routes) {
            if (y['dir'] == dir && asList(y['subIds']).contains(x['id'])) r = y;
          }
        }
        if (r != null) {
          final subs = asList(r['subIds'])
              .map((id) => cloud.sub(id))
              .whereType<Json>()
              .where((y) => y['status'] == 'active' && dayApplies(y, d) && dayTime(y, dir, d) != null && inRouteOn(y, dir, pool, d))
              .toList();
          time = routePickTime(r, subs, str(x['id']), stopMin) ?? base;
        }
        out.add((when: 'tomorrow', time: time, trip: null, sub: x, dir: dir, pooled: r != null));
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out.isEmpty ? null : out.first;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final n = _upcoming();
    if (n == null) return const SizedBox.shrink();
    final x = n.sub;
    final trip = n.trip;
    final d = cloud.driver(trip?['driverId'] ?? x['driverId']) ?? const <String, dynamic>{};
    final leg = subLeg(x, n.dir);
    final can = trip != null && canSkip(trip, (cloud.config['skipCutoffMin'] as num).toInt());
    return YkCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            YkIcon('calendar', size: 15, color: t.muted, stroke: 2.2),
            const SizedBox(width: 6),
            Text(n.when == 'today' ? 'گەشتی داهاتوو، ئەمڕۆ' : 'گەشتی داهاتوو، بەیانی',
                style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w700, color: t.muted)),
          ]),
          if (n.pooled) const YkBadge('تەکسی هاوبەش', tone: BadgeTone.info),
        ]),
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: trip == null ? null : () => openLink(context, 'track/${trip['id']}'),
          child: Row(children: [
            Container(
              constraints: const BoxConstraints(minWidth: 70),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(Fmt.clockBare(n.time), style: TextStyle(fontSize: 25.6, fontWeight: FontWeight.w700, height: 1.05, color: t.text)),
                Text(Fmt.period(n.time), style: TextStyle(fontSize: 12.5, color: t.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(x['riderNames']), style: Ts.bold(context)),
                Text('${leg.from.split('، ').first} ← ${leg.to.split('، ').first}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.muted(context, size: 14)),
              ]),
            ),
          ]),
        ),
        if (d.isNotEmpty) ...[
          const SizedBox(height: 14),
          DriverHead(d, onTap: () => openLink(context, 'driver/${d['id']}')),
        ],
        const SizedBox(height: 14),
        Row(children: [
          if (can) ...[
            Expanded(child: YkButton('نایەم', icon: 'x', small: true, kind: BtnKind.secondary, onPressed: () => showSkipSheet(context, str(trip['id'])))),
            const SizedBox(width: 8),
          ],
          Expanded(child: YkButton('نامە', icon: 'chat', small: true, kind: BtnKind.secondary, onPressed: () => openLink(context, 'chat/${d['id']}'))),
          const SizedBox(width: 8),
          Expanded(
            child: trip != null
                ? YkButton('وردەکاری', small: true, kind: BtnKind.secondary, onPressed: () => openLink(context, 'track/${trip['id']}'))
                : YkButton('گەشتەکان', small: true, kind: BtnKind.secondary, onPressed: () => openLink(context, 'trips')),
          ),
        ]),
      ]),
    );
  }
}

/// دوای گەشت: داوای هەڵسەنگاندن
class _RateNudge extends StatelessWidget {
  const _RateNudge({required this.cloud});
  final Cloud cloud;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final done = cloud.myTrips.where((x) => x['status'] == 'done' && x['ratedByPassenger'] == null).toList()
      ..sort((a, b) => ((b['doneAt'] as num?) ?? 0).compareTo((a['doneAt'] as num?) ?? 0));
    if (done.isEmpty) return const SizedBox.shrink();
    final trip = done.first;
    final d = cloud.driver(trip['driverId']) ?? const {};
    return YkCard(
      onTap: () => openLink(context, 'track/${trip['id']}'),
      child: Row(children: [
        YkIcon('star', size: 26, color: t.amber, stroke: 1.5, fill: t.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('گەشتەکە لەگەڵ ${str(d['name']).split(' ').first} چۆن بوو؟', style: Ts.bold(context)),
            Text('هەڵسەنگاندنەکەت یارمەتی شۆفێرە باشەکان دەدات', style: Ts.muted(context, size: 12.8)),
          ]),
        ),
        YkIcon('forward', size: 18, color: t.muted),
      ]),
    );
  }
}
