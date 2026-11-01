// نامەکان: لیستی گفتوگۆکان (وەک واتسئاپ) و پەڕەی گفتوگۆ لەگەڵ شۆفێر
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/sel.dart';
import '../ui/help.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'drivers_screen.dart' show callPhone;
import 'nav.dart';
import 'request_screen.dart' show askConfirm;

/// ئاواتاری شۆفێر بە خاڵی سەوز ئەگەر ئۆنلاین بێت
class _Av extends StatelessWidget {
  const _Av(this.d, {this.size = 54, this.online = false});
  final Json d;
  final double size;
  final bool online;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Stack(clipBehavior: Clip.none, children: [
      DriverAvatar({...d, 'status': null}, size: size, radius: size / 2),
      if (online)
        Positioned(
          bottom: 1,
          left: 1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.success, border: Border.all(color: t.bg, width: 2)),
          ),
        ),
    ]);
  }
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final threads = cloud.threads;
    final unread = cloud.unreadMsgs;
    final subDrivers = cloud.subDriversNoThread;
    return YkScreen(withNav: true, title: tr('نامەکان'), onRefresh: context.read<Cloud>().refresh, children: [
      Row(children: [
        Expanded(child: Text(tr('نامەکان'), style: Ts.h1(context))),
        if (unread > 0) YkBadge(Fmt.n(tr('{0} نەخوێندراوە', [unread])), tone: BadgeTone.danger),
        const SizedBox(width: 8),
        const HelpButton('inbox'),
      ]),
      if (threads.isEmpty)
        YkEmpty(icon: 'chat', title: tr('هێشتا نامەت نییە'), text: tr('کاتێک شۆفێرێکت هەبوو، لێرە ڕاستەوخۆ نامەی بۆ دەنێریت'))
      else
        Column(children: [
          for (var i = 0; i < threads.length; i++) _ThreadRow(th: threads[i], last: i == threads.length - 1),
        ]),
      if (subDrivers.isNotEmpty) ...[
        Text(tr('شۆفێرەکانت'), style: Ts.h3(context)),
        YkList(children: [
          for (final id in subDrivers)
            Builder(builder: (context) {
              final d = cloud.driver(id) ?? {'id': id, 'name': tr('شۆفێر')};
              return InkWell(
                onTap: () => openLink(context, 'chat/$id'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    _Av(d, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(d['name']), style: Ts.bold(context).copyWith(height: 1.4)),
                        Text(carText(d), style: Ts.muted(context, size: 12.8)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.silverLine)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        YkIcon('chat', size: 16, color: t.silverText),
                        const SizedBox(width: 6),
                        Text(tr('نامە'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.silverText)),
                      ]),
                    ),
                  ]),
                ),
              );
            }),
        ]),
      ],
    ]);
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.th, required this.last});
  final Thread th;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.read<Cloud>();
    final d = cloud.driver(th.driverId) ?? {'id': th.driverId, 'name': tr('شۆفێر')};
    final m = th.last;
    final mine = m['system'] != true && m['fromDriver'] != true;
    final preview = m['unsent'] == true ? tr('نامەیەک گەڕێنرایەوە') : m['voice'] != null ? tr('نامەی دەنگی') : str(m['text']);
    final un = th.unread > 0;
    return InkWell(
      onTap: () => openLink(context, 'chat/${th.driverId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          _Av(d, online: d['online'] == true),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: t.line))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Text(str(d['name']),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: un ? FontWeight.w800 : FontWeight.w700, color: t.text)),
                  ),
                  Text(Fmt.ago(((m['at'] as num?) ?? 0).toInt()), style: TextStyle(fontSize: 12.5, color: un ? t.text : t.muted, fontWeight: un ? FontWeight.w700 : FontWeight.w400)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Expanded(
                    child: Text('${mine ? tr('تۆ: ') : ''}$preview', // i18n-keep
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.4, color: un ? t.text : t.muted, fontWeight: un ? FontWeight.w700 : FontWeight.w400)),
                  ),
                  if (un)
                    Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: t.act, borderRadius: BorderRadius.circular(11)),
                      alignment: Alignment.center,
                      child: Text(Fmt.n(th.unread), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: t.actText)),
                    ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/* ---------------- گفتوگۆ ---------------- */

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.driverId});
  final String driverId;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = -1;
  Timer? _tick;
  // وەڵامە خێراکان بە کوردی دەنێردرێن (شۆفێر کوردی دەخوێنێتەوە)، تەنها دوگمەکە وەردەگێڕدرێت
  static const _quick = ['باشە، سوپاس', 'ئامادەین', '٥ خولەک چاوەڕێ بکە', 'ئەمڕۆ نایەین', 'لە بەردەم دەرگاین']; // i18n-keep

  @override
  void initState() {
    super.initState();
    // دوگمەی گەڕاندنەوە دوای ٥ خولەک نامێنێت
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      animate ? _scroll.animateTo(max, duration: const Duration(milliseconds: 250), curve: Curves.easeOut) : _scroll.jumpTo(max);
    });
  }

  Future<void> _send(String text) async {
    final v = text.trim();
    if (v.isEmpty) return;
    _ctrl.clear();
    await context.read<Cloud>().sendMessage(widget.driverId, v);
    _toEnd();
  }

  Future<void> _unsend(Json m) async {
    final cloud = context.read<Cloud>();
    if (!cloud.canUnsend(m)) return;
    final left = ((kUnsendMs - (nowMs() - ((m['at'] as num?) ?? 0))) / 60000).ceil().clamp(1, 5);
    final txt = str(m['text']);
    final ok = await askConfirm(
      context,
      Fmt.n(tr('«{0}» دەگەڕێنرێتەوە و لای کەسەکەی تر «ئەم نامەیە گەڕێنرایەوە» دەردەکەوێت. ({1} خولەکی ماوە)', [txt.length > 80 ? txt.substring(0, 80) : txt, left])),
      yes: trc('گەڕاندنەوە', 'سحب', 'Unsend'),
    );
    if (!ok || !mounted) return;
    final err = await cloud.unsendMessage(str(m['id']));
    if (mounted) toast(context, err ?? tr('نامەکە گەڕێنرایەوە'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final d = cloud.driver(widget.driverId);
    if (d == null) {
      return Scaffold(body: YkScreen(children: [YkHeader(tr('نامە')), YkEmpty(icon: 'chat', title: tr('شۆفێرەکە نەدۆزرایەوە'))]));
    }
    final msgs = cloud.threadMsgs(widget.driverId);
    if (msgs.length != _lastCount) {
      _toEnd(animate: _lastCount >= 0);
      _lastCount = msgs.length;
      if (msgs.any((m) => m['fromDriver'] == true && m['readP'] != true)) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) context.read<Cloud>().markThreadRead(widget.driverId);
        });
      }
    }
    final phone = str(d['phone']);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // سەرەوە: ناو، ئۆتۆمبێل، پەیوەندی
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(children: [
              if (Navigator.of(context).canPop())
                IconButton(tooltip: tr('گەڕانەوە'), onPressed: () => Navigator.of(context).maybePop(), icon: YkIcon(L.rtl ? 'back' : 'forward', size: 22, color: t.text)),
              _Av(d, size: 42, online: d['online'] == true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(str(d['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.h3(context)),
                  Text(carText(d), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ts.muted(context, size: 12.8)),
                ]),
              ),
              if (phone.isNotEmpty) IconButton(tooltip: tr('پەیوەندی'), onPressed: () => callPhone(phone), icon: YkIcon('phone', size: 20, color: t.text)),
            ]),
          ),
          Divider(height: 1, thickness: 1, color: t.line),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                controller: _scroll,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        YkCard(
                          child: Column(children: [
                            if (phone.isNotEmpty)
                              Row(children: [
                                Expanded(child: Text(tr('ژمارەی شۆفێر'), style: Ts.sm(context))),
                                GestureDetector(
                                  onTap: () => callPhone(phone),
                                  child: Text(Fmt.phone(phone), textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w700, color: t.brand)),
                                ),
                              ]),
                            Row(children: [
                              Expanded(child: Text(tr('ژمارەکەت بۆ شۆفێر شاراوەیە'), style: Ts.sm(context))),
                              YkIcon('lock', size: 16, color: t.muted),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        if (msgs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Text(tr('هێشتا هیچ نامەیەک نییە. یەکەم نامە بنووسە.'), textAlign: TextAlign.center, style: Ts.muted(context, size: 14)),
                          ),
                        ..._bubbles(context, cloud, msgs),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _composer(context),
        ]),
      ),
    );
  }

  List<Widget> _bubbles(BuildContext context, Cloud cloud, List<Json> msgs) {
    final t = context.yk;
    final out = <Widget>[];
    String? lastDay;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final m in msgs) {
      final at = ((m['at'] as num?) ?? 0).toInt();
      final dt = DateTime.fromMillisecondsSinceEpoch(at);
      final day = DateTime(dt.year, dt.month, dt.day);
      final key = day.toIso8601String();
      if (key != lastDay) {
        lastDay = key;
        final label = day == today ? tr('ئەمڕۆ') : day == today.subtract(const Duration(days: 1)) ? tr('دوێنێ') : Fmt.ago(at);
        out.add(Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: Ts.muted(context, size: 12.5)),
          ),
        ));
      }
      final time = Fmt.clock(Fmt.hhmm(at));
      if (m['system'] == true) {
        out.add(Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: t.noteBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.noteLine)),
            child: Text(trData(m['text']), textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8)),
          ),
        ));
        continue;
      }
      final mine = m['fromDriver'] != true;
      final undo = cloud.canUnsend(m);
      final fg = mine ? t.actText : t.text;
      Widget body;
      if (m['unsent'] == true) {
        body = Row(mainAxisSize: MainAxisSize.min, children: [
          YkIcon('x', size: 14, color: fg.withValues(alpha: .7)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(mine ? tr('نامەکەت گەڕاندەوە') : tr('ئەم نامەیە گەڕێنرایەوە'),
                style: TextStyle(fontStyle: FontStyle.italic, color: fg.withValues(alpha: .7), fontSize: 15.2)),
          ),
        ]);
      } else if (m['voice'] != null) {
        body = Row(mainAxisSize: MainAxisSize.min, children: [
          YkIcon('play', size: 16, color: fg, fill: fg),
          const SizedBox(width: 8),
          Container(width: 110, height: 3, color: fg.withValues(alpha: .45)),
          const SizedBox(width: 8),
          Text(Fmt.n('0:0${m['voice']}'), style: TextStyle(fontSize: 12.5, color: fg)),
        ]);
      } else {
        body = Text(str(m['text']), style: TextStyle(fontSize: 15.2, height: 1.55, color: fg));
      }
      final read = m['readD'] == true;
      out.add(Align(
        // RTL: نامەی خۆم لە لای ڕاست (سەرەتا)، هی شۆفێر لە لای چەپ
        alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
        child: GestureDetector(
          onTap: undo ? () => _unsend(m) : null,
          onLongPress: undo ? () => _unsend(m) : null,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width.clamp(0.0, 480.0).toDouble() * .8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: mine ? t.act : t.chip,
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(18),
                topEnd: const Radius.circular(18),
                bottomStart: Radius.circular(mine ? 6 : 18),
                bottomEnd: Radius.circular(mine ? 18 : 6),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              body,
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(time, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: .75))),
                if (mine && m['unsent'] != true) ...[
                  const SizedBox(width: 4),
                  Text(read ? '✓✓' : '✓',
                      style: TextStyle(fontSize: 11.5, letterSpacing: -2, color: read ? const Color(0xFF8EC5FF) : fg.withValues(alpha: .6), fontWeight: FontWeight.w700)),
                ],
                if (undo) ...[const SizedBox(width: 6), YkIcon('undo', size: 12, color: fg.withValues(alpha: .6))],
              ]),
            ]),
          ),
        ),
      ));
    }
    return out;
  }

  Widget _composer(BuildContext context) {
    final t = context.yk;
    final bottom = MediaQuery.of(context).padding.bottom;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(color: t.nav, border: Border(top: BorderSide(color: t.glassLine))),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + (kb > 0 ? 0 : bottom)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quick.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () => _send(_quick[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.silverLine)),
                    child: Text(tr(_quick[i]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.silverText)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: ykInput(context, hint: tr('نامە بنووسە...')).copyWith(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: t.line, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: t.line, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: t.act, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: trc('ناردن', 'إرسال', 'Send'),
                child: Material(
                  color: t.act,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _send(_ctrl.text),
                    child: SizedBox(width: 46, height: 46, child: Center(child: YkIcon('send', size: 20, color: t.actText))),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
