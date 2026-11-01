// ڕێکخستنەکان: ڕووکار، قەبارەی نووسین، ژمارەکان، ئاگادارکردنەوە (گۆڕینی وشەی نهێنی لە زانیاری پرۆفایلدایە)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/settings.dart';
import '../core/web_notify_stub.dart' if (dart.library.js_interop) '../core/web_notify_web.dart';
import '../ui/form_parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final st = context.watch<LocalSettings>();
    Widget group(String label, Widget seg) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, style: Ts.sm(context).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          seg,
        ]);
    return Scaffold(
      body: YkScreen(
        children: [
          YkHeader(tr('ڕێکخستنەکان')),
          Text(tr('ڕووکار'), style: Ts.h3(context)),
          YkCard(
            child: Column(children: [
              group(tr('زمان'), YkSeg<String>(options: L.options, value: st.lang, onChanged: st.setLang)),
              const SizedBox(height: 10),
              group(tr('ڕووکار'), YkSeg<String>(options: [('light', tr('ڕووناک')), ('dark', tr('تاریک')), ('auto', tr('خۆکار'))], value: st.theme, onChanged: st.setTheme)),
              const SizedBox(height: 10),
              group(tr('قەبارەی نووسین'), YkSeg<String>(options: [('sm', tr('بچووک')), ('md', tr('ئاسایی')), ('lg', trc('گەورە', 'كبير', 'Large'))], value: st.textScale, onChanged: st.setTextScale)),
              const SizedBox(height: 10),
              group(tr('ژمارەکان'), YkSeg<String>(options: const [('ku', '١٢٣'), ('en', '123')], value: st.digits, onChanged: st.setDigits)),
            ]),
          ),
          Text(tr('تایبەتمەندی و ئاگادارکردنەوە'), style: Ts.h3(context)),
          YkCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('ژمارەی مۆبایلەکەم'), style: Ts.body(context)),
                    Text(tr('هەمیشە شاراوەیە. شۆفێر تەنها لە ڕێگەی نامەوە پەیوەندیت پێوە دەکات'), style: Ts.muted(context, size: 12.8)),
                  ]),
                ),
                YkIcon('lock', size: 18, color: t.muted),
              ]),
              const YkHr(),
              const _NotifyRow(),
              const YkHr(),
              for (final (k, label) in [('ride', tr('ئاگادارکردنەوەی گەشت')), ('pay', tr('ئاگادارکردنەوەی پارەدان')), ('news', tr('هەواڵ و ئۆفەر'))])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(label, style: Ts.body(context))),
                    YkToggle(value: st.notify[k] ?? true, onChanged: (_) => st.toggleNotify(k)),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// گۆڕینی وشەی نهێنی
void changePasswordSheet(BuildContext context) {
  final oldC = TextEditingController();
  final newC = TextEditingController();
  String? err;
  bool busy = false;
  showYkSheet(context, builder: (c) {
    return StatefulBuilder(builder: (c, setS) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('گۆڕینی وشەی نهێنی'), style: Ts.h2(c)),
        const SizedBox(height: 12),
        YkField(label: tr('وشەی نهێنی ئێستا'), child: PasswordInput(controller: oldC)),
        const SizedBox(height: 12),
        YkField(label: tr('وشەی نهێنی نوێ'), child: PasswordInput(controller: newC, hint: Fmt.n(tr('لانیکەم ٦ پیت')), newPassword: true)),
        if (err != null) ...[const SizedBox(height: 8), YkError(err!)],
        const SizedBox(height: 12),
        YkButton(tr('پاشەکەوت'), block: true, busy: busy, onPressed: () async {
          setS(() => busy = true);
          final e = await c.read<AuthService>().changePassword(oldC.text, newC.text);
          if (!c.mounted) return;
          setS(() {
            busy = false;
            err = e;
          });
          if (e == null) {
            Navigator.pop(c);
            toast(context, tr('وشەی نهێنی گۆڕدرا'));
          }
        }),
        const SizedBox(height: 8),
        YkButton(tr('پاشگەزبوونەوە'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  });
}

/// هەمان دەقەکانی notifyText ـی وێب
String _notifyText(String st) {
  if (st == 'granted') return tr('کاتێک ئەپەکە داخراوە ئاگادار دەکرێیتەوە');
  if (st == 'denied') return tr('ڕێگەپێدان ڕەتکرایەوە. لە ڕێکخستنی مۆبایل بیگۆڕە');
  if (st == 'insecure' || st == 'unsupported') return tr('ئەم مۆبایلە ئێستا پشتگیری ناکات. ئاگادارکردنەوەی ناو ئەپ کار دەکات');
  return tr('بۆ ئاگادارکردنەوە کاتێک لە ئەپەکە نیت');
}

/// ئاگادارکردنەوە لەسەر مۆبایل: دەق و دوگمەی «چالاککردن» (askNotify ـی وێب).
/// لە ئایفۆن تەنها کاتێک ئەپەکە خراوەتە سەر شاشەی سەرەکی کار دەکات
class _NotifyRow extends StatefulWidget {
  const _NotifyRow();
  @override
  State<_NotifyRow> createState() => _NotifyRowState();
}

class _NotifyRowState extends State<_NotifyRow> {
  @override
  Widget build(BuildContext context) {
    final st = notifyStatus();
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('ئاگادارکردنەوە لەسەر مۆبایل'), style: Ts.body(context)),
          Text(_notifyText(st), style: Ts.muted(context, size: 12.8)),
        ]),
      ),
      const SizedBox(width: 10),
      YkButton(st == 'granted' ? tr('چالاکە') : tr('چالاککردن'), small: true, kind: BtnKind.secondary, onPressed: () async {
        final r = await askNotify();
        if (!context.mounted) return;
        final msg = {
          'granted': tr('ئاگادارکردنەوە چالاک کرا'),
          'denied': tr('ڕێگەپێدان ڕەتکرایەوە'),
          'insecure': tr('ئێستا تەنها ئاگادارکردنەوەی ناو ئەپ کار دەکات'),
          'unsupported': tr('ئەم وێبگەڕە پشتگیری ناکات. ئەپەکە بخە سەر شاشەی سەرەکی'),
        };
        if (msg[r] != null) toast(context, msg[r]!);
        setState(() {});
      }),
    ]);
  }
}
