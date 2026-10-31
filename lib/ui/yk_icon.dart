// ئایکۆنی یەکسا (هەمان SVGـی وەشانی وێب)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'icon_paths.dart';

String _hex(Color c) {
  final v = c.toARGB32();
  return '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

double _alpha(Color c) => ((c.toARGB32() >> 24) & 0xFF) / 255.0;

class YkIcon extends StatelessWidget {
  const YkIcon(this.name, {super.key, this.size = 22, this.color, this.stroke = 1.9, this.fill});

  final String name;
  final double size;
  final Color? color;
  final double stroke;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    final f = fill;
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
        'fill="${f == null ? 'none' : _hex(f)}" ${f == null ? '' : 'fill-opacity="${_alpha(f)}"'} '
        'stroke="${_hex(c)}" stroke-opacity="${_alpha(c)}" stroke-width="$stroke" '
        'stroke-linecap="round" stroke-linejoin="round">${kIconPaths[name] ?? ''}</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
