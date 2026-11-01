// پرۆفایل (هەمان ڕیزبەندی وەشانی وێب). ئەو بەشانەی هێشتا نەنووسراون پەڕەی «بەم زووانە» دەکەنەوە.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth.dart';
import '../core/billing.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/pricing.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yk_icon.dart';
import 'account_screens.dart' show showContactSheet;
import 'nav.dart';
import 'profile_edit_screen.dart';
import 'register_screen.dart' show showTerms;
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.yk;
    final cloud = context.watch<Cloud>();
    final p = cloud.passenger;
    final pax = cloud.pax;
    final me = cloud.me;
    final members = ((pax['family'] as Map?)?['members'] as List?) ?? const [];
    final points = ((pax['rewards'] as Map?)?['points'] as num?) ?? 0;
    final subs = cloud.list('subscriptions').where((x) => x['owner'] == me).length;
    final history = cloud.list('phistory').where((x) => x['owner'] == me).length;
    final acc = cloud.account ?? const {};
    final home = cloud.place(p['homeId']);
    Map<String, dynamic>? partner;
    for (final x in cloud.partners) {
      if (x['id'] == acc['partnerId']) partner = x;
    }

    void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return YkScreen(
      withNav: true,
      title: tr('پرۆفایل'),
      children: [
        Text(tr('پرۆفایل'), style: Ts.h1(context)),
        YkCard(
          child: Row(children: [
            GestureDetector(
              onTap: () => pickMyPhoto(context),
              child: Stack(clipBehavior: Clip.none, children: [
              PersonAvatar(size: 64, imageId: p['photo'] as String?),
              Positioned(
                bottom: -2,
                left: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.act, border: Border.all(color: t.card, width: 2)),
                  alignment: Alignment.center,
                  child: YkIcon('camera', size: 13, color: t.actText, stroke: 2.2),
                ),
              ),
            ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['name'] ?? ''}', style: Ts.h3(context)),
                Text(Fmt.phone('${p['phone'] ?? ''}'), textDirection: TextDirection.ltr, style: Ts.muted(context, size: 14)),
                if (home != null)
                  Row(children: [
                    YkIcon('home', size: 12, color: t.muted),
                    const SizedBox(width: 4),
                    Flexible(child: Text(trData(home['name']), style: Ts.muted(context, size: 12.8))),
                  ]),
              ]),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: t.glass, shape: BoxShape.circle, border: Border.all(color: t.glassLine)),
              child: IconButton(
                tooltip: tr('دەستکاری'),
                padding: EdgeInsets.zero,
                onPressed: () => go(const ProfileEditScreen()),
                icon: YkIcon('edit', size: 18, color: t.text),
              ),
            ),
          ]),
        ),
        PLabel(tr('هەژمارەکەم')),
        YkList(children: [
          YkListItem(
            icon: 'wallet',
            label: cloud.walletOn ? tr('جزدانەکەم') : tr('پارەدان و فاتورە'),
            trailing: cloud.walletOn
                // باڵانس، و ئەگەر پارەی ئەم مانگە ماوە «پارەی مانگ»
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    CountPill(Fmt.money(cloud.freeBalance)),
                    if (cloud.dueLines().isNotEmpty) ...[const SizedBox(width: 6), YkBadge(tr('پارەی مانگ'), tone: BadgeTone.note)],
                  ])
                : (cloud.billing['paid'] != true && cloud.invoice().total > 0 ? YkBadge(tr('ئامادەیە'), tone: BadgeTone.note) : null),
            onTap: () => openLink(context, 'wallet'),
          ),
          YkListItem(icon: 'tag', label: tr('ئۆفەرەکان'), onTap: () => openLink(context, 'offers')),
          YkListItem(
            icon: 'gift',
            label: tr('پاداشت'),
            trailing: points > 0 ? CountPill(Fmt.n(tr('{0} خاڵ', [points]))) : null,
            onTap: () => openLink(context, 'rewards'),
          ),
          YkListItem(
            icon: 'users',
            label: tr('خێزان'),
            trailing: members.length > 1 ? CountPill(Fmt.n(members.length)) : null,
            onTap: () => openLink(context, 'family'),
          ),
          YkListItem(
            icon: 'calendar',
            label: tr('بەشدارییەکانم'),
            trailing: subs > 0 ? CountPill(Fmt.n(subs)) : null,
            onTap: () => openLink(context, 'subs'),
          ),
          YkListItem(icon: 'megaphone', label: tr('داواکارییەکانم'), onTap: () => openLink(context, 'requests')),
          YkListItem(
            icon: 'clock',
            label: tr('گەشتە کۆنەکان'),
            trailing: history > 0 ? CountPill(Fmt.n(history)) : null,
            onTap: () => openLink(context, 'history'),
          ),
        ]),
        PLabel(tr('ڕێکخستن و یارمەتی')),
        YkList(children: [
          YkListItem(icon: 'settings', label: tr('ڕێکخستنەکان'), onTap: () => go(const SettingsScreen())),
          YkListItem(icon: 'help', label: tr('پرسیارە باوەکان'), onTap: () => openLink(context, 'faq')),
          YkListItem(icon: 'flag', label: tr('یارمەتی و سکاڵاکان'), onTap: () => openLink(context, 'support')),
          YkListItem(icon: 'phone', label: tr('پەیوەندی'), onTap: () => showContactSheet(context)),
          YkListItem(icon: 'doc', label: tr('مەرج و ڕێساکان'), onTap: () => showTerms(context)),
          if (partner != null)
            YkListItem(
              icon: partner['type'] == 'company' ? 'briefcase' : 'school',
              label: '${partner['name']}',
              sub: tr('لە ڕێگەی ئەم شوێنەوە تۆمار بوویت'),
            )
          else
            YkListItem(icon: 'school', label: tr('کۆدی قوتابخانە یان کۆمپانیا'), onTap: () => _partnerCode(context)),
        ]),
        // ٢٠ پیکسڵ دوورتر لە کارتەکەی سەرەوە، تا بە هەڵە پەنجەی بەر نەکەوێت
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: YkButton(tr('چوونەدەرەوە'), icon: 'logout', kind: BtnKind.secondary, block: true, onPressed: () => context.read<AuthService>().logout()),
        ),
        Text(Fmt.n(tr('یەکسا، وەشانی 1٫0')), textAlign: TextAlign.center, style: Ts.muted(context, size: 12.8)),
      ],
    );
  }

  /// کۆدی قوتابخانە یان کۆمپانیا (تەنها یەک جار)
  void _partnerCode(BuildContext context) {
    final ctrl = TextEditingController();
    String? err;
    showYkSheet(context, builder: (c) {
      return StatefulBuilder(builder: (c, setS) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('کۆدی قوتابخانە یان کۆمپانیا'), style: Ts.h2(c)),
          const SizedBox(height: 6),
          Text(tr('ئەو کۆدەی قوتابخانە، زانکۆ یان کۆمپانیاکەت پێیداویت بنووسە. تەنها یەک جار دەنووسرێت.'), style: Ts.muted(c, size: 14)),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.right,
              decoration: ykInput(c, hint: 'CODE'),
            ),
          ),
          if (err != null) ...[const SizedBox(height: 8), YkError(err!)],
          const SizedBox(height: 12),
          YkButton(tr('تۆمارکردن'), block: true, onPressed: () async {
            final cloud = c.read<Cloud>();
            final pt = cloud.partnerByCode(ctrl.text);
            final acc = cloud.account;
            String? e;
            if (pt == null) {
              e = tr('ئەم کۆدە دروست نییە');
            } else if (acc == null) {
              e = tr('ئەکاونت نەدۆزرایەوە');
            } else if (acc['partnerId'] != null) {
              e = tr('پێشتر کۆدێکت تۆمار کردووە');
            }
            if (e != null || pt == null) {
              setS(() => err = e);
              return;
            }
            await cloud.update('accounts/${cloud.me}', {'partnerId': pt['id']});
            if (c.mounted) {
              Navigator.pop(c);
              toast(context, tr('کۆدەکە تۆمار کرا'));
            }
          }),
          const SizedBox(height: 8),
          YkButton(tr('داخستن'), kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
        ]);
      });
    });
  }
}
