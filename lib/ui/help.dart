// ڕوونکردنەوەی پەڕە: دوگمەی (؟) لە سەرەوە و پەڕەی خوارەوەی ڕوونکردنەوە (TK.helpBtn / acts.help)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cloud.dart';
import '../core/format.dart';
import 'theme.dart';
import 'widgets.dart';
import 'yk_icon.dart';

/// ناونیشان و بڕگەکانی هەر ڕوونکردنەوەیەک (TK.HELP). بڕگەی کۆتایی کاڵ دەبێت ئەگەر [mutedLast]
({String title, List<String> body, bool mutedLast})? _help(String key, Map<String, dynamic> c) {
  switch (key) {
    case 'trips':
      return (
        title: 'گەشتەکانی ئەمڕۆ',
        body: [
          'ئەگەر ئەمڕۆ کەسێک نایەت، «نایەم» دابگرە. شۆفێرەکە دەستبەجێ ئاگادار دەکرێتەوە و پێویست ناکات بێت.',
          Fmt.n('«نایەم» تا ${c['skipCutoffMin'] ?? 30} خولەک پێش کاتی گەشت دەکرێت. نرخی مانگانە ناگۆڕێت.'),
        ],
        mutedLast: true,
      );
    case 'inbox':
      return (
        title: 'نامەکان',
        body: [
          'بۆ ناردنی نامە بۆ شۆفێرێکی نوێ، پرۆفایلەکەی بکەرەوە و «نامە» دابگرە.',
          'ژمارەی مۆبایلەکەت بۆ شۆفێر شاراوەیە. نامەی خۆت تا ٥ خولەک دەتوانیت بگەڕێنیتەوە.',
        ],
        mutedLast: true,
      );
    case 'wallet':
      return (
        title: 'جزدانەکەم',
        body: [
          'پارە دەخەیتە سەر جزدانەکەت (FIB، FastPay یان کاش)، پاشان پارەی هەر مانگێک خۆت لە «پارەدانی مانگ» دەدەیت، پێش یەکەم گەشت.',
          'پارەکە لای یەکسا دەمێنێتەوە و ڕۆژ بە ڕۆژ، تەنها دوای تەواوبوونی هەر گەشتێک، دەچێتە سەر حیسابی شۆفێر.',
          Fmt.n('بۆ هەر ${c['skipEvery'] ?? ''} ڕۆژ «نایەم» لە مانگێکدا، پارەی ${c['skipRefundDays'] ?? ''} ڕۆژ دەگەڕێتەوە سەر جزدانەکەت. ئەگەر شۆفێر نەهات و یەکسا پەسەندی کرد، قەرەبووەکەش لێرە دەبینیت.'),
        ],
        mutedLast: false,
      );
  }
  return null;
}

/// پیشاندانی ڕوونکردنەوەی پەڕەیەک
void showHelp(BuildContext context, String key) {
  final h = _help(key, context.read<Cloud>().config);
  if (h == null) return;
  showYkSheet(context, builder: (c) {
    final t = c.yk;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: YkIcon('help', size: 22, color: t.act, stroke: 2),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(h.title, style: Ts.h2(c))),
      ]),
      const SizedBox(height: 12),
      for (var i = 0; i < h.body.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        Text(h.body[i],
            style: (h.mutedLast && i == h.body.length - 1 ? Ts.muted(c, size: 15) : TextStyle(fontSize: 15, color: t.text)).copyWith(height: 1.9)),
      ],
      const SizedBox(height: 16),
      YkButton('تێگەیشتم', block: true, onPressed: () => Navigator.pop(c)),
    ]);
  });
}

/// دوگمەی خڕی (؟) بۆ سەرەوەی پەڕە (.icon-btn.help-btn)
class HelpButton extends StatelessWidget {
  const HelpButton(this.helpKey, {super.key});
  final String helpKey;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Semantics(
      button: true,
      label: 'ڕوونکردنەوە',
      child: GestureDetector(
        onTap: () => showHelp(context, helpKey),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: t.glass, shape: BoxShape.circle, border: Border.all(color: t.glassLine)),
          alignment: Alignment.center,
          child: YkIcon('help', size: 22, color: t.text),
        ),
      ),
    );
  }
}
