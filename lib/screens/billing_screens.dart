// پارەدان و جزدان: فاتورە (بێ جزدان)، جزدانەکەم، پارەدانی مانگ، زیادکردن، ڕاکێشان، ناردن، مامەڵەکان
import 'dart:collection'; // firstOrNull / lastOrNull
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/billing.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/images.dart';
import '../core/sel.dart';
import '../ui/help.dart';
import '../ui/form_parts.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'nav.dart';
import 'request_screen.dart' show askConfirm;

int _pos(int x) => x < 0 ? 0 : x;

/// «٢٥٬٠٠٠» ← 25000
int parseAmount(String v) => int.tryParse(v.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}').replaceAll(RegExp(r'[^\d]'), '')) ?? 0; // i18n-keep

/// کارتی ڕەشی جزدان (ui.walletCard)
class WalletCard extends StatelessWidget {
  const WalletCard({super.key, required this.title, required this.tag, required this.amount, this.pills = const []});
  final String title, tag;
  final int amount;
  final List<(String, Widget)> pills;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E), Color(0xFF0E0E10)], stops: [0, .45, 1]),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
        boxShadow: const [BoxShadow(color: Color(0x47000000), blurRadius: 36, offset: Offset(0, 18))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E))),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
              Text(tag, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ),
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(colors: [Color(0xFFE9C46A), Color(0xFFB8892E)]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${amount < 0 ? '−' : ''}${Fmt.n(Fmt.group(amount.abs()))} '),
            TextSpan(text: tr('دینار'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white70)),
          ]),
          style: TextStyle(color: amount < 0 ? const Color(0xFFFCA5A5) : Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white.withValues(alpha: .1)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 6, children: [
          for (final p in pills)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                YkIcon(p.$1, size: 16, color: const Color(0xFFFBBF24)),
                const SizedBox(width: 6),
                DefaultTextStyle.merge(style: const TextStyle(color: Colors.white, fontSize: 13.4), child: p.$2),
              ]),
            ),
        ]),
      ]),
    );
  }
}

Widget _trust(BuildContext context, String text, {String icon = 'shield'}) {
  final t = context.yk;
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(top: 2), child: YkIcon(icon, size: 16, color: icon == 'shield' ? t.okText : t.muted)),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: Ts.muted(context, size: 12.8))),
  ]);
}

Widget _row(BuildContext context, String k, Widget v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(k, style: Ts.muted(context, size: 14))), v]),
    );

Text _b(String s, {Color? color, double size = 15}) => Text(s, style: TextStyle(fontWeight: FontWeight.w700, fontSize: size, color: color));

/* ---------------- دێڕی دەفتەر و پسوولە ---------------- */

class TxRow extends StatelessWidget {
  const TxRow(this.e, {super.key, this.pending = false, this.onTap});
  final Json e;
  final bool pending;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.read<Cloud>();
    final l = txLabel(cloud, e);
    final amt = ((e['amount'] as num?) ?? 0).toInt();
    final tone = pending ? 'pend' : amt > 0 ? 'in' : l.bad ? 'bad' : '';
    final col = tone == 'in' ? t.okText : tone == 'pend' ? const Color(0xFFB45309) : tone == 'bad' ? t.dangerText : t.text;
    final bg = tone == 'in' ? t.okBg : tone == 'pend' ? t.noteBg : tone == 'bad' ? t.dangerBg : t.chip;
    return InkWell(
      onTap: onTap ?? () => showReceipt(context, e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)), alignment: Alignment.center, child: YkIcon(l.icon, size: 20, color: col)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.7, color: t.text)),
              if (l.sub.isNotEmpty) Text(l.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.muted(context, size: 12.2)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${amt > 0 ? '+' : amt < 0 ? '−' : ''}${Fmt.n(Fmt.group(amt.abs()))}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: amt > 0 ? t.okText : t.text)),
            Text(pending ? tr('چاوەڕێ') : Fmt.clock(Fmt.hhmm(((e['at'] as num?) ?? 0).toInt())), style: Ts.muted(context, size: 11)),
          ]),
        ]),
      ),
    );
  }
}

/// پسوولەی دێڕێکی دەفتەر یان داواکارییەک (ui.receipt)
void showReceipt(BuildContext context, Json e, {bool pending = false, Widget? extra}) {
  final cloud = context.read<Cloud>();
  final l = txLabel(cloud, e);
  final amt = ((e['amount'] as num?) ?? 0).toInt();
  final at = ((e['at'] as num?) ?? nowMs()).toInt();
  final idTxt = str(e['id']).length > 10 ? str(e['id']).substring(str(e['id']).length - 10).toUpperCase() : str(e['id']).toUpperCase();
  showYkSheet(context, builder: (c) {
    final t = c.yk;
    Widget row(String k, String v, {bool latin = false}) => v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(k, style: Ts.muted(c, size: 14)),
              const SizedBox(width: 10),
              Expanded(child: Text(v, textAlign: TextAlign.end, textDirection: latin ? TextDirection.ltr : null, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: t.text))),
            ]),
          );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(shape: BoxShape.circle, color: amt < 0 ? t.chip : t.okBg),
          alignment: Alignment.center,
          child: YkIcon(amt < 0 ? 'receipt' : 'check', size: 32, color: amt < 0 ? t.text : t.okText, stroke: 2.4),
        ),
      ),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '${amt > 0 ? '+' : amt < 0 ? '−' : ''}${Fmt.n(Fmt.group(amt.abs()))} '),
          TextSpan(text: tr('دینار'), style: TextStyle(fontSize: 16, color: t.muted, fontWeight: FontWeight.w400)),
        ]),
        textAlign: TextAlign.center,
        style: Ts.h1(c),
      ),
      Center(child: pending ? YkBadge(tr('چاوەڕێی پشکنینە'), tone: BadgeTone.note) : YkBadge(tr('تۆمارکراو'), tone: BadgeTone.ok)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(Yk.rMd), border: Border.all(color: t.line)),
        child: Column(children: [
          row(tr('جۆر'), l.title),
          row(tr('وردەکاری'), l.sub),
          row(tr('شێواز'), e['method'] != null ? cloud.payName(e['method']) : ''),
          row(tr('ژمارەی حەواڵە'), str(e['ref']), latin: true),
          row(tr('کات'), tr('{0}، {1}', [Fmt.date(at), Fmt.clock(Fmt.hhmm(at))])),
          row(tr('ناسنامە'), idTxt, latin: true),
        ]),
      ),
      if (extra != null) ...[const SizedBox(height: 12), extra],
      const SizedBox(height: 10),
      if (!pending)
        YkButton(tr('هاوبەشکردنی پسوولە'), icon: 'share', kind: BtnKind.secondary, block: true, onPressed: () {
          SharePlus.instance.share(ShareParams(text: tr('یەکسا: {0}\n{1}\n{2}، {3}\n{4}', [l.title, '${amt > 0 ? '+' : '−'}${Fmt.money(amt.abs())}', Fmt.date(at), Fmt.hhmm(at), idTxt])));
        }),
      const SizedBox(height: 8),
      YkButton(tr('داخستن'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
    ]);
  });
}

/* ---------------- پارەدان (بێ جزدان) ---------------- */

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final b = cloud.billing;
    final paid = b['paid'] == true;
    final history = asList(b['history']).map(asMap).toList();
    // دوای پارەدان، هەمان ئەو فاتورەیە نیشان دەدرێت کە دراوە
    final h0 = paid && history.isNotEmpty && history.first['month'] == b['month'] && history.first['lines'] is List ? history.first : null;
    final inv = cloud.invoice();
    final lines = h0 != null ? asList(h0['lines']).map(asMap).toList() : inv.lines.map((l) => l.toJson()).toList();
    final promo = h0 != null ? ((h0['promo'] as num?) ?? 0).toInt() : inv.promo;
    final discounts = h0 != null
        ? asList(h0['discounts']).map((d) => (str(asMap(d)['label']), ((asMap(d)['amount'] as num?) ?? 0).toInt())).toList()
        : inv.discounts.map((d) => (d.label, d.amount)).toList();
    final credit = h0 != null ? ((h0['credit'] as num?) ?? 0).toInt() : inv.credit;
    final total = h0 != null ? ((h0['total'] as num?) ?? 0).toInt() : inv.total;
    final pr = asMap(b['promo']);
    final p1000 = (cloud.config['pointsPer1000'] as num?) ?? 0;

    return Scaffold(
      body: YkScreen(children: [
        YkHeader(tr('پارەدان')),
        YkCard(
          big: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(tr('فاتورەی {0}', [Fmt.monthName(str(b['month']))]), style: Ts.bold(context))),
              paid ? YkBadge(tr('دراوە'), tone: BadgeTone.ok) : YkBadge(tr('ئامادەیە'), tone: BadgeTone.note),
            ]),
            const SizedBox(height: 6),
            if (lines.isEmpty) Text(tr('هیچ بەشدارییەکی چالاک نییە'), style: Ts.muted(context, size: 14)),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(str(l['label']), style: Ts.sm(context)),
                      if (str(l['note']).isNotEmpty) Text(tr('{0}، نرخی تەواو {1}', [l['note'], Fmt.n(Fmt.group((l['full'] as num?) ?? 0))]), style: Ts.muted(context, size: 12.5)),
                    ]),
                  ),
                  _b(Fmt.n(Fmt.group((l['amount'] as num?) ?? 0)), size: 14),
                ]),
              ),
            if (promo > 0) _row(context, tr('داشکاندن ({0})', [str(pr['code'])]), _b(Fmt.n(Fmt.group(promo)), color: t.okText, size: 14)),
            for (final d in discounts) _row(context, trData(d.$1), _b(Fmt.n(Fmt.group(-d.$2)), color: t.okText, size: 14)),
            if (credit > 0)
              for (final a in (h0 != null ? [<String, dynamic>{'note': tr('قەرەبوو'), 'amount': credit}] : inv.adjustments))
                _row(context, trData(str(a['note'])), _b(Fmt.n(Fmt.group((a['amount'] as num?) ?? 0)), color: t.okText, size: 14)),
            const YkHr(),
            Row(children: [
              Expanded(child: Text(tr('کۆی گشتی'), style: Ts.bold(context))),
              Text(Fmt.money(total), style: Ts.h2(context).copyWith(color: t.brand)),
            ]),
            if (h0 == null && inv.waiting.isNotEmpty)
              Text(tr('{0} داشکاندنی چاوەڕوان لە فاتورەی داهاتوو دەبڕدرێت', [Fmt.money(inv.waiting.fold<int>(0, (n, d) => n + d.amount))]), style: Ts.muted(context, size: 12.8)),
          ]),
        ),
        if (paid)
          YkButton(tr('پسوولە'), icon: 'receipt', kind: BtnKind.secondary, block: true, onPressed: () => _billReceipt(context))
        else ...[
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('شێوازی پارەدان'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.muted)),
            const SizedBox(height: 6),
            YkSeg<String>(
              options: [('fib', 'FIB'), ('fastpay', 'FastPay'), ('cash', tr('کاش'))],
              value: str(b['method']).isEmpty ? 'cash' : str(b['method']),
              onChanged: (v) => cloud.setPayMethod(v),
            ),
          ]),
          if (pr.isEmpty) const _PromoField(),
          YkButton(tr('پارەدان، {0}', [Fmt.money(inv.total)]), block: true, onPressed: inv.total > 0 ? () => _payNow(context) : null),
          if (p1000 > 0) Text(Fmt.n(tr('بە هەر {0} دینار، {1} خاڵی پاداشت وەردەگریت', [Fmt.group(1000), p1000])), textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8)),
        ],
        Text(tr('مێژووی پارەدان'), style: Ts.h3(context)),
        if (history.isEmpty)
          Text(tr('هێشتا هیچ پارەدانێک نییە'), style: Ts.muted(context, size: 14))
        else
          YkList(children: [
            for (final h in history)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  IcoBox('check', size: 38, iconSize: 18, bg: t.okBg, color: t.okText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(Fmt.monthName(str(h['month'])), style: Ts.bold(context)),
                      Text(Fmt.ago(((h['at'] as num?) ?? 0).toInt()), style: Ts.muted(context, size: 12.5)),
                    ]),
                  ),
                  _b(Fmt.money((h['total'] as num?) ?? 0)),
                ]),
              ),
          ]),
      ]),
    );
  }

  void _payNow(BuildContext context) {
    final cloud = context.read<Cloud>();
    final inv = cloud.invoice();
    final method = str(cloud.billing['method']).isEmpty ? 'cash' : str(cloud.billing['method']);
    final m = {'fib': 'FIB', 'fastpay': 'FastPay', 'cash': tr('کاش')}[method] ?? method;
    var busy = false;
    showYkSheet(context, builder: (c) {
      return StatefulBuilder(builder: (c, setS) {
        final t = c.yk;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('پشتڕاستکردنەوەی پارەدان'), style: Ts.h2(c)),
          const SizedBox(height: 12),
          YkCard(
            child: Column(children: [
              _row(c, tr('بڕ'), _b(Fmt.money(inv.total), color: t.brand)),
              _row(c, tr('شێواز'), _b(m)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            method == 'cash' ? tr('پارەکە بدە بە بەڕێوەبەر یان نوێنەری یەکسا؛ کاتێک وەریگرت تۆماری دەکات.') : tr('لە ئەپی {0} بنێرە بۆ هەژماری یەکسا، پاشان لێرە پشتڕاستی بکەرەوە. یەکسا دەیپشکنێت.', [m]),
            style: Ts.muted(c, size: 12.8),
          ),
          const SizedBox(height: 14),
          YkButton(trc('پارەدان', 'ادفع', 'Pay'), block: true, busy: busy, onPressed: () async {
            setS(() => busy = true);
            final pts = await cloud.pay();
            if (c.mounted) Navigator.pop(c);
            if (context.mounted) toast(context, pts > 0 ? Fmt.n(tr('پارەدان سەرکەوتوو بوو، {0} خاڵ زیاد کرا', [pts])) : tr('پارەدان سەرکەوتوو بوو'));
          }),
          const SizedBox(height: 8),
          YkButton(tr('پاشگەزبوونەوە'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
        ]);
      });
    });
  }

  /// پسوولەی دوایین پارەدان
  void _billReceipt(BuildContext context) {
    final cloud = context.read<Cloud>();
    final b = cloud.billing;
    final hist = asList(b['history']).map(asMap).toList();
    final h = hist.isEmpty ? null : hist.first;
    if (h == null) return;
    final p = cloud.passenger;
    final lines = asList(h['lines']).map(asMap).toList();
    final at = ((h['at'] as num?) ?? 0).toInt();
    showYkSheet(context, builder: (c) {
      final t = c.yk;
      // لە ناو builder، تا لە هەر دووبارە دروستکردنێک دێڕەکان دووبارە نەبنەوە
      final text = StringBuffer(tr('یەکسا، پسوولەی {0}\n{1}\n{2}، {3}\n', [Fmt.monthName(str(h['month'])), Fmt.date(at), p['name'], Fmt.phone(str(p['phone']))]));
      final rows = <(String, String)>[
        for (final l in lines) (str(l['label']), Fmt.n(Fmt.group((l['amount'] as num?) ?? 0))),
        if (((h['promo'] as num?) ?? 0) > 0) (tr('داشکاندن'), Fmt.n(Fmt.group(h['promo'] as num))),
        for (final d in asList(h['discounts']).map(asMap)) (trData(str(d['label'])), Fmt.n(Fmt.group(-((d['amount'] as num?) ?? 0)))),
        if (((h['credit'] as num?) ?? 0) > 0) (tr('قەرەبوو'), Fmt.n(Fmt.group(h['credit'] as num))),
      ];
      for (final r in rows) {
        text.writeln('${r.$1}: ${r.$2}');
      }
      text.write(tr('کۆی گشتی: {0}', [Fmt.money((h['total'] as num?) ?? 0)]));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(Yk.rLg), border: Border.all(color: t.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(tr('یەکسا'), style: Ts.h2(c))),
              YkBadge(tr('دراوە'), tone: BadgeTone.ok),
            ]),
            const SizedBox(height: 8),
            Text(tr('پسوولەی {0}', [Fmt.monthName(str(h['month']))]), style: Ts.bold(c)),
            Text(Fmt.date(at), style: Ts.muted(c, size: 12.8)),
            Text(tr('{0}، {1}', [p['name'], Fmt.phone(str(p['phone']))]), style: Ts.muted(c, size: 12.8)),
            const YkHr(),
            for (final r in rows) _row(c, r.$1, _b(r.$2, size: 14)),
            const YkHr(),
            _row(c, tr('کۆی گشتی'), _b(Fmt.money((h['total'] as num?) ?? 0))),
          ]),
        ),
        const SizedBox(height: 12),
        YkButton(tr('هاوبەشکردن / پاشەکەوت'), icon: 'share', block: true, onPressed: () => SharePlus.instance.share(ShareParams(text: text.toString()))),
        const SizedBox(height: 8),
        YkButton(tr('داخستن'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  }
}

/// خانەی کۆدی داشکاندن
class _PromoField extends StatefulWidget {
  const _PromoField();
  @override
  State<_PromoField> createState() => _PromoFieldState();
}

class _PromoFieldState extends State<_PromoField> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _c,
          textCapitalization: TextCapitalization.characters,
          decoration: ykInput(context, hint: tr('کۆدی داشکاندن (ئەگەر هەتە)')),
        ),
      ),
      const SizedBox(width: 8),
      YkButton(tr('جێبەجێکردن'), kind: BtnKind.secondary, onPressed: () async {
        final cloud = context.read<Cloud>();
        final code = _c.text;
        final err = await cloud.applyPromo(code);
        final n = cloud.list('news').where((x) => str(x['code']).toUpperCase() == code.trim().toUpperCase()).firstOrNull;
        if (context.mounted) toast(context, err ?? Fmt.n(tr('داشکاندنی {0}٪ جێبەجێ کرا', [n?['rate'] ?? 10])));
      }),
    ]);
  }
}

/* ---------------- جزدان ---------------- */

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final bal = cloud.balance;
    final inv = cloud.invoice(due: true);
    final need = _pos(inv.total - bal);
    final paidNow = cloud.mySubs.any((x) => cloud.subPaid(x));
    Widget tile(String icon, String label, Widget page) => Expanded(
          child: YkCard(
            onTap: () => push(context, page),
            child: Row(children: [
              IcoBox(icon, size: 40, bg: t.chip, color: t.text),
              const SizedBox(width: 10),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(label, maxLines: 1, style: Ts.bold(context)))),
              YkIcon(L.rtl ? 'forward' : 'back', size: 16, color: t.muted),
            ]),
          ),
        );
    return Scaffold(
      body: YkScreen(onRefresh: context.read<Cloud>().refresh, children: [
        YkHeader(tr('جزدانەکەم'), right: const HelpButton('wallet')),
        WalletCard(
          title: tr('باڵانسی بەردەست'),
          tag: tr('جزدانی یەکسا'),
          amount: bal - cloud.pendingWithdraw,
          pills: [
            (
              inv.lines.isNotEmpty ? 'calendar' : 'check',
              inv.lines.isNotEmpty
                  ? Text.rich(TextSpan(children: [
                      TextSpan(text: '${tr('ئەم مانگە')} '),
                      TextSpan(text: Fmt.n(Fmt.group(inv.total)), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]))
                  : Text(paidNow ? tr('ئەم مانگە دراوە') : tr('هیچ پارەیەک نییە')),
            ),
          ],
        ),
        _trust(context, tr('پارەکەت لای یەکسا پارێزراوە. هەر جووڵەیەک لێرە تۆمار دەکرێت.')),
        // پارەدان: پارەی مانگانەی هەموو شۆفێرەکان (نەدراو و دراو)
        GestureDetector(
          onTap: () => push(context, const PaymentsScreen()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: t.amber,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x4DF5A623), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0x59FFFFFF), borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: const YkIcon('wallet', size: 22, color: Color(0xFF0B1733), stroke: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('پارەدان'), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0B1733))),
                  Text(tr('پارەی مانگانەی شۆفێرەکانت'), style: const TextStyle(fontSize: 12.8, color: Color(0xFF0B1733))),
                ]),
              ),
              YkIcon(L.rtl ? 'forward' : 'back', size: 20, color: const Color(0xFF0B1733)),
            ]),
          ),
        ),
        Row(children: [tile('plus', tr('زیادکردن'), const TopupScreen()), const SizedBox(width: 10), tile('download', tr('ڕاکێشان'), const WithdrawScreen())]),
        Row(children: [tile('send', tr('ناردن'), const SendMoneyScreen()), const SizedBox(width: 10), tile('receipt', tr('مامەڵەکان'), const TxsScreen())]),
        if (inv.lines.isNotEmpty)
          YkCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(tr('پارەی {0}', [Fmt.monthName(str(cloud.billing['month']))]), style: Ts.bold(context))),
                YkBadge(tr('گەشتەکان چاوەڕێن'), tone: BadgeTone.note),
              ]),
              const SizedBox(height: 10),
              _Progress(value: bal / (inv.total == 0 ? 1 : inv.total)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text(Fmt.n(tr('ئامادەیە {0}', [Fmt.group(bal.clamp(0, inv.total))])), style: Ts.muted(context, size: 14))),
                Text(Fmt.n(tr('لە {0}', [Fmt.group(inv.total)])), style: Ts.muted(context, size: 14)),
              ]),
              const SizedBox(height: 10),
              need > 0
                  ? YkButton(tr('زیادکردنی {0} ی ماوە', [Fmt.n(Fmt.group(need))]), icon: 'plus', small: true, block: true, kind: BtnKind.secondary, onPressed: () => push(context, TopupScreen(amount: need)))
                  : YkButton(tr('پارەدانی مانگ لە جزدان'), icon: 'check', small: true, block: true, onPressed: () => push(context, const PayMonthScreen())),
            ]),
          ),
      ]),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: value.clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: context.yk.chip, color: context.yk.act),
      );
}

/* ---------------- پارەدانی مانگ ---------------- */

class PayMonthScreen extends StatefulWidget {
  const PayMonthScreen({super.key});
  @override
  State<PayMonthScreen> createState() => _PayMonthScreenState();
}

class _PayMonthScreenState extends State<PayMonthScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final inv = cloud.invoice(due: true);
    final bal = cloud.balance;
    final need = _pos(inv.total - bal);
    final pr = asMap(cloud.billing['promo']);
    if (inv.lines.isEmpty) {
      final has = cloud.mySubs.isNotEmpty;
      return Scaffold(
        body: YkScreen(children: [
          YkHeader(tr('پارەدانی مانگ')),
          YkEmpty(
            icon: 'receipt',
            title: has ? tr('پارەی ئەم مانگە دراوە') : tr('هیچ بەشدارییەکت نییە'),
            text: has ? tr('گەشتەکانت بەردەوامن. مانگی داهاتوو لێرە دەردەکەوێت.') : tr('بەشدارییەکی مانگانە دروست بکە'),
            button: YkButton(tr('جزدانەکەم'), kind: BtnKind.secondary, onPressed: () => Navigator.of(context).maybePop()),
          ),
        ]),
      );
    }
    return Scaffold(
      body: YkScreen(children: [
        YkHeader(tr('پارەدانی مانگ')),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < inv.lines.length; i++) ...[
              if (i > 0) const YkHr(),
              Builder(builder: (context) {
                final l = inv.lines[i];
                final s = cloud.sub(l.subId) ?? const {};
                final d = cloud.driver(s['driverId']) ?? const {};
                return Row(children: [
                  PersonAvatar(size: 48, imageId: str(d['photo']).isEmpty ? null : str(d['photo'])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.bold(context)),
                      Text(l.note.isNotEmpty ? tr('{0}، {1}', [fmtDays(asList(s['days'])), l.note]) : fmtDays(asList(s['days'])), style: Ts.muted(context, size: 12.5)),
                    ]),
                  ),
                  _b(Fmt.n(Fmt.group(l.amount))),
                ]);
              }),
            ],
            if (inv.promo > 0 || inv.discounts.isNotEmpty) const YkHr(),
            if (inv.promo > 0) _row(context, tr('داشکاندنی هاوبەش'), _b('−${Fmt.n(Fmt.group(inv.promo))}', color: t.okText)),
            for (final d in inv.discounts) _row(context, trData(d.label), _b('−${Fmt.n(Fmt.group(d.amount))}', color: t.okText)),
            const SizedBox(height: 6),
            if (pr.isNotEmpty) _row(context, tr('کۆدی داشکاندن'), _b(str(pr['code']), size: 14)) else const _PromoField(),
            const YkHr(),
            _row(context, tr('کۆی پارەی {0}', [Fmt.monthName(str(cloud.billing['month']))]), _b(Fmt.money(inv.total))),
            _row(context, tr('باڵانسی جزدانەکەت'), _b(Fmt.money(bal), color: bal >= inv.total ? t.okText : null)),
            const SizedBox(height: 6),
            if (need > 0) ...[
              _Progress(value: bal / (inv.total == 0 ? 1 : inv.total)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text(Fmt.n(tr('لە جزدانەکەت {0}', [Fmt.group(bal < 0 ? 0 : bal)])), style: Ts.muted(context, size: 14))),
                Text(Fmt.n(tr('پێویستە {0} ی تر', [Fmt.group(need)])), style: TextStyle(fontSize: 14, color: t.dangerText, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              YkButton(tr('زیادکردنی {0}', [Fmt.n(Fmt.group(need))]), icon: 'plus', block: true, large: true, onPressed: () => push(context, TopupScreen(amount: need))),
            ] else ...[
              _row(context, tr('باڵانس دوای پارەدان'), _b(Fmt.money(bal - inv.total))),
              const SizedBox(height: 10),
              YkButton(tr('پارەدان لە جزدان'), icon: 'check', block: true, large: true, busy: _busy, onPressed: () async {
                // پرسیاری دووپاتکردنەوە پێش بڕینی پارە لە جزدان
                final ok = await askConfirm(context, tr('پارەی {0} ({1}) لە جزدانەکەت دەدرێت؟', [Fmt.monthName(str(cloud.billing['month'])), Fmt.money(inv.total)]), yes: tr('پارەدان'), danger: false);
                if (!ok || !context.mounted) return;
                setState(() => _busy = true);
                final err = await cloud.payMonth();
                if (!context.mounted) return;
                setState(() => _busy = false);
                if (err != null) {
                  toast(context, err);
                  return;
                }
                toast(context, tr('پارەی مانگ درا، گەشتەکان دەست پێدەکەن'));
                Navigator.of(context).maybePop();
              }),
            ],
            const SizedBox(height: 10),
            _trust(context, tr('پارەکە لای یەکسا دەمێنێتەوە و ڕۆژ بە ڕۆژ، تەنها دوای تەواوبوونی هەر گەشتێک، دەچێتە سەر حیسابی شۆفێر.')),
          ]),
        ),
        if (inv.waiting.isNotEmpty) Text(tr('{0} بۆ مانگی داهاتوو دەمێنێتەوە.', [inv.waiting.map((w) => trData(w.label)).join(tr('، '))]), style: Ts.muted(context, size: 12.8)),
      ]),
    );
  }
}

/* ---------------- پارەدان: نەدراو و دراو ---------------- */

String _monthName(String mk) {
  final p = mk.split('-');
  return '${Fmt.month(int.parse(p[1]) - 1)} ${Fmt.n(p[0])}';
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _tab = 'due';

  List<String> get _months {
    final now = DateTime.now();
    return [Fmt.monthKey(), Fmt.monthKey(DateTime(now.year, now.month + 1, 1))];
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final paid = cloud.myWallet.where((e) => e['type'] == 'monthpay' && e['incoming'] != true).toList();
    return Scaffold(
      body: YkScreen(onRefresh: cloud.refresh, children: [
        YkHeader(tr('پارەدانی مانگانە')),
        YkSeg<String>(
          options: [('due', tr('نەدراو')), ('paid', Fmt.n(tr('دراو ({0})', [paid.length])))],
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        if (_tab == 'due') ..._due(context, cloud) else ..._paid(context, paid),
      ]),
    );
  }

  /// هەر بەشدارییەکی نەدراو کارتێکە؛ بە کلیک کردن وردەکارییەکەی دەکرێتەوە و لەوێ دەدرێت
  List<Widget> _due(BuildContext context, Cloud cloud) {
    final t = context.yk;
    final groups = [for (final mk in _months) (mk, cloud.dueLines(mk: mk))].where((g) => g.$2.isNotEmpty).toList();
    if (groups.isEmpty) {
      return [
        YkEmpty(
          icon: 'receipt',
          title: cloud.mySubs.isEmpty ? tr('هیچ بەشدارییەکت نییە') : tr('هەموو پارەکان دراون'),
          text: cloud.mySubs.isEmpty ? tr('بەشدارییەکی مانگانە دروست بکە') : tr('پارەی ئەم مانگە و مانگی داهاتوو دراوە. لە «دراو» پسوولەکان دەبینیت.'),
        ),
      ];
    }
    return [
      for (final (m, lines) in groups) ...[
        PLabel(_monthName(m)),
        for (final l in lines)
          Builder(builder: (context) {
            final s = cloud.sub(l.subId) ?? const {};
            final d = cloud.driver(s['driverId']) ?? const {};
            return YkCard(
              onTap: () => push(context, PaymentDetailScreen(month: m, subId: l.subId)),
              child: Row(children: [
                PersonAvatar(size: 46, imageId: str(d['photo']).isEmpty ? null : str(d['photo'])),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(str(d['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.bold(context)),
                    Text('${str(s['riderNames'])} · ${fmtDays(asList(s['days']))}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.muted(context, size: 12.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _b(Fmt.n(Fmt.group(l.amount))),
                  const SizedBox(height: 4),
                  YkBadge(tr('نەدراو'), tone: BadgeTone.note),
                ]),
                const SizedBox(width: 6),
                YkIcon(L.rtl ? 'forward' : 'back', size: 16, color: t.muted),
              ]),
            );
          }),
      ],
    ];
  }

  List<Widget> _paid(BuildContext context, List<Json> paid) {
    final t = context.yk;
    if (paid.isEmpty) {
      return [YkEmpty(icon: 'receipt', title: tr('هێشتا هیچ پارەیەکت نەداوە'), text: tr('هەر پارەیەکی مانگانە بدەیت، لێرە وەک بەڵگە دەمێنێتەوە'))];
    }
    return [
      for (final e in paid)
        YkCard(
          onTap: () => showReceipt(context, e),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(str(e['month']).isEmpty ? trData(str(e['note'])) : _monthName(str(e['month'])), style: Ts.bold(context))),
              YkBadge(tr('دراو ✓'), tone: BadgeTone.ok),
            ]),
            Text(Fmt.date(((e['at'] as num?) ?? 0).toInt()), style: Ts.muted(context, size: 12.5)),
            const SizedBox(height: 8),
            for (final l in asList(e['lines']).map(asMap))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(
                    child: Text('${str((context.read<Cloud>().driver(l['driverId']) ?? const {})['name'])} · ${str(l['names'])}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.sm(context)),
                  ),
                  Text(Fmt.n(Fmt.group((l['amt'] as num?) ?? 0)), style: Ts.sm(context)),
                ]),
              ),
            const YkHr(),
            Row(children: [
              Expanded(child: Text(tr('کۆی دراو'), style: Ts.muted(context, size: 13.4))),
              Text(Fmt.money(-(((e['amount'] as num?) ?? 0))), style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
            ]),
          ]),
        ),
    ];
  }
}

/// وردەکاری پارەی مانگێکی یەک بەشداری: کێیە، بۆ کێیە، چ ڕێگایەک و چەند گەشت، پاشان پارەدان
class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen({super.key, required this.month, required this.subId});
  final String month;
  final String subId;
  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final mk = widget.month;
    final s = cloud.sub(widget.subId) ?? const {};
    final d = cloud.driver(s['driverId']) ?? const {};
    final inv = cloud.invoice(due: true, mk: mk, only: {widget.subId});
    if (inv.lines.isEmpty) {
      return Scaffold(
        body: YkScreen(children: [
          YkHeader(tr('پارەی {0}', [_monthName(mk)])),
          YkEmpty(icon: 'receipt', title: tr('ئەم پارەیە دراوە'), text: tr('لە «دراو» پسوولەکەی دەبینیت')),
        ]),
      );
    }
    final l = inv.lines.first;
    final bal = cloud.balance;
    final need = _pos(inv.total - bal);
    String place(Object? x) => str(x).split('، ').first; // i18n-keep
    String time(Object? x) => str(x).isEmpty ? '—' : Fmt.clock(str(x));
    // دێڕی زانیاری: نووسینی درێژ دەچێتە دێڕی دووەم، نەک لە شاشە دەربچێت
    Widget info(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: Ts.muted(context, size: 14)),
            const SizedBox(width: 12),
            Expanded(child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
          ]),
        );
    return Scaffold(
      body: YkScreen(children: [
        YkHeader(tr('پارەی {0}', [_monthName(mk)])),
        // شۆفێر
        YkCard(
          onTap: () => openLink(context, 'driver/${d['id']}'),
          child: Row(children: [
            PersonAvatar(size: 56, imageId: str(d['photo']).isEmpty ? null : str(d['photo'])),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(d['name']), style: Ts.bold(context).copyWith(fontSize: 16.5)),
                Text(carText(d), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.muted(context, size: 13)),
              ]),
            ),
            if (str(d['plate']).isNotEmpty) Plate(str(d['plate']), type: str(d['plateType']).isEmpty ? 'taxi' : str(d['plateType']), small: true),
          ]),
        ),
        // بەشداری
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            info(tr('سەرنشین'), str(s['riderNames'])),
            info(tr('لە'), place(s['from'])),
            info(tr('بۆ'), place(s['to'])),
            info(tr('ڕۆژەکان'), fmtDays(asList(s['days']))),
            info(tr('چوون / هاتنەوە'), '${time(s['go'])} / ${time(s['back'])}'),
            info(tr('گەشتەکانی {0}', [_monthName(mk)]), Fmt.n(tr('{0} گەشت', [l.legs]))),
            if (l.note.isNotEmpty) Text(l.note, style: Ts.muted(context, size: 12.8)),
          ]),
        ),
        // بڕ و پارەدان
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _row(context, tr('نرخی مانگانە'), _b(Fmt.money(l.full))),
            if (l.amount != l.full) _row(context, tr('بڕی ئەم مانگە'), _b(Fmt.money(l.amount))),
            if (inv.promo > 0) _row(context, tr('داشکاندنی هاوبەش'), _b('−${Fmt.n(Fmt.group(inv.promo))}', color: t.okText)),
            for (final x in inv.discounts) _row(context, trData(x.label), _b('−${Fmt.n(Fmt.group(x.amount))}', color: t.okText)),
            const YkHr(),
            _row(context, tr('کۆی پارە'), _b(Fmt.money(inv.total), size: 18)),
            _row(context, tr('باڵانسی جزدان'), _b(Fmt.money(bal), color: bal >= inv.total ? t.okText : null)),
            if (need > 0) _row(context, tr('ماوە بۆ زیادکردن'), _b(Fmt.money(need), color: t.dangerText)),
            const SizedBox(height: 12),
            if (need > 0)
              YkButton(tr('زیادکردنی {0} ی ماوە', [Fmt.n(Fmt.group(need))]), icon: 'plus', block: true, large: true, onPressed: () => push(context, TopupScreen(amount: need)))
            else
              YkButton(tr('پارەدان لە جزدان'), icon: 'check', block: true, large: true, busy: _busy, onPressed: () async {
                final ok = await askConfirm(context, tr('{0} لە جزدانەکەت بۆ {1}، {2} دەدرێت.', [Fmt.money(inv.total), str(d['name']), _monthName(mk)]), yes: tr('پارەدان'), danger: false);
                if (!ok || !context.mounted) return;
                setState(() => _busy = true);
                final err = await cloud.payMonth(mk: mk, only: {widget.subId});
                if (!context.mounted) return;
                setState(() => _busy = false);
                if (err != null) return toast(context, err);
                toastAfterNav(context, tr('پارەی {0} درا', [_monthName(mk)]));
                Navigator.of(context).pop();
              }),
            const SizedBox(height: 10),
            _trust(context, tr('پارەکە لای یەکسا دەمێنێتەوە و ڕۆژ بە ڕۆژ، تەنها دوای تەواوبوونی هەر گەشتێک، دەچێتە سەر حیسابی شۆفێر.')),
          ]),
        ),
      ]),
    );
  }
}

/* ---------------- زیادکردن ---------------- */

/// خانەی گەورەی بڕ (amt-hero)
class _AmountField extends StatelessWidget {
  const _AmountField({required this.ctrl, required this.label, this.sub});
  final TextEditingController ctrl;
  final String label;
  final String? sub;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    // .amt-hero: بۆشایی ١٢ لە سەرەوە، ٢ لە خوارەوە
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Column(children: [
      Text(label, style: Ts.muted(context, size: 12.8).copyWith(height: 1.7)),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩,٬]'))], // i18n-keep
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: t.text),
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '0', contentPadding: EdgeInsets.symmetric(vertical: 8)),
      ),
      Text(sub ?? tr('دینار'), style: Ts.muted(context, size: 12.8).copyWith(height: 1.7)),
    ]),
    );
  }
}

Widget _mono(BuildContext context, Json m) {
  final t = context.yk;
  final txt = str(m['name']).replaceAll(RegExp('[^A-Za-z]'), '');
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(12)),
    alignment: Alignment.center,
    child: m['account'] == false
        ? YkIcon('cash', size: 22, color: t.text)
        : Text((txt.length > 3 ? txt.substring(0, 3) : txt).toUpperCase(), style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.w900, fontSize: 12.5, color: t.text)),
  );
}

/* ---------------- تەختەکلیل، بڕ و شێواز (هاوبەش بۆ زیادکردن و ڕاکێشان) ---------------- */

/// بڕی گەورە لە ناوەڕاست (amt-hero) بەبێ کیبۆردی مۆبایل
class _AmountHero extends StatelessWidget {
  const _AmountHero({required this.amount, required this.top, this.bottom});
  final int amount;
  final String top;
  final String? bottom;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(children: [
        Text(top, style: Ts.muted(context, size: 13.4)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          // ژمارەکان پەیڕەوی ڕێکخستنی «ژمارەکان» دەکەن (کوردی یان ئینگلیزی)
          child: Text(Fmt.n(amount == 0 ? '0' : Fmt.group(amount)),
              textDirection: TextDirection.ltr,
              style: TextStyle(fontFamily: Fmt.digits == 'en' ? 'Arial' : null, fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: Fmt.digits == 'en' ? -1 : 0, color: amount == 0 ? t.muted : t.text)),
        ),
        Text(bottom ?? tr('دینار'), textAlign: TextAlign.center, style: Ts.muted(context, size: 14)),
      ]),
    );
  }
}

/// تەختەکلیلی ژمارە (١-٩، 000، 0، سڕینەوە). [onKey]: ژمارە، '000' یان 'del'
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});
  final ValueChanged<String> onKey;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    Widget key(String k) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              onKey(k);
            },
            child: SizedBox(
              height: 54,
              child: Center(
                child: k == 'del'
                    ? YkIcon('backspace', size: 26, color: t.text)
                    : Text(Fmt.n(k), style: TextStyle(fontFamily: Fmt.digits == 'en' ? 'Arial' : null, fontSize: 25, fontWeight: FontWeight.w600, color: t.text)),
              ),
            ),
          ),
        );
    // ڕیزبەندی ژمارەکان هەمیشە وەک تەلەفۆن (چەپ بۆ ڕاست)
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(children: [
        for (final r in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['000', '0', 'del'],
        ])
          Row(children: [for (final k in r) key(k)]),
      ]),
    );
  }
}

/// گۆڕینی بڕ بە دوگمەیەکی تەختەکلیل، بە سنووری [max]
int _applyKey(int cur, String k, int max) {
  if (k == 'del') return cur ~/ 10;
  final next = k == '000' ? cur * 1000 : cur * 10 + int.parse(k);
  return next > max ? cur : next;
}

/// شێوازی پارەدان بە یەک دێڕ، لەگەڵ «گۆڕین» ئەگەر زیاتر لە یەکێک هەبێت
class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.methods, required this.value, required this.sub, required this.onChanged});
  final List<Json> methods;
  final String? value;
  final String Function(Json m) sub;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final m = methods.where((x) => x['id'] == value).firstOrNull ?? (methods.isEmpty ? null : methods.first);
    if (m == null) {
      return YkCard(tone: CardTone.note, child: Text(tr('هێشتا هیچ شێوازێکی پارەدان دانەنراوە. پەیوەندی بە یەکسا بکە.'), style: const TextStyle(fontSize: 14)));
    }
    final many = methods.length > 1;
    return YkCard(
      onTap: many ? () => _pick(context) : null,
      child: Row(children: [
        _mono(context, m),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trData(m['name']), style: Ts.bold(context)),
            Text(sub(m), style: Ts.muted(context, size: 12.5)),
          ]),
        ),
        if (many) ...[
          Text(tr('گۆڕین'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.4, color: t.muted)),
          const SizedBox(width: 4),
          YkIcon('down', size: 14, color: t.muted, stroke: 2.4),
        ],
      ]),
    );
  }

  void _pick(BuildContext context) {
    showYkSheet(context, builder: (c) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('شێوازی پارەدان'), style: Ts.h3(c)),
        const SizedBox(height: 10),
        YkList(children: [
          for (final x in methods)
            InkWell(
              onTap: () {
                Navigator.pop(c);
                onChanged(str(x['id']));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  _mono(c, x),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trData(x['name']), style: Ts.bold(c)),
                      Text(sub(x), style: Ts.muted(c, size: 12.5)),
                    ]),
                  ),
                  YkCheck(x['id'] == value, radio: true),
                ]),
              ),
            ),
        ]),
      ]);
    });
  }
}

/* ---------------- زیادکردن ---------------- */

class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key, this.amount = 0});
  final int amount;
  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  static const _max = 5000000;
  final _ref = TextEditingController();
  late int _amount;
  String? _method;
  int _step = 1;
  String? _photo;
  bool _busy = false;

  int get _needR => widget.amount > 0 ? ((widget.amount / 1000).ceil() * 1000) : 0;

  @override
  void initState() {
    super.initState();
    _amount = _needR > 0 ? _needR : 50000;
  }

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    // کاش لە ئەپ نییە: سەرنشین لە نووسینگە ڕاستەوخۆ دەڵێت. تەنها FIB و FastPay (ئەگەر هەژماری یەکسایان هەبێت)
    final ms = cloud.payMethods.where((m) => m['on'] != false && m['topup'] != false && m['account'] != false && str(m['yeksaAccount']).isNotEmpty).toList();
    if (_method == null || !ms.any((m) => m['id'] == _method)) _method = ms.isEmpty ? null : str(ms.first['id']);
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(() => _step = 1);
      },
      child: Scaffold(body: _step == 1 ? _first(context, cloud, ms) : _second(context, cloud)),
    );
  }

  Widget _first(BuildContext context, Cloud cloud, List<Json> ms) {
    return YkScreen(children: [
      YkHeader(tr('زیادکردنی پارە')),
      _AmountHero(amount: _amount, top: Fmt.n(tr('باڵانس: {0}', [Fmt.money(_pos(cloud.freeBalance))]))),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        if (_needR > 0) YkChip(Fmt.n(tr('بۆ ئەم مانگە {0}', [Fmt.group(_needR)])), on: _amount == _needR, onTap: () => setState(() => _amount = _needR)),
        for (final a in const [25000, 50000, 100000])
          YkChip(Fmt.n('+${Fmt.group(a)}'), on: false, onTap: () => setState(() => _amount = (_amount + a).clamp(0, _max))),
      ]),
      _MethodRow(
        methods: ms,
        value: _method,
        sub: (m) => tr('ناردن بۆ هەژماری یەکسا'),
        onChanged: (v) => setState(() => _method = v),
      ),
      _Keypad(onKey: (k) => setState(() => _amount = _applyKey(_amount, k, _max))),
      YkButton(tr('بەردەوام بوون'), block: true, large: true, onPressed: ms.isEmpty
          ? null
          : () {
              if (_amount < 1000) return toast(context, tr('بڕەکە بنووسە'));
              setState(() => _step = 2);
            }),
    ]);
  }

  Widget _second(BuildContext context, Cloud cloud) {
    final t = context.yk;
    final m = cloud.payMethod(_method) ?? const {};
    final name = str(m['name']);
    Widget step(String n, bool on, String title, Widget body) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on ? t.act : t.silver, border: on ? null : Border.all(color: t.silverLine)),
              alignment: Alignment.center,
              child: Text(n, style: TextStyle(color: on ? t.actText : t.muted, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: Ts.bold(context).copyWith(fontSize: 14.5)),
                const SizedBox(height: 6),
                body,
              ]),
            ),
          ]),
        );
    final refDone = _ref.text.trim().length >= 3;
    return YkScreen(children: [
      YkHeader(tr('ناردن بە {0}', [name])),
      // ژمارەی هەژماری یەکسا بە کۆپی
      YkCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _mono(context, m),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Fmt.n(tr('{0} بنێرە بۆ', [Fmt.money(_amount)])), style: Ts.muted(context, size: 12.8)),
                Text(str(m['holder']).isEmpty ? tr('یەکسا') : str(m['holder']), style: Ts.bold(context).copyWith(fontSize: 16)),
              ]),
            ),
            YkBadge(tr('پشتڕاستکراو'), tone: BadgeTone.ok),
          ]),
          const SizedBox(height: 12),
          CustomPaint(
            painter: DashedBorder(color: t.silverLine, radius: 14),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(
                  child: Text(str(m['yeksaAccount']),
                      textDirection: TextDirection.ltr, textAlign: TextAlign.end, style: TextStyle(fontFamily: 'Arial', fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1, color: t.text)),
                ),
                const SizedBox(width: 10),
                YkButton(tr('کۆپی'), icon: 'copy', small: true, kind: BtnKind.secondary, onPressed: () {
                  Clipboard.setData(ClipboardData(text: str(m['yeksaAccount'])));
                  toast(context, tr('کۆپی کرا'));
                }),
              ]),
            ),
          ),
        ]),
      ),
      step(Fmt.n('1'), true, tr('ئەپی {0} بکەرەوە و {1} بنێرە', [name, Fmt.n(Fmt.group(_amount))]), Text(tr('بۆ ئەو ژمارەیەی سەرەوە'), style: Ts.muted(context, size: 12.8))),
      step(
        Fmt.n('2'),
        refDone,
        tr('ژمارەی حەواڵە'),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(controller: _ref, onChanged: (_) => setState(() {}), decoration: ykInput(context, hint: tr('کۆپی بکە لە پسوولەی {0}', [name])).copyWith(hintTextDirection: L.rtl ? TextDirection.rtl : TextDirection.ltr)),
        ),
      ),
      step(
        Fmt.n('3'),
        _photo != null,
        tr('وێنەی پسوولە (ئارەزوومەندانە)'),
        InkWell(
          onTap: _pickPhoto,
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            painter: DashedBorder(color: t.line, radius: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_photo != null)
                  ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 48, height: 48, child: YkImage(_photo, fit: BoxFit.cover)))
                else
                  YkIcon('camera', size: 20, color: t.muted),
                const SizedBox(width: 10),
                Flexible(child: Text(_photo != null ? tr('وێنە زیاد کرا، بۆ گۆڕین دابگرە') : tr('زیادکردنی وێنە'), style: Ts.muted(context, size: 13.4))),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      YkButton(tr('پارەم نارد، پشکنین بکە'), icon: 'send', block: true, large: true, busy: _busy, onPressed: () async {
        final ref = _ref.text.trim();
        if (ref.length < 3) return toast(context, tr('ژمارەی حەواڵە بنووسە'));
        setState(() => _busy = true);
        final id = await cloud.requestTopup(_amount, str(_method), ref, _photo);
        if (!context.mounted) return;
        setState(() => _busy = false);
        if (id == null) return toast(context, tr('نەنێردرا، دووبارە هەوڵ بدەرەوە'));
        // پەڕەی دۆخی داواکارییەکە جێگەی ئەم پەڕەیە دەگرێتەوە؛ «گەڕانەوە» دەچێتە جزدان
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RequestStatusScreen(withdraw: false, id: id)));
      }),
    ]);
  }

  Future<void> _pickPhoto() async {
    final store = context.read<ImageStore>();
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, maxHeight: 1000, imageQuality: 72);
      if (f == null) return;
      final id = await store.save(await f.readAsBytes(), pub: false);
      if (mounted) setState(() => _photo = id);
    } catch (_) {
      if (mounted) toast(context, tr('ئەم وێنەیە ناخوێندرێتەوە'));
    }
  }
}

/* ---------------- ڕاکێشان ---------------- */

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _acc = TextEditingController();
  int _amount = 0;
  String? _method;
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final cloud = context.read<Cloud>();
    _amount = _pos(cloud.freeBalance);
    _acc.text = '0${cleanPhone(str(cloud.passenger['phone']))}';
  }

  @override
  void dispose() {
    _acc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final f = _pos(cloud.freeBalance);
    // کاش لە ئەپ نییە: لە نووسینگە ڕاستەوخۆ وەردەگیرێتەوە
    final ms = cloud.payMethods.where((m) => m['on'] != false && m['account'] != false).toList();
    if (_method == null || !ms.any((m) => m['id'] == _method)) _method = ms.isEmpty ? null : str(ms.first['id']);
    final m = cloud.payMethod(_method) ?? const {};
    final min = ((cloud.config['withdrawMin'] as num?) ?? 0).toInt();
    final pend = cloud.myWithdrawsPending;
    final chips = <int>[f, 25000, 50000].where((a) => a > 0 && a <= f).toSet().toList();
    return Scaffold(
      body: YkScreen(children: [
        YkHeader(tr('ڕاکێشانی پارە')),
        _AmountHero(
          amount: _amount,
          top: tr('چەند ڕادەکێشیت؟'),
          bottom: Fmt.n(min > 0 ? tr('دینار · بەردەست {0} · کەمترین {1}', [Fmt.group(f), Fmt.group(min)]) : tr('دینار · بەردەست {0}', [Fmt.group(f)])),
        ),
        if (chips.isNotEmpty)
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < chips.length; i++)
              YkChip(Fmt.n(i == 0 ? tr('هەمووی {0}', [Fmt.group(chips[i])]) : Fmt.group(chips[i])), on: _amount == chips[i], onTap: () => setState(() => _amount = chips[i])),
          ]),
        _MethodRow(methods: ms, value: _method, sub: (x) => tr('بۆ هەژماری {0} ـی خۆت', [x['name']]), onChanged: (v) => setState(() => _method = v)),
        if (ms.isNotEmpty)
          YkField(
            label: tr('ژمارەی هەژماری {0} ـەکەت', [str(m['name'])]),
            child: Directionality(textDirection: TextDirection.ltr, child: TextField(controller: _acc, keyboardType: TextInputType.phone, decoration: ykInput(context))),
          ),
        _Keypad(onKey: (k) => setState(() => _amount = _applyKey(_amount, k, f))),
        if (_err != null) YkError(_err!),
        YkButton(tr('داوای ڕاکێشان'), block: true, large: true, busy: _busy, onPressed: f > 0 && ms.isNotEmpty
            ? () async {
                FocusScope.of(context).unfocus();
                setState(() {
                  _busy = true;
                  _err = null;
                });
                String? newId;
                final err = await cloud.requestWithdraw(_amount, str(_method), _acc.text, onId: (id) => newId = id);
                if (!context.mounted) return;
                setState(() {
                  _busy = false;
                  _err = err;
                });
                if (err == null && newId != null) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RequestStatusScreen(withdraw: true, id: newId!)));
                }
              }
            : null),
        _trust(context, tr('یەکسا پارەکەت بۆ دەنێرێت و ئاگادار دەکرێیتەوە. تا نەنێردرێت، دەتوانیت هەڵیبوەشێنیتەوە.'), icon: 'clock'),
        if (pend.isNotEmpty) ...[
          Text(tr('چاوەڕێی ناردن'), style: Ts.h3(context)),
          YkList(children: [for (final w in pend) _pendingWithdraw(context, w)]),
        ],
      ]),
    );
  }
}

/* ---------------- دۆخی داواکاری (زیادکردن / ڕاکێشان) ---------------- */

class RequestStatusScreen extends StatefulWidget {
  const RequestStatusScreen({super.key, required this.withdraw, required this.id});
  final bool withdraw;
  final String id;
  @override
  State<RequestStatusScreen> createState() => _RequestStatusScreenState();
}

class _RequestStatusScreenState extends State<RequestStatusScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final x = cloud.list(widget.withdraw ? 'withdraws' : 'topups').where((e) => e['id'] == widget.id).firstOrNull;
    final st = str(x?['status']).isEmpty ? 'pending' : str(x!['status']);
    final amount = ((x?['amount'] as num?) ?? 0).toInt();
    final ok = st == 'approved' || st == 'sent';
    final bad = st == 'rejected' || st == 'cancelled';
    final method = cloud.payName(str(x?['method']));
    final at = ((x?['at'] as num?) ?? 0).toInt();
    final title = widget.withdraw ? tr('داوای ڕاکێشان') : tr('داواکاری زیادکردن');
    final sub = switch (st) {
      'approved' => tr('زیادکرا بۆ جزدانەکەت'),
      'sent' => tr('نێردرا بۆ هەژمارەکەت'),
      'rejected' => str(x?['why']).isEmpty ? tr('ڕەتکرایەوە') : tr('ڕەتکرایەوە، {0}', [trData(x!['why'])]),
      'cancelled' => tr('هەڵوەشێنرایەوە'),
      _ => widget.withdraw ? tr('چاوەڕێی ناردنی یەکسا') : tr('چاوەڕێی پشکنینی یەکسا'),
    };
    // ژمارەی حەواڵە / هەژمار (لاتینی) لە دێڕێکی جیادا و بە LRI…PDI جیا دەکرێتەوە، تا لە ناو
    // دەقی کوردیدا (RTL) لە نیوەدا نەشکێت و پیتەکانی تێکەڵ نەبن (بۆ نموونە TEST-CANCEL)
    String ltr(Object? v) => '\u2066$v\u2069';
    final when = at > 0 ? tr('{0}، {1}', [Fmt.date(at), Fmt.clock(Fmt.hhmm(at))]) : '';
    final detail = !widget.withdraw
        ? (str(x?['ref']).isNotEmpty ? tr('حەواڵە {0}', [ltr(x!['ref'])]) : '')
        : (str(x?['account']).isNotEmpty ? '$method ${ltr(x!['account'])}' : '');
    // هەنگاوەکان: نێردرا ← پشکنین/ناردن ← تەواو. هەڵوەشاندنەوە پێش پشکنینی یەکسا دەکرێت، بۆیە
    // هەنگاوی ناوەڕاست تێپەڕ نابێت؛ ڕەتکردنەوە دوای پشکنینە، بۆیە ئەو هەنگاوە تەواوە
    final reviewed = ok || st == 'rejected';
    final steps = <(String, String, int)>[
      (tr('داواکاری نێردرا'), [when, detail].where((s) => s.isNotEmpty).join('\n'), 2),
      (widget.withdraw ? tr('یەکسا پارەکە دەنێرێت') : tr('یەکسا دەیپشکنێت'), st == 'pending' ? tr('ئاسایی لە ماوەیەکی کورتدا') : '', reviewed ? 2 : (st == 'pending' ? 1 : 0)),
      (bad ? sub : (widget.withdraw ? tr('نێردرا بۆ هەژمارەکەت') : tr('زیادکرا بۆ جزدان')), '', ok || bad ? 2 : 0),
    ];
    Widget dot(int s, bool last) {
      if (s == 2) {
        final c = last && bad ? t.danger : t.act;
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          alignment: Alignment.center,
          child: YkIcon(last && bad ? 'x' : 'check', size: 12, color: last && bad ? Colors.white : t.actText, stroke: 3.2),
        );
      }
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(shape: BoxShape.circle, color: s == 1 ? t.bg : t.silver, border: Border.all(color: s == 1 ? t.act : t.silverLine, width: s == 1 ? 3 : 1.5)),
      );
    }

    return Scaffold(
      body: YkScreen(children: [
        YkHeader(title),
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? t.okBg : bad ? t.dangerBg : t.silver, border: Border.all(color: ok || bad ? Colors.transparent : t.silverLine)),
            alignment: Alignment.center,
            child: YkIcon(ok ? 'check' : bad ? 'x' : 'clock', size: 34, color: ok ? t.okText : bad ? t.dangerText : t.act, stroke: 2.2),
          ),
        ),
        Column(children: [
          Text(Fmt.n(Fmt.group(amount)), textDirection: TextDirection.ltr, style: TextStyle(fontFamily: Fmt.digits == 'en' ? 'Arial' : null, fontSize: 32, fontWeight: FontWeight.w900, color: t.text)),
          Text(sub, textAlign: TextAlign.center, style: Ts.muted(context, size: 14)),
        ]),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < steps.length; i++)
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Column(children: [
                    dot(steps[i].$3, i == steps.length - 1),
                    if (i < steps.length - 1) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: steps[i].$3 > 0 && steps[i + 1].$3 > 0 ? t.act : t.silverLine)),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 18 : 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(steps[i].$1, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: steps[i].$3 == 0 ? t.muted : (i == steps.length - 1 && bad ? t.dangerText : t.text))),
                        if (steps[i].$2.isNotEmpty) Text(steps[i].$2, style: Ts.muted(context, size: 12.5)),
                      ]),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        if (st == 'pending')
          YkButton(tr('هەڵوەشاندنەوەی داواکاری'), kind: BtnKind.secondary, block: true, busy: _busy, onPressed: () async {
            final warn = widget.withdraw ? tr('داوای ڕاکێشان هەڵدەوەشێتەوە؟') : tr('داواکاری زیادکردن هەڵدەوەشێتەوە؟ ئەگەر پارەت ناردووە، هەڵی مەوەشێنەرەوە.');
            if (!await askConfirm(context, warn, yes: tr('هەڵوەشاندنەوە'))) return;
            setState(() => _busy = true);
            if (widget.withdraw) {
              await cloud.cancelWithdraw(widget.id);
            } else {
              await cloud.cancelTopup(widget.id);
            }
            if (mounted) setState(() => _busy = false);
          }),
        YkButton(tr('گەڕانەوە بۆ جزدان'), block: true, large: true, onPressed: () => Navigator.of(context).maybePop()),
      ]),
    );
  }
}

Widget _pendingWithdraw(BuildContext context, Json w) {
  final e = {'id': w['id'], 'type': 'withdraw', 'amount': -((w['amount'] as num?) ?? 0), 'method': w['method'], 'note': str(w['account']).isEmpty ? tr('چاوەڕێی ناردنی یەکسا') : w['account'], 'at': w['at']};
  return TxRow(e, pending: true, onTap: () => push(context, RequestStatusScreen(withdraw: true, id: str(w['id']))));
}

Widget _pendingTopup(BuildContext context, Json x) {
  final refund = x['kind'] == 'refund';
  final e = {
    'id': x['id'],
    'type': refund ? 'refund' : 'topup',
    'amount': x['amount'],
    'method': refund ? null : x['method'],
    'ref': x['ref'],
    'note': refund ? x['note'] : (str(x['ref']).isNotEmpty ? tr('چاوەڕێی پشکنینی یەکسا، حەواڵە {0}', [x['ref']]) : tr('چاوەڕێی پشکنینی یەکسا')),
    'at': x['at'],
  };
  // گەڕاندنەوە پسوولەیە؛ زیادکردن پەڕەی دۆخی داواکارییەکە دەکاتەوە
  return TxRow(e, pending: true, onTap: () {
    if (refund) {
      showReceipt(context, e, pending: true);
    } else {
      push(context, RequestStatusScreen(withdraw: false, id: str(x['id'])));
    }
  });
}

/* ---------------- ناردن ---------------- */

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});
  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _phone = TextEditingController();
  final _amt = TextEditingController();
  final _note = TextEditingController();
  ({String uid, String name, String phone})? _peer;
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _amt.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await context.read<Cloud>().lookupPeer(_phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.err != null) {
        _err = r.err;
      } else {
        _peer = (uid: r.uid!, name: r.name, phone: r.phone);
        _err = null;
      }
    });
  }

  Future<void> _send() async {
    final cloud = context.read<Cloud>();
    final p = _peer;
    if (p == null) return;
    final amount = parseAmount(_amt.text);
    if (amount <= 0) return toast(context, tr('بڕەکە بنووسە'));
    if (amount > cloud.freeBalance) {
      setState(() => _err = tr('باڵانسەکەت بەس نییە ({0})', [Fmt.money(cloud.freeBalance < 0 ? 0 : cloud.freeBalance)]));
      return;
    }
    if (!await askConfirm(context, tr('{0} بۆ {1} دەنێردرێت. دوای ناردن ناگەڕێتەوە.', [Fmt.money(amount), p.name]), yes: tr('ناردن'), danger: false)) return;
    setState(() => _busy = true);
    final err = await cloud.sendMoney(p.uid, p.name, amount, _note.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _err = err);
      return;
    }
    final nav = Navigator.of(context);
    nav.pop();
    showYkSheet(nav.context, builder: (c) {
      final t = c.yk;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(width: 68, height: 68, decoration: BoxDecoration(shape: BoxShape.circle, color: t.okBg), alignment: Alignment.center, child: YkIcon('check', size: 34, color: t.okText, stroke: 2.6)),
        ),
        const SizedBox(height: 10),
        Text(tr('نێردرا'), textAlign: TextAlign.center, style: Ts.h2(c)),
        Text(tr('{0} چووە جزدانی {1}', [Fmt.money(amount), p.name]), textAlign: TextAlign.center, style: Ts.muted(c, size: 14)),
        const SizedBox(height: 14),
        YkButton(tr('باشە'), block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final f = cloud.freeBalance < 0 ? 0 : cloud.freeBalance;
    final p = _peer;
    return Scaffold(
      body: YkScreen(children: [
        YkHeader(tr('ناردن بۆ سەرنشین')),
        if (p != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: context.yk.chip, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const PersonAvatar(size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: Ts.bold(context)),
                  Text(tr('{0} · سەرنشینی یەکسا', [Fmt.phone(p.phone)]), style: Ts.muted(context, size: 12.5)),
                ]),
              ),
              YkButton(tr('گۆڕین'), small: true, kind: BtnKind.secondary, onPressed: () => setState(() {
                    _peer = null;
                    _err = null;
                  })),
            ]),
          )
        else ...[
          YkField(
            label: tr('ژمارەی مۆبایلی سەرنشینی وەرگر'),
            child: Row(children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    onChanged: (v) {
                      if (_err != null) setState(() => _err = null);
                      if (RegExp(r'^7\d{9}$').hasMatch(cleanPhone(v))) _find();
                    },
                    decoration: ykInput(context, hint: '7xx xxx xxxx'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              YkButton(tr('دۆزینەوە'), icon: 'search', kind: BtnKind.secondary, busy: _busy, onPressed: _find),
            ]),
          ),
          Text(tr('تەنها دەتوانیت بۆ سەرنشینێکی تری یەکسا بنێریت.'), style: Ts.muted(context, size: 12.8)),
        ],
        if (_err != null) YkError(_err!),
        if (p != null) ...[
          _AmountField(ctrl: _amt, label: tr('بڕ'), sub: Fmt.n(tr('دینار · بەردەست {0}', [Fmt.group(f)]))),
          YkField(label: tr('تێبینی'), optional: true, child: TextField(controller: _note, maxLength: 80, decoration: ykInput(context, hint: tr('بۆ نموونە: پارەی مانگی خوشکم')))),
          YkButton(tr('ناردن'), icon: 'send', block: true, large: true, busy: _busy, onPressed: f > 0 ? _send : null),
          _trust(context, tr('پارەکە یەکسەر دەچێتە جزدانی وەرگر. دوای ناردن ناگەڕێتەوە، بۆیە ناوەکە باش بپشکنە.')),
        ],
      ]),
    );
  }
}

/* ---------------- مامەڵەکان ---------------- */

class TxsScreen extends StatefulWidget {
  const TxsScreen({super.key});
  @override
  State<TxsScreen> createState() => _TxsScreenState();
}

class _TxsScreenState extends State<TxsScreen> {
  String _k = 'all';
  static List<(String, String)> get _f => [('all', tr('هەمووی')), ('in', tr('زیادکردن')), ('out', tr('ڕاکێشان')), ('xfer', tr('ناردن و وەرگرتن')), ('month', tr('پارەی مانگ')), ('back', tr('گەڕاندنەوە'))];
  static const _types = {
    'in': ['topup', 'adjust+'],
    'out': ['withdraw', 'adjust-'],
    'xfer': ['xfer'],
    'month': ['monthpay'],
    'back': ['refund', 'skipref', 'comp'],
  };

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final all = cloud.myWallet.where((e) => e['type'] != 'legacy').toList();
    bool inK(Json e) {
      if (_k == 'all') return true;
      final ty = _types[_k]!;
      if (e['type'] == 'adjust') return ty.contains(((e['amount'] as num?) ?? 0) >= 0 ? 'adjust+' : 'adjust-');
      return ty.contains(e['type']);
    }

    final list = all.where(inK).toList();
    final m0 = DateTime(DateTime.now().year, DateTime.now().month, 1).millisecondsSinceEpoch;
    final inM = all.where((e) => ((e['at'] as num?) ?? 0) >= m0);
    final sumIn = inM.fold<num>(0, (n, e) => n + (((e['amount'] as num?) ?? 0) > 0 ? (e['amount'] as num) : 0));
    final sumOut = inM.fold<num>(0, (n, e) => n + (((e['amount'] as num?) ?? 0) < 0 ? -(e['amount'] as num) : 0));
    final pTp = cloud.myTopupsPending.where((x) => _k == 'all' || _k == 'in' || (_k == 'back' && x['kind'] == 'refund')).toList();
    final pWd = cloud.myWithdrawsPending.where((w) => _k == 'all' || _k == 'out').toList();

    // کۆمەڵکردن بە پێی ڕۆژ: ئەمڕۆ، دوێنێ، پاشان مانگ
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final groups = <String, List<Json>>{};
    for (final e in list) {
      final at = ((e['at'] as num?) ?? 0).toInt();
      final d = DateTime.fromMillisecondsSinceEpoch(at);
      final k = at >= d0 ? tr('ئەمڕۆ') : at >= d0 - 86400000 ? tr('دوێنێ') : Fmt.n('${Fmt.month(d.month - 1)} ${d.year}');
      groups.putIfAbsent(k, () => []).add(e);
    }
    Widget sum(String k, String v, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: Ts.muted(context, size: 12)),
              Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.8, color: c)),
            ]),
          ),
        );
    return Scaffold(
      body: YkScreen(onRefresh: context.read<Cloud>().refresh, children: [
        YkHeader(tr('مامەڵەکان')),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in _f) ...[YkChip(f.$2, on: _k == f.$1, onTap: () => setState(() => _k = f.$1)), const SizedBox(width: 6)],
          ]),
        ),
        Row(children: [
          sum(tr('هاتوو ئەم مانگە'), '+${Fmt.n(Fmt.group(sumIn))}', t.okText),
          const SizedBox(width: 10),
          sum(tr('چوو ئەم مانگە'), '−${Fmt.n(Fmt.group(sumOut))}', t.text),
        ]),
        if (pTp.isNotEmpty || pWd.isNotEmpty) ...[
          Text(tr('چاوەڕێ'), style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
          YkList(children: [
            for (final x in pTp) _pendingTopup(context, x),
            for (final w in pWd) _pendingWithdraw(context, w),
          ]),
        ],
        for (final g in groups.entries) ...[
          Row(children: [
            Expanded(child: Text(g.key, style: TextStyle(fontWeight: FontWeight.w800, color: t.text))),
          ]),
          YkList(children: [for (final e in g.value) TxRow(e)]),
        ],
        if (list.isEmpty && pTp.isEmpty && pWd.isEmpty)
          YkEmpty(
            icon: 'wallet',
            title: tr('هیچ مامەڵەیەک نییە'),
            text: _k == 'all' ? tr('هەر پارەیەک زیاد بکەیت، ڕایبکێشیت یان بینێریت، لێرە دەردەکەوێت') : tr('لەم جۆرە هیچ مامەڵەیەک نییە'),
          ),
      ]),
    );
  }
}
