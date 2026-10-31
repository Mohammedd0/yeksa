// بەشداری نوێ: سێ هەنگاو (سەرنشینەکان ← شوێن و کات ← نرخ و ناردن)، هەمان ڕیزبەندی وەشانی وێب
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cloud.dart';
import '../core/draft.dart';
import '../core/format.dart';
import '../core/live.dart' show toGeo;
import '../core/maps_status.dart';
import '../core/pricing.dart';
import '../core/request_actions.dart';
import '../core/sel.dart';
import '../ui/form_parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'drivers_screen.dart';
import 'location_picker.dart';
import 'nav.dart';
import 'request_screen.dart';
import 'subs_screen.dart' show RequestsScreen;

/// ڕەشنووسی ئێستا (U.draft). کاتێک پەڕەکە دادەخرێت لادەبرێت
class DraftHolder {
  static Draft? current;
  static bool open = false;
}

/// دەستپێکردنی بەشداری نوێ. ئەگەر شۆفێرێک دیاری کرابێت (بەشداری لەگەڵ ...)، ڕەشنووسەکە بەردەوام دەبێت
void startSub(BuildContext context, {String? prefDriver}) {
  final cloud = context.read<Cloud>();
  if (DraftHolder.open && DraftHolder.current != null) {
    if (prefDriver != null && DraftHolder.current!.replacesSub == null) DraftHolder.current!.prefDriver = prefDriver;
    Navigator.of(context).popUntil((r) => r.settings.name == 'new' || r.isFirst);
    return;
  }
  DraftHolder.current = Draft.fresh(cloud, prefDriver: prefDriver);
  Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'new'), builder: (_) => const NewSubScreen()));
}

/// دوای ناردن: پەڕەکان دادەخرێن و داواکارییەکە دەکرێتەوە
void afterSend(BuildContext context, List<String> ids, String msg) {
  DraftHolder.current = null;
  final nav = Navigator.of(context);
  toast(context, msg);
  nav.popUntil((r) => r.isFirst);
  nav.push(MaterialPageRoute(builder: (_) => ids.length == 1 ? RequestScreen(id: ids.first) : const RequestsScreen()));
}

/// ناردنی داواکاری ڕاستەوخۆ بۆ شۆفێرێک
Future<void> sendDirect(BuildContext context, String driverId) async {
  final dr = DraftHolder.current;
  final cloud = context.read<Cloud>();
  if (dr == null || !dr.ready) {
    startSub(context, prefDriver: driverId);
    return;
  }
  final ids = await cloud.createRequests(dr, driverId);
  if (!context.mounted) return;
  afterSend(context, ids, 'داواکارییەکە بۆ ${str(cloud.driver(driverId)?['name'])} نێردرا');
}

Future<void> broadcast(BuildContext context) async {
  final dr = DraftHolder.current;
  if (dr == null) return;
  final ids = await context.read<Cloud>().createRequests(dr, 'all');
  if (!context.mounted) return;
  afterSend(context, ids, 'داواکارییەکەت بڵاو کرایەوە');
}

class NewSubScreen extends StatefulWidget {
  const NewSubScreen({super.key});
  @override
  State<NewSubScreen> createState() => _NewSubScreenState();
}

class _NewSubScreenState extends State<NewSubScreen> {
  final _scroll = ScrollController();
  bool _busy = false;

  Draft get dr => DraftHolder.current ??= Draft.fresh(context.read<Cloud>());

  @override
  void initState() {
    super.initState();
    DraftHolder.open = true;
  }

  @override
  void dispose() {
    DraftHolder.open = false;
    DraftHolder.current = null;
    _scroll.dispose();
    super.dispose();
  }

  void _set(VoidCallback f) => setState(f);

  void _step(int d) {
    setState(() => dr.step = (dr.step + d).clamp(1, 3).toInt());
    if (_scroll.hasClients) _scroll.jumpTo(0);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    context.watch<Cloud>();
    const steps = ['سەرنشینەکان', 'شوێن و کات', 'نرخ و ناردن'];
    final d = dr;
    final body = d.step == 1
        ? _step1(context)
        : d.step == 2
            ? _step2(context)
            : _step3(context);
    return PopScope(
      canPop: d.step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _step(-1);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 14, 16, 32 + MediaQuery.of(context).padding.bottom),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  YkHeader('بەشداری نوێ', sub: Fmt.n('هەنگاوی ${d.step} لە ٣، ${steps[d.step - 1]}')),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(4)),
                          alignment: AlignmentDirectional.centerStart,
                          child: AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 400),
                            widthFactor: i < d.step ? 1 : 0,
                            child: Container(decoration: BoxDecoration(color: t.act, borderRadius: BorderRadius.circular(4))),
                          ),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(key: ValueKey(d.step), child: body),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gap(List<Widget> c, [double g = 14]) {
    final out = <Widget>[];
    for (var i = 0; i < c.length; i++) {
      if (i > 0) out.add(SizedBox(height: g));
      out.add(c[i]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
  }

  /* ---------------- هەنگاوی ١: کێ سوار دەبێت ---------------- */

  Widget _step1(BuildContext context) {
    final t = context.yk;
    final cloud = context.read<Cloud>();
    final d = dr;
    final all = cloud.members;
    final mem = cloud.draftMembers(d);
    final hasChild = mem.any((m) => m['kind'] == 'child');
    final hasAdult = mem.any((m) => m['kind'] != 'child');
    final mixed = hasChild && hasAdult;

    Widget shieldCard(String bold, String rest) => YkCard(
          tone: CardTone.info,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            YkIcon('shield', size: 20, color: t.infoText),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(TextSpan(children: [
                if (bold.isNotEmpty) TextSpan(text: '$bold ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: rest),
              ]), style: TextStyle(fontSize: 14, height: 1.6, color: t.infoText)),
            ),
          ]),
        );

    final typeBlock = <Widget>[];
    if (mem.isNotEmpty) {
      if (mixed && d.mode == 'one') {
        typeBlock.add(shieldCard('تەنها خێزانەکەت لە ئۆتۆمبێلەکەدا دەبن.', 'چونکە منداڵ لەگەڵ کەسی گەورەی خێزانەکەیەتی، کەسی نەناسراو سوار ناکرێت. تەنها شۆفێری پشکنراوی منداڵان.'));
      } else {
        final lbl = hasChild && !hasAdult
            ? const [('shared', 'لەگەڵ منداڵانی تر', 'تەنها منداڵ لە ئۆتۆمبێلەکەدا دەبن، هەرزانتر'), ('private', 'تەنها منداڵەکانی خۆم', 'کەسی تر سوار ناکرێت')]
            : hasChild
                ? const [('shared', 'هاوبەش', 'منداڵ تەنها لەگەڵ منداڵ، گەورە لەگەڵ گەورە'), ('private', 'تایبەت', 'هەر کەسێک تەکسی تایبەتی خۆی')]
                : const [('shared', 'هاوبەش لەگەڵ کەسانی تر', 'هەرزانتر، لەسەر ڕێگاکەت'), ('private', 'تەکسی تایبەت', 'تەنها تۆ، ٤٠٪ زیاتر')];
        typeBlock.add(_gap([
          Text('جۆری گەشت', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.muted)),
          for (final o in lbl)
            Semantics(
              selected: d.rideType == o.$1,
              child: _SelCard(
                on: d.rideType == o.$1,
                onTap: () => _set(() => d.rideType = o.$1),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.$2, style: Ts.bold(context)),
                      Text(o.$3, style: Ts.muted(context, size: 12.8)),
                    ]),
                  ),
                  YkCheck(d.rideType == o.$1, radio: true),
                ]),
              ),
            ),
        ], 8));
        if (hasChild) typeBlock.add(shieldCard('', 'منداڵ هەرگیز لەگەڵ کەسی گەورەی نەناسراو سوار ناکرێت. تەنها شۆفێرانی پشکنراوی منداڵان دەیبینن.'));
      }
    }

    return _gap([
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('کێ سوار دەبێت؟', style: Ts.h3(context)),
        Text('دەتوانیت چەند کەسێک هەڵبژێریت', style: Ts.muted(context, size: 14)),
      ]),
      YkList(children: [
        for (final m in all)
          _MemberRow(
            m: m,
            photo: cloud.memberPhoto(m['id']),
            on: d.memberIds.contains(m['id']),
            onTap: () => _set(() {
              final id = str(m['id']);
              d.memberIds.contains(id) ? d.memberIds.remove(id) : d.memberIds.add(id);
              if (d.memberIds.length < 2) d.mode = 'one';
            }),
          ),
      ]),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: YkButton('زیادکردنی ئەندام', icon: 'plus', kind: BtnKind.ghost, small: true, onPressed: () => openLink(context, 'family')),
      ),
      if (mem.length > 1)
        _gap([
          Text(Fmt.n('${mem.length} کەس هەڵبژێردران. چۆن بڕۆن؟'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.muted)),
          YkSeg<String>(options: const [('one', 'یەک تەکسی پێکەوە'), ('separate', 'تەکسی جیا')], value: d.mode, onChanged: (v) => _set(() => d.mode = v)),
          Text(
            d.mode == 'one' ? 'هەموویان پێکەوە لە یەک ئۆتۆمبێلدا. کەسی دووەم بەدواوە ٣٠٪ هەرزانترە.' : 'بۆ هەر کەسێک داواکارییەکی جیا دروست دەکرێت و هەر یەکەی شۆفێری خۆی دەبێت.',
            style: Ts.muted(context, size: 12.8),
          ),
        ], 8),
      ...typeBlock,
      if (mem.isNotEmpty)
        YkCard(
          child: Row(children: [
            IcoBox('woman', bg: t.wBg, color: t.wText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تەنها شۆفێری ئافرەت', style: Ts.bold(context)),
                Text('تەنها شۆفێرە ئافرەتەکان داواکارییەکە دەبینن', style: Ts.muted(context, size: 12.8)),
              ]),
            ),
            YkToggle(value: d.womanOnly, onChanged: (v) => _set(() => d.womanOnly = v)),
          ]),
        ),
      YkButton('دواتر', block: true, onPressed: mem.isEmpty ? null : () => _step(1)),
      if (mem.isEmpty) const YkHint('سەرەتا کەسێک هەڵبژێرە کە سوار دەبێت'),
    ]);
  }

  /* ---------------- هەنگاوی ٢: شوێن و کات ---------------- */

  Widget _step2(BuildContext context) {
    final t = context.yk;
    final cloud = context.read<Cloud>();
    final d = dr;
    final km = d.fromId.isNotEmpty && d.toId.isNotEmpty ? cloud.distance(d.fromId, d.toId, d.fromGeo, d.toGeo) : 0.0;
    Widget lbl(String text, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            YkIcon('pin', size: 14, color: c),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w700, color: t.muted)),
          ]),
        );
    Widget note(String key) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextFormField(
            key: ValueKey('note-$key-${key == 'from' ? d.fromId : d.toId}'),
            initialValue: key == 'from' ? d.fromNote : d.toNote,
            onChanged: (v) => key == 'from' ? d.fromNote = v : d.toNote = v,
            decoration: ykInput(context,
                hint: key == 'from' ? 'وردەکاری: ناوی کۆڵان، نزیک... (ئارەزوومەندانە)' : 'وردەکاری: دەرگای سەرەکی، نهۆم... (ئارەزوومەندانە)'),
          ),
        );
    final ok = d.fromId.isNotEmpty && d.toId.isNotEmpty && d.schedOk;
    final timesBlock = d.perDay != null
        ? <Widget>[]
        : <Widget>[
            _gap([
              Text('جۆری هاتووچۆ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.text)),
              YkSeg<String>(
                options: const [('both', 'چوون و هاتنەوە'), ('go', 'تەنها چوون'), ('back', 'تەنها هاتنەوە')],
                value: d.dir,
                onChanged: (v) => _set(() => d.dir = v),
              ),
            ], 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (d.dir != 'back')
                Expanded(child: YkField(label: 'کاتی چوون', child: TimeField(value: d.go, title: 'کاتی چوون', onChanged: (v) => _set(() => d.go = v)))),
              if (d.dir == 'both') const SizedBox(width: 10),
              if (d.dir != 'go')
                Expanded(
                    child: YkField(label: 'کاتی هاتنەوە', child: TimeField(value: d.backTime, title: 'کاتی هاتنەوە', onChanged: (v) => _set(() => d.backTime = v)))),
            ]),
            if (d.dir != 'both')
              Text('${d.dir == 'go' ? 'تەنها لە ماڵەوە بۆ شوێنی مەبەست' : 'تەنها لە شوێنی مەبەستەوە بۆ ماڵەوە'}، نرخ کەمترە', style: Ts.muted(context, size: 12.8)),
          ];
    return _gap([
      YkCard(
        child: _gap([
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            lbl('لە کوێوە (شوێنی سوار بوون)', t.success),
            PlaceField(draftKey: 'from', draft: d, onChanged: () => _set(() {})),
            if (d.fromId.isNotEmpty) note('from'),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            lbl('بۆ کوێ (شوێنی مەبەست)', t.amber),
            PlaceField(draftKey: 'to', draft: d, onChanged: () => _set(() {})),
            if (d.toId.isNotEmpty) note('to'),
          ]),
          if (km > 0) IconLine('route', Fmt.n('نزیکەی ${km.toStringAsFixed(1)} کیلۆمەتر، ${(km * 2.5 + 8).round()} خولەک'), muted: true),
        ]),
      ),
      YkCard(
        child: _gap([
          ...timesBlock,
          YkField(label: 'ڕۆژی دەستپێکردن', child: DateField(value: d.startDate, title: 'ڕۆژی دەستپێکردن', onChanged: (v) => _set(() => d.startDate = v))),
          Text('مانگی یەکەم بە پێی ڕۆژە ماوەکان حیساب دەکرێت', style: Ts.muted(context, size: 12.8)),
        ], 12),
      ),
      YkCard(
        child: _gap([
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('هەموو ڕۆژەکان هەمان کات نین', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.text)),
                Text('بۆ نموونە هەندێک ڕۆژ دەوامی بەیانی و هەندێک ڕۆژ نیوەڕۆ، یان هەندێک ڕۆژ تەنها چوون', style: Ts.muted(context, size: 12.8)),
              ]),
            ),
            const SizedBox(width: 10),
            YkToggle(value: d.perDay != null, onChanged: (_) => _set(d.togglePerDay)),
          ]),
          if (d.perDay != null) _perDayTable(context),
        ], 12),
      ),
      YkCard(
        child: _gap([
          Row(children: [
            Expanded(child: Text('ڕۆژەکانی هەفتە', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.text))),
            Text(d.days.contains(true) ? fmtDays(d.days) : 'هیچ ڕۆژێک', style: Ts.muted(context, size: 12.8)),
          ]),
          DaysPicker(days: d.days, onToggle: (i) => _set(() => d.toggleDay(i))),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in kDayPresets) YkChip(p.$2, on: presetOn(d.days, p.$1), onTap: () => _set(() => d.setDays(presetDays(p.$1)))),
          ]),
        ], 12),
      ),
      Row(children: [
        YkButton('گەڕانەوە', kind: BtnKind.secondary, onPressed: () => _step(-1)),
        const SizedBox(width: 10),
        Expanded(child: YkButton('بینینی نرخ', block: true, onPressed: ok ? () => _step(1) : null)),
      ]),
      if (d.toId.isEmpty)
        const YkHint('شوێنی مەبەست هەڵبژێرە بۆ بینینی نرخ')
      else if (d.fromId.isEmpty)
        const YkHint('شوێنی سوار بوون هەڵبژێرە')
      else if (!d.schedOk)
        YkHint('لانیکەم یەک ڕۆژی هەفتە هەڵبژێرە${d.perDay != null ? ' و چوون یان هاتنەوەی بۆ دیاری بکە' : ''}'),
    ]);
  }

  /// خشتەی کاتی هەر ڕۆژێک
  Widget _perDayTable(BuildContext context) {
    final t = context.yk;
    final d = dr;
    final rows = [for (var i = 0; i < 7; i++) if (d.days[i]) i];
    if (rows.isEmpty) return Text('سەرەتا ڕۆژەکان هەڵبژێرە', style: Ts.muted(context, size: 12.8));
    Widget cell(int i, String dir) {
      final v = d.perDay?['$i']?[dir];
      if (v == null) {
        return InkWell(
          onTap: () => _set(() => d.toggleLeg(i, dir)),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line, width: 1.5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              YkIcon('plus', size: 14, color: t.muted),
              const SizedBox(width: 4),
              Text(dir == 'go' ? 'چوون' : 'هاتنەوە', style: TextStyle(fontSize: 13, color: t.muted, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      }
      return Row(children: [
        Expanded(child: TimeField(value: v, dense: true, title: '${kWeekdays[i]}، ${dir == 'go' ? 'چوون' : 'هاتنەوە'}', onChanged: (x) => _set(() => d.setLegTime(i, dir, x)))),
        SizedBox(
          width: 30,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'لابردن',
            onPressed: () => _set(() => d.toggleLeg(i, dir)),
            icon: YkIcon('x', size: 14, color: t.muted, stroke: 2.4),
          ),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const SizedBox(width: 74),
        Expanded(child: Text('چوون', textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8))),
        const SizedBox(width: 8),
        Expanded(child: Text('هاتنەوە', textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8))),
      ]),
      for (final i in rows)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            SizedBox(width: 74, child: Text(kWeekdays[i], style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, color: t.text))),
            Expanded(child: cell(i, 'go')),
            const SizedBox(width: 8),
            Expanded(child: cell(i, 'back')),
          ]),
        ),
      const SizedBox(height: 8),
      Row(children: [
        YkIcon('x', size: 12, color: t.muted),
        const SizedBox(width: 4),
        Expanded(child: Text('واتە ئەو ڕۆژە ئەو بەشەی نییە، بۆ نموونە «بەیانی خۆم دەیبەم».', style: Ts.muted(context, size: 12.8))),
      ]),
    ]);
  }

  /* ---------------- هەنگاوی ٣: نرخ و ناردن ---------------- */

  Widget _step3(BuildContext context) {
    final t = context.yk;
    final cloud = context.read<Cloud>();
    final d = dr;
    final q = cloud.draftQuote(d);
    final total = q.fold<int>(0, (n, x) => n + x.price);
    final mem = cloud.draftMembers(d);
    final asReq = cloud.draftAsReq(d);
    final fitsN = cloud.drivers.where((x) => cloud.fits(x, asReq)).length;
    final pref = d.prefDriver == null ? null : cloud.driver(d.prefDriver);
    final prefFits = pref != null && cloud.fits(pref, cloud.draftAsReq(d, str(pref['id'])));
    final b = cloud.offerBounds(total);
    final summary = <String, dynamic>{
      'from': '${str(cloud.place(d.fromId)?['name'])}${d.fromNote.trim().isNotEmpty ? '، ${d.fromNote.trim()}' : ''}',
      'to': '${str(cloud.place(d.toId)?['name'])}${d.toNote.trim().isNotEmpty ? '، ${d.toNote.trim()}' : ''}',
      'startDate': d.startDate,
      ...d.sched(),
    };

    Future<void> run(Future<void> Function() f) async {
      if (_busy) return;
      setState(() => _busy = true);
      try {
        await f();
      } catch (e) {
        if (context.mounted) toast(context, 'هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    Widget pickCard({required String icon, required Color bg, required Color ic, required String title, required String sub, required VoidCallback onTap}) =>
        YkCard(
          onTap: _busy ? null : onTap,
          tone: CardTone.normal,
          child: Row(children: [
            IcoBox(icon, size: 46, bg: bg, color: ic, iconSize: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Ts.bold(context)),
                Text(sub, style: Ts.muted(context, size: 12.8)),
              ]),
            ),
            YkIcon('forward', size: 20, color: t.muted),
          ]),
        );

    final old = d.replacesSub == null ? null : cloud.sub(d.replacesSub);
    return _gap([
      // گۆڕینی شۆفێر: ئاگادارکردنەوە و دوگمەی هەڵوەشاندنەوەی ڕەشنووس (dropDraft)
      if (old != null)
        YkCard(
          tone: CardTone.note,
          child: Row(children: [
            YkIcon('swap', size: 20, color: t.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'گۆڕینی شۆفێر: کاتێک لەگەڵ شۆفێری نوێ ڕێککەوتیت، بەشدارییەکەت لەگەڵ '),
                  TextSpan(text: str((cloud.driver(old['driverId']) ?? const {})['name']).isEmpty ? 'شۆفێری ئێستا' : str(cloud.driver(old['driverId'])!['name']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' هەڵدەوەشێتەوە.'),
                ]),
                style: Ts.sm(context),
              ),
            ),
            const SizedBox(width: 8),
            YkButton('هەڵوەشاندنەوە', small: true, kind: BtnKind.secondary, onPressed: () {
              DraftHolder.current = null;
              Navigator.of(context).popUntil((r) => r.isFirst);
              ShellTabs.index.value = 2;
            }),
          ]),
        ),
      YkCard(
        big: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('نرخی پێشنیارکراوی مانگانە', style: Ts.bold(context))),
            const YkBadge('مەزەندە', tone: BadgeTone.note),
          ]),
          const SizedBox(height: 4),
          Text(Fmt.money(total), style: Ts.h1(context).copyWith(color: t.brand)),
          Text(Fmt.n('شۆفێرەکان دەتوانن لە نێوان ${Fmt.group(b.min)} تا ${Fmt.group(b.max)} دینار نرخی خۆیان پێشنیار بکەن. تۆ هەموو نرخەکان دەبینیت و هەڵدەبژێریت.'),
              style: Ts.muted(context, size: 12.8)),
          if (q.length > 1) ...[
            const YkHr(),
            for (final x in q)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(child: Text(x.names, style: Ts.sm(context))),
                  Text(Fmt.money(x.price), style: Ts.sm(context).copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ]),
      ),
      YkCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(Fmt.names(mem.map((m) => str(m['name'])).toList()), style: Ts.sm(context).copyWith(fontWeight: FontWeight.w700))),
            if (q.length > 1) YkBadge(Fmt.n('${q.length} داواکاری'), tone: BadgeTone.info),
          ]),
          const SizedBox(height: 4),
          RequestSummary(summary),
          const SizedBox(height: 8),
          RequestTags({'hasChild': mem.any((m) => m['kind'] == 'child'), 'rideType': q.first.rideType, 'womanOnly': d.womanOnly, 'riders': d.mode == 'one' ? mem.length : 1}),
        ]),
      ),
      YkField(
        label: 'تێبینی بۆ شۆفێر',
        optional: true,
        child: TextFormField(
          initialValue: d.note,
          minLines: 2,
          maxLines: 5,
          onChanged: (v) => d.note = v,
          decoration: ykInput(context, hint: 'بۆ نموونە: کورسیی منداڵ پێویستە'),
        ),
      ),
      if (pref != null) ...[
        YkButton('ناردن بۆ ${str(pref['name'])}',
            icon: 'send', block: true, busy: _busy, onPressed: prefFits ? () => run(() => sendDirect(context, str(pref['id']))) : null),
        if (!prefFits) YkError('${str(pref['name'])} بۆ ئەم گەشتە ناگونجێت (کورسی، منداڵ یان ئافرەت)'),
        YkButton('بڵاوکردنەوە بۆ هەموو شۆفێرەکان', icon: 'megaphone', kind: BtnKind.secondary, block: true, onPressed: _busy ? null : () => run(() => broadcast(context))),
      ] else ...[
        pickCard(
          icon: 'megaphone',
          bg: t.silver,
          ic: t.act,
          title: 'بڵاوکردنەوە بۆ هەموو شۆفێرەکان',
          sub: Fmt.n('$fitsN شۆفێری گونجاو دەیبینن و نرخ دەنێرن، پێشنیارکراو'),
          onTap: () => run(() => broadcast(context)),
        ),
        pickCard(
          icon: 'search',
          bg: t.chip,
          ic: t.text,
          title: 'خۆم شۆفێر هەڵدەبژێرم',
          sub: 'لیستی شۆفێرەکان ببینە و ڕاستەوخۆ بۆ یەکێکیان بنێرە',
          onTap: () => push(context, const DriversScreen()),
        ),
      ],
      YkButton('گەڕانەوە', kind: BtnKind.ghost, block: true, onPressed: () => _step(-1)),
    ]);
  }
}

/// کارتی هەڵبژاردن (.card.selected)
class _SelCard extends StatelessWidget {
  const _SelCard({required this.on, required this.onTap, required this.child});
  final bool on;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: on ? t.silver : t.glass,
          borderRadius: BorderRadius.circular(Yk.rLg),
          border: Border.all(color: on ? t.act : t.glassLine, width: on ? 2 : 1),
        ),
        child: child,
      ),
    );
  }
}

/// ڕیزی ئەندام لە لیستی «کێ سوار دەبێت»
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.m, required this.on, required this.onTap, this.photo});
  final Json m;
  final bool on;
  final VoidCallback onTap;
  final String? photo;
  @override
  Widget build(BuildContext context) {
    final kid = m['kind'] == 'child';
    final age = m['age'];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          PersonAvatar(size: 40, imageId: photo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(m['name']), style: Ts.bold(context).copyWith(height: 1.4)),
              Text(Fmt.n('${str(m['relation'])}${kid && age != null ? '، $age ساڵ' : ''}'), style: Ts.muted(context, size: 12.8)),
            ]),
          ),
          if (kid) ...[const YkBadge('منداڵ', tone: BadgeTone.note), const SizedBox(width: 8)],
          YkCheck(on),
        ]),
      ),
    );
  }
}

/// خانەی شوێن: بنووسە و ئەپەکە شوێنەکە دەدۆزێتەوە («بەخت» ← گەڕەکی بەختیاری)
class PlaceField extends StatefulWidget {
  const PlaceField({super.key, required this.draftKey, required this.draft, required this.onChanged});
  final String draftKey;
  final Draft draft;
  final VoidCallback onChanged;
  @override
  State<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<PlaceField> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.draftKey == 'from' ? widget.draft.fromQ : widget.draft.toQ);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick(String id) {
    widget.draft.setId(widget.draftKey, id);
    widget.draft.setQ(widget.draftKey, '');
    _ctrl.clear();
    _focus.unfocus();
    widget.onChanged();
  }

  void _clear() {
    widget.draft.setId(widget.draftKey, '');
    widget.draft.setQ(widget.draftKey, '');
    widget.draft.setGeo(widget.draftKey, null);
    widget.onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// دیاریکردنی شوێنی ورد لەسەر نەخشە یان شوێنی ئێستای مۆبایل
  Future<void> _pin(bool here) async {
    final cloud = context.read<Cloud>();
    final key = widget.draftKey;
    final d = widget.draft;
    final id = d.idOf(key) ?? '';
    final cur = toGeo(key == 'from' ? d.fromGeo : d.toGeo) ?? toGeo(cloud.placeGeo(id));
    _focus.unfocus();
    // بێ Google Maps: «شوێنی ئێستام» ڕاستەوخۆ لە GPS ـەوە وەردەگیرێت
    if (MapsStatus.failed.value) {
      if (!here) return;
      final (pos, err) = await currentLocation();
      if (!mounted) return;
      if (pos == null) {
        toast(context, err ?? 'نەتوانرا شوێنەکەت بدۆزرێتەوە');
        return;
      }
      d.setGeo(key, {'lat': pos.lat, 'lng': pos.lng});
      widget.onChanged();
      return;
    }
    final g = await pickLocation(context, title: key == 'from' ? 'شوێنی سوار بوون' : 'شوێنی مەبەست', center: cur, useHere: here);
    if (g == null || !mounted) return;
    d.setGeo(key, {'lat': g.lat, 'lng': g.lng});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.read<Cloud>();
    final key = widget.draftKey;
    final d = widget.draft;
    final color = key == 'from' ? t.success : t.amber;
    final id = d.idOf(key) ?? '';
    final pl = id.isEmpty ? null : cloud.place(id);
    if (pl != null) {
      final pg = cloud.placeGeo(id);
      final geo = key == 'from' ? d.fromGeo : d.toGeo;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(Yk.rMd), border: Border.all(color: t.act, width: 2)),
          child: Row(children: [
            YkIcon(placeIcon(pl['kind']), size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(str(pl['name']), style: Ts.bold(context))),
            YkLink('گۆڕین', onTap: _clear),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          YkIcon(geo != null ? 'check' : 'pin', size: 16, color: geo != null ? t.okText : t.muted, stroke: geo != null ? 2.6 : 2),
          const SizedBox(width: 6),
          Expanded(
            child: Text(geo != null ? 'شوێنی ورد لەسەر نەخشە دیاری کرا' : pg != null ? 'شوێنی گشتی ئەم ناوچەیە' : 'شوێنی ورد دیاری نەکراوە',
                style: TextStyle(fontSize: 13, color: geo != null ? t.okText : t.muted)),
          ),
          if (!MapsStatus.failed.value) YkLink(geo != null ? 'گۆڕین' : 'دیاریکردن لەسەر نەخشە', size: 13, onTap: () => _pin(false)),
        ]),
      ]);
    }
    final other = key == 'from' ? d.toId : d.fromId;
    final q = _ctrl.text;
    final list = cloud.searchPlaces(q, other);
    final qq = q.trim();
    final geo = key == 'from' ? d.fromGeo : d.toGeo;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (geo != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            YkIcon('check', size: 16, color: t.okText, stroke: 2.6),
            const SizedBox(width: 6),
            Expanded(child: Text('شوێنی ورد وەرگیرا. ئێستا ناوی گەڕەکەکە بنووسە', style: TextStyle(fontSize: 13, color: t.okText))),
          ]),
        ),
      TextField(
        controller: _ctrl,
        focusNode: _focus,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: (v) => setState(() => d.setQ(key, v)),
        decoration: ykInput(
          context,
          hint: key == 'from' ? 'بنووسە، بۆ نموونە: ئازادی' : 'بنووسە، بۆ نموونە: بەخت',
          prefix: Padding(padding: const EdgeInsets.all(14), child: YkIcon('search', size: 20, color: t.muted)),
        ),
      ),
      if (list.isNotEmpty || qq.length >= 2)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final p in list) _sugg(context, placeIcon(p['kind']), t.muted, _mark(context, str(p['name']), qq), () => _pick(str(p['id']))),
            if (qq.length >= 2 && !list.any((p) => p['name'] == qq))
              _sugg(context, 'pin', t.brand, Text('بەکارهێنانی «$qq»', style: Ts.sm(context)), () => _pick('c:$qq')),
          ]),
        ),
      if (geo == null) ...[
        const SizedBox(height: 8),
        Row(children: [
          if (!MapsStatus.failed.value) ...[
            YkButton('لەسەر نەخشە', icon: 'pin', small: true, kind: BtnKind.secondary, onPressed: () => _pin(false)),
            const SizedBox(width: 8),
          ],
          YkButton('شوێنی ئێستام', icon: 'navigate', small: true, kind: BtnKind.secondary, onPressed: () => _pin(true)),
        ]),
      ],
    ]);
  }

  Widget _sugg(BuildContext context, String icon, Color ic, Widget label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          YkIcon(icon, size: 18, color: ic),
          const SizedBox(width: 10),
          Expanded(child: label),
        ]),
      ),
    );
  }

  /// بەشی دۆزراوە لە ناوەکەدا ڕەنگ دەکرێت (<mark>)
  Widget _mark(BuildContext context, String name, String q) {
    final t = context.yk;
    final i = q.isEmpty ? -1 : name.indexOf(q);
    if (i < 0) return Text(name, style: Ts.sm(context));
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: name.substring(0, i)),
        TextSpan(text: name.substring(i, i + q.length), style: TextStyle(backgroundColor: t.noteBg, fontWeight: FontWeight.w700)),
        TextSpan(text: name.substring(i + q.length)),
      ]),
      style: Ts.sm(context),
    );
  }
}
