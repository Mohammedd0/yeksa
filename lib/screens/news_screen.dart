// ڕێکلام و هەواڵ، ئۆفەرەکان و پەڕەی هەر هەواڵێک
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/actions.dart';
import '../core/cloud.dart';
import '../core/images.dart';
import '../core/sel.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'nav.dart';

class NewsListScreen extends StatelessWidget {
  const NewsListScreen({super.key, required this.kind});

  /// «ad» یان «offer»
  final String kind;

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final offer = kind == 'offer';
    final list = cloud.newsFor('passenger').where((n) => YkSel.newsKind(n) == kind).toList();
    return Scaffold(
      body: YkScreen(onRefresh: offer ? context.read<Cloud>().refresh : null, children: [
        YkHeader(offer ? 'ئۆفەرەکان' : 'ڕێکلام و هەواڵ'),
        if (list.isEmpty)
          YkEmpty(
            icon: offer ? 'tag' : 'news',
            title: offer ? 'ئێستا هیچ ئۆفەرێک نییە' : 'ئێستا هیچ هەواڵێک نییە',
            text: offer ? 'کاتێک داشکاندن یان ئۆفەرێکی نوێ هات، لێرە و لە سەرەکی دەیبینیت' : 'هەواڵ و ڕێکلامە نوێکان لێرە دەردەکەون',
            button: YkButton('گەڕانەوە بۆ سەرەکی', kind: BtnKind.secondary, onPressed: () => openLink(context, 'home')),
          ),
        for (final n in list) NewsCard(n, onTap: () => push(context, NewsDetailScreen(id: str(n['id'])))),
      ]),
    );
  }
}

class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<Cloud>().markNewsSeen(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final n = cloud.doc('news/${widget.id}');
    if (n == null) {
      return const Scaffold(
        body: YkScreen(children: [YkHeader('هەواڵ'), YkEmpty(icon: 'news', title: 'ئەم هەواڵە نەدۆزرایەوە')]),
      );
    }
    final th = newsTheme(n['theme'] as String?);
    final img = str(n['image']);
    final hasImg = img.isNotEmpty && context.watch<ImageStore>().get(img) != null;
    final offer = YkSel.newsKind(n) == 'offer';

    Widget heroText(Color fg) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (str(n['tag']).isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(999)),
              child: Text(str(n['tag']), style: TextStyle(color: fg, fontSize: 12.2, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 8),
          Text(str(n['title']), style: TextStyle(color: fg, fontSize: 19.2, fontWeight: FontWeight.w700, height: 1.45)),
          Text(str(n['sub']), style: TextStyle(color: fg.withValues(alpha: .9), fontSize: 14)),
        ]);

    return Scaffold(
      body: YkScreen(children: [
        YkHeader(str(n['tag']).isEmpty ? 'هەواڵ' : str(n['tag'])),
        ClipRRect(
          borderRadius: BorderRadius.circular(Yk.rXl),
          child: hasImg
              ? Stack(children: [
                  YkImage(img, fit: BoxFit.cover),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0x9E000000), Color(0x00000000)], stops: [0, .7]),
                      ),
                    ),
                  ),
                  Positioned(left: 18, right: 18, bottom: 18, child: heroText(Colors.white)),
                ])
              : Container(
                  constraints: const BoxConstraints(minHeight: 190),
                  decoration: BoxDecoration(gradient: newsGradient(n['theme'] as String?)),
                  padding: const EdgeInsets.all(20),
                  child: Stack(children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Opacity(
                        opacity: .9,
                        child: n['big'] != null ? bigText(n['big'], 57, th.fg) : YkIcon(str(n['icon']), size: 84, color: th.fg, stroke: 1.3),
                      ),
                    ),
                    Padding(padding: const EdgeInsets.only(top: 60), child: heroText(th.fg)),
                  ]),
                ),
        ),
        Text(str(n['body']), style: TextStyle(fontSize: 16.3, height: 1.9, color: t.text)),
        if (str(n['until']).isNotEmpty)
          Row(children: [
            YkIcon('clock', size: 16, color: t.muted),
            const SizedBox(width: 8),
            Text(str(n['until']), style: Ts.muted(context, size: 14)),
          ]),
        if (str(n['code']).isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(Yk.rMd),
              border: Border.all(color: t.line, width: 1.5, style: BorderStyle.solid),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('کۆدی داشکاندن', style: Ts.muted(context, size: 12.8)),
                  Text(str(n['code']), textDirection: TextDirection.ltr, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2, color: t.text)),
                ]),
              ),
              YkButton('کۆپی', icon: 'copy', small: true, kind: BtnKind.secondary, onPressed: () {
                Clipboard.setData(ClipboardData(text: str(n['code'])));
                toast(context, 'کۆپی کرا');
              }),
            ]),
          ),
        if (offer && str(n['code']).isEmpty) YkButton('بەشداری نوێ', block: true, onPressed: () => openLink(context, 'new')),
      ]),
    );
  }
}
