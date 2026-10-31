// چوونەژوورەوە بە ژمارەی مۆبایل و وشەی نهێنی
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth.dart';
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
      toastAfterNav(context, 'بەخێربێیتەوە');
      // AuthGate خۆی دەچێتە سەرەکی؛ هەر پەڕەیەکی تر کە لەسەرەوەیە دادەخرێت
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _forgot() {
    showYkSheet(context, builder: (c) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('وشەی نهێنیت لەبیر چووە؟', style: Ts.h2(c)),
          const SizedBox(height: 8),
          Text('پەیوەندی بە تیمی پشتگیری یەکسا بکە بۆ یارمەتی.', style: Ts.muted(c, size: 14).copyWith(height: 1.9)),
          const SizedBox(height: 16),
          YkButton('باشە', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    return Scaffold(
      body: AutofillGroup(
        child: YkScreen(
          center: true,
          gap: 12,
          children: [
            Column(children: [
              const YLogo.big(),
              const SizedBox(height: 20),
              Text('بەخێربێیتەوە', style: Ts.h1(context)),
              const SizedBox(height: 6),
              Text('بە ژمارەی مۆبایل و وشەی نهێنی بچۆ ژوورەوە', style: Ts.muted(context, size: 14)),
              const SizedBox(height: 10),
            ]),
            YkField(label: 'ژمارەی مۆبایل', child: PhoneInput(controller: _phone, textInputAction: TextInputAction.next)),
            YkField(
              label: 'وشەی نهێنی',
              child: PasswordInput(controller: _pass, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit()),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [YkLink('وشەی نهێنیت لەبیر چووە؟', onTap: _forgot)]),
            if (_err != null) YkError(_err!),
            YkButton('چوونەژوورەوە', block: true, busy: _busy, onPressed: _submit),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ئەکاونتت نییە؟ ', style: TextStyle(fontSize: 14, color: t.text)),
                YkLink('ئەکاونتی نوێ دروست بکە', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
