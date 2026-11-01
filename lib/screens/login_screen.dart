// چوونەژوورەوە بە ژمارەی مۆبایل و وشەی نهێنی
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth.dart';
import '../core/i18n.dart';
import '../core/invite_link.dart';
import '../core/settings.dart';
import '../ui/logo.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // لینکی هاوبەش (#/register?ref=CODE): ڕاستەوخۆ پەڕەی تۆمارکردن بە کۆدەکەوە
    final ref = takePendingRef();
    if (ref != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterScreen(refCode: ref)));
      });
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final err = await context.read<AuthService>().login(_phone.text, _pass.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _err = err;
    });
    if (err == null) {
      toastAfterNav(context, tr('بەخێربێیتەوە'));
      // AuthGate خۆی دەچێتە سەرەکی؛ هەر پەڕەیەکی تر کە لەسەرەوەیە دادەخرێت
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _forgot() {
    showYkSheet(context, builder: (c) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('وشەی نهێنیت لەبیر چووە؟'), style: Ts.h2(c)),
          const SizedBox(height: 8),
          Text(tr('پەیوەندی بە تیمی پشتگیری یەکسا بکە بۆ یارمەتی.'), style: Ts.muted(c, size: 14).copyWith(height: 1.9)),
          const SizedBox(height: 16),
          YkButton(tr('باشە'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final st = context.watch<LocalSettings>();
    return Scaffold(
      body: AutofillGroup(
        child: YkScreen(
          center: true,
          gap: 12,
          children: [
            // هەڵبژاردنی زمان پێش چوونەژوورەوە
            Align(alignment: AlignmentDirectional.centerEnd, child: YkLangPill(value: st.lang, onChanged: st.setLang)),
            Column(children: [
              const YLogo.big(),
              const SizedBox(height: 20),
              Text(tr('بەخێربێیتەوە'), style: Ts.h1(context)),
              const SizedBox(height: 6),
              Text(tr('بە ژمارەی مۆبایل و وشەی نهێنی بچۆ ژوورەوە'), textAlign: TextAlign.center, style: Ts.muted(context, size: 14)),
              const SizedBox(height: 10),
            ]),
            YkField(label: tr('ژمارەی مۆبایل'), child: PhoneInput(controller: _phone, textInputAction: TextInputAction.next)),
            YkField(
              label: tr('وشەی نهێنی'),
              child: PasswordInput(controller: _pass, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit()),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [YkLink(tr('وشەی نهێنیت لەبیر چووە؟'), onTap: _forgot)]),
            if (_err != null) YkError(_err!),
            YkButton(tr('چوونەژوورەوە'), block: true, busy: _busy, onPressed: _submit),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tr('ئەکاونتت نییە؟ '), style: TextStyle(fontSize: 14, color: t.text)),
                YkLink(tr('ئەکاونتی نوێ دروست بکە'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
