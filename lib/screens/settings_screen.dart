// ڕێکخستنەکان: ڕووکار، قەبارەی نووسین، ژمارەکان، ئاگادارکردنەوە (گۆڕینی وشەی نهێنی لە زانیاری پرۆفایلدایە)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth.dart';
import '../core/settings.dart';
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
          const YkHeader('ڕێکخستنەکان'),
          Text('ڕووکار', style: Ts.h3(context)),
          YkCard(
            child: Column(children: [
              group('ڕووکار', YkSeg<String>(options: const [('light', 'ڕووناک'), ('dark', 'تاریک'), ('auto', 'خۆکار')], value: st.theme, onChanged: st.setTheme)),
              const SizedBox(height: 10),
              group('قەبارەی نووسین', YkSeg<String>(options: const [('sm', 'بچووک'), ('md', 'ئاسایی'), ('lg', 'گەورە')], value: st.textScale, onChanged: st.setTextScale)),
              const SizedBox(height: 10),
              group('ژمارەکان', YkSeg<String>(options: const [('ku', '١٢٣'), ('en', '123')], value: st.digits, onChanged: st.setDigits)),
            ]),
          ),
          Text('تایبەتمەندی و ئاگادارکردنەوە', style: Ts.h3(context)),
          YkCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ژمارەی مۆبایلەکەم', style: Ts.body(context)),
                    Text('هەمیشە شاراوەیە. شۆفێر تەنها لە ڕێگەی نامەوە پەیوەندیت پێوە دەکات', style: Ts.muted(context, size: 12.8)),
                  ]),
                ),
                YkIcon('lock', size: 18, color: t.muted),
              ]),
              const YkHr(),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ئاگادارکردنەوە لەسەر مۆبایل', style: Ts.body(context)),
                    Text('بۆ ئاگادارکردنەوە کاتێک لە ئەپەکە نیت', style: Ts.muted(context, size: 12.8)),
                  ]),
                ),
                const SizedBox(width: 10),
                // ئاگادارکردنەوەی دەرەوەی ئەپ (push) پێویستی بە Firebase Cloud Messaging ـە، هێشتا دانەنراوە
                YkButton('چالاککردن', small: true, kind: BtnKind.secondary, onPressed: () => toast(context, 'ئێستا تەنها ئاگادارکردنەوەی ناو ئەپ کار دەکات')),
              ]),
              const YkHr(),
              for (final (k, label) in const [('ride', 'ئاگادارکردنەوەی گەشت'), ('pay', 'ئاگادارکردنەوەی پارەدان'), ('news', 'هەواڵ و ئۆفەر')])
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
        Text('گۆڕینی وشەی نهێنی', style: Ts.h2(c)),
        const SizedBox(height: 12),
        YkField(label: 'وشەی نهێنی ئێستا', child: PasswordInput(controller: oldC)),
        const SizedBox(height: 12),
        YkField(label: 'وشەی نهێنی نوێ', child: PasswordInput(controller: newC, hint: 'لانیکەم ٦ پیت', newPassword: true)),
        if (err != null) ...[const SizedBox(height: 8), YkError(err!)],
        const SizedBox(height: 12),
        YkButton('پاشەکەوت', block: true, busy: busy, onPressed: () async {
          setS(() => busy = true);
          final e = await c.read<AuthService>().changePassword(oldC.text, newC.text);
          if (!c.mounted) return;
          setS(() {
            busy = false;
            err = e;
          });
          if (e == null) {
            Navigator.pop(c);
            toast(context, 'وشەی نهێنی گۆڕدرا');
          }
        }),
        const SizedBox(height: 8),
        YkButton('پاشگەزبوونەوە', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  });
}
