// ڕاگرتن، گۆڕانکاری، گۆڕینی شۆفێر و هەڵوەشاندنەوەی بەشداری
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/account.dart';
import '../core/cloud.dart';
import '../core/draft.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/live.dart' show toGeo;
import '../core/pricing.dart';
import '../core/sel.dart';
import '../ui/form_parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'nav.dart';
import 'new_sub_screen.dart';
import 'request_screen.dart' show askConfirm;

Future<void> pauseSub(BuildContext context, String id) async {
  final cloud = context.read<Cloud>();
  final s = cloud.sub(id);
  if (s == null) return;
  final dn = str(cloud.driver(s['driverId'])?['name']);
  final paused = s['status'] == 'paused';
  if (!paused && !await askConfirm(context, tr('بەشدارییەکە ڕادەگیرێت و {0} ئاگادار دەکرێتەوە.', [dn]), yes: tr('ڕاگرتن'))) return;
  await cloud.toggleSubPause(id);
  if (context.mounted) toast(context, paused ? tr('دەستی پێکردەوە، {0} ئاگادار کرا', [dn]) : tr('ڕاگیرا، {0} ئاگادار کرا', [dn]));
}

/// گۆڕینی شۆفێر: بەشدارییەکی نوێ بە هەمان زانیاری، کە دوای ڕێککەوتن بەشداری کۆن هەڵدەوەشێنێتەوە
void changeDriver(BuildContext context, String id) {
  final cloud = context.read<Cloud>();
  final x = cloud.sub(id);
  if (x == null) return;
  String findId(String name) {
    for (final p in cloud.places) {
      if (name.startsWith(str(p['name']))) return str(p['id']);
    }
    return 'c:${name.split('، ').first}'; // i18n-keep
  }

  final d = Draft.fresh(cloud)
    ..step = 3
    ..memberIds = asList(x['memberIds']).map(str).toList()
    ..mode = str(x['mode']).isEmpty ? 'one' : str(x['mode'])
    ..rideType = x['rideType'] == 'private' ? 'private' : 'shared'
    ..womanOnly = x['womanOnly'] == true
    ..fromId = findId(str(x['from']))
    ..toId = findId(str(x['to']))
    ..go = str(x['go']).isEmpty ? '07:30' : str(x['go'])
    ..dir = str(x['go']).isNotEmpty && str(x['back']).isNotEmpty ? 'both' : str(x['go']).isNotEmpty ? 'go' : 'back'
    ..backTime = str(x['back']).isEmpty ? '14:00' : str(x['back'])
    ..days = List.generate(7, (i) => asList(x['days']).length > i && asList(x['days'])[i] == true)
    ..note = 'بۆ گۆڕینی شۆفێر' // i18n-keep
    ..replacesSub = id;
  // هەمان شوێنی وردی بەشدارییە کۆنەکە (نەک شوێنی ماڵ)
  final fg = toGeo(x['fromGeo']), tg = toGeo(x['toGeo']);
  d.fromGeo = fg == null ? null : {'lat': fg.lat, 'lng': fg.lng};
  d.toGeo = tg == null ? null : {'lat': tg.lat, 'lng': tg.lng};
  if (hasPerDay(x)) {
    d.perDay = {
      for (final e in asMap(x['perDay']).entries) e.key: {'go': asMap(e.value)['go'] as String?, 'back': asMap(e.value)['back'] as String?},
    };
  }
  final nav = Navigator.of(context);
  final msg = ScaffoldMessenger.maybeOf(context);
  nav.pop();
  DraftHolder.current = d;
  nav.push(MaterialPageRoute(settings: const RouteSettings(name: 'new'), builder: (_) => const NewSubScreen()));
  msg?.showSnackBar(SnackBar(content: Text(tr('شۆفێری نوێ هەڵبژێرە. کاتێک ڕێککەوتن، بەشداری کۆن هەڵدەوەشێتەوە'))));
}

/// گۆڕانکاری لە کات و ڕۆژەکان
void editSub(BuildContext context, String id) {
  final cloud = context.read<Cloud>();
  final x = cloud.sub(id);
  if (x == null) return;
  final per = hasPerDay(x);
  bool has(String dir) => per ? asMap(x['perDay']).values.any((e) => asMap(e)[dir] != null) : str(x[dir]).isNotEmpty;
  final allow = {'go': has('go'), 'back': has('back')};
  // Draft بۆ هەڵگرتنی کات و ڕۆژەکان و خشتەی هەر ڕۆژێک بەکاردێت
  final e = Draft()
    ..go = str(x['go']).isEmpty ? '07:30' : str(x['go'])
    ..backTime = str(x['back']).isEmpty ? '14:00' : str(x['back'])
    ..dir = allow['go']! && allow['back']! ? 'both' : allow['go']! ? 'go' : 'back'
    ..days = List.generate(7, (i) => asList(x['days']).length > i && asList(x['days'])[i] == true);
  if (per) {
    e.perDay = {
      for (final en in asMap(x['perDay']).entries) en.key: {'go': asMap(en.value)['go'] as String?, 'back': asMap(en.value)['back'] as String?},
    };
  }
  final d = cloud.driver(x['driverId']) ?? const {};
  var busy = false;

  showYkSheet(context, builder: (c) {
    return StatefulBuilder(builder: (c, setS) {
      final t = c.yk;
      Widget cell(int i, String dir) {
        final v = e.perDay?['$i']?[dir];
        if (v == null) {
          return InkWell(
            onTap: () {
              if (allow[dir] != true) {
                toast(c, dir == 'go' ? tr('ئەم بەشدارییە چوونی تێدا نییە. بۆ زیادکردنی، داواکارییەکی نوێ بنێرە') : tr('ئەم بەشدارییە هاتنەوەی تێدا نییە. بۆ زیادکردنی، داواکارییەکی نوێ بنێرە'));
                return;
              }
              setS(() => e.toggleLeg(i, dir));
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line, width: 1.5)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                YkIcon('plus', size: 14, color: t.muted),
                const SizedBox(width: 4),
                Text(dir == 'go' ? tr('چوون') : tr('هاتنەوە'), style: TextStyle(fontSize: 13, color: t.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }
        return Row(children: [
          Expanded(child: TimeField(value: v, dense: true, onChanged: (v2) => setS(() => e.setLegTime(i, dir, v2)))),
          SizedBox(
            width: 30,
            child: IconButton(padding: EdgeInsets.zero, onPressed: () => setS(() => e.toggleLeg(i, dir)), icon: YkIcon('x', size: 14, color: t.muted, stroke: 2.4)),
          ),
        ]);
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('گۆڕانکاری لە بەشداری'), style: Ts.h2(c)),
        const SizedBox(height: 4),
        Text(tr('{0}، {1}. هەر گۆڕانکارییەک بۆ شۆفێرەکە دەنێردرێت.', [Fmt.names(cloud.names(asList(x['memberIds']))), str(d['name'])]), style: Ts.muted(c, size: 14)),
        const SizedBox(height: 12),
        if (e.perDay == null)
          Row(children: [
            Expanded(
              child: Opacity(
                opacity: allow['go']! ? 1 : .45,
                child: YkField(
                  label: tr('کاتی چوون'),
                  child: IgnorePointer(ignoring: !allow['go']!, child: TimeField(value: e.go, title: tr('کاتی چوون'), onChanged: (v) => setS(() => e.go = v))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Opacity(
                opacity: allow['back']! ? 1 : .45,
                child: YkField(
                  label: tr('کاتی هاتنەوە'),
                  child: IgnorePointer(ignoring: !allow['back']!, child: TimeField(value: e.backTime, title: tr('کاتی هاتنەوە'), onChanged: (v) => setS(() => e.backTime = v))),
                ),
              ),
            ),
          ]),
        const SizedBox(height: 12),
        DaysPicker(days: e.days, onToggle: (i) => setS(() => e.toggleDay(i))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('هەموو ڕۆژەکان هەمان کات نین'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.text)),
              Text(tr('کاتی جیاواز بۆ هەر ڕۆژێک'), style: Ts.muted(c, size: 12.8)),
            ]),
          ),
          YkToggle(value: e.perDay != null, onChanged: (_) => setS(e.togglePerDay)),
        ]),
        if (e.perDay != null) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < 7; i++)
            if (e.days[i])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  SizedBox(width: 74, child: Text(Fmt.weekday(i), style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: t.text))),
                  Expanded(child: cell(i, 'go')),
                  const SizedBox(width: 8),
                  Expanded(child: cell(i, 'back')),
                ]),
              ),
        ],
        const SizedBox(height: 14),
        YkButton(tr('پاشەکەوت و ناردن بۆ شۆفێر'), block: true, busy: busy, onPressed: () async {
          if (!e.days.contains(true)) {
            toast(c, tr('لانیکەم یەک ڕۆژ هەڵبژێرە'));
            return;
          }
          Map<String, dynamic> patch;
          if (e.perDay != null) {
            final n = normPerDay(e.perDay!);
            if (n.empty) {
              toast(c, tr('لانیکەم یەک چوون یان هاتنەوە دیاری بکە'));
              return;
            }
            patch = {'perDay': n.perDay, 'days': n.days, 'go': n.go, 'back': n.back};
          } else {
            patch = {'days': List<bool>.from(e.days), 'perDay': null};
            if (allow['go']!) patch['go'] = e.go;
            if (allow['back']!) patch['back'] = e.backTime;
          }
          setS(() => busy = true);
          await cloud.updateSub(id, patch);
          if (c.mounted) Navigator.pop(c);
          if (context.mounted) toast(context, tr('پاشەکەوت کرا و شۆفێرەکە ئاگادار کرایەوە'));
        }),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: YkButton(tr('نامە بۆ شۆفێر'), icon: 'chat', small: true, block: true, kind: BtnKind.secondary, onPressed: () {
              Navigator.pop(c);
              openLink(context, 'chat/${d['id'] ?? x['driverId']}');
            }),
          ),
          const SizedBox(width: 8),
          Expanded(child: YkButton(tr('گۆڕینی شۆفێر'), icon: 'swap', small: true, block: true, kind: BtnKind.secondary, onPressed: () => changeDriver(c, id))),
        ]),
        const SizedBox(height: 8),
        YkButton(tr('هەڵوەشاندنەوەی بەشداری'), small: true, block: true, kind: BtnKind.danger, onPressed: () async {
          if (!await askConfirm(c, tr('بەشدارییەکە هەڵدەوەشێنرێتەوە و گەشتە نەکراوەکان لادەبرێن. گەشتە کراوەکان لە «گەشتەکانم» دەمێننەوە.'), yes: tr('هەڵوەشاندنەوە'))) return;
          await cloud.cancelSub(id);
          if (c.mounted) Navigator.pop(c);
          if (context.mounted) toast(context, tr('بەشدارییەکە هەڵوەشێنرایەوە'));
        }),
        const SizedBox(height: 8),
        YkButton(tr('داخستن'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  });
}
