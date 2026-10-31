// زانیاری پرۆفایل: وێنە، ناو، شار، گەڕەکی ماڵ، ڕەگەز، وشەی نهێنی، سڕینەوەی هەژمار
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/account.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/images.dart';
import '../core/pricing.dart';
import '../core/sel.dart';
import '../ui/form_parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'request_screen.dart' show askConfirm;
import 'settings_screen.dart' show changePasswordSheet;

/// هەڵبژاردنی وێنەی پرۆفایل (بچووک دەکرێتەوە بۆ ١٠٠٠ پیکسڵ، JPEG)
Future<void> pickMyPhoto(BuildContext context) async {
  final cloud = context.read<Cloud>();
  final store = context.read<ImageStore>();
  try {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, maxHeight: 1000, imageQuality: 72);
    if (f == null) return;
    if (context.mounted) toast(context, 'وێنەکە ئامادە دەکرێت...');
    final bytes = await f.readAsBytes();
    // data URL ـی base64 ≈ ١.٣٣ × قەبارە؛ بەڵگەنامەی Firestore لە ١ مێگابایت زیاتر نابێت (وێب: ٧٠٠٬٠٠٠ پیت)
    if (bytes.length > 500 * 1024) {
      if (context.mounted) toast(context, 'وێنەکە زۆر گەورەیە. وێنەیەکی بچووکتر هەڵبژێرە');
      return;
    }
    final old = cloud.passenger['photo'] as String?;
    final id = await store.save(bytes);
    await cloud.setMyPhoto(id);
    if (old != null && old != id) await store.remove(old);
    if (context.mounted) toast(context, 'وێنەکەت دانرا');
  } catch (_) {
    if (context.mounted) toast(context, 'ئەم وێنەیە ناخوێندرێتەوە. وێنەیەکی تر هەڵبژێرە');
  }
}

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late String _city, _home, _gender;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<Cloud>().passenger;
    _name = TextEditingController(text: str(p['name']));
    _city = str(p['city']).isEmpty ? 'erbil' : str(p['city']);
    _home = str(p['homeId']);
    _gender = str(p['gender']);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      toast(context, 'ناوەکە بنووسە');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<Cloud>().updateProfile(name, _home, _city, _gender);
      if (!mounted) return;
      toast(context, 'پاشەکەوت کرا');
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) toast(context, 'هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final p = cloud.passenger;
    final photo = p['photo'] as String?;
    final homes = cloud.places.where((x) => x['kind'] == 'home').toList();
    Widget gbtn(String v, String l) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _gender = _gender == v ? '' : v),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: _gender == v ? t.silver : t.card,
                borderRadius: BorderRadius.circular(Yk.rMd),
                border: Border.all(color: _gender == v ? t.act : t.line, width: 1.5),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                YkCheck(_gender == v, radio: true),
                const SizedBox(width: 8),
                Text(l, style: Ts.bold(context)),
              ]),
            ),
          ),
        );
    return Scaffold(
      body: YkScreen(children: [
        const YkHeader('زانیاری پرۆفایل'),
        Center(
          child: GestureDetector(
            onTap: () => pickMyPhoto(context),
            child: Stack(clipBehavior: Clip.none, children: [
              PersonAvatar(size: 112, imageId: photo),
              Positioned(
                bottom: 2,
                left: 2,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.act, border: Border.all(color: t.bg, width: 3)),
                  alignment: Alignment.center,
                  child: YkIcon('camera', size: 18, color: t.actText, stroke: 2.2),
                ),
              ),
            ]),
          ),
        ),
        if (photo != null)
          Center(
            child: YkLink('لابردنی وێنە', onTap: () async {
              if (!await askConfirm(context, 'وێنەی پرۆفایلەکەت لادەبرێت؟', yes: 'لابردن')) return;
              if (!context.mounted) return;
              final store = context.read<ImageStore>();
              await cloud.setMyPhoto(null);
              await store.remove(photo);
            }),
          ),
        YkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            YkField(label: 'ناوی تەواو', child: TextField(controller: _name, autofillHints: const [AutofillHints.name], decoration: ykInput(context))),
            const SizedBox(height: 12),
            YkField(
              label: 'ژمارەی مۆبایل',
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: t.chip, borderRadius: BorderRadius.circular(Yk.rMd), border: Border.all(color: t.line, width: 1.5)),
                child: Row(children: [
                  Expanded(child: Text(Fmt.phone(str(p['phone'])), textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: TextStyle(color: t.muted, fontSize: 16))),
                  const SizedBox(width: 8),
                  YkIcon('lock', size: 16, color: t.muted),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            YkField(
              label: 'شار',
              child: YkSelect<String>(
                title: 'شار',
                items: [for (final c in cloud.cities) (str(c['id']), str(c['name']))],
                value: _city,
                onChanged: (v) => setState(() => _city = v),
              ),
            ),
            const SizedBox(height: 12),
            YkField(
              label: 'گەڕەکی ماڵ',
              child: YkSelect<String>(
                title: 'گەڕەکی ماڵ',
                items: [for (final x in homes) (str(x['id']), '${str(x['name'])}، ${str(cloud.city(str(x['city']))?['name'])}')],
                value: _home.isEmpty ? null : _home,
                onChanged: (v) => setState(() => _home = v),
              ),
            ),
            const SizedBox(height: 12),
            YkField(label: 'ڕەگەز', child: Row(children: [gbtn('m', 'نێر'), const SizedBox(width: 10), gbtn('f', 'مێ')])),
          ]),
        ),
        YkList(children: [
          YkListItem(icon: 'lock', label: 'گۆڕینی وشەی نهێنی', onTap: () => changePasswordSheet(context)),
        ]),
        YkButton('پاشەکەوت', block: true, busy: _busy, onPressed: _save),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => _deleteAccount(context),
            icon: YkIcon('trash', size: 17, color: t.dangerText),
            label: Text('سڕینەوەی هەژمار', style: TextStyle(color: t.dangerText, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  void _deleteAccount(BuildContext context) {
    final cloud = context.read<Cloud>();
    final pass = TextEditingController();
    String? err;
    var busy = false;
    final subs = cloud.mySubs.length;
    showYkSheet(context, builder: (c) {
      return StatefulBuilder(builder: (c, setS) {
        final t = c.yk;
        Text line(String s) => Text(s, style: const TextStyle(fontSize: 14, height: 1.9));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IcoBox('alert', size: 46, iconSize: 22, bg: t.dangerBg, color: t.dangerText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('سڕینەوەی هەژمار', style: Ts.h2(c)),
                Text('ئەمە ناگەڕێتەوە.', style: Ts.muted(c, size: 14)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(Yk.rMd), border: Border.all(color: t.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ئەمانە دەسڕێنەوە:', style: TextStyle(fontWeight: FontWeight.w700)),
              line('• ناو، ژمارەی مۆبایل و ئەندامانی خێزان'),
              line('• شوێنەکانی سەر نەخشە، ئاگادارکردنەوەکان و مێژووی گەشتەکانت'),
              if (subs > 0) line(Fmt.n('• $subs بەشداری هەڵدەوەشێتەوە و شۆفێرەکە ئاگادار دەکرێتەوە')),
              const SizedBox(height: 6),
              const Text('ئەمانە بێ ناو دەمێننەوە:', style: TextStyle(fontWeight: FontWeight.w700)),
              line('• گەشتە کراوەکان و نامەکان، بۆ حیسابی شۆفێر و چارەسەرکردنی سکاڵا'),
            ]),
          ),
          const SizedBox(height: 12),
          YkField(label: 'وشەی نهێنی بۆ پشتڕاستکردنەوە', child: PasswordInput(controller: pass)),
          if (err != null) ...[const SizedBox(height: 8), YkError(err!)],
          const SizedBox(height: 14),
          Material(
            color: t.danger,
            borderRadius: BorderRadius.circular(Yk.rMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(Yk.rMd),
              onTap: busy
                  ? null
                  : () async {
                      if (pass.text.isEmpty) {
                        setS(() => err = 'وشەی نهێنی بنووسە');
                        return;
                      }
                      setS(() {
                        busy = true;
                        err = null;
                      });
                      final e = await cloud.deleteMyAccount(pass.text);
                      if (e != null) {
                        if (c.mounted) {
                          setS(() {
                            busy = false;
                            err = e;
                          });
                        }
                        return;
                      }
                      if (c.mounted) Navigator.of(c).popUntil((r) => r.isFirst);
                    },
              child: SizedBox(
                height: 50,
                child: Center(
                  child: busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Text('سڕینەوەی هەمیشەیی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          YkButton('پاشگەزبوونەوە', kind: BtnKind.ghost, block: true, onPressed: busy ? null : () => Navigator.pop(c)),
        ]);
      });
    });
  }
}
