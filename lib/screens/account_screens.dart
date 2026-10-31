// خێزان، پاداشت، یارمەتی و سکاڵا، پرسیارە باوەکان، پەیوەندی
import 'dart:collection'; // firstOrNull / lastOrNull
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/account.dart';
import '../core/auth.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/pricing.dart';
import '../core/sel.dart';
import '../core/trips.dart';
import '../ui/form_parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'request_screen.dart' show askConfirm;

/* ---------------- خێزان ---------------- */

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final members = cloud.members;
    final subs = cloud.mySubs;
    return Scaffold(
      body: YkScreen(children: [
        YkHeader('خێزان', right: YkButton('ئەندام', icon: 'plus', small: true, onPressed: () => _addMember(context))),
        Text('هەموو ئەندامانی خێزان لە یەک ئەکاونت. هەر ئەندامێک دەتوانێت تەکسی خۆی هەبێت.', style: Ts.muted(context, size: 14)),
        YkList(children: [
          for (var i = 0; i < members.length; i++)
            Builder(builder: (context) {
              final m = members[i];
              final mine = subs.where((x) => asList(x['memberIds']).contains(m['id'])).toList();
              final kid = m['kind'] == 'child';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  PersonAvatar(size: 46, imageId: cloud.memberPhoto(m['id'])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(str(m['name']), style: Ts.bold(context)),
                        if (kid) YkBadge(Fmt.n('منداڵ${m['age'] != null ? '، ${m['age']} ساڵ' : ''}'), tone: BadgeTone.note),
                      ]),
                      Text('${str(m['relation'])}، ${mine.isEmpty ? 'هیچ بەشدارییەک' : mine.map((x) => str(x['to'])).join('، ')}', style: Ts.muted(context, size: 12.8)),
                    ]),
                  ),
                  if (i > 0)
                    IconButton(
                      tooltip: 'لابردن',
                      onPressed: () async {
                        if (mine.isNotEmpty) {
                          toast(context, '${m['name']} بەشداری چالاکی هەیە. سەرەتا بەشدارییەکە ڕابگرە');
                          return;
                        }
                        if (!await askConfirm(context, '${m['name']} لاببرێت؟', yes: 'لابردن')) return;
                        await cloud.removeMember(str(m['id']));
                      },
                      icon: YkIcon('x', size: 18, color: t.muted),
                    ),
                ]),
              );
            }),
        ]),
        Row(children: [
          Expanded(child: Text('سەرپەرشتیارەکان', style: Ts.h3(context))),
          YkLink('زیادکردن', pill: true, onTap: () => _addGuardian(context)),
        ]),
        Text('ئەم کەسانە ئاگادارکردنەوەی سوار بوون و گەیشتنی منداڵەکان وەردەگرن و گەشتەکان بە لایڤ دەبینن.', style: Ts.muted(context, size: 14)),
        if (cloud.guardians.isNotEmpty)
          YkList(children: [
            for (final g in cloud.guardians)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  PersonAvatar(size: 40, imageId: str(g['name']).contains('(تۆ)') ? cloud.passenger['photo'] as String? : null),
                  const SizedBox(width: 12),
                  Expanded(child: Text(str(g['name']), style: Ts.bold(context))),
                  YkIcon('bell', size: 18, color: t.success),
                ]),
              ),
          ]),
        YkCard(
          tone: CardTone.info,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            YkIcon('shield', size: 20, color: t.infoText),
            const SizedBox(width: 10),
            Expanded(child: Text('منداڵ هەرگیز لەگەڵ کەسی گەورەی نەناسراو سوار ناکرێت. گەشتی منداڵان تەنها بە شۆفێری پشکنراوی منداڵانە.', style: TextStyle(fontSize: 14, color: t.infoText))),
          ]),
        ),
      ]),
    );
  }

  void _addMember(BuildContext context) {
    final cloud = context.read<Cloud>();
    final name = TextEditingController();
    var kind = 'child';
    var woman = false;
    var age = 8;
    showYkSheet(context, builder: (c) {
      return StatefulBuilder(builder: (c, setS) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('زیادکردنی ئەندام', style: Ts.h2(c)),
          const SizedBox(height: 12),
          YkField(label: 'ناو', child: TextField(controller: name, decoration: ykInput(c, hint: 'بۆ نموونە: ئارام'))),
          const SizedBox(height: 12),
          YkSeg<String>(options: const [('child', 'منداڵ'), ('adult', 'گەورە')], value: kind, onChanged: (v) => setS(() => kind = v)),
          const SizedBox(height: 10),
          YkSeg<bool>(options: const [(false, 'کوڕ / پیاو'), (true, 'کچ / ئافرەت')], value: woman, onChanged: (v) => setS(() => woman = v)),
          if (kind == 'child') ...[
            const SizedBox(height: 12),
            YkField(
              label: 'تەمەن',
              child: Row(children: [
                IconButton(onPressed: age > 3 ? () => setS(() => age--) : null, icon: YkIcon('minus', size: 20, color: c.yk.text)),
                Expanded(child: Text(Fmt.n('$age ساڵ'), textAlign: TextAlign.center, style: Ts.h3(c))),
                IconButton(onPressed: age < 17 ? () => setS(() => age++) : null, icon: YkIcon('plus', size: 20, color: c.yk.text)),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          YkButton('زیادکردن', block: true, onPressed: () async {
            final n = name.text.trim();
            if (n.length < 2) {
              toast(c, 'ناوەکە بنووسە');
              return;
            }
            Navigator.pop(c);
            await cloud.addMember(n, kind, woman, kind == 'child' ? age : null);
            if (context.mounted) toast(context, '$n زیاد کرا');
          }),
          const SizedBox(height: 8),
          YkButton('پاشگەزبوونەوە', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
        ]);
      });
    });
  }

  void _addGuardian(BuildContext context) {
    final cloud = context.read<Cloud>();
    final name = TextEditingController();
    showYkSheet(context, builder: (c) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('زیادکردنی سەرپەرشتیار', style: Ts.h2(c)),
        const SizedBox(height: 6),
        Text('بۆ نموونە باپیرە، داپیرە یان مامۆستا، کە لە کاتی نەبوونی تۆ منداڵەکان وەردەگرێت. ناوەکەی بۆ شۆفێر دەردەکەوێت.', style: Ts.muted(c, size: 14)),
        const SizedBox(height: 12),
        YkField(label: 'ناو', child: TextField(controller: name, decoration: ykInput(c, hint: 'ناوی سەرپەرشتیار'))),
        const SizedBox(height: 14),
        YkButton('زیادکردن', block: true, onPressed: () async {
          final n = name.text.trim();
          if (n.length < 2) {
            toast(c, 'ناوەکە بنووسە');
            return;
          }
          Navigator.pop(c);
          await cloud.addGuardian(n);
          if (context.mounted) toast(context, 'زیاد کرا');
        }),
        const SizedBox(height: 8),
        YkButton('پاشگەزبوونەوە', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  }
}

/* ---------------- پاداشت ---------------- */

const _refSt = {
  'joined': ('چاوەڕێی بەشداری', BadgeTone.normal),
  'subscribed': ('بەشداری کرد', BadgeTone.ok),
  'cancelled': ('هەڵوەشاوە', BadgeTone.danger),
  'revoked': ('لابراوە', BadgeTone.danger),
};

String rewardValue(Json x) => x['kind'] == 'days' ? Fmt.n('${x['amount']} ڕۆژی بەخۆڕایی') : '${Fmt.money((x['amount'] as num?) ?? 0)} داشکاندن';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final r = context.read<Cloud>().rewards;
      if (r['codeOk'] != true) context.read<AuthService>().ensureRefCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final auth = context.read<AuthService>();
    final r = cloud.rewards;
    final points = ((r['points'] as num?) ?? 0).toInt();
    final list = cloud.rewardsList.where((x) => x['on'] != false).toList()..sort((a, b) => (a['cost'] as num).compareTo(b['cost'] as num));
    final next = list.where((x) => (x['cost'] as num) > points).firstOrNull ?? list.lastOrNull;
    final code = str(r['code']);
    final mine = cloud.refsAsInviter;
    final joined = mine.where((x) => x['status'] != 'revoked').length;
    final subd = mine.where((x) => x['status'] == 'subscribed').length;
    // داشکاندنە چاوەڕوانەکان: پاداشتی وەرگیراو و بانگهێشتی هاوڕێ
    final pend = <(String, num)>[
      for (final p in asList(r['pending']).map(asMap)) (str(p['title']), p['kind'] == 'days' ? 0 : ((p['amount'] as num?) ?? 0)),
      if (cloud.refAsInvitee case final ri? when ri['status'] == 'subscribed' && ri['inviteeUsedAt'] == null)
        ('داشکاندنی بانگهێشت (یەکەم مانگ)', (ri['amount'] as num?) ?? 0),
      for (final x in mine.where((x) => x['status'] == 'subscribed' && x['inviterUsedAt'] == null))
        ('بانگهێشتی ${str(x['inviteeName']).isEmpty ? 'هاوڕێ' : x['inviteeName']}', (x['amount'] as num?) ?? 0),
    ];
    final pendSum = pend.fold<num>(0, (n, d) => n + d.$2);
    final refOn = cloud.config['refOn'] == true;
    final redeemed = asList(r['redeemed']);

    return Scaffold(
      body: YkScreen(children: [
        const YkHeader('پاداشت'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(Yk.rXl)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('خاڵەکانت', style: TextStyle(color: Colors.white70, fontSize: 15))),
              YkIcon('medal', size: 26, color: t.amber),
            ]),
            Text(Fmt.n(Fmt.group(points)), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700, height: 1.3)),
            if (next != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (points / (next['cost'] as num)).clamp(0.0, 1.0).toDouble(),
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  color: t.amber,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                points >= (next['cost'] as num) ? 'دەتوانیت پاداشتێک وەربگریت' : Fmt.n('${Fmt.group((next['cost'] as num) - points)} خاڵی تر بۆ «${next['title']}»'),
                style: const TextStyle(color: Colors.white70, fontSize: 12.8),
              ),
            ],
          ]),
        ),
        if (pend.isNotEmpty)
          YkCard(
            tone: CardTone.ok,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('داشکاندنی چاوەڕوان', style: TextStyle(fontWeight: FontWeight.w700))),
                Text(Fmt.money(pendSum), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              for (final d in pend)
                Row(children: [
                  Expanded(child: Text(d.$1, style: const TextStyle(fontSize: 14))),
                  Text(d.$2 > 0 ? Fmt.n(Fmt.group(d.$2)) : '', style: const TextStyle(fontSize: 14)),
                ]),
              const SizedBox(height: 4),
              Text(
                '${cloud.mySubs.isNotEmpty ? 'لە فاتورەی داهاتووت دەبڕدرێت' : 'کاتێک بەشداری بکەیت، لە یەکەم فاتورەت دەبڕدرێت'}. پارە نییە و ناکێشرێتەوە.',
                style: Ts.muted(context, size: 12.8),
              ),
            ]),
          ),
        if (refOn)
          YkCard(
            big: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                IcoBox('users', size: 46, iconSize: 22, color: t.act),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('بانگهێشتی هاوڕێ', style: Ts.h3(context)),
                    Text('کاتێک هاوڕێکەت بە کۆدەکەت بەشداری دەکات، هەردووکتان ${auth.refText()} داشکاندن وەردەگرن', style: Ts.muted(context, size: 14)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              if (code.isNotEmpty && r['codeOk'] == true) ...[
                // .ref-code: باکگراوندی زیوی، چوارچێوەی خاڵخاڵ، کۆدەکە لە سەرەتا و کۆپی لە کۆتایی
                CustomPaint(
                  painter: DashedBorder(color: t.silverLine, radius: 16),
                  child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
                  decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: Text(code, maxLines: 1, textDirection: TextDirection.ltr, style: TextStyle(fontFamily: 'Arial', fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 3.4, color: t.text))),
                    const SizedBox(width: 10),
                    YkButton('کۆپی', icon: 'copy', small: true, kind: BtnKind.secondary, onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      toast(context, 'کۆپی کرا');
                    }),
                  ]),
                ),
                ),
                const SizedBox(height: 10),
                YkButton('ناردنی کۆد بۆ هاوڕێ', icon: 'send', block: true, onPressed: () {
                  SharePlus.instance.share(ShareParams(text: 'لە یەکسا بە کۆدی $code تۆمار بکە و ${auth.refText()} داشکاندن لە یەکەم مانگت وەربگرە'));
                }),
              ] else ...[
                Container(height: 56, decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(16))),
                const SizedBox(height: 6),
                Text('کۆدەکەت ئامادە دەکرێت...', textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8)),
              ],
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Text(Fmt.n('$joined هاوڕێ هاتوون'), style: Ts.muted(context, size: 14))),
                  Text(Fmt.n('$subd بەشدارییان کردووە'), style: Ts.muted(context, size: 14)),
                ]),
                const SizedBox(height: 6),
                YkList(children: [
                  for (final x in mine)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        const PersonAvatar(size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(str(x['inviteeName']), style: Ts.sm(context).copyWith(fontWeight: FontWeight.w700)),
                            Text(Fmt.ago((((x['subAt'] ?? x['at']) as num?) ?? 0).toInt()), style: Ts.muted(context, size: 12.5)),
                          ]),
                        ),
                        if (x['status'] == 'subscribed' && x['inviterUsedAt'] != null)
                          const YkBadge('بەکارهات')
                        else if (x['status'] == 'subscribed')
                          YkBadge(Fmt.money((x['amount'] as num?) ?? 0), tone: BadgeTone.ok)
                        else
                          YkBadge(_refSt[x['status']]?.$1 ?? '', tone: _refSt[x['status']]?.$2 ?? BadgeTone.normal),
                      ]),
                    ),
                ]),
              ],
            ]),
          ),
        if (list.isNotEmpty) ...[
          Text('گۆڕینەوەی خاڵ', style: Ts.h3(context)),
          for (final x in list)
            Builder(builder: (context) {
              final got = x['repeat'] != true && redeemed.contains(x['id']);
              final can = !got && points >= (x['cost'] as num);
              return YkCard(
                child: Row(children: [
                  IcoBox(x['kind'] == 'days' ? 'calendar' : 'tag', color: t.act),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(str(x['title']), style: Ts.bold(context)),
                      Text('${Fmt.n(Fmt.group(x['cost'] as num))} خاڵ، ${rewardValue(x)}', style: Ts.muted(context, size: 12.8)),
                    ]),
                  ),
                  YkButton(got ? 'وەرگیرا' : 'وەرگرتن', small: true, kind: can ? BtnKind.primary : BtnKind.secondary, onPressed: can ? () => _redeem(context, x) : null),
                ]),
              );
            }),
          Text('پاداشت دەبێت بە داشکاندن و لە فاتورەی داهاتووت دەبڕدرێت.', style: Ts.muted(context, size: 12.8)),
        ],
      ]),
    );
  }

  Future<void> _redeem(BuildContext context, Json x) async {
    final ok = await askConfirm(
      context,
      '«${x['title']}» بە ${Fmt.n(Fmt.group(x['cost'] as num))} خاڵ وەردەگریت؟ ${rewardValue(x)} لە فاتورەی داهاتووت دەبڕدرێت.',
      yes: 'وەرگرتن',
      danger: false,
    );
    if (!ok || !context.mounted) return;
    final got = await context.read<Cloud>().redeem(str(x['id']));
    if (got != null && context.mounted) toast(context, '«${x['title']}» وەرگیرا');
  }
}

/* ---------------- یارمەتی و سکاڵاکان ---------------- */

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final tickets = asList(cloud.pax['tickets']).map(asMap).toList();
    const st = {
      'open': ('کراوە', BadgeTone.note),
      'progress': ('لە کاردایە', BadgeTone.info),
      'resolved': ('چارەسەر کرا', BadgeTone.ok),
    };
    Widget sos(String label, String tel) => Expanded(
          child: Material(
            color: t.danger,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => launchUrl(Uri.parse('tel:$tel')),
              child: SizedBox(
                height: 40,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const YkIcon('phone', size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
              ),
            ),
          ),
        );
    return Scaffold(
      body: YkScreen(children: [
        const YkHeader('یارمەتی و سکاڵاکان'),
        YkCard(
          tone: CardTone.danger,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('فریاکەوتن', style: TextStyle(fontWeight: FontWeight.w700)),
            const Text('لە کاتی مەترسیدا', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [sos('پۆلیس ١٠٤', '104'), const SizedBox(width: 10), sos('فریاگوزاری ١٢٢', '122')]),
          ]),
        ),
        Row(children: [
          Expanded(child: Text('سکاڵاکان', style: Ts.h3(context))),
          YkLink('نوێ', pill: true, onTap: () => _newTicket(context)),
        ]),
        // وێنەی پەڕەی بەتاڵ لە ژێر «سکاڵاکان» (Padding: تا YkScreen نەیباتە ناوەڕاستی شاشە)
        if (tickets.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: YkEmpty(icon: 'tickets', title: 'هیچ سکاڵایەکی نێردراو نییە', text: 'هەر سکاڵایەک بنێریت لێرە دەردەکەوێت'),
          )
        else
          YkList(children: [
            for (final tk in tickets)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(Fmt.n('#${tk['id']}'), style: Ts.sm(context).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    YkBadge(st[tk['status']]?.$1 ?? str(tk['status']), tone: st[tk['status']]?.$2 ?? BadgeTone.normal),
                  ]),
                  Text(str(tk['subject']), style: Ts.sm(context)),
                  if (str(tk['reply']).isNotEmpty) Text('وەڵام: ${tk['reply']}', style: Ts.muted(context, size: 12.8)),
                ]),
              ),
          ]),
      ]),
    );
  }

  void _newTicket(BuildContext context) {
    final cloud = context.read<Cloud>();
    final ctrl = TextEditingController();
    const presets = ['دواکەوتنی شۆفێر', 'گۆڕینی کات', 'گۆڕینی شۆفێر', 'پارەدان', 'شتی تر'];
    showYkSheet(context, builder: (c) {
      return StatefulBuilder(builder: (c, setS) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('سکاڵای نوێ', style: Ts.h2(c)),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in presets) YkChip(p, on: ctrl.text == p, onTap: () => setS(() => ctrl.text = p)),
          ]),
          const SizedBox(height: 12),
          YkField(
            label: 'کێشەکە بنووسە',
            child: TextField(controller: ctrl, minLines: 3, maxLines: 6, onChanged: (_) => setS(() {}), decoration: ykInput(c, hint: 'بە کورتی...')),
          ),
          const SizedBox(height: 14),
          YkButton('ناردن', block: true, onPressed: () async {
            final v = ctrl.text.trim();
            if (v.length < 3) {
              toast(c, 'کێشەکە بنووسە');
              return;
            }
            Navigator.pop(c);
            await cloud.addTicket(v);
            if (context.mounted) toast(context, 'داواکارییەکەت نێردرا. بەم زووانە وەڵام دەدرێتەوە');
          }),
          const SizedBox(height: 8),
          YkButton('پاشگەزبوونەوە', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
        ]);
      });
    });
  }
}

/* ---------------- پرسیارە باوەکان ---------------- */

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final list = cloud.faqList;
    return Scaffold(
      body: YkScreen(children: [
        const YkHeader('پرسیارە باوەکان'),
        if (list.isEmpty)
          const YkEmpty(icon: 'help', title: 'هیچ پرسیارێک نییە', text: 'تیمی یەکسا لێرە وەڵامی پرسیارە باوەکان دادەنێت')
        else
          Container(
            decoration: BoxDecoration(color: t.glass, borderRadius: BorderRadius.circular(Yk.rLg), border: Border.all(color: t.glassLine)),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: t.line, indent: 16),
                  ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    iconColor: t.text,
                    collapsedIconColor: t.muted,
                    title: Text(str(list[i]['q']), style: Ts.bold(context)),
                    children: [Text(cloud.faqText(list[i]['a']), style: Ts.muted(context, size: 14))],
                  ),
                ],
              ]),
            ),
          ),
      ]),
    );
  }
}

/// پەنجەرەی «پەیوەندی»: ژمارەکانی یەکسا، هەر یەکەیان پەیوەندی ڕاستەوخۆ
void showContactSheet(BuildContext context) {
  final cloud = context.read<Cloud>();
  final l = cloud.contacts;
  showYkSheet(context, builder: (c) {
    final t = c.yk;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('پەیوەندی بە یەکسا', textAlign: TextAlign.center, style: Ts.h2(c)),
      const SizedBox(height: 12),
      if (l.isEmpty)
        Text('هێشتا هیچ ژمارەیەک دانەنراوە', textAlign: TextAlign.center, style: Ts.muted(c, size: 14))
      else
        YkList(children: [
          for (final x in l)
            InkWell(
              onTap: () => launchUrl(Uri.parse('tel:+964${cleanPhone(str(x['phone']))}')),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(Fmt.phone(str(x['phone'])), textDirection: TextDirection.ltr, style: Ts.bold(context)),
                      if (str(x['label']).isNotEmpty) Text(str(x['label']), style: Ts.muted(c, size: 12.8)),
                    ]),
                  ),
                  IcoBox('phone', bg: t.okBg, color: t.okText),
                ]),
              ),
            ),
        ]),
      const SizedBox(height: 12),
      YkButton('داخستن', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
    ]);
  });
}
