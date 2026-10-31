// چوارچێوەی سەرەکی ئەپ: پێنج بەش و شریتی خوارەوە
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth.dart';
import '../core/billing.dart';
import '../core/cloud.dart';
import '../core/request_actions.dart';
import '../ui/bottom_nav.dart';
import 'home_screen.dart';
import 'inbox_screen.dart';
import 'nav.dart';
import 'profile_screen.dart';
import 'subs_screen.dart';
import 'trips_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  // گۆڕینی بەش: پەڕە نوێیەکە بە نەرمی دەردەکەوێت (fadeIn ـی وێب: ٠.٢٢ چرکە، ٦ پیکسڵ)
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  int get _tab => ShellTabs.index.value;

  Timer? _tick;

  // nav ی بچووکبووەوە لە کاتی هاتنە خوارەوە (navMini ی وێب)
  bool _mini = false;
  double _acc = 0;

  void _onTab() {
    setState(() {
      _mini = false;
      _acc = 0;
    });
    if (!MediaQuery.of(context).disableAnimations) _enter.forward(from: 0);
  }

  void _setMini(bool v) {
    if (_mini != v) setState(() => _mini = v);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification) return false;
    final dy = n.scrollDelta ?? 0;
    final m = n.metrics;
    if (m.pixels < 24) {
      _acc = 0;
      _setMini(false);
      return false;
    }
    if (m.pixels > m.maxScrollExtent - 4) return false; // لەرینەوەی کۆتایی پەڕە لە iPhone
    _acc = dy.sign == _acc.sign ? _acc + dy : dy;
    if (_acc > 16) {
      _setMini(true);
    } else if (_acc < -16) {
      _setMini(false);
    }
    return false;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _enter.dispose();
    ShellTabs.index.removeListener(_onTab);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ShellTabs.index.value = 0;
    ShellTabs.index.addListener(_onTab);
    // کۆدی بانگهێشتی خۆی و تۆماری ژمارەکەی (بۆ ناردنی پارە) لە پشتەوە
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthService>();
      await context.read<Cloud>().whenReady();
      auth.ensureRefCode();
      auth.ensureDir();
      if (!mounted) return;
      // گەشتەکانی ئەمڕۆ (چوون و هاتنەوە) بۆ هەموو بەشدارییەکان، هەر ١٠ خولەک جارێک دەپشکنرێت
      final cloud = context.read<Cloud>();
      cloud.fixBilling();
      cloud.genTodayTrips();
      _tick = Timer.periodic(const Duration(minutes: 10), (_) => cloud.genTodayTrips());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final me = cloud.me;
    // داواکارییە کراوەکان کە شۆفێر نرخی بۆ ناردوون
    final waiting = cloud
        .list('requests')
        .where((r) =>
            r['owner'] == me &&
            r['status'] == 'open' &&
            ((r['offers'] as List?) ?? const []).any((o) => (o as Map)['status'] == 'pending'))
        .length;
    // نامە نەخوێندراوەکانی شۆفێر
    final unread = cloud.list('messages').where((m) => m['peer'] == me && m['fromDriver'] == true && m['readP'] != true).length;

    final pages = <Widget>[
      const HomeScreen(),
      const TripsScreen(),
      const SubsScreen(),
      const InboxScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: AnimatedBuilder(
          animation: _enter,
          builder: (context, child) {
            final v = Curves.ease.transform(_enter.value);
            return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 6 * (1 - v)), child: child));
          },
          child: IndexedStack(index: _tab, children: pages),
        ),
      ),
      bottomNavigationBar: YkBottomNav(
        index: _tab,
        mini: _mini,
        onTap: (i) => ShellTabs.index.value = i,
        items: [
          const NavItem('home', 'سەرەکی'),
          const NavItem('route', 'گەشتەکان'),
          NavItem('calendar', 'بەشداری', badge: waiting),
          NavItem('chat', 'نامەکان', badge: unread),
          const NavItem('user', 'پرۆفایل'),
        ],
      ),
    );
  }
}
