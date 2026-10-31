// گواستنەوە لە نێوان پەڕەکان (هاوتای data-go و TK.go لە وەشانی وێب)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cloud.dart';
import 'account_screens.dart';
import 'billing_screens.dart';
import 'drivers_screen.dart';
import 'inbox_screen.dart';
import 'new_sub_screen.dart';
import 'news_screen.dart';
import 'notices_screen.dart';
import 'request_screen.dart';
import 'subs_screen.dart';
import 'track_screen.dart';
import 'trips_screen.dart';

/// بەشەکانی شریتی خوارەوە
class ShellTabs {
  static final ValueNotifier<int> index = ValueNotifier(0);
  static const keys = ['home', 'trips', 'subs', 'inbox', 'profile'];
}

void push(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

/// کردنەوەی لینکێکی وەک وەشانی وێب: «subs»، «news/abc»، «rewards»...
void openLink(BuildContext context, String? link) {
  if (link == null || link.isEmpty) return;
  final parts = link.split('/');
  final head = parts.first;
  final id = parts.length > 1 ? parts.sublist(1).join('/') : null;
  final tab = ShellTabs.keys.indexOf(head);
  if (tab >= 0 && id == null) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    ShellTabs.index.value = tab;
    return;
  }
  switch (head) {
    case 'notices':
      return push(context, const NoticesScreen());
    case 'news':
      return push(context, id == null ? const NewsListScreen(kind: 'ad') : NewsDetailScreen(id: id));
    case 'offers':
      return push(context, const NewsListScreen(kind: 'offer'));
    case 'requests':
      return push(context, const RequestsScreen());
    case 'new':
      return startSub(context);
    case 'request':
      return push(context, id == null ? const RequestsScreen() : RequestScreen(id: id));
    case 'drivers':
      return push(context, const DriversScreen());
    case 'driver':
      if (id != null) return push(context, DriverScreen(id: id.split('?').first));
    case 'track':
      if (id != null) return push(context, TrackScreen(id: id));
    case 'wallet':
      return push(context, context.read<Cloud>().walletOn ? const WalletScreen() : const BillingScreen());
    case 'billing':
      return push(context, context.read<Cloud>().walletOn ? const WalletScreen() : const BillingScreen());
    case 'paymonth':
      return push(context, const PayMonthScreen());
    case 'topup':
      return push(context, const TopupScreen());
    case 'txs':
      return push(context, const TxsScreen());
    case 'family':
      return push(context, const FamilyScreen());
    case 'rewards':
      return push(context, const RewardsScreen());
    case 'support':
      return push(context, const SupportScreen());
    case 'faq':
      return push(context, const FaqScreen());
    case 'chat':
      if (id != null) return push(context, ChatScreen(driverId: Uri.decodeComponent(id)));
    case 'history':
      return push(context, id == null ? const HistoryScreen() : HistoryDetailScreen(id: id));
  }
  // پەڕەیەکی نەناسراو: هیچ ناکرێت (بۆ نموونە لینکی کۆنی ئاگادارکردنەوە)
  debugPrint('لینکی نەناسراو: $link');
}
