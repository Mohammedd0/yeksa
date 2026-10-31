// پێکهاتە هاوبەشەکان: دوگمە، کارت، خانەی نووسین، سەرپەڕە، وێنەی کەس، پەڕەی خوارەوە
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/images.dart';
import 'empty_art.dart';
import 'theme.dart';
import 'yk_icon.dart';

enum BtnKind { primary, secondary, ghost, danger }

/// دوگمە (.btn): سەرەکی ڕەشە (لە تاریک سپی)، دووەم زیوی
class YkButton extends StatefulWidget {
  const YkButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = BtnKind.primary,
    this.icon,
    this.small = false,
    this.large = false,
    this.block = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final String? icon;
  final bool small, large, block, busy;

  @override
  State<YkButton> createState() => _YkButtonState();
}

class _YkButtonState extends State<YkButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final w = widget;
    final enabled = w.onPressed != null && !w.busy;
    late Color bg, fg;
    Border? border;
    switch (w.kind) {
      case BtnKind.primary:
        bg = t.act;
        fg = t.actText;
      case BtnKind.secondary:
        bg = t.silver;
        fg = t.silverText;
        border = Border.all(color: t.silverLine);
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = t.silverText;
        border = Border.all(color: t.silverLine);
      case BtnKind.danger:
        bg = Colors.transparent;
        fg = t.dangerText;
        border = Border.all(color: t.danger, width: 1.5);
    }
    final h = w.small ? 38.0 : w.large ? 56.0 : 48.0;
    final fs = w.small ? 14.0 : w.large ? 16.8 : 16.0;
    final child = Row(
      mainAxisSize: w.block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (w.busy)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        else ...[
          if (w.icon != null) ...[YkIcon(w.icon!, size: w.small ? 16 : 20, color: fg), const SizedBox(width: 8)],
          Flexible(
            child: Text(w.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: fs, fontFamily: kFont)),
          ),
        ],
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                w.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            opacity: w.onPressed == null ? .45 : (w.busy ? .65 : 1),
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: h,
              width: w.block ? double.infinity : null,
              padding: EdgeInsets.symmetric(horizontal: w.small ? 14 : 18),
              decoration: BoxDecoration(
                color: bg,
                border: border,
                borderRadius: BorderRadius.circular(w.small ? 14 : Yk.rMd),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// دوگمەی نووسین (.link)
class YkLink extends StatelessWidget {
  const YkLink(this.label, {super.key, required this.onTap, this.size = 14, this.pill = false});
  final String label;
  final VoidCallback onTap;
  final double size;

  /// لە سەردێڕی بەشەکان (.section-title .link): دوگمەیەکی خڕی زیوی
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    if (pill) {
      return Material(
        color: t.silver,
        shape: StadiumBorder(side: BorderSide(color: t.silverLine)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
            child: Text(label, style: TextStyle(color: t.text, fontWeight: FontWeight.w700, fontSize: 12.8, height: 1.4)),
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(label, style: TextStyle(color: context.yk.brand, fontWeight: FontWeight.w700, fontSize: size)),
      ),
    );
  }
}

enum CardTone { normal, note, ok, danger, info }

/// کارت (.card)
class YkCard extends StatelessWidget {
  const YkCard({super.key, required this.child, this.onTap, this.big = false, this.tone = CardTone.normal, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final bool big;
  final CardTone tone;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    Color bg = t.glass;
    Color border = t.glassLine;
    Color? fg;
    switch (tone) {
      case CardTone.note:
        bg = t.noteBg;
        border = t.noteLine;
      case CardTone.ok:
        bg = t.okBg;
        border = Colors.transparent;
        fg = t.okText;
      case CardTone.danger:
        bg = t.dangerBg;
        border = Colors.transparent;
        fg = t.dangerText;
      case CardTone.info:
        bg = t.infoBg;
        border = Colors.transparent;
        fg = t.infoText;
      case CardTone.normal:
        break;
    }
    final r = BorderRadius.circular(big ? Yk.rXl : Yk.rLg);
    Widget c = Container(
      padding: padding ?? EdgeInsets.all(big ? 16 : 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(color: border),
        boxShadow: tone == CardTone.normal ? const [BoxShadow(color: Color(0x0A10203F), blurRadius: 2, offset: Offset(0, 1))] : null,
      ),
      child: fg == null ? child : DefaultTextStyle.merge(style: TextStyle(color: fg), child: IconTheme.merge(data: IconThemeData(color: fg), child: child)),
    );
    if (onTap != null) c = _Pressable(onTap: onTap!, child: c);
    return c;
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _down ? .985 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
    );
  }
}

/// ناونیشانی خانە + خانەکە (.field)
class YkField extends StatelessWidget {
  const YkField({super.key, required this.label, required this.child, this.hint, this.optional = false});
  final String label;
  final Widget child;
  final String? hint;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: label),
          if (optional) TextSpan(text: ' (ئارەزوومەندانە)', style: TextStyle(fontWeight: FontWeight.w400, fontSize: 12.8, color: t.muted)),
        ]), style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w700, color: t.muted)),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint!, style: TextStyle(fontSize: 12.8, color: t.muted, height: 1.5)),
        ],
      ],
    );
  }
}

/// شێوەی خانەی نووسین (.input)
InputDecoration ykInput(BuildContext context, {String? hint, Widget? prefix, Widget? suffix}) {
  final t = context.yk;
  OutlineInputBorder b(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(Yk.rMd), borderSide: BorderSide(color: c, width: 1.5));
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.muted.withValues(alpha: .7)),
    filled: true,
    fillColor: t.card,
    isDense: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(t.line),
    enabledBorder: b(t.line),
    focusedBorder: b(t.act),
    errorBorder: b(t.danger),
    focusedErrorBorder: b(t.danger),
    prefixIcon: prefix,
    suffixIcon: suffix,
  );
}

/// خانەی ژمارەی مۆبایل: +964 لە لای چەپ، ژمارە بە پیتی لاتینی
class PhoneInput extends StatelessWidget {
  const PhoneInput({super.key, required this.controller, this.onSubmitted, this.textInputAction});
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: TextStyle(fontSize: 16, color: t.text, fontFamily: null, letterSpacing: .5),
        inputFormatters: [_PhoneFormatter()],
        decoration: ykInput(context,
            hint: '7xx xxx xxxx',
            prefix: Padding(
              padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
              child: Text('+964', style: TextStyle(color: t.muted, fontSize: 16)),
            )).copyWith(prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0)),
      ),
    );
  }
}

/// ژمارەی مۆبایل: تەنها ١٠ ژمارە، 0 و 964 لادەبرێن، ژمارەی کوردی دەگۆڕدرێت، بە شێوەی 770 049 1654
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    const ku = '٠١٢٣٤٥٦٧٨٩';
    var d = newValue.text.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${ku.indexOf(m[0]!)}').replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('964')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length > 10) d = d.substring(0, 10);
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 3 || i == 6) b.write(' ');
      b.write(d[i]);
    }
    final s = b.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// خانەی وشەی نهێنی بە دوگمەی چاو
class PasswordInput extends StatefulWidget {
  const PasswordInput({super.key, required this.controller, this.hint = '••••••', this.newPassword = false, this.onSubmitted, this.textInputAction});
  final TextEditingController controller;
  final String hint;
  final bool newPassword;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: widget.controller,
        obscureText: !_show,
        autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 16, color: t.text),
        decoration: ykInput(context,
            hint: widget.hint,
            prefix: IconButton(
              tooltip: _show ? 'شاردنەوەی وشەی نهێنی' : 'پیشاندانی وشەی نهێنی',
              onPressed: () => setState(() => _show = !_show),
              icon: YkIcon(_show ? 'eyeOff' : 'eye', size: 20, color: t.muted),
            )),
      ),
    );
  }
}

/// سەرپەڕەی پەڕە: دوگمەی گەڕانەوە، ناونیشان، ڕوونکردنەوە (.header)
class YkHeader extends StatelessWidget {
  const YkHeader(this.title, {super.key, this.sub, this.back = true, this.right});
  final String title;
  final String? sub;
  final bool back;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final canBack = back && Navigator.of(context).canPop();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (canBack)
            // دوگمەی خڕ لەسەر باکگراوندی شووشەیی (.icon-btn)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: t.glass, shape: BoxShape.circle, border: Border.all(color: t.glassLine)),
              child: IconButton(
                tooltip: 'گەڕانەوە',
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: YkIcon('back', size: 22, color: t.text),
              ),
            ),
          if (canBack) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Ts.h2(context).copyWith(height: 1.3)),
                if (sub != null) Text(sub!, style: Ts.muted(context, size: 14)),
              ],
            ),
          ),
          if (right != null)
            // دوگمەی ئایکۆن لە لای چەپ هەمان بازنەی شووشەیی (.icon-btn) وەردەگرێت
            if (right is IconButton)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: t.glass, shape: BoxShape.circle, border: Border.all(color: t.glassLine)),
                child: right,
              )
            else
              right!,
        ],
      ),
    );
  }
}

/// وێنەی کەس: وێنەکەی خۆی (img/{id})، یان وێنەی بنەڕەت (کەسێکی هێڵکاری لەسەر زیوی، .pav)
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, this.size = 44, this.imageId});
  final double size;
  final String? imageId;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: t.silver, border: Border.all(color: t.silverLine)),
      clipBehavior: Clip.antiAlias,
      child: personSvg(t.personLine),
    );
    if (imageId == null || imageId!.isEmpty) return fallback;
    return ClipOval(child: YkImage(imageId, width: size, height: size, placeholder: fallback));
  }
}

/// کەسێکی هێڵکاری (ui.personSvg)
Widget personSvg(Color color, {double stroke = 4}) {
  final c = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  return SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none" stroke="$c" stroke-width="$stroke" stroke-linecap="round">'
    '<circle cx="50" cy="39" r="15"/><path d="M22 84c3-15 14-23 28-23s25 8 28 23"/></svg>',
  );
}

/// نامەی هەڵە (.err)
class YkError extends StatelessWidget {
  const YkError(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: context.yk.danger, fontSize: 13.1));
}

/// پەڕەی خوارەوە (sheet)، وەک TK.sheet: بۆشایی ١٠ لە سەرەوە، دەستگرەی ٤٢×٥، بۆشایی ١٤،
/// و ٢٠ + safe-area لە خوارەوە (.sheet)
Future<T?> showYkSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  final t = context.yk;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + MediaQuery.viewPaddingOf(c).bottom + MediaQuery.viewInsetsOf(c).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: c.yk.line, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 14),
          builder(c),
        ]),
      ),
    ),
  );
}

/// پەیامی کورت لە خوارەوەی شاشە (TK.toast)
void toast(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
}

/// وەک [toast]، بەڵام دوای تەواوبوونی گۆڕینی پەڕە پیشان دەدرێت. بەکاری بهێنە کاتێک
/// یەکسەر دوای toast پەڕەیەک دادەخرێت، چونکە لە کاتی ئەنیمەیشندا دوو Scaffold هەمان
/// SnackBar پیشان دەدەن و Flutter هەڵەی «multiple heroes share the same tag» دەدات
void toastAfterNav(BuildContext context, String text) {
  final m = ScaffoldMessenger.maybeOf(context);
  Future.delayed(const Duration(milliseconds: 400), () {
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  });
}

/// کلیککردنەوە لەسەر هەمان بەشی شریتی خوارەوە: پەڕەکە دەچێتەوە سەرەوە (وەک واتسئاپ)
final ValueNotifier<int> ykScrollTop = ValueNotifier(0);

/// شاشەیەکی ئاسایی بە بۆشایی هەمان وێب (.screen).
/// کاتێک ناونیشانی گەورە بە سکرۆڵ دەڕوات، شریتێکی بچووکی ناونیشان لە سەرەوە دەردەکەوێت (#tbar ی وێب).
/// ناونیشان لە [title]، یان لە یەکەم [YkHeader] وەردەگیرێت
class YkScreen extends StatefulWidget {
  const YkScreen({super.key, required this.children, this.withNav = false, this.center = false, this.gap = 14, this.title, this.onRefresh});
  final List<Widget> children;
  final bool withNav;
  final bool center;
  final double gap;
  final String? title;

  /// ڕاکێشان بۆ نوێکردنەوە (TK.enablePtr): لە سەرەوەی پەڕە ڕایبکێشە بۆ خوارەوە
  final Future<void> Function()? onRefresh;

  @override
  State<YkScreen> createState() => _YkScreenState();
}

class _YkScreenState extends State<YkScreen> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _firstKey = GlobalKey();
  bool _bar = false;

  // ڕاکێشان بۆ نوێکردنەوە: هەمان ژمارەکانی وێب (PTR_GO = 84)
  static const _ptrGo = 84.0;
  static const _ptrHold = 70.0;
  double _pull = 0;
  bool _dragging = false;
  bool _busy = false;
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  bool _onPtr(ScrollNotification n) {
    if (widget.onRefresh == null || n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) _dragging = true;
    // کاتی بەردانی پەنجە بڕیار بە دوایین ڕاکێشان دەدرێت (وەک touchend ـی وێب). پێشتر یەکەم
    // چوارچێوەی گەڕانەوە _pull ـی دەکردە ٠ پێش پشکنین، بۆیە نوێکردنەوە هەرگیز نەدەکرا
    final released = _dragging &&
        ((n is ScrollUpdateNotification && n.dragDetails == null) || n is ScrollEndNotification);
    if (released) {
      _dragging = false;
      if (!_busy && _pull >= _ptrGo) {
        _startRefresh();
        return false;
      }
    }
    if (n is ScrollEndNotification) _dragging = false;
    if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null) _dragging = true;
      if (!_busy) {
        final p = n.metrics.pixels < 0 ? -n.metrics.pixels : 0.0;
        if (p != _pull) setState(() => _pull = p);
      }
    }
    return false;
  }

  Future<void> _startRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _pull = _ptrHold;
    });
    _spin.repeat();
    final t0 = DateTime.now();
    try {
      await widget.onRefresh!().timeout(const Duration(seconds: 6));
    } catch (_) {}
    final left = 800 - DateTime.now().difference(t0).inMilliseconds;
    if (left > 0) await Future.delayed(Duration(milliseconds: left));
    if (!mounted) return;
    _spin.stop();
    setState(() {
      _busy = false;
      _pull = 0;
    });
  }

  YkHeader? get _header => widget.children.isNotEmpty && widget.children.first is YkHeader ? widget.children.first as YkHeader : null;
  String? get _title => widget.title ?? _header?.title;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_sync);
    if (widget.withNav) ykScrollTop.addListener(_onTopSignal);
  }

  // تەنها پەڕەی دیار (بەشەکانی تری IndexedStack تیکەریان ناچالاکە)
  void _onTopSignal() {
    if (mounted && TickerMode.valuesOf(context).enabled) _toTop();
  }

  /// گەڕانەوە بۆ سەرەوەی پەڕە (کلیک لە شریتی کات لە ئایفۆن، لە ناونیشانی بچووک، یان لە بەشی چالاک)
  void _toTop() {
    if (!_scroll.hasClients || _scroll.offset <= 0) return;
    _scroll.animateTo(0, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    if (widget.withNav) ykScrollTop.removeListener(_onTopSignal);
    _scroll.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _sync() {
    if (_title == null || !_scroll.hasClients) return;
    final size = _firstKey.currentContext?.size;
    if (size == null) return;
    // بنی ناونیشانەکە (بێ دێڕی ڕوونکردنەوە) لە ژێر شریتەکە ون بوو؟ هاوتای barSync ـی وێب
    final h = _header?.sub != null ? size.height - 21 : size.height;
    final on = _scroll.offset > 14 + h - 42;
    if (on != _bar) setState(() => _bar = on);
  }

  @override
  Widget build(BuildContext context) {
    // لە ناو Shell ـدا padding ی خوارەوە بەرزی شریتی خوارەوەشی تێدایە (extendBody)، بۆیە بۆ
    // پەڕەکانی nav تەنها بۆشایی سیستەم (viewPadding) وەردەگیرێت، وەک وێب: 112 + safe-area
    // لە ناو Shell، padding.bottom بەرزی تەواوی شریتی خوارەوەیە (extendBody)؛ بۆشایی خوارەوە
    // هەمیشە لانیکەم ٢٨ پیکسڵ لە سەرووی شریتە گەورەکەوە دەبێت، تا دوایین کارت لە ژێری نەمێنێت
    final navTop = widget.withNav ? MediaQuery.paddingOf(context).bottom + 28 - 112 : 0.0;
    final bottom = widget.withNav
        ? math.max(MediaQuery.viewPaddingOf(context).bottom, navTop)
        : MediaQuery.of(context).padding.bottom;
    final list = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (i > 0) list.add(SizedBox(height: widget.gap));
      list.add(i == 0 ? KeyedSubtree(key: _firstKey, child: widget.children[i]) : widget.children[i]);
    }
    // پەڕەی بەتاڵ (.screen:has(> .empty)): وێنە و نووسین و ئەوەی دوای دێت دێنە ناوەڕاستی بۆشایی
    final emptyAt = widget.center ? -1 : widget.children.indexWhere((w) => w is YkEmpty);
    // بۆشایی هێڵی خوارەوەی ئایفۆن لە وێبیش لە app.dart ـەوە دێت (_withWebSafe)
    final padBottom = (emptyAt >= 0 ? (widget.withNav ? 150 : 70) : (widget.withNav ? 112 : 32)) + bottom;
    // SizedBox.expand: Stack و Scaffold سنووری شل دەدەن، بۆیە SingleChildScrollView بە بەرزی
    // ناوەڕۆک بچووک دەبووەوە و لە پەڕە کورتەکاندا دەستلێدان لە ژێر ناوەڕۆکەوە هیچی نەدەگرت
    // (نە ڕاکێشان، نە لەرینەوە، نە نوێکردنەوە). ئێستا ڕووبەری سکرۆڵ هەموو شاشەکە دەگرێت
    final body = SizedBox.expand(child: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (c, box) => NotificationListener<ScrollNotification>(
          onNotification: _onPtr,
          // لە کاتی نوێکردنەوەدا پەڕەکە ٧٠ پیکسڵ لە خوارەوە دەوەستێت. تەنها وێنەکە دەجووڵێت
          // (Transform)، نەک قەبارەی پەڕە، تا شوێنی سکرۆڵ تێک نەچێت (وەک translateY ـی .screen)
          child: TweenAnimationBuilder<double>(
          tween: Tween(end: _busy ? _ptrHold : 0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.ease,
          builder: (context, v, child) => Transform.translate(offset: Offset(0, v), child: child),
          child: SingleChildScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 14, 16, padBottom),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
            // لەسەر شاشەی گەورە (کۆمپیوتەر) پانی ٤٨٠ دەمێنێتەوە، وەک وەشانی وێب
            constraints: BoxConstraints(
              minHeight: widget.center ? (box.maxHeight - 46 - bottom).clamp(0.0, double.infinity) : 0,
              maxWidth: 480,
            ),
            child: emptyAt >= 0
                ? _AutoCenterColumn(
                    minHeight: (box.maxHeight - 14 - padBottom).clamp(0.0, double.infinity),
                    centerFrom: emptyAt * 2,
                    children: list,
                  )
                : Column(
                    mainAxisAlignment: widget.center ? MainAxisAlignment.center : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: list,
                  ),
          ),
          ),
        ),
          ),
        ),
      ),
    ));
    final ptr = widget.onRefresh == null
        ? null
        : Positioned(
            top: MediaQuery.paddingOf(context).top,
            left: 0,
            right: 0,
            child: IgnorePointer(child: _PtrIndicator(pull: _pull, busy: _busy, spin: _spin)),
          );
    // لە ئەپی ئایفۆن: کلیک لەسەر شریتی کات (status bar) پەڕەکە دەباتەوە سەرەوە
    final topPad = MediaQuery.paddingOf(context).top;
    final statusTap = topPad <= 0
        ? null
        : Positioned(top: 0, left: 0, right: 0, height: topPad, child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _toTop));
    final title = _title;
    if (title == null) return ptr == null && statusTap == null ? body : Stack(children: [body, if (ptr != null) ptr, if (statusTap != null) statusTap]);
    final h = _header;
    return Stack(
      children: [
        body,
        if (ptr != null) ptr,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_bar,
            child: AnimatedOpacity(
              opacity: _bar ? 1 : 0,
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
              curve: Curves.ease,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toTop,
                child: _TitleBar(title: title, back: h != null && h.back && Navigator.of(context).canPop()),
              ),
            ),
          ),
        ),
        if (statusTap != null && !_bar) statusTap,
      ],
    );
  }
}

/// شریتی ناونیشانی بچووکی تەم‌دار لە سەرەوە (#tbar)
class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, required this.back});
  final String title;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final top = MediaQuery.of(context).padding.top;
    // لە وێبی Flutter تەڵخی پشت قورسە، بۆیە ڕەنگەکە کەمێک تۆختر دەکرێت
    const alpha = kIsWeb ? 0xF0 : 0xC7;
    final bar = Container(
      // پانی تەواو (وەک #tbar)، نەک تەنها بە قەبارەی ناونیشانەکە
      width: double.infinity,
      padding: EdgeInsets.only(top: top),
      decoration: BoxDecoration(
        color: (t.dark ? const Color(0xFF16181D) : const Color(0xFFFFFFFF)).withAlpha(alpha),
        border: Border(bottom: BorderSide(width: .5, color: t.dark ? const Color(0x1AFFFFFF) : const Color(0x24000000))),
      ),
      child: SizedBox(
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16.3, fontWeight: FontWeight.w600, color: t.text)),
            ),
            if (back)
              PositionedDirectional(
                start: 8,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: IconButton(
                    tooltip: 'گەڕانەوە',
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: YkIcon('back', size: 22, color: t.text),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRect(
          child: kIsWeb ? bar : BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: bar),
        ),
      ),
    );
  }
}

/// لیستی ستایلی ئایفۆن (.list): ئایکۆن بێ چوارگۆشە، خەتی نێوان لە سەرەتای نووسینەوە
class YkList extends StatelessWidget {
  const YkList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        final hasIcon = children[i] is YkListItem && (children[i] as YkListItem).icon != null;
        rows.add(Padding(
          padding: EdgeInsetsDirectional.only(start: hasIcon ? 58 : 16),
          child: Divider(height: 1, thickness: 1, color: t.line),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: t.glass,
        borderRadius: BorderRadius.circular(Yk.rLg),
        border: Border.all(color: t.glassLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(type: MaterialType.transparency, child: Column(children: rows)),
    );
  }
}

class YkListItem extends StatelessWidget {
  const YkListItem({super.key, this.icon, required this.label, this.sub, this.trailing, this.onTap, this.chevron = true, this.color});
  final String? icon;
  final String label;
  final String? sub;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return InkWell(
      onTap: onTap,
      highlightColor: t.chip,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                SizedBox(width: 28, height: 28, child: Center(child: YkIcon(icon!, size: 24, stroke: 1.7, color: color ?? t.text))),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontSize: 16.3, color: color ?? t.text, fontWeight: sub == null ? FontWeight.w500 : FontWeight.w700)),
                  if (sub != null) Text(sub!, style: Ts.muted(context, size: 12.8)),
                ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron && onTap != null) ...[const SizedBox(width: 8), YkIcon('forward', size: 18, color: t.muted)],
            ],
          ),
        ),
      ),
    );
  }
}

/// ژمارەی بچووک لە بازنەیەکدا (.cntp)
class CountPill extends StatelessWidget {
  const CountPill(this.text, {super.key, this.section = false});
  final String text;

  /// لە سەردێڕی بەشەکان (.section-title .cntp): زیوی، ٢٦، نووسینی تۆخ
  final bool section;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final d = section ? 26.0 : 24.0;
    return Container(
      constraints: BoxConstraints(minWidth: d),
      height: d,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: section ? t.silver : t.chip, borderRadius: BorderRadius.circular(d / 2)),
      child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: section ? t.text : t.muted, height: 1.2)),
    );
  }
}

enum BadgeTone { normal, ok, danger, note, info, woman, red }

/// نیشانە (.badge)
class YkBadge extends StatelessWidget {
  const YkBadge(this.label, {super.key, this.tone = BadgeTone.normal});
  final String label;
  final BadgeTone tone;
  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final (bg, fg) = switch (tone) {
      BadgeTone.ok => (t.okBg, t.okText),
      BadgeTone.danger => (t.dangerBg, t.dangerText),
      BadgeTone.note => (t.silver, t.text),
      BadgeTone.info => (t.infoBg, t.infoText),
      BadgeTone.woman => (t.wBg, t.wText),
      BadgeTone.normal => (t.chip, t.text),
      // .badge.red: سووری تۆخ بە نووسینی سپی (نەخوێندراوە، نرخ هات)
      BadgeTone.red => (t.danger, Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12.2, fontWeight: FontWeight.w700, color: fg, height: 1.4)),
    );
  }
}

/// ناونیشانی گرووپ (.plabel)
class PLabel extends StatelessWidget {
  const PLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Text(text, style: TextStyle(fontSize: 13.1, fontWeight: FontWeight.w700, color: context.yk.muted)),
      );
}

/// هەڵبژاردنی یەک لە چەند (.seg)
class YkSeg<T> extends StatelessWidget {
  const YkSeg({super.key, required this.options, required this.value, required this.onChanged});
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.dark ? const Color(0x0FFFFFFF) : t.chip, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 38),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: o.$1 == value ? (t.dark ? const Color(0xFF33373F) : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: o.$1 == value && !t.dark ? const [BoxShadow(color: Color(0x1A101828), blurRadius: 4, offset: Offset(0, 1))] : null,
                  ),
                  child: Text(o.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w700, height: 1.35, color: o.$1 == value ? t.text : t.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// هەڵبژاردن لە لیستێک: وەک خانەی نووسین دەردەکەوێت و لیستێکی بچووک لە خوارەوە دەکاتەوە
/// (لە جیاتی لیستی گەورەی Material)
class YkSelect<T> extends StatelessWidget {
  const YkSelect({super.key, required this.items, required this.value, required this.onChanged, this.hint = 'هەڵبژێرە', this.title});
  final List<(T, String)> items;
  final T? value;
  final ValueChanged<T> onChanged;
  final String hint;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    String? label;
    for (final it in items) {
      if (it.$1 == value) label = it.$2;
    }
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(Yk.rMd),
            border: Border.all(color: t.line, width: 1.5),
          ),
          child: Row(children: [
            Expanded(child: Text(label ?? hint, style: TextStyle(fontSize: 16, color: label == null ? t.muted : t.text))),
            YkIcon('down', size: 18, color: t.muted),
          ]),
        ),
      ),
    );
  }

  /// لیستێکی بچووکی ستایلی ئایفۆن لەسەر خانەکە دەکرێتەوە (وەک <select> لە Safari)
  void _open(BuildContext context) {
    FocusScope.of(context).unfocus();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'داخستن',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (c, a1, a2) => _SelectMenu<T>(anchor: rect, items: items, value: value),
      transitionBuilder: (c, anim, a2, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
      ),
    ).then((v) {
      if (v != null) onChanged(v);
    });
  }
}

class _SelectMenu<T> extends StatelessWidget {
  const _SelectMenu({required this.anchor, required this.items, required this.value});
  final Rect anchor;
  final List<(T, String)> items;
  final T? value;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final mq = MediaQuery.of(context);
    const rowH = 46.0;
    final w = (mq.size.width * .58).clamp(200.0, 300.0);
    final h = rowH * items.length + 8;
    // لە ناوەڕاستی خانەکە، بە شێوەیەک کە هەڵبژێردراوەکە لەسەر خانەکە بێت
    final sel = items.indexWhere((it) => it.$1 == value);
    var top = anchor.center.dy - 4 - rowH * (sel < 0 ? 0 : sel) - rowH / 2;
    top = top.clamp(mq.padding.top + 8, mq.size.height - mq.padding.bottom - h - 8);
    final left = (anchor.center.dx - w / 2).clamp(12.0, mq.size.width - w - 12);
    return Stack(children: [
      Positioned(
        top: top,
        left: left,
        width: w,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: t.dark ? const Color(0x66000000) : const Color(0x26000000), blurRadius: 40, offset: const Offset(0, 12))],
          ),
          child: Material(
            color: t.dark ? const Color(0xF22A2D33) : const Color(0xF7FAFAFA),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: .5, color: t.line),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(items[i].$1),
                    child: SizedBox(
                      height: rowH - (i > 0 ? 1 : 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(textDirection: TextDirection.ltr, children: [
                          SizedBox(width: 26, child: items[i].$1 == value ? YkIcon('check', size: 18, color: t.text, stroke: 2.6) : null),
                          Expanded(child: Text(items[i].$2, textAlign: TextAlign.left, style: TextStyle(fontSize: 17, color: t.text, fontWeight: FontWeight.w500))),
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// دوو یان سێ هەڵبژاردە لە تەنیشت یەکەوە، وەک ڕەگەز (نێر / مێ)
class YkChoice<T> extends StatelessWidget {
  const YkChoice({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(items[i].$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(Yk.rMd),
                border: Border.all(color: items[i].$1 == value ? t.act : t.line, width: items[i].$1 == value ? 2 : 1.5),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: items[i].$1 == value ? t.act : t.muted.withValues(alpha: .5), width: items[i].$1 == value ? 6 : 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(items[i].$2, style: TextStyle(fontSize: 16, color: t.text, fontWeight: items[i].$1 == value ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// پەڕەی بەتاڵ (ui.empty): وێنەی خۆڵەمێشی نەرم، ناونیشان، ڕوونکردنەوە و دوگمەیەکی ئارەزوومەندانە
class YkEmpty extends StatelessWidget {
  const YkEmpty({super.key, required this.icon, required this.title, this.text, this.button});
  final String icon;
  final String title;
  final String? text;
  final Widget? button;

  static String art(String body, bool dark) => _art(body, dark);

  static String _art(String body, bool dark) {
    final p = dark ? '#232833' : '#ECEEF2';
    final c1 = dark ? '#2A303B' : '#F2F4F7';
    final c2 = dark ? '#353C49' : '#DDE1E7';
    final s = dark ? '#4A5262' : '#C3C9D1';
    // هەمان یاساکانی .empty-art لە core.css
    return body
        .replaceAll('class="ea-p"', 'fill="$p"')
        .replaceAll('class="ea-1"', 'fill="$c1" stroke="$s" stroke-width="2"')
        .replaceAll('class="ea-2"', 'fill="$c2" stroke="$s" stroke-width="2"')
        .replaceAll('class="ea-l"', 'fill="none" stroke="$s" stroke-width="2" stroke-linecap="round"')
        .replaceAll('class="ea-g"', 'fill="none" stroke="$p" stroke-width="4" stroke-linecap="round"')
        .replaceAll('class="ea-d"', 'fill="$s"');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final art = kEmptyArt[kEmptyAlias[icon] ?? icon];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (art != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: AspectRatio(
              aspectRatio: 220 / 180,
              child: SvgPicture.string(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 180">${_art(kEmptyBg + art, t.dark)}</svg>',
              ),
            ),
          )
        else
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: t.silver, borderRadius: BorderRadius.circular(20)),
            alignment: Alignment.center,
            child: YkIcon(icon, size: 30, color: t.muted),
          ),
        SizedBox(height: art != null ? 22 : 8),
        Text(title, textAlign: TextAlign.center, style: Ts.h3(context)),
        if (text != null) ...[
          const SizedBox(height: 8),
          Text(text!, textAlign: TextAlign.center, style: Ts.muted(context, size: 14)),
        ],
        if (button != null) ...[const SizedBox(height: 20), button!],
      ]),
    );
  }
}

/// ستوونێک کە ئەگەر ناوەڕۆکەکەی لە [minHeight] کورتتر بوو، منداڵەکانی لە [centerFrom] ـەوە
/// دەخاتە ناوەڕاستی بۆشایی ماوە (margin-top: auto لەسەر .empty و margin-bottom: auto لەسەر
/// کۆتا منداڵ). بێ intrinsic، بۆیە لەگەڵ LayoutBuilder ـیش کار دەکات
class _AutoCenterColumn extends MultiChildRenderObjectWidget {
  const _AutoCenterColumn({required this.minHeight, required this.centerFrom, required super.children});
  final double minHeight;
  final int centerFrom;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAutoCenter(minHeight, centerFrom);

  @override
  void updateRenderObject(BuildContext context, _RenderAutoCenter r) {
    r
      ..minHeight = minHeight
      ..centerFrom = centerFrom;
  }
}

class _AutoCenterData extends ContainerBoxParentData<RenderBox> {}

class _RenderAutoCenter extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _AutoCenterData>, RenderBoxContainerDefaultsMixin<RenderBox, _AutoCenterData> {
  _RenderAutoCenter(this._minHeight, this._centerFrom);

  double _minHeight;
  set minHeight(double v) {
    if (v == _minHeight) return;
    _minHeight = v;
    markNeedsLayout();
  }

  int _centerFrom;
  set centerFrom(int v) {
    if (v == _centerFrom) return;
    _centerFrom = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _AutoCenterData) child.parentData = _AutoCenterData();
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final cc = BoxConstraints(minWidth: w, maxWidth: w);
    var total = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(cc, parentUsesSize: true);
      total += child.size.height;
      child = childAfter(child);
    }
    final h = constraints.constrainHeight(total < _minHeight ? _minHeight : total);
    final extra = h - total;
    var y = 0.0;
    var i = 0;
    child = firstChild;
    while (child != null) {
      if (i == _centerFrom) y += extra / 2;
      (child.parentData! as _AutoCenterData).offset = Offset(0, y);
      y += child.size.height;
      i++;
      child = childAfter(child);
    }
    size = Size(w, h);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// نیشانەی ڕاکێشان بۆ نوێکردنەوە (#ptr): بازنەیەک بە Y، خاڵێکی پرتەقاڵی دێتە خوارەوە و
/// پاشان هێڵێک بە دەوری بازنەکەدا دەکێشێت؛ لە کاتی نوێکردنەوەدا دەسوڕێتەوە
class _PtrIndicator extends StatelessWidget {
  const _PtrIndicator({required this.pull, required this.busy, required this.spin});
  final double pull;
  final bool busy;
  final AnimationController spin;

  @override
  Widget build(BuildContext context) {
    if (pull <= 0 && !busy) return const SizedBox.shrink();
    final t = context.yk;
    final p = (pull / 84).clamp(0.0, 1.0);
    final dy = (pull - 64).clamp(0.0, double.infinity) / 2 + (pull < 64 ? pull : 64) - 56;
    final label = busy ? '' : (p >= 1 ? 'بەری بدە بۆ نوێکردنەوە' : 'ڕابکێشە بۆ نوێکردنەوە');
    return Transform.translate(
      offset: Offset(0, dy),
      child: Opacity(
        opacity: (pull / 30).clamp(0.0, 1.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.dark ? const Color(0xFF23262E) : t.card,
              border: Border.all(color: t.dark ? const Color(0x14FFFFFF) : t.line),
              boxShadow: [BoxShadow(color: t.dark ? const Color(0x66000000) : const Color(0x24101828), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: AnimatedBuilder(
              animation: spin,
              builder: (context, child) => CustomPaint(
                painter: _PtrPainter(
                  p: p,
                  spinAngle: busy ? 90 + .9 * 360 + spin.value * 540 : null,
                  line: t.line,
                  ink: t.text,
                ),
              ),
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w600, color: t.muted)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// هەمان ptrSvg ـی وێب (viewBox 48)
class _PtrPainter extends CustomPainter {
  _PtrPainter({required this.p, required this.spinAngle, required this.line, required this.ink});
  final double p;
  final double? spinAngle;
  final Color line, ink;
  static const _amber = Color(0xFFF5A623);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 48;
    canvas.scale(k);
    const c = Offset(24, 24);
    const r = 20.0;
    double drop, arc, ang;
    if (spinAngle != null) {
      drop = 1;
      arc = .3;
      ang = spinAngle!;
    } else if (p < .35) {
      drop = p / .35;
      arc = 0;
      ang = 90;
    } else {
      drop = 1;
      arc = ((p - .35) / .65) * .9;
      ang = 90 + arc * 360;
    }
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = line);
    if (arc > 0.01) {
      final start = (ang - arc * 360) * math.pi / 180;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, arc * 2 * math.pi, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..color = _amber);
    }
    final y = Path()
      ..moveTo(16.5, 13.5)
      ..lineTo(24, 23.5)
      ..lineTo(31.5, 13.5)
      ..moveTo(24, 23.5)
      ..lineTo(24, 28);
    canvas.drawPath(y, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink);
    final Offset dot;
    if (drop < 1) {
      dot = Offset(24, 31 + (24 + r - 31) * drop);
    } else {
      final a = ang * math.pi / 180;
      dot = Offset(24 + r * math.cos(a), 24 + r * math.sin(a));
    }
    canvas.drawCircle(dot, 3.6, Paint()..color = _amber);
  }

  @override
  bool shouldRepaint(_PtrPainter o) => o.p != p || o.spinAngle != spinAngle || o.line != line || o.ink != ink;
}

/// چوارچێوەی خاڵخاڵی خڕ (border: 1.5px dashed)
class DashedBorder extends CustomPainter {
  DashedBorder({required this.color, required this.radius, this.width = 1.5});
  final Color color;
  final double radius;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(width / 2);
    for (final m in (Path()..addRRect(r)).computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, (d + 5).clamp(0, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorder old) => old.color != color || old.radius != radius || old.width != width;
}
