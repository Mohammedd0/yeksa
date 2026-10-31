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
import '../core/images.dart';
import '../core/sel.dart';
import '../ui/help.dart';
import '../ui/form_parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'account_screens.dart' show showContactSheet;
import 'nav.dart';
import 'request_screen.dart' show askConfirm;

int _pos(int x) => x < 0 ? 0 : x;

/// «٢٥٬٠٠٠» ← 25000
int parseAmount(String v) => int.tryParse(v.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}').replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

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
            const TextSpan(text: 'دینار', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white70)),
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
            Text(pending ? 'چاوەڕێ' : Fmt.clock(Fmt.hhmm(((e['at'] as num?) ?? 0).toInt())), style: Ts.muted(context, size: 11)),
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
          TextSpan(text: 'دینار', style: TextStyle(fontSize: 16, color: t.muted, fontWeight: FontWeight.w400)),
        ]),
        textAlign: TextAlign.center,
        style: Ts.h1(c),
      ),
      Center(child: pending ? const YkBadge('چاوەڕێی پشکنینە', tone: BadgeTone.note) : const YkBadge('تۆمارکراو', tone: BadgeTone.ok)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(Yk.rMd), border: Border.all(color: t.line)),
        child: Column(children: [
          row('جۆر', l.title),
          row('وردەکاری', l.sub),
          row('شێواز', e['method'] != null ? cloud.payName(e['method']) : ''),
          row('ژمارەی حەواڵە', str(e['ref']), latin: true),
          row('کات', '${Fmt.date(at)}، ${Fmt.clock(Fmt.hhmm(at))}'),
          row('ناسنامە', idTxt, latin: true),
        ]),
      ),
      if (extra != null) ...[const SizedBox(height: 12), extra],
      const SizedBox(height: 10),
      if (!pending)
        YkButton('هاوبەشکردنی پسوولە', icon: 'share', kind: BtnKind.secondary, block: true, onPressed: () {
          SharePlus.instance.share(ShareParams(text: 'یەکسا: ${l.title}\n${amt > 0 ? '+' : '−'}${Fmt.money(amt.abs())}\n${Fmt.date(at)}، ${Fmt.hhmm(at)}\n$idTxt'));
        }),
      const SizedBox(height: 8),
      YkButton('داخستن', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
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
        const YkHeader('پارەدان'),
        YkCard(
          big: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('فاتورەی ${str(b['month'])}', style: Ts.bold(context))),
              paid ? const YkBadge('دراوە', tone: BadgeTone.ok) : const YkBadge('ئامادەیە', tone: BadgeTone.note),
            ]),
            const SizedBox(height: 6),
            if (lines.isEmpty) Text('هیچ بەشدارییەکی چالاک نییە', style: Ts.muted(context, size: 14)),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(str(l['label']), style: Ts.sm(context)),
                      if (str(l['note']).isNotEmpty) Text('${l['note']}، نرخی تەواو ${Fmt.n(Fmt.group((l['full'] as num?) ?? 0))}', style: Ts.muted(context, size: 12.5)),
                    ]),
                  ),
                  _b(Fmt.n(Fmt.group((l['amount'] as num?) ?? 0)), size: 14),
                ]),
              ),
            if (promo > 0) _row(context, 'داشکاندن (${str(pr['code'])})', _b(Fmt.n(Fmt.group(promo)), color: t.okText, size: 14)),
            for (final d in discounts) _row(context, d.$1, _b(Fmt.n(Fmt.group(-d.$2)), color: t.okText, size: 14)),
            if (credit > 0)
              for (final a in (h0 != null ? [<String, dynamic>{'note': 'قەرەبوو', 'amount': credit}] : inv.adjustments))
                _row(context, str(a['note']), _b(Fmt.n(Fmt.group((a['amount'] as num?) ?? 0)), color: t.okText, size: 14)),
            const YkHr(),
            Row(children: [
              Expanded(child: Text('کۆی گشتی', style: Ts.bold(context))),
              Text(Fmt.money(total), style: Ts.h2(context).copyWith(color: t.brand)),
            ]),
            if (h0 == null && inv.waiting.isNotEmpty)
              Text('${Fmt.money(inv.waiting.fold<int>(0, (n, d) => n + d.amount))} داشکاندنی چاوەڕوان لە فاتورەی داهاتوو دەبڕدرێت', style: Ts.muted(context, size: 12.8)),
          ]),
        ),
        if (paid)
          YkButton('پسوولە', icon: 'receipt', kind: BtnKind.secondary, block: true, onPressed: () => _billReceipt(context))
        else ...[
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('شێوازی پارەدان', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.muted)),
            const SizedBox(height: 6),
            YkSeg<String>(
              options: const [('fib', 'FIB'), ('fastpay', 'FastPay'), ('cash', 'کاش')],
              value: str(b['method']).isEmpty ? 'cash' : str(b['method']),
              onChanged: (v) => cloud.setPayMethod(v),
            ),
          ]),
          if (pr.isEmpty) const _PromoField(),
          YkButton('پارەدان، ${Fmt.money(inv.total)}', block: true, onPressed: inv.total > 0 ? () => _payNow(context) : null),
          if (p1000 > 0) Text(Fmt.n('بە هەر ${Fmt.group(1000)} دینار، $p1000 خاڵی پاداشت وەردەگریت'), textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8)),
        ],
        Text('مێژووی پارەدان', style: Ts.h3(context)),
        if (history.isEmpty)
          Text('هێشتا هیچ پارەدانێک نییە', style: Ts.muted(context, size: 14))
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
                      Text(str(h['month']), style: Ts.bold(context)),
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
    final m = const {'fib': 'FIB', 'fastpay': 'FastPay', 'cash': 'کاش'}[method] ?? method;
    var busy = false;
    showYkSheet(context, builder: (c) {
      return StatefulBuilder(builder: (c, setS) {
        final t = c.yk;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('پشتڕاستکردنەوەی پارەدان', style: Ts.h2(c)),
          const SizedBox(height: 12),
          YkCard(
            child: Column(children: [
              _row(c, 'بڕ', _b(Fmt.money(inv.total), color: t.brand)),
              _row(c, 'شێواز', _b(m)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            method == 'cash' ? 'پارەکە بدە بە بەڕێوەبەر یان نوێنەری یەکسا؛ کاتێک وەریگرت تۆماری دەکات.' : 'لە ئەپی $m بنێرە بۆ هەژماری یەکسا، پاشان لێرە پشتڕاستی بکەرەوە. یەکسا دەیپشکنێت.',
            style: Ts.muted(c, size: 12.8),
          ),
          const SizedBox(height: 14),
          YkButton('پارەدان', block: true, busy: busy, onPressed: () async {
            setS(() => busy = true);
            final pts = await cloud.pay();
            if (c.mounted) Navigator.pop(c);
            if (context.mounted) toast(context, 'پارەدان سەرکەوتوو بوو${pts > 0 ? Fmt.n('، $pts خاڵ زیاد کرا') : ''}');
          }),
          const SizedBox(height: 8),
          YkButton('پاشگەزبوونەوە', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
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
      final text = StringBuffer('یەکسا، پسوولەی ${h['month']}\n${Fmt.date(at)}\n${p['name']}، ${Fmt.phone(str(p['phone']))}\n');
      final rows = <(String, String)>[
        for (final l in lines) (str(l['label']), Fmt.n(Fmt.group((l['amount'] as num?) ?? 0))),
        if (((h['promo'] as num?) ?? 0) > 0) ('داشکاندن', Fmt.n(Fmt.group(h['promo'] as num))),
        for (final d in asList(h['discounts']).map(asMap)) (str(d['label']), Fmt.n(Fmt.group(-((d['amount'] as num?) ?? 0)))),
        if (((h['credit'] as num?) ?? 0) > 0) ('قەرەبوو', Fmt.n(Fmt.group(h['credit'] as num))),
      ];
      for (final r in rows) {
        text.writeln('${r.$1}: ${r.$2}');
      }
      text.write('کۆی گشتی: ${Fmt.money((h['total'] as num?) ?? 0)}');
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(Yk.rLg), border: Border.all(color: t.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('یەکسا', style: Ts.h2(c))),
              const YkBadge('دراوە', tone: BadgeTone.ok),
            ]),
            const SizedBox(height: 8),
            Text('پسوولەی ${h['month']}', style: Ts.bold(c)),
            Text(Fmt.date(at), style: Ts.muted(c, size: 12.8)),
            Text('${p['name']}، ${Fmt.phone(str(p['phone']))}', style: Ts.muted(c, size: 12.8)),
            const YkHr(),
            for (final r in rows) _row(c, r.$1, _b(r.$2, size: 14)),
            const YkHr(),
            _row(c, 'کۆی گشتی', _b(Fmt.money((h['total'] as num?) ?? 0))),
          ]),
        ),
        const SizedBox(height: 12),
        YkButton('هاوبەشکردن / پاشەکەوت', icon: 'share', block: true, onPressed: () => SharePlus.instance.share(ShareParams(text: text.toString()))),
        const SizedBox(height: 8),
        YkButton('داخستن', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
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
          decoration: ykInput(context, hint: 'کۆدی داشکاندن (ئەگەر هەتە)'),
        ),
      ),
      const SizedBox(width: 8),
      YkButton('جێبەجێکردن', kind: BtnKind.secondary, onPressed: () async {
        final cloud = context.read<Cloud>();
        final code = _c.text;
        final err = await cloud.applyPromo(code);
        final n = cloud.list('news').where((x) => str(x['code']).toUpperCase() == code.trim().toUpperCase()).firstOrNull;
        if (context.mounted) toast(context, err ?? Fmt.n('داشکاندنی ${n?['rate'] ?? 10}٪ جێبەجێ کرا'));
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
              Expanded(child: Text(label, style: Ts.bold(context))),
              YkIcon('forward', size: 16, color: t.muted),
            ]),
          ),
        );
    return Scaffold(
      body: YkScreen(onRefresh: context.read<Cloud>().refresh, children: [
        const YkHeader('جزدانەکەم', right: HelpButton('wallet')),
        WalletCard(
          title: 'باڵانسی بەردەست',
          tag: 'جزدانی یەکسا',
          amount: bal - cloud.pendingWithdraw,
          pills: [
            (
              inv.lines.isNotEmpty ? 'calendar' : 'check',
              inv.lines.isNotEmpty
                  ? Text.rich(TextSpan(children: [
                      const TextSpan(text: 'ئەم مانگە '),
                      TextSpan(text: Fmt.n(Fmt.group(inv.total)), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]))
                  : Text(paidNow ? 'ئەم مانگە دراوە' : 'هیچ پارەیەک نییە'),
            ),
          ],
        ),
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
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('پارەدان', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0B1733))),
                  Text('پارەی مانگانەی شۆفێرەکانت', style: TextStyle(fontSize: 12.8, color: Color(0xFF0B1733))),
                ]),
              ),
              const YkIcon('forward', size: 20, color: Color(0xFF0B1733)),
            ]),
          ),
        ),
        _trust(context, 'پارەکەت لای یەکسا پارێزراوە. هەر جووڵەیەک لێرە تۆمار دەکرێت.'),
        Row(children: [tile('plus', 'زیادکردن', const TopupScreen()), const SizedBox(width: 10), tile('download', 'ڕاکێشان', const WithdrawScreen())]),
        Row(children: [tile('send', 'ناردن', const SendMoneyScreen()), const SizedBox(width: 10), tile('receipt', 'مامەڵەکان', const TxsScreen())]),
        if (inv.lines.isNotEmpty)
          YkCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('پارەی ${str(cloud.billing['month'])}', style: Ts.bold(context))),
                const YkBadge('گەشتەکان چاوەڕێن', tone: BadgeTone.note),
              ]),
              const SizedBox(height: 10),
              _Progress(value: bal / (inv.total == 0 ? 1 : inv.total)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text(Fmt.n('ئامادەیە ${Fmt.group(bal.clamp(0, inv.total))}'), style: Ts.muted(context, size: 14))),
                Text(Fmt.n('لە ${Fmt.group(inv.total)}'), style: Ts.muted(context, size: 14)),
              ]),
              const SizedBox(height: 10),
              need > 0
                  ? YkButton('زیادکردنی ${Fmt.n(Fmt.group(need))} ی ماوە', icon: 'plus', small: true, block: true, kind: BtnKind.secondary, onPressed: () => push(context, TopupScreen(amount: need)))
                  : YkButton('پارەدانی مانگ لە جزدان', icon: 'check', small: true, block: true, onPressed: () => push(context, const PayMonthScreen())),
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
          const YkHeader('پارەدانی مانگ'),
          YkEmpty(
            icon: 'receipt',
            title: has ? 'پارەی ئەم مانگە دراوە' : 'هیچ بەشدارییەکت نییە',
            text: has ? 'گەشتەکانت بەردەوامن. مانگی داهاتوو لێرە دەردەکەوێت.' : 'بەشدارییەکی مانگانە دروست بکە',
            button: YkButton('جزدانەکەم', kind: BtnKind.secondary, onPressed: () => Navigator.of(context).maybePop()),
          ),
        ]),
      );
    }
    return Scaffold(
      body: YkScreen(children: [
        const YkHeader('پارەدانی مانگ'),
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
                      Text('${fmtDays(asList(s['days']))}${l.note.isNotEmpty ? '، ${l.note}' : ''}', style: Ts.muted(context, size: 12.5)),
                    ]),
                  ),
                  _b(Fmt.n(Fmt.group(l.amount))),
                ]);
              }),
            ],
            if (inv.promo > 0 || inv.discounts.isNotEmpty) const YkHr(),
            if (inv.promo > 0) _row(context, 'داشکاندنی هاوبەش', _b('−${Fmt.n(Fmt.group(inv.promo))}', color: t.okText)),
            for (final d in inv.discounts) _row(context, d.label, _b('−${Fmt.n(Fmt.group(d.amount))}', color: t.okText)),
            const SizedBox(height: 6),
            if (pr.isNotEmpty) _row(context, 'کۆدی داشکاندن', _b(str(pr['code']), size: 14)) else const _PromoField(),
            const YkHr(),
            _row(context, 'کۆی پارەی ${str(cloud.billing['month'])}', _b(Fmt.money(inv.total))),
            _row(context, 'باڵانسی جزدانەکەت', _b(Fmt.money(bal), color: bal >= inv.total ? t.okText : null)),
            const SizedBox(height: 6),
            if (need > 0) ...[
              _Progress(value: bal / (inv.total == 0 ? 1 : inv.total)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text(Fmt.n('لە جزدانەکەت ${Fmt.group(bal < 0 ? 0 : bal)}'), style: Ts.muted(context, size: 14))),
                Text(Fmt.n('پێویستە ${Fmt.group(need)} ی تر'), style: TextStyle(fontSize: 14, color: t.dangerText, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              YkButton('زیادکردنی ${Fmt.n(Fmt.group(need))}', icon: 'plus', block: true, large: true, onPressed: () => push(context, TopupScreen(amount: need))),
            ] else ...[
              _row(context, 'باڵانس دوای پارەدان', _b(Fmt.money(bal - inv.total))),
              const SizedBox(height: 10),
              YkButton('پارەدان لە جزدان', icon: 'check', block: true, large: true, busy: _busy, onPressed: () async {
                setState(() => _busy = true);
                final err = await cloud.payMonth();
                if (!context.mounted) return;
                setState(() => _busy = false);
                if (err != null) {
                  toast(context, err);
                  return;
                }
                toast(context, 'پارەی مانگ درا، گەشتەکان دەست پێدەکەن');
                Navigator.of(context).maybePop();
              }),
            ],
            const SizedBox(height: 10),
            _trust(context, 'پارەکە لای یەکسا دەمێنێتەوە و ڕۆژ بە ڕۆژ، تەنها دوای تەواوبوونی هەر گەشتێک، دەچێتە سەر حیسابی شۆفێر.'),
          ]),
        ),
        if (inv.waiting.isNotEmpty) Text('${inv.waiting.map((w) => w.label).join('، ')} بۆ مانگی داهاتوو دەمێنێتەوە.', style: Ts.muted(context, size: 12.8)),
      ]),
    );
  }
}

/* ---------------- پارەدان: نەدراو و دراو ---------------- */

String _monthName(String mk) {
  final p = mk.split('-');
  return '${kMonths[int.parse(p[1]) - 1]} ${Fmt.n(p[0])}';
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _tab = 'due';
  String? _month; // مانگی هەڵبژێردراو (تەنها یەک مانگ لە یەک کاتدا)
  final Set<String> _sel = {};
  bool _busy = false;
  bool _init = false;

  List<String> get _months {
    final now = DateTime.now();
    return [Fmt.monthKey(), Fmt.monthKey(DateTime(now.year, now.month + 1, 1))];
  }

  void _toggle(String mk, String subId) {
    setState(() {
      if (_month != mk) {
        _month = mk;
        _sel.clear();
      }
      if (!_sel.remove(subId)) _sel.add(subId);
      if (_sel.isEmpty) _month = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    // لە یەکەم جاردا هەموو بڕەکانی یەکەم مانگی نەدراو هەڵدەبژێردرێن
    if (!_init) {
      _init = true;
      for (final mk in _months) {
        final ls = cloud.dueLines(mk: mk);
        if (ls.isNotEmpty) {
          _month = mk;
          _sel.addAll(ls.map((l) => l.subId));
          break;
        }
      }
    }
    final paid = cloud.myWallet.where((e) => e['type'] == 'monthpay' && e['incoming'] != true).toList();
    return Scaffold(
      body: YkScreen(onRefresh: cloud.refresh, children: [
        const YkHeader('پارەدانی مانگانە'),
        YkSeg<String>(
          options: [('due', 'نەدراو'), ('paid', Fmt.n('دراو (${paid.length})'))],
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        if (_tab == 'due') ..._due(context, cloud) else ..._paid(context, paid),
      ]),
    );
  }

  List<Widget> _due(BuildContext context, Cloud cloud) {
    final t = context.yk;
    final groups = [for (final mk in _months) (mk, cloud.dueLines(mk: mk))].where((g) => g.$2.isNotEmpty).toList();
    if (groups.isEmpty) {
      return [
        YkEmpty(
          icon: 'receipt',
          title: cloud.mySubs.isEmpty ? 'هیچ بەشدارییەکت نییە' : 'هەموو پارەکان دراون',
          text: cloud.mySubs.isEmpty ? 'بەشدارییەکی مانگانە دروست بکە' : 'پارەی ئەم مانگە و مانگی داهاتوو دراوە. لە «دراو» پسوولەکان دەبینیت.',
        ),
      ];
    }
    final mk = _month;
    final inv = mk == null || _sel.isEmpty ? null : cloud.invoice(due: true, mk: mk, only: _sel);
    final bal = cloud.balance;
    final total = inv?.total ?? 0;
    final need = _pos(total - bal);
    return [
      for (final (m, lines) in groups) ...[
        PLabel(_monthName(m)),
        for (final l in lines)
          Builder(builder: (context) {
            final s = cloud.sub(l.subId) ?? const {};
            final d = cloud.driver(s['driverId']) ?? const {};
            final on = _month == m && _sel.contains(l.subId);
            return YkCard(
              onTap: () => _toggle(m, l.subId),
              child: Row(children: [
                YkCheck(on),
                const SizedBox(width: 10),
                PersonAvatar(size: 46, imageId: str(d['photo']).isEmpty ? null : str(d['photo'])),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(str(d['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.bold(context)),
                    Text('${str(s['riderNames'])} · ${fmtDays(asList(s['days']))}${l.note.isNotEmpty ? '، ${l.note}' : ''}',
                        maxLines: 2, style: Ts.muted(context, size: 12.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _b(Fmt.n(Fmt.group(l.amount))),
                  const SizedBox(height: 4),
                  const YkBadge('نەدراو', tone: BadgeTone.note),
                ]),
              ]),
            );
          }),
      ],
      if (inv != null)
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _row(context, Fmt.n('بڕی ${_monthName(mk!)} (${inv.lines.length} شۆفێر)'), _b(Fmt.money(inv.sub))),
            if (inv.promo > 0) _row(context, 'داشکاندنی هاوبەش', _b('−${Fmt.n(Fmt.group(inv.promo))}', color: t.okText)),
            for (final d in inv.discounts) _row(context, d.label, _b('−${Fmt.n(Fmt.group(d.amount))}', color: t.okText)),
            const YkHr(),
            _row(context, 'کۆی گشتی', _b(Fmt.money(total))),
            _row(context, 'باڵانسی جزدان', _b(Fmt.money(bal), color: bal >= total ? t.okText : null)),
            if (need > 0) _row(context, 'ماوە بۆ زیادکردن', _b(Fmt.money(need), color: t.dangerText)),
            const SizedBox(height: 10),
            if (need > 0)
              YkButton('زیادکردنی ${Fmt.n(Fmt.group(need))} ی ماوە', icon: 'plus', block: true, large: true, onPressed: () => push(context, TopupScreen(amount: need)))
            else
              YkButton('پارەدان لە جزدان', icon: 'check', block: true, large: true, busy: _busy, onPressed: () async {
                final ok = await askConfirm(context, '${Fmt.money(total)} لە جزدانەکەت بۆ ${_monthName(mk)} دەدرێت.', yes: 'پارەدان', danger: false);
                if (!ok || !context.mounted) return;
                setState(() => _busy = true);
                final err = await cloud.payMonth(mk: mk, only: {..._sel});
                if (!context.mounted) return;
                setState(() => _busy = false);
                if (err != null) return toast(context, err);
                toast(context, 'پارەی ${_monthName(mk)} درا');
                setState(() {
                  _sel.clear();
                  _month = null;
                  _tab = 'paid';
                });
              }),
            const SizedBox(height: 10),
            _trust(context, 'پارەکە لای یەکسا دەمێنێتەوە و ڕۆژ بە ڕۆژ، تەنها دوای تەواوبوونی هەر گەشتێک، دەچێتە سەر حیسابی شۆفێر.'),
          ]),
        )
      else
        Text('ئەو شۆفێرانە هەڵبژێرە کە پارەکەیان دەدەیت', textAlign: TextAlign.center, style: Ts.muted(context, size: 13.4)),
    ];
  }

  List<Widget> _paid(BuildContext context, List<Json> paid) {
    final t = context.yk;
    if (paid.isEmpty) {
      return [const YkEmpty(icon: 'receipt', title: 'هێشتا هیچ پارەیەکت نەداوە', text: 'هەر پارەیەکی مانگانە بدەیت، لێرە وەک بەڵگە دەمێنێتەوە')];
    }
    return [
      for (final e in paid)
        YkCard(
          onTap: () => showReceipt(context, e),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(str(e['month']).isEmpty ? str(e['note']) : _monthName(str(e['month'])), style: Ts.bold(context))),
              const YkBadge('دراو ✓', tone: BadgeTone.ok),
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
              Expanded(child: Text('کۆی دراو', style: Ts.muted(context, size: 13.4))),
              Text(Fmt.money(-(((e['amount'] as num?) ?? 0))), style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
            ]),
          ]),
        ),
    ];
  }
}

/* ---------------- زیادکردن ---------------- */

class _Steps extends StatelessWidget {
  const _Steps(this.n);
  final int n;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(child: Container(height: 5, decoration: BoxDecoration(color: i < n ? t.act : t.chip, borderRadius: BorderRadius.circular(3)))),
      ],
    ]);
  }
}

/// خانەی گەورەی بڕ (amt-hero)
class _AmountField extends StatelessWidget {
  const _AmountField({required this.ctrl, required this.label, this.sub = 'دینار', this.onChanged});
  final TextEditingController ctrl;
  final String label, sub;
  final ValueChanged<int>? onChanged;
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
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩,٬]'))],
        onChanged: (v) => onChanged?.call(parseAmount(v)),
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: t.text),
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '0', contentPadding: EdgeInsets.symmetric(vertical: 8)),
      ),
      Text(sub, style: Ts.muted(context, size: 12.8).copyWith(height: 1.7)),
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

class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key, this.amount = 0});
  final int amount;
  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  late final TextEditingController _amt;
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
    _amt = TextEditingController(text: Fmt.group(_amount));
  }

  @override
  void dispose() {
    _amt.dispose();
    _ref.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final ms = cloud.payMethods.where((m) => m['on'] != false && m['topup'] != false && (m['account'] == false || str(m['yeksaAccount']).isNotEmpty)).toList();
    if (_method == null || !ms.any((m) => m['id'] == _method)) _method = ms.isEmpty ? null : str(ms.first['id']);
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(() => _step = 1);
      },
      child: Scaffold(body: _step == 1 ? _first(context, ms) : _second(context)),
    );
  }

  Widget _first(BuildContext context, List<Json> ms) {
    final t = context.yk;
    final base = [25000, 50000, 100000];
    final chips = [...base, if (_needR > 0 && !base.contains(_needR)) _needR];
    return YkScreen(children: [
      const YkHeader('زیادکردنی پارە'),
      const _Steps(1),
      _AmountField(ctrl: _amt, label: 'چەند دەخەیتە سەر جزدانەکەت؟', onChanged: (v) => setState(() => _amount = v)),
      Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
        for (final a in chips)
          YkChip(a == _needR ? Fmt.n('بۆ ئەم مانگە ${Fmt.group(a)}') : Fmt.n(Fmt.group(a)), on: _amount == a, onTap: () {
            setState(() => _amount = a);
            _amt.text = Fmt.group(a);
          }),
      ]),
      Text('بە چی دەینێریت؟', style: Ts.h3(context)),
      if (ms.isEmpty)
        const YkCard(tone: CardTone.note, child: Text('هێشتا هیچ شێوازێکی پارەدان دانەنراوە. پەیوەندی بە یەکسا بکە.', style: TextStyle(fontSize: 14)))
      else
        YkList(children: [
          for (final m in ms)
            InkWell(
              onTap: () => setState(() => _method = str(m['id'])),
              child: Container(
                color: _method == m['id'] ? t.chip : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  _mono(context, m),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(str(m['name']), style: Ts.bold(context)),
                      Text(m['account'] == false ? 'بیدە بە بەڕێوەبەر یان نوێنەری یەکسا' : 'لە ئەپی ${m['name']} بنێرە بۆ هەژماری یەکسا', style: Ts.muted(context, size: 12.5)),
                    ]),
                  ),
                  YkCheck(_method == m['id'], radio: true),
                ]),
              ),
            ),
        ]),
      YkButton('بەردەوام بوون', block: true, large: true, onPressed: ms.isEmpty
          ? null
          : () {
              final a = parseAmount(_amt.text);
              if (a < 1000) return toast(context, 'بڕەکە بنووسە');
              if (a > 5000000) return toast(context, 'بڕەکە زۆرە');
              setState(() {
                _amount = a;
                _step = 2;
              });
            }),
      _trust(context, 'پارەدانی ڕاستەوخۆ لە ناو ئەپ بە FIB و FastPay بەم زووانە دێت.', icon: 'lock'),
    ]);
  }

  Widget _second(BuildContext context) {
    final t = context.yk;
    final cloud = context.read<Cloud>();
    final m = cloud.payMethod(_method) ?? const {};
    final cash = m['account'] == false;
    Widget step(String n, String title, String sub) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: t.act), alignment: Alignment.center, child: Text(n, style: TextStyle(color: t.actText, fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Ts.sm(context).copyWith(fontWeight: FontWeight.w700)),
                Text(sub, style: Ts.muted(context, size: 12.5)),
              ]),
            ),
          ]),
        );
    return YkScreen(children: [
      YkHeader(cash ? 'پارەدان بە کاش' : 'ناردنی پارەکە'),
      const _Steps(2),
      if (cash)
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _mono(context, m),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${Fmt.money(_amount)} بە کاش', style: Ts.bold(context)),
                  Text('بیدە بە بەڕێوەبەر یان نوێنەری یەکسا', style: Ts.muted(context, size: 12.5)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Text('کاتێک پارەکەیان وەرگرت، باڵانسەکەت زیاد دەکەن و ئاگادار دەکرێیتەوە. بۆ کات و شوێن «پەیوەندی» بکە.', style: Ts.muted(context, size: 14)),
            const SizedBox(height: 10),
            YkButton('پەیوەندی بە یەکسا', icon: 'phone', small: true, block: true, kind: BtnKind.secondary, onPressed: () => showContactSheet(context)),
          ]),
        )
      else ...[
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _mono(context, m),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('بنێرە بۆ', style: Ts.muted(context, size: 12.5)),
                  Text(str(m['holder']).isEmpty ? 'یەکسا' : str(m['holder']), style: Ts.bold(context)),
                ]),
              ),
              const YkBadge('پشتڕاستکراو', tone: BadgeTone.ok),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(child: Text(str(m['yeksaAccount']), textDirection: TextDirection.ltr, style: TextStyle(fontFamily: 'Arial', fontSize: 20, fontWeight: FontWeight.w800, color: t.text))),
                YkButton('کۆپی', icon: 'copy', small: true, kind: BtnKind.secondary, onPressed: () {
                  Clipboard.setData(ClipboardData(text: str(m['yeksaAccount'])));
                  toast(context, 'کۆپی کرا');
                }),
              ]),
            ),
            const SizedBox(height: 6),
            _row(context, 'بڕ', _b(Fmt.money(_amount))),
          ]),
        ),
        YkCard(
          child: Column(children: [
            step('١', 'ئەپی ${m['name']} بکەرەوە و ${Fmt.n(Fmt.group(_amount))} بنێرە', 'بۆ ئەو ژمارەیەی سەرەوە'),
            step('٢', 'ژمارەی حەواڵەکە لێرە بنووسە', 'لە پسوولەی ${m['name']} کۆپی بکە'),
            step('٣', 'داواکاری بنێرە', 'یەکسا دەیپشکنێت و باڵانسەکەت زیاد دەکات'),
          ]),
        ),
        YkField(label: 'ژمارەی حەواڵە', child: Directionality(textDirection: TextDirection.ltr, child: TextField(controller: _ref, decoration: ykInput(context)))),
        InkWell(
          onTap: _pickPhoto,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line, width: 1.5)),
            child: Row(children: [
              if (_photo != null)
                ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 54, height: 54, child: YkImage(_photo, fit: BoxFit.cover)))
              else
                YkIcon('camera', size: 20, color: t.muted),
              const SizedBox(width: 10),
              Expanded(child: Text(_photo != null ? 'وێنەی پسوولە زیاد کرا، بۆ گۆڕین دابگرە' : 'وێنەی پسوولەکە زیاد بکە (ئارەزوومەندانە)', style: Ts.muted(context, size: 13.4))),
            ]),
          ),
        ),
      ],
      YkButton(cash ? 'ناردنی داواکاری' : 'پارەم نارد، پشکنین بکە', icon: 'send', block: true, large: true, busy: _busy, onPressed: () async {
        final ref = _ref.text.trim();
        if (!cash && ref.length < 3) return toast(context, 'ژمارەی حەواڵە بنووسە');
        setState(() => _busy = true);
        final id = await cloud.requestTopup(_amount, str(_method), ref, _photo);
        if (!context.mounted) return;
        setState(() => _busy = false);
        if (id == null) return toast(context, 'نەنێردرا، دووبارە هەوڵ بدەرەوە');
        // ڕاستەوخۆ دەگەڕێتەوە جزدانەکەم (TK.go(C.home)). maybePop لێرە بە هۆی PopScope
        // تەنها هەنگاوی یەکەمی دەکردەوە
        toastAfterNav(context, 'داواکارییەکەت نێردرا');
        Navigator.of(context).pop();
      }),
      Text('ئاسایی لە ماوەیەکی کورتدا پەسەند دەکرێت و ئاگادار دەکرێیتەوە.', textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8)),
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
      if (mounted) toast(context, 'ئەم وێنەیە ناخوێندرێتەوە');
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
  late final TextEditingController _amt;
  final _acc = TextEditingController();
  String? _method;
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final cloud = context.read<Cloud>();
    final f = _pos(cloud.freeBalance);
    _amt = TextEditingController(text: Fmt.group(f));
    _acc.text = '0${cleanPhone(str(cloud.passenger['phone']))}';
  }

  @override
  void dispose() {
    _amt.dispose();
    _acc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final f = _pos(cloud.freeBalance);
    final ms = cloud.payMethods.where((m) => m['on'] != false).toList();
    _method ??= ms.isEmpty ? null : str(ms.first['id']);
    final m = cloud.payMethod(_method) ?? const {};
    final min = ((cloud.config['withdrawMin'] as num?) ?? 0).toInt();
    final pend = cloud.myWithdrawsPending;
    final cur = parseAmount(_amt.text);
    final chips = <int>[f, 25000, 50000].where((a) => a > 0 && a <= f).toSet().toList();
    Widget sum(String k, String v, {Color? c}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: Ts.muted(context, size: 12)),
              Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16.8, color: c ?? t.text)),
            ]),
          ),
        );
    return Scaffold(
      body: YkScreen(children: [
        const YkHeader('ڕاکێشانی پارە'),
        _AmountField(ctrl: _amt, label: 'چەند ڕادەکێشیت؟', onChanged: (_) => setState(() {})),
        if (chips.isNotEmpty)
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < chips.length; i++)
              YkChip(Fmt.n('${i == 0 ? 'هەمووی ' : ''}${Fmt.group(chips[i])}'), on: cur == chips[i], onTap: () => setState(() => _amt.text = Fmt.group(chips[i]))),
          ]),
        Row(children: [
          sum('بەردەست بۆ ڕاکێشان', Fmt.n(Fmt.group(f))),
          const SizedBox(width: 10),
          sum(min > 0 ? 'کەمترین بڕ' : 'چاوەڕێی ناردن', Fmt.n(Fmt.group(min > 0 ? min : pend.fold<num>(0, (n, w) => n + ((w['amount'] as num?) ?? 0)))), c: t.muted),
        ]),
        Text('بۆ کوێ بنێردرێت؟', style: Ts.h3(context)),
        YkList(children: [
          for (final x in ms)
            InkWell(
              onTap: () => setState(() => _method = str(x['id'])),
              child: Container(
                color: _method == x['id'] ? t.chip : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  _mono(context, x),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(str(x['name']), style: Ts.bold(context)),
                      Text(x['account'] == false ? 'لە ئۆفیسی یەکسا وەریدەگریتەوە' : 'بۆ هەژماری ${x['name']} ـی خۆت', style: Ts.muted(context, size: 12.5)),
                    ]),
                  ),
                  YkCheck(_method == x['id'], radio: true),
                ]),
              ),
            ),
        ]),
        if (m['account'] != false)
          YkField(
            label: 'ژمارەی هەژماری ${str(m['name'])} ـەکەت',
            child: Directionality(textDirection: TextDirection.ltr, child: TextField(controller: _acc, keyboardType: TextInputType.phone, decoration: ykInput(context))),
          ),
        if (_err != null) YkError(_err!),
        YkButton('داوای ڕاکێشان', block: true, large: true, busy: _busy, onPressed: f > 0
            ? () async {
                setState(() {
                  _busy = true;
                  _err = null;
                });
                final err = await cloud.requestWithdraw(parseAmount(_amt.text), str(_method), _acc.text);
                if (!context.mounted) return;
                setState(() {
                  _busy = false;
                  _err = err;
                });
                if (err == null) {
                  toast(context, 'داواکارییەکەت نێردرا');
                  Navigator.of(context).maybePop();
                }
              }
            : null),
        _trust(context, 'یەکسا پارەکەت بۆ دەنێرێت و ئاگادار دەکرێیتەوە. تا نەنێردرێت، دەتوانیت هەڵیبوەشێنیتەوە.', icon: 'clock'),
        if (pend.isNotEmpty) ...[
          Text('چاوەڕێی ناردن', style: Ts.h3(context)),
          YkList(children: [for (final w in pend) _pendingWithdraw(context, w)]),
        ],
      ]),
    );
  }
}

Widget _pendingWithdraw(BuildContext context, Json w) {
  final cloud = context.read<Cloud>();
  final e = {'id': w['id'], 'type': 'withdraw', 'amount': -((w['amount'] as num?) ?? 0), 'method': w['method'], 'note': str(w['account']).isEmpty ? 'چاوەڕێی ناردنی یەکسا' : w['account'], 'at': w['at']};
  return TxRow(e, pending: true, onTap: () {
    showReceipt(context, e,
        pending: true,
        extra: YkButton('هەڵوەشاندنەوەی داواکاری', kind: BtnKind.secondary, block: true, onPressed: () async {
          Navigator.pop(context);
          await cloud.cancelWithdraw(str(w['id']));
          if (context.mounted) toast(context, 'هەڵوەشێنرایەوە');
        }));
  });
}

Widget _pendingTopup(BuildContext context, Json x) {
  final cloud = context.read<Cloud>();
  final refund = x['kind'] == 'refund';
  final e = {
    'id': x['id'],
    'type': refund ? 'refund' : 'topup',
    'amount': x['amount'],
    'method': refund ? null : x['method'],
    'ref': x['ref'],
    'note': refund ? x['note'] : 'چاوەڕێی پشکنینی یەکسا${str(x['ref']).isNotEmpty ? '، حەواڵە ${x['ref']}' : ''}',
    'at': x['at'],
  };
  return TxRow(e, pending: true, onTap: () {
    showReceipt(context, e,
        pending: true,
        extra: refund
            ? null
            : YkButton('هەڵوەشاندنەوەی داواکاری', kind: BtnKind.secondary, block: true, onPressed: () async {
                if (!await askConfirm(context, 'داواکاری پڕکردنەوە هەڵدەوەشێتەوە؟ ئەگەر پارەت ناردووە، هەڵی مەوەشێنەرەوە.', yes: 'هەڵوەشاندنەوە')) return;
                await cloud.cancelTopup(str(x['id']));
                if (context.mounted) {
                  Navigator.pop(context);
                  toast(context, 'هەڵوەشێنرایەوە');
                }
              }));
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
    if (amount <= 0) return toast(context, 'بڕەکە بنووسە');
    if (amount > cloud.freeBalance) {
      setState(() => _err = 'باڵانسەکەت بەس نییە (${Fmt.money(cloud.freeBalance < 0 ? 0 : cloud.freeBalance)})');
      return;
    }
    if (!await askConfirm(context, '${Fmt.money(amount)} بۆ ${p.name} دەنێردرێت. دوای ناردن ناگەڕێتەوە.', yes: 'ناردن', danger: false)) return;
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
        Text('نێردرا', textAlign: TextAlign.center, style: Ts.h2(c)),
        Text('${Fmt.money(amount)} چووە جزدانی ${p.name}', textAlign: TextAlign.center, style: Ts.muted(c, size: 14)),
        const SizedBox(height: 14),
        YkButton('باشە', block: true, onPressed: () => Navigator.pop(c)),
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
        const YkHeader('ناردن بۆ سەرنشین'),
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
                  Text('${Fmt.phone(p.phone)} · سەرنشینی یەکسا', style: Ts.muted(context, size: 12.5)),
                ]),
              ),
              YkButton('گۆڕین', small: true, kind: BtnKind.secondary, onPressed: () => setState(() {
                    _peer = null;
                    _err = null;
                  })),
            ]),
          )
        else ...[
          YkField(
            label: 'ژمارەی مۆبایلی سەرنشینی وەرگر',
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
              YkButton('دۆزینەوە', icon: 'search', kind: BtnKind.secondary, busy: _busy, onPressed: _find),
            ]),
          ),
          Text('تەنها دەتوانیت بۆ سەرنشینێکی تری یەکسا بنێریت.', style: Ts.muted(context, size: 12.8)),
        ],
        if (_err != null) YkError(_err!),
        if (p != null) ...[
          _AmountField(ctrl: _amt, label: 'بڕ', sub: Fmt.n('دینار · بەردەست ${Fmt.group(f)}')),
          YkField(label: 'تێبینی', optional: true, child: TextField(controller: _note, maxLength: 80, decoration: ykInput(context, hint: 'بۆ نموونە: پارەی مانگی خوشکم'))),
          YkButton('ناردن', icon: 'send', block: true, large: true, busy: _busy, onPressed: f > 0 ? _send : null),
          _trust(context, 'پارەکە یەکسەر دەچێتە جزدانی وەرگر. دوای ناردن ناگەڕێتەوە، بۆیە ناوەکە باش بپشکنە.'),
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
  static const _f = [('all', 'هەمووی'), ('in', 'زیادکردن'), ('out', 'ڕاکێشان'), ('xfer', 'ناردن و وەرگرتن'), ('month', 'پارەی مانگ'), ('back', 'گەڕاندنەوە')];
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
      final k = at >= d0 ? 'ئەمڕۆ' : at >= d0 - 86400000 ? 'دوێنێ' : Fmt.n('${kMonths[d.month - 1]} ${d.year}');
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
        const YkHeader('مامەڵەکان'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in _f) ...[YkChip(f.$2, on: _k == f.$1, onTap: () => setState(() => _k = f.$1)), const SizedBox(width: 6)],
          ]),
        ),
        Row(children: [
          sum('هاتوو ئەم مانگە', '+${Fmt.n(Fmt.group(sumIn))}', t.okText),
          const SizedBox(width: 10),
          sum('چوو ئەم مانگە', '−${Fmt.n(Fmt.group(sumOut))}', t.text),
        ]),
        if (pTp.isNotEmpty || pWd.isNotEmpty) ...[
          Text('چاوەڕێ', style: TextStyle(fontWeight: FontWeight.w800, color: t.text)),
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
            title: 'هیچ مامەڵەیەک نییە',
            text: _k == 'all' ? 'هەر پارەیەک زیاد بکەیت، ڕایبکێشیت یان بینێریت، لێرە دەردەکەوێت' : 'لەم جۆرە هیچ مامەڵەیەک نییە',
          ),
      ]),
    );
  }
}
