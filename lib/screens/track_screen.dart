// پەڕەی گەشت: نەخشەی لایڤ، کاتی گەیشتن، شۆفێر، وێستگەکان، هەڵسەنگاندن، جێگرەوە، «شۆفێر نەهات»، فریاکەوتن
import 'dart:collection'; // firstOrNull / lastOrNull
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/cloud.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/live.dart';
import '../core/sel.dart';
import '../core/trips.dart';
import '../ui/form_parts.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import '../ui/trip_map.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'drivers_screen.dart' show callPhone, DriverScreen;
import 'nav.dart';
import 'request_screen.dart' show askConfirm;
import 'trips_screen.dart';

class TrackScreen extends StatelessWidget {
  const TrackScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return LiveTicker(builder: (context) => _body(context));
  }

  Widget _body(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final trip = cloud.trip(id);
    if (trip == null) {
      return Scaffold(body: YkScreen(children: [YkHeader(tr('گەشت')), YkEmpty(icon: 'route', title: tr('ئەم گەشتە نەدۆزرایەوە'))]));
    }
    final did = str(trip['driverId']);
    final d = cloud.driver(did) ?? {'id': did, 'name': tr('شۆفێر'), 'phone': ''};
    final od = trip['originalDriverId'] != null ? cloud.driver(trip['originalDriverId']) : null;
    final status = trip['status'];
    final stops = stopsOf(trip);
    final ni = nextStopIndex(trip);
    final active = status == 'active';
    final unread = cloud.unreadFrom(did);
    final statusBadge = status == 'scheduled' ? YkBadge(tr('دەست پێدەکات {0}', [Fmt.clock(str(trip['time']))]), tone: BadgeTone.note) : status == 'done' ? YkBadge(tr('گەیشت'), tone: BadgeTone.ok) : tripStatusBadge(trip);

    return Scaffold(
      body: YkScreen(children: [
        YkHeader(
          str(trip['title']),
          // .sos-btn: بازنەی سووری کاڵ بە چوارچێوەی سوور
          right: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: t.dangerBg, shape: BoxShape.circle, border: Border.all(color: t.danger.withValues(alpha: .45))),
            child: IconButton(
              tooltip: tr('فریاکەوتن'),
              padding: EdgeInsets.zero,
              onPressed: () => _sos(context),
              icon: YkIcon('shield', size: 22, color: t.danger, stroke: 2.2),
            ),
          ),
        ),
        Wrap(spacing: 6, runSpacing: 6, children: [
          statusBadge,
          if (trip['runId'] != null) YkBadge(tr('تەکسی هاوبەش'), tone: BadgeTone.info),
        ]),
        TripMap(trip: trip, height: 330, live: active),
        // شۆفێر گەیشتووەتە وێستگەکەت: لە جیاتی کاتی گەیشتن، «لە بەردەم دەرگایە»
        if (active && cloud.arrivedFor(trip) != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(Yk.rLg)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('شۆفێر گەیشتووە'), style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  Text(tr('لە بەردەم دەرگا چاوەڕێت دەکات'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(Fmt.n(tr('لە {0}ەوە', [Fmt.clock(Fmt.hhmm(cloud.arrivedFor(trip)!))])), style: const TextStyle(fontSize: 13, color: Colors.white70)),
                ]),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: kGreen),
                alignment: Alignment.center,
                child: const YkIcon('check', size: 24, color: Colors.white, stroke: 3),
              ),
            ]),
          )
        else if (active)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(Yk.rLg)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cloud.waiting(trip) ? tr('شۆفێر دەگاتە لات') : tr('کاتی گەیشتن بە {0}', [tripDest(trip)]), style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: Fmt.clockBare(cloud.eta(trip))),
                      TextSpan(text: ' ${Fmt.period(cloud.eta(trip))}', style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w400)),
                    ]),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ]),
              ),
              Column(children: [
                Text(Fmt.n(cloud.minutesLeft(trip)), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: kAmber)),
                Text(tr('خولەک'), style: const TextStyle(fontSize: 12.8, color: Colors.white70)),
              ]),
            ]),
          ),
        if (status == 'absent')
          YkCard(
            tone: CardTone.danger,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('شۆفێر لە وێستگەکەت چاوەڕێی کرد و کەس نەهات'), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(tr('چونکە پێشتر «نایەم»ت نەکردبوو، ئەم گەشتە وەک کراو حیساب دەکرێت. ئەگەر هەڵەیە، نامە بۆ شۆفێر بنێرە یان لە پشتگیری ڕاپۆرت بکە.'), style: const TextStyle(fontSize: 14)),
            ]),
          ),
        if (status == 'missed')
          YkCard(
            tone: CardTone.danger,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('ئەم گەشتە نەکرا'), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(tr('شۆفێر دەستی پێکرد بەڵام سوارکردنەکەت تۆمار نەکرا. پارەی ئەم گەشتە بۆ شۆفێر حیساب نەکراوە. ئەگەر کێشەیەک هەبوو لە پشتگیری ڕاپۆرت بکە.'), style: const TextStyle(fontSize: 14)),
            ]),
          ),
        if (status == 'done' && trip['ratedByPassenger'] == null) RateCard(tripId: id),
        if (coRidersOthers(trip) > 0) CoRidersCard(trip: trip),
        if (trip['originalDriverId'] != null && trip['swapOk'] != true && status == 'scheduled')
          YkCard(
            tone: CardTone.note,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                YkIcon('swap', size: 20, color: t.brand),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('شۆفێری جێگرەوە بۆ ئەم گەشتە'), style: Ts.bold(context))),
              ]),
              Text(tr('{0} ناتوانێت بێت. {1} لە جیاتی ئەو دێت. زانیارییەکانی لە خوارەوەیە.', [str(od?['name']).isEmpty ? tr('شۆفێرەکەت') : od!['name'], str(d['name'])]), style: Ts.sm(context)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: YkButton(tr('ڕەتکردنەوە'), small: true, block: true, kind: BtnKind.secondary, onPressed: () async {
                    if (!await askConfirm(context, tr('جێگرەوەکە ڕەت دەکرێتەوە و شۆفێری خۆت ئاگادار دەکرێتەوە کە دەبێت خۆی بێت.'), yes: tr('ڕەتکردنەوە'))) return;
                    await cloud.rejectSwap(id);
                    if (context.mounted) toast(context, tr('ڕەتکرایەوە. شۆفێرەکەت ئاگادار کرایەوە'));
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: YkButton(tr('ڕازیم'), icon: 'check', small: true, block: true, onPressed: () async {
                    await cloud.approveSwap(id);
                    if (context.mounted) toast(context, tr('سوپاس، جێگرەوەکە پەسەند کرا'));
                  }),
                ),
              ]),
            ]),
          ),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DriverHead(d, onTap: () => push(context, DriverScreen(id: did))),
            const SizedBox(height: 12),
            Row(children: [
              if (str(d['phone']).isNotEmpty) ...[
                Expanded(
                  child: _NavyBtn(
                    label: tr('پەیوەندی بە {0}', [str(d['name']).split(' ').first]),
                    onTap: () => callPhone(str(d['phone'])),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Stack(clipBehavior: Clip.none, children: [
                YkButton(tr('نامە'), icon: 'chat', kind: BtnKind.secondary, onPressed: () => openLink(context, 'chat/$did')),
                if (unread > 0)
                  PositionedDirectional(
                    top: -6,
                    end: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(999)),
                      child: Text(Fmt.n(unread), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ]),
          ]),
        ),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('وێستگەکان'), style: Ts.h3(context)),
            const SizedBox(height: 10),
            Timeline(items: [
              for (var i = 0; i < stops.length; i++) _stopItem(context, trip, stops[i], i == ni && active),
            ]),
          ]),
        ),
        if (status == 'scheduled' && minutesUntil(str(trip['time'])) <= -10)
          YkButton(tr('شۆفێر نەهات؟'), icon: 'alert', small: true, block: true, kind: BtnKind.ghost, onPressed: () => _noShow(context, trip)),
        YkButton(tr('هاوبەشکردنی گەشت'), icon: 'share', kind: BtnKind.secondary, block: true, onPressed: () {
          SharePlus.instance.share(ShareParams(text: tr('{0}، گەیشتن نزیکەی {1}، یەکسا', [trip['title'], Fmt.clock(cloud.eta(trip))])));
        }),
      ]),
    );
  }

  /// وێستگەیەک لە هێڵی کات. وێستگەی هاوڕێکانی تەکسی: شوێن نیشان نادرێت، تەنها ناوی یەکەم
  TimelineItem _stopItem(BuildContext context, Json trip, Json x, bool now) {
    final t = context.yk;
    final own = ownStop(trip, x);
    final done = x['done'] == true;
    final mineRiders = own && x['parts'] is List
        ? asList(x['parts']).map(asMap).where((p) => p['subId'] == trip['subId']).map((p) => str(p['riders'])).join(tr('، '))
        : str(x['riders']);
    final when = done ? (x['absent'] == true ? tr('نەهات') : '${Fmt.clock(Fmt.hhmm(((x['doneAt'] as num?) ?? 0).toInt()))} ✓') : Fmt.clock(str(x['time']));
    return TimelineItem(
      state: done ? TlState.done : now ? TlState.now : (own ? TlState.normal : TlState.other),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              own ? str(x['place']) : (x['kind'] == 'pickup' ? tr('سوارکردنی هاوڕێکانت') : tr('دابەزاندنی هاوڕێکانت')),
              style: TextStyle(fontSize: 15.2, fontWeight: own ? FontWeight.w700 : FontWeight.w600, color: own ? t.text : t.muted),
            ),
          ),
          Text(when, style: TextStyle(fontSize: 14, color: done ? t.okText : t.muted)),
        ]),
        Text(
          own ? tr('{0}، {1}', [x['kind'] == 'pickup' ? tr('سوار بوون') : tr('دابەزین'), mineRiders]) : asList(x['people']).map((p) => str(asMap(p)['n'])).join(tr('، ')),
          style: Ts.muted(context, size: 12.8),
        ),
        if (own && x['arrivedAt'] is num && !done)
          Text(tr('شۆفێر گەیشتووە، {0}', [Fmt.clock(Fmt.hhmm((x['arrivedAt'] as num).toInt()))]), style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, color: t.okText)),
      ]),
    );
  }

  void _noShow(BuildContext context, Json trip) {
    final cloud = context.read<Cloud>();
    final ctrl = TextEditingController();
    showYkSheet(context, builder: (c) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('شۆفێر نەهات؟'), style: Ts.h2(c)),
        const SizedBox(height: 6),
        Text(
          tr('کاتی گەشتەکە {0} بوو و شۆفێر هێشتا دەستی پێنەکردووە. {1}', [Fmt.clock(str(trip['time'])), cloud.walletOn ? tr('تیمی یەکسا ڕاپۆرتەکە دەپشکنێت؛ ئەگەر ڕاست بوو، قەرەبوو دەچێتە سەر جزدانەکەت و شۆفێر سزا دەدرێت.') : tr('قەرەبوو بۆ فاتورەکەت زیاد دەکرێت و شۆفێر سزا دەدرێت. تیمی یەکسا ڕاپۆرتەکە دەپشکنێت.')]),
          style: Ts.muted(c, size: 14),
        ),
        const SizedBox(height: 12),
        YkField(
          label: tr('تێبینی'),
          optional: true,
          child: TextField(controller: ctrl, minLines: 2, maxLines: 4, decoration: ykInput(c, hint: tr('بۆ نموونە: ٢٠ خولەک چاوەڕێمان کرد'))),
        ),
        const SizedBox(height: 14),
        _DangerBtn(
          label: tr('ناردنی ڕاپۆرت'),
          onTap: () async {
            Navigator.pop(c);
            final err = await cloud.reportNoShow(str(trip['id']), ctrl.text.trim());
            if (context.mounted) {
              toast(context, err ?? (cloud.walletOn ? tr('ڕاپۆرت نێردرا. یەکسا دەیپشکنێت و ئاگادار دەکرێیتەوە') : tr('ڕاپۆرت تۆمار کرا و قەرەبوو زیاد کرا')));
            }
          },
        ),
        const SizedBox(height: 8),
        YkButton(tr('پاشگەزبوونەوە'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  }

  void _sos(BuildContext context) {
    final cloud = context.read<Cloud>();
    showYkSheet(context, builder: (c) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('فریاکەوتن'), style: Ts.h2(c)),
        const SizedBox(height: 6),
        Text(tr('شوێنی ئێستای گەشتەکە بۆ سەرپەرشتیارەکانی خێزان و تیمی یەکسا دەنێردرێت.'), style: Ts.muted(c, size: 15)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _DangerBtn(label: tr('پۆلیس ١٠٤'), icon: 'phone', onTap: () => launchUrl(Uri.parse('tel:104')))),
          const SizedBox(width: 10),
          Expanded(child: _DangerBtn(label: tr('فریاگوزاری ١٢٢'), icon: 'phone', onTap: () => launchUrl(Uri.parse('tel:122')))),
        ]),
        const SizedBox(height: 10),
        YkButton(tr('ئاگادارکردنەوەی تیمی یەکسا'), kind: BtnKind.secondary, block: true, onPressed: () async {
          Navigator.pop(c);
          final trip = cloud.myTrips.where((x) => x['status'] == 'active').firstOrNull ?? cloud.trip(id);
          final d = trip == null ? null : cloud.driver(trip['driverId']);
          await cloud.addTicket('SOS: داوای یارمەتی${trip != null ? '، ${trip['title']}${d != null ? '، شۆفێر ${d['name']}' : ''}' : ''}'); // i18n-keep
          if (context.mounted) toast(context, tr('تیمی یەکسا ئاگادار کرا و پەیوەندیت پێوە دەکات'));
        }),
        const SizedBox(height: 8),
        YkButton(tr('داخستن'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  }
}

/// دوگمەی سووری پڕ (.danger-solid)
class _DangerBtn extends StatelessWidget {
  const _DangerBtn({required this.label, required this.onTap, this.icon});
  final String label;
  final String? icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Material(
      color: t.danger,
      borderRadius: BorderRadius.circular(Yk.rMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Yk.rMd),
        child: SizedBox(
          height: 54,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[YkIcon(icon!, size: 18, color: Colors.white), const SizedBox(width: 8)],
            Flexible(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
          ]),
        ),
      ),
    );
  }
}

/// دوگمەی تاریک (.btn.navy)
class _NavyBtn extends StatelessWidget {
  const _NavyBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(Yk.rMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Yk.rMd),
        child: SizedBox(
          height: 48,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const YkIcon('phone', size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

/// «گەشتەکە چۆن بوو؟»
class RateCard extends StatefulWidget {
  const RateCard({super.key, required this.tripId});
  final String tripId;
  @override
  State<RateCard> createState() => _RateCardState();
}

class _RateCardState extends State<RateCard> {
  int _stars = 5;
  final Set<String> _tags = {};
  bool _busy = false;
  // تاگەکان بە کوردی بۆ شۆفێر هەڵدەگیرێن؛ تەنها پیشاندان وەردەگێڕدرێت
  static const _all = ['لەکاتی خۆیدا', 'ئارام لێدەخوڕێت', 'ئۆتۆمبێلی پاک', 'ڕێزدار', 'ئاگاداری منداڵ بوو']; // i18n-keep

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.read<Cloud>();
    final pts = (cloud.config['pointsPerRating'] as num?) ?? 0;
    return YkCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('گەشتەکە چۆن بوو؟'), style: Ts.h3(context)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var n = 1; n <= 5; n++)
            IconButton(
              tooltip: Fmt.n(tr('{0} ئەستێرە', [n])),
              onPressed: () => setState(() => _stars = n),
              icon: YkIcon('star', size: 34, color: t.amber, stroke: 1.5, fill: n <= _stars ? t.amber : null),
            ),
        ]),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final g in _all) YkChip(tr(g), on: _tags.contains(g), onTap: () => setState(() => _tags.contains(g) ? _tags.remove(g) : _tags.add(g))),
        ]),
        const SizedBox(height: 12),
        YkButton(
          pts > 0 ? Fmt.n(tr('ناردنی هەڵسەنگاندن، +{0} خاڵ', [pts])) : tr('ناردنی هەڵسەنگاندن'),
          block: true,
          busy: _busy,
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await cloud.rateDriver(widget.tripId, _stars, _tags.toList());
                    if (context.mounted) toast(context, pts > 0 ? Fmt.n(tr('سوپاس! {0} خاڵ زیاد کرا', [pts])) : tr('سوپاس!'));
                  } catch (_) {
                    if (context.mounted) toast(context, tr('هەڵسەنگاندنەکە نەنێردرا، دووبارە هەوڵ بدە'));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
      ]),
    );
  }
}

/// «کێ لەگەڵمە»: تەکسی هاوبەش بە ڕیزی سوارکردن
class CoRidersCard extends StatelessWidget {
  const CoRidersCard({super.key, required this.trip});
  final Json trip;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final co = coRiders(trip);
    final others = coRidersOthers(trip);
    final mine = co.where((c) => c['mine'] == true).firstOrNull;
    final before = mine == null ? 0 : co.where((c) => c['mine'] != true && (c['order'] as int) < (mine['order'] as int) && c['done'] != true).length;
    return YkCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IcoBox('users', bg: t.infoBg, color: t.infoText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Fmt.n(tr('تەکسی هاوبەش، {0} کەسی تر لەگەڵتن', [others])), style: Ts.bold(context)),
              Text(tr('بە ڕیزی سوارکردن. تەنها ناوی یەکەم پیشان دەدرێت'), style: Ts.muted(context, size: 12.8)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        for (final c in co)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c['mine'] == true ? t.noteBg : t.chip,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Opacity(
              opacity: c['absent'] == true ? .55 : 1,
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.card),
                  child: Text(Fmt.n(c['order']), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t.text)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (c['mine'] == true) Text(tr('تۆ'), style: Ts.bold(context)),
                    for (final p in (c['people'] as List).cast<Json>()) PersonChip(p),
                  ]),
                ),
                if (c['absent'] == true)
                  YkBadge(tr('نەهات'), tone: BadgeTone.danger)
                else if (c['done'] == true)
                  Text(tr('سوار بوو'), style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, color: t.okText)),
              ]),
            ),
          ),
        if (trip['status'] != 'done' && mine != null && mine['done'] != true && before > 0) ...[
          const SizedBox(height: 8),
          Text(Fmt.n(tr('شۆفێر سەرەتا {0} وێستگە دەڕوات، پاشان دێت بۆ لای تۆ', [before])), style: Ts.muted(context, size: 12.8)),
        ],
      ]),
    );
  }
}
