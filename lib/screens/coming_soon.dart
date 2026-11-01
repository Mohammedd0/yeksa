// شوێنی کاتی بۆ ئەو پەڕانەی لە قۆناغەکانی داهاتوودا دەنووسرێن (بە هەمان وێنەی پەڕە بەتاڵەکانی وێب)
import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title, required this.icon, this.phase = 2, this.inTab = false});
  final String title;
  final String icon;
  final int phase;
  final bool inTab;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    // هەر ڕستەیەک تەواو، بۆ ئەوەی لە عەرەبی/ئینگلیزیدا ڕیزبەندی وشەکان بگۆڕدرێت
    final names = {
      2: tr('ئەم بەشە لە قۆناغی دووەمدا زیاد دەکرێت'),
      3: tr('ئەم بەشە لە قۆناغی سێیەمدا زیاد دەکرێت'),
      4: tr('ئەم بەشە لە قۆناغی چوارەمدا زیاد دەکرێت'),
      5: tr('ئەم بەشە لە قۆناغی پێنجەمدا زیاد دەکرێت'),
    };
    final body = SafeArea(
      bottom: false,
      child: Padding(
        // وەک .screen:has(> .empty): وێنەکە لە ناوەڕاستی بۆشاییەکەدایە، نزیکتر لە پەنجە
        padding: EdgeInsets.fromLTRB(16, 14, 16, (inTab ? 150 : 70) + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (inTab) Text(title, style: Ts.h1(context)) else YkHeader(title),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: YkEmpty(
                    icon: icon,
                    title: names[phase] ?? tr('ئەم بەشە لە قۆناغەکانی داهاتوودا زیاد دەکرێت'),
                    text: tr('تا ئەو کاتە دەتوانیت لە وەشانی وێبدا بەکاری بهێنیت. هەموو زانیارییەکان یەکن.'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return inTab ? body : Scaffold(body: body);
  }
}
