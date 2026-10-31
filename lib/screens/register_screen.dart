// دروستکردنی ئەکاونتی نوێ
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/auth.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.refCode});

  /// کۆدی بانگهێشت لە لینک یان QR (passenger/#/register?ref=CODE)
  final String? refCode;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _ref = TextEditingController();
  String _gender = '';
  String? _city;
  String? _err;
  bool _busy = false;

  Invite? _refRes;
  bool _refWait = false;
  Timer? _refTimer;

  @override
  void initState() {
    super.initState();
    if (widget.refCode != null && widget.refCode!.isNotEmpty) {
      _ref.text = widget.refCode!.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkRef(_ref.text));
    }
  }

  @override
  void dispose() {
    _refTimer?.cancel();
    _name.dispose();
    _phone.dispose();
    _pass.dispose();
    _ref.dispose();
    super.dispose();
  }

  /// پشکنینی کۆدی بانگهێشت لە کاتی نووسیندا: هاوبەش یان هاوڕێ
  void _checkRef(String v) {
    final code = v.trim().toUpperCase();
    _refTimer?.cancel();
    if (code.length < 4) {
      setState(() {
        _refRes = null;
        _refWait = false;
      });
      return;
    }
    setState(() => _refWait = true);
    _refTimer = Timer(const Duration(milliseconds: 350), () async {
      final r = await context.read<AuthService>().resolveInvite(code);
      if (!mounted || _ref.text.trim().toUpperCase() != code) return;
      setState(() {
        _refRes = r;
        _refWait = false;
      });
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final cloud = context.read<Cloud>();
    final err = await context.read<AuthService>().register(
          name: _name.text,
          phone: _phone.text,
          pass: _pass.text,
          ref: _ref.text,
          city: _city ?? (cloud.cities.isNotEmpty ? cloud.cities.first['id'] as String : 'erbil'),
          gender: _gender,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _err = err;
    });
    if (err == null) {
      toastAfterNav(context, 'ئەکاونتەکەت دروست کرا');
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Widget _refMsg(BuildContext context) {
    final t = context.yk;
    if (_ref.text.trim().length < 4) return const SizedBox.shrink();
    if (_refWait) return Text('پشکنین...', style: Ts.muted(context, size: 12.8));
    final r = _refRes;
    if (r == null) return const SizedBox.shrink();
    Widget ok(String s) => Row(children: [
          YkIcon('check', size: 16, color: t.okText, stroke: 2.6),
          const SizedBox(width: 6),
          Expanded(child: Text(s, style: TextStyle(color: t.okText, fontWeight: FontWeight.w700, fontSize: 14))),
        ]);
    if (r.partner != null) return ok('${r.partner!['name']}');
    if (r.friend != null) {
      final auth = context.read<AuthService>();
      final cloud = context.read<Cloud>();
      final who = (r.friend!['name'] as String?)?.isNotEmpty == true ? r.friend!['name'] : 'هاوڕێکەت';
      final amt = cloud.config['refOn'] == true ? '. ${auth.refText()} داشکاندن لە یەکەم مانگت' : '';
      return ok('بانگهێشتی $who$amt');
    }
    return Text(r.offline ? 'ئینتەرنێت نییە، دواتر دەپشکنرێت' : 'ئەم کۆدە نەدۆزرایەوە', style: TextStyle(color: t.danger, fontSize: 12.8));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final cities = cloud.cities;
    _city ??= cities.isNotEmpty ? cities.first['id'] as String : 'erbil';
    final partner = cloud.partnerByCode(_ref.text);

    return Scaffold(
      body: AutofillGroup(
        child: YkScreen(
          gap: 12,
          children: [
            const YkHeader('ئەکاونتی نوێ', sub: 'تەنها یەک خولەک دەخایەنێت'),
            if (partner != null)
              YkCard(
                tone: CardTone.info,
                child: Row(children: [
                  YkIcon(partner['type'] == 'company' ? 'briefcase' : 'school', size: 22, color: t.infoText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('لە ڕێگەی ${partner['name']}ەوە', style: Ts.bold(context).copyWith(color: t.infoText)),
                      Text('کۆد: ${partner['code']}', style: TextStyle(fontSize: 12.8, color: t.infoText)),
                    ]),
                  ),
                ]),
              ),
            YkField(
              label: 'ناوی تەواو',
              child: TextField(
                controller: _name,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                style: Ts.body(context),
                decoration: ykInput(context, hint: 'ناو و ناوی باوک'),
              ),
            ),
            YkField(label: 'ژمارەی مۆبایل', child: PhoneInput(controller: _phone, textInputAction: TextInputAction.next)),
            YkField(label: 'وشەی نهێنی', child: PasswordInput(controller: _pass, hint: 'لانیکەم ٦ پیت', newPassword: true)),
            YkField(
              label: 'ڕەگەز',
              hint: 'کاتێک لە تەکسییەکی هاوبەشدایت، سەرنشینانی تر تەنها ناوی یەکەم و ڕەگەزت دەبینن',
              child: YkChoice<String>(
                items: const [('m', 'نێر'), ('f', 'مێ')],
                value: _gender.isEmpty ? null : _gender,
                onChanged: (v) => setState(() => _gender = v),
              ),
            ),
            YkField(
              label: 'شار',
              child: YkSelect<String>(
                title: 'شار',
                items: [for (final c in cities) (c['id'] as String, '${c['name']}')],
                value: _city,
                onChanged: (v) => setState(() => _city = v),
              ),
            ),
            YkField(
              label: 'کۆدی بانگهێشت',
              optional: true,
              hint: 'کۆدی هاوڕێ، ناوەندی خوێندن یان شوێنی کار',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _ref,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    textAlign: TextAlign.right,
                    inputFormatters: [_UpperCase()],
                    onChanged: _checkRef,
                    style: TextStyle(fontSize: 16, color: t.text, letterSpacing: 1),
                    decoration: ykInput(context, hint: 'YK7Q4M'),
                  ),
                ),
              ]),
            ),
            _refMsg(context),
            if (_err != null) YkError(_err!),
            YkButton('دروستکردنی ئەکاونت', block: true, busy: _busy, onPressed: _submit),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('بە دروستکردنی ئەکاونت ڕازی دەبیت بە ', style: Ts.muted(context, size: 12.8)),
                YkLink('مەرج و ڕێساکان و پاراستنی زانیاری', size: 12.8, onTap: () => showTerms(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// مەرج و ڕێساکان (TK.showTerms('passenger'))
void showTerms(BuildContext context) {
  final cfg = context.read<Cloud>().config;
  showYkSheet(context, builder: (c) {
    TextSpan item(String head, String body) => TextSpan(children: [
          TextSpan(text: '$head ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: '$body\n'),
        ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('مەرج و ڕێساکان', style: Ts.h2(c)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            item('١. پاراستنی زانیاری:', 'زانیاری کەسی، وێنەی بەڵگەنامەکان و ژمارەی مۆبایل تەنها بۆ پشتڕاستکردنەوە و سەلامەتی گەشتەکان بەکاردێن و بە کەسی تر نادرێن.'),
            item('٢. ژمارەی مۆبایل:', 'ژمارەی سەرنشین تەنها ئەگەر خۆی ڕێگە بدات بۆ شۆفێر دیار دەبێت.'),
            item('٣. سەلامەتی منداڵان:', 'منداڵ هەرگیز لەگەڵ کەسی گەورەی نەناسراو سوار ناکرێت و تەنها شۆفێری پشکنراوی منداڵان گەشتی منداڵان وەردەگرن.'),
            item('٤. سەرنشین:', Fmt.n('«نایەم» تا ${cfg['skipCutoffMin']} خولەک پێش گەشت دەکرێت. ئەگەر شۆفێر نەهات، ڕاپۆرت بکە و قەرەبوو دەکرێیتەوە.')),
            item('٥. پارەدان:', 'نرخی مانگانە پێش دەستپێکردن ڕێک دەکەوێت و لە کاتی گەشتدا ناگۆڕێت.'),
          ]),
          style: Ts.sm(c).copyWith(height: 2),
        ),
        const SizedBox(height: 12),
        YkButton('تێگەیشتم', block: true, onPressed: () => Navigator.pop(c)),
      ],
    );
  });
}
