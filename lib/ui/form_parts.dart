// پێکهاتەکانی فۆرمی بەشداری: هەڵبژاردنی کات و ڕۆژ (ستایلی ئایفۆن)، سویچ، چیپ، ڕۆژەکانی هەفتە، کورتەی داواکاری
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/sel.dart';
import 'theme.dart';
import 'widgets.dart';
import 'yk_icon.dart';

/// کاتەکان لە ٥:٠٠ تا ٢٢:٠٠ بە پێنج خولەک (ui.timeSelect)
List<String> timeOptions([String? value]) {
  final out = <String>[];
  for (var m = 5 * 60; m <= 22 * 60; m += 5) {
    out.add('${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
  }
  if (value != null && value.isNotEmpty && !out.contains(value)) {
    out
      ..add(value)
      ..sort();
  }
  return out;
}

/// خانەیەک کە وەک .input دەردەکەوێت و پەنجەنان شتێک دەکاتەوە
class _TapField extends StatelessWidget {
  const _TapField({required this.text, required this.onTap, this.icon = 'clock', this.dense = false});
  final String text;
  final VoidCallback onTap;
  final String icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(dense ? 12 : Yk.rMd),
      child: Container(
        height: dense ? 40 : 50,
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(dense ? 12 : Yk.rMd),
          border: Border.all(color: t.line, width: 1.5),
        ),
        child: Row(children: [
          if (!dense) ...[YkIcon(icon, size: 18, color: t.muted), const SizedBox(width: 8)],
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: dense ? 13.6 : 16, fontWeight: dense ? FontWeight.w700 : FontWeight.w500, color: t.text)),
          ),
          YkIcon('down', size: dense ? 13 : 16, color: t.muted, stroke: 2.4),
        ]),
      ),
    );
  }
}

/// پەڕەی خوارەوەی ستایلی ئایفۆن بە چەرخێک (CupertinoPicker)
Future<int?> _wheelSheet(BuildContext context, {required String title, required List<String> labels, required int initial}) {
  var sel = initial;
  return showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    backgroundColor: context.yk.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (c) {
      final t = c.yk;
      // SingleChildScrollView: لە شاشەی نزم (وێب لە پەنجەرەی بچووک) دوگمەی «هەڵبژاردن» لە دەرەوەی شاشە نەمێنێتەوە
      // بۆشایی وەک .sheet: ١٠ لە سەرەوە، ٢٠ + safe-area لە خوارەوە
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + MediaQuery.viewPaddingOf(c).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 14),
          Text(title, style: Ts.h3(c), textAlign: TextAlign.center),
          SizedBox(
            height: 216,
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(initialItem: initial),
              itemExtent: 40,
              magnification: 1.08,
              useMagnifier: true,
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(background: t.chip.withValues(alpha: .7)),
              onSelectedItemChanged: (i) => sel = i,
              children: [
                for (final l in labels)
                  Center(child: Text(l, style: TextStyle(fontFamily: kFont, fontSize: 18, fontWeight: FontWeight.w600, color: t.text))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          YkButton(tr('هەڵبژاردن'), block: true, onPressed: () => Navigator.pop(c, sel)),
        ]),
      );
    },
  );
}

/// هەڵبژاردنی کات بە کوردی (لە جیاتی «07:30 AM»)
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.value, required this.onChanged, this.title, this.dense = false});
  final String value;
  final ValueChanged<String> onChanged;
  final String? title;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _TapField(
      text: dense ? Fmt.clockBare(value) : Fmt.clock(value),
      dense: dense,
      onTap: () async {
        final opts = timeOptions(value);
        final i = await _wheelSheet(context, title: title ?? tr('کات'), labels: opts.map(Fmt.clock).toList(), initial: opts.contains(value) ? opts.indexOf(value) : 0);
        if (i != null) onChanged(opts[i]);
      },
    );
  }
}

/// «2026-11-01» ← شەممە ١ی تشرینی دووەم
String fmtDay(String? iso) {
  if (iso == null || iso.length < 10) return '';
  final p = iso.split('-').map(int.parse).toList();
  return Fmt.date(DateTime(p[0], p[1], p[2]).millisecondsSinceEpoch);
}

/// هەڵبژاردنی ڕۆژ لە ئەمڕۆوە تا ٤٥ ڕۆژی تر (ui.dateSelect)
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged, this.days = 45, this.title});
  final String value;
  final ValueChanged<String> onChanged;
  final int days;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final opts = [for (var n = 0; n <= days; n++) Fmt.todayIso(DateTime(now.year, now.month, now.day + n))];
    String label(int n) {
      final d = Fmt.n(fmtDay(opts[n]));
      return n == 0 ? tr('ئەمڕۆ، {0}', [d]) : n == 1 ? tr('سبەینێ، {0}', [d]) : d;
    }
    final idx = opts.indexOf(value);
    return _TapField(
      icon: 'calendar',
      text: idx >= 0 ? label(idx) : Fmt.n(fmtDay(value)),
      onTap: () async {
        final i = await _wheelSheet(context, title: title ?? tr('ڕۆژ'), labels: [for (var n = 0; n < opts.length; n++) label(n)], initial: idx < 0 ? 0 : idx);
        if (i != null) onChanged(opts[i]);
      },
    );
  }
}

/// سویچی ئایفۆن (ui.toggle)
class YkToggle extends StatelessWidget {
  const YkToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: context.yk.success);
}

/// چیپ (.chip)
class YkChip extends StatelessWidget {
  const YkChip(this.label, {super.key, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? t.act : t.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? t.act : t.line, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: on ? t.actText : t.text)),
        ]),
      ),
    );
  }
}

/// ڕۆژەکانی هەفتە (.days): حەوت دوگمە
class DaysPicker extends StatelessWidget {
  const DaysPicker({super.key, required this.days, required this.onToggle});
  final List<bool> days;
  final ValueChanged<int> onToggle;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Row(children: [
      for (var i = 0; i < 7; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: Semantics(
            label: Fmt.weekday(i),
            selected: days[i],
            button: true,
            child: GestureDetector(
              onTap: () => onToggle(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: days[i] ? t.act : t.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: days[i] ? t.act : t.line, width: 1.5),
                ),
                child: Text(Fmt.weekdayShort(i), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: days[i] ? t.actText : t.text)),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// نیشانی چەکی بازنەیی (.check) و ڕادیۆ (.radio)
class YkCheck extends StatelessWidget {
  const YkCheck(this.on, {super.key, this.radio = false});
  final bool on;
  final bool radio;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    if (radio) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 24,
        height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? t.act : t.line, width: 2)),
        alignment: Alignment.center,
        child: on ? Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: t.act)) : null,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? t.act : Colors.transparent,
        border: Border.all(color: on ? t.act : t.line, width: 2),
      ),
      alignment: Alignment.center,
      child: on ? YkIcon('check', size: 15, color: t.actText, stroke: 3) : null,
    );
  }
}

/// چوارگۆشەی ئایکۆن (.ico-box)
class IcoBox extends StatelessWidget {
  const IcoBox(this.icon, {super.key, this.size = 40, this.bg, this.color, this.iconSize = 20});
  final String icon;
  final double size, iconSize;
  final Color? bg, color;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg ?? t.silver, borderRadius: BorderRadius.circular(size * .3)),
      alignment: Alignment.center,
      child: YkIcon(icon, size: iconSize, color: color ?? t.brand),
    );
  }
}

/// ڕیزێکی ئایکۆن و نووسین (.row sm)
class IconLine extends StatelessWidget {
  const IconLine(this.icon, this.text, {super.key, this.color, this.muted = false});
  final String icon;
  final String text;
  final Color? color;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 3), child: YkIcon(icon, size: 16, color: color ?? t.muted)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.5, color: muted ? t.muted : t.text))),
      ]),
    );
  }
}

/// کورتەی داواکاری: شوێن، کات، ڕۆژ، دەستپێکردن (ui.requestSummary)
class RequestSummary extends StatelessWidget {
  const RequestSummary(this.r, {super.key});
  final Json r;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final pd = asMap(r['perDay']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      IconLine('pin', str(r['from']), color: t.success),
      IconLine('pin', str(r['to']), color: t.amber),
      if (pd.isNotEmpty)
        PerDayList(pd)
      else ...[
        IconLine('clock', fmtSchedule(r), muted: true),
        IconLine('calendar', fmtDays(asList(r['days'])), muted: true),
      ],
      if (str(r['startDate']).isNotEmpty) IconLine('flag', Fmt.n(tr('دەستپێکردن: {0}', [fmtDay(str(r['startDate']))])), muted: true),
    ]);
  }
}

/// خشتەی کاتەکانی هەر ڕۆژێک (ui.perDayList)
class PerDayList extends StatelessWidget {
  const PerDayList(this.pd, {super.key});
  final Map<String, dynamic> pd;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    Widget cell(String? v, String on, String off) => Expanded(
          child: Text(v == null || v.isEmpty ? off : '$on ${Fmt.clock(v)}',
              style: TextStyle(fontSize: 13.4, color: v == null || v.isEmpty ? t.muted : t.text, fontStyle: v == null || v.isEmpty ? FontStyle.italic : null)),
        );
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        for (var i = 0; i < 7; i++)
          if (asMap(pd['$i']).isNotEmpty && (asMap(pd['$i'])['go'] != null || asMap(pd['$i'])['back'] != null))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 82, child: Text(Fmt.weekday(i), style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w700, color: t.text))),
                cell(asMap(pd['$i'])['go'] as String?, tr('چوون'), tr('بێ چوون')),
                cell(asMap(pd['$i'])['back'] as String?, tr('هاتنەوە'), tr('بێ هاتنەوە')),
              ]),
            ),
      ]),
    );
  }
}

/// نیشانەکانی داواکاری (ui.requestTags)
class RequestTags extends StatelessWidget {
  const RequestTags(this.r, {super.key});
  final Json r;
  @override
  Widget build(BuildContext context) {
    final rt = r['rideType'];
    final riders = (r['riders'] as num?) ?? 1;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (r['hasChild'] == true)
        YkBadge(rt == 'private' ? tr('تەنها منداڵەکانی خۆم') : rt == 'family' ? tr('لەگەڵ خێزان') : tr('تەنها لەگەڵ منداڵ'), tone: BadgeTone.note)
      else
        YkBadge(rt == 'private' ? tr('تەکسی تایبەت') : tr('هاوبەش')),
      if (r['womanOnly'] == true) YkBadge(tr('شۆفێری ئافرەت'), tone: BadgeTone.woman),
      if (riders > 1) YkBadge(Fmt.n(tr('{0} سەرنشین', [riders])), tone: BadgeTone.info),
    ]);
  }
}

/// هێڵی نێوان (.hr)
class YkHr extends StatelessWidget {
  const YkHr({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, thickness: 1, color: context.yk.line),
      );
}

/// ڕێنمایی بچووک (.hint)
class YkHint extends StatelessWidget {
  const YkHint(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      YkIcon('help', size: 16, color: t.muted),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: Ts.muted(context, size: 13.4))),
    ]);
  }
}
