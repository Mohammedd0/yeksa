// لۆگۆی یەکسا: نیشانەی Y، هێڵێکی باریک، «یەکسا» (یەک تۆخ، سا خۆڵەمێشی) و YEKSA لە ژێری
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/i18n.dart';
import 'theme.dart';

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// تەنها نیشانەی Y
class YMark extends StatelessWidget {
  const YMark({super.key, this.size = 34, this.ink, this.bg});
  final double size;
  final Color? ink;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final i = _hex(ink ?? t.act);
    final b = _hex(bg ?? t.bg);
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<path d="M24 14 L50 50 L76 14" fill="none" stroke="$i" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/>'
        '<path d="M50 50 L50 76" fill="none" stroke="$i" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/>'
        '<path d="M50 57 L50 71" fill="none" stroke="$b" stroke-width="3.2" stroke-linecap="round" stroke-dasharray="5 5"/>'
        '<circle cx="50" cy="85" r="10" fill="#F5A623" stroke="$b" stroke-width="3.5"/>'
        '</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// لۆگۆی تەواو. [height]: ٣٤ ئاسایی، ٥٨ گەورە، ٢٦ بچووک. [inverse]: بۆ سەر باکگراوندی تاریک
class YLogo extends StatelessWidget {
  const YLogo({super.key, this.height = 34, this.inverse = false});
  const YLogo.big({super.key, this.inverse = false}) : height = 58;
  const YLogo.small({super.key, this.inverse = false}) : height = 26;

  final double height;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final ink = inverse ? const Color(0xFFF2F2F7) : t.act;
    final gray = inverse || t.dark ? const Color(0xFF8E95A2) : const Color(0xFF8A8F98);
    final bg = inverse ? const Color(0xFF1C1C1E) : t.bg;
    final h = height;
    return Semantics(
      label: tr('یەکسا'),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            YMark(size: h, ink: ink, bg: bg),
            SizedBox(width: h * .28),
            Container(width: 1.5, height: h * .94, color: inverse ? Colors.white24 : t.line),
            SizedBox(width: h * .28),
            // لۆگۆکە لە هەموو زمانەکاندا وەک خۆی (ڕاست بۆ چەپ) دەمێنێتەوە، تەنانەت لە ئینگلیزیش
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [ink, ink, gray, gray],
                    stops: const [0, .56, .56, 1],
                  ).createShader(r),
                  child: Text('یەکسا', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: h * .76, height: 1, color: Colors.white)), // i18n-keep
                ),
                SizedBox(height: h * .12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'YEK', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
                      TextSpan(text: 'SA', style: TextStyle(color: gray)),
                    ]),
                    style: TextStyle(fontFamily: null, fontWeight: FontWeight.w700, fontSize: h * .27, letterSpacing: h * .27 * .32, height: 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
