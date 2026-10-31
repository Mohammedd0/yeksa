// فاتورە، پارەدان و جزدان (TK.invoice، recordPayment، payMonthIn، balance، requestTopup، requestWithdraw، sendMoney ـی core.js)
import 'dart:collection'; // firstOrNull / lastOrNull
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'actions.dart';
import 'cloud.dart';
import 'format.dart';
import 'pricing.dart';
import 'request_actions.dart';
import 'sel.dart';
import 'trips.dart';

/// شێوازە بنەڕەتییەکانی پارەدان (بەڕێوەبەر دەتوانێت بیانگۆڕێت)
const kPayMethodsDefault = [
  {'id': 'fib', 'name': 'FIB', 'on': true, 'account': true, 'topup': true, 'yeksaAccount': '', 'holder': ''},
  {'id': 'fastpay', 'name': 'FastPay', 'on': true, 'account': true, 'topup': true, 'yeksaAccount': '', 'holder': ''},
  {'id': 'cash', 'name': 'کاش', 'on': true, 'account': false, 'topup': true},
];

String safeId(Object? x) => '$x'.replaceAll(RegExp(r'[^\w-]'), '_');

String monthOf(String? day) => (day ?? Fmt.todayIso()).substring(0, 7);

class InvLine {
  InvLine({required this.subId, required this.label, required this.note, required this.full, required this.amount, this.legs = 0, this.factor = 1});
  final String subId, label, note;
  final num full;
  final int amount;
  final int legs;
  final double factor;
  Json toJson() => {'subId': subId, 'label': label, 'note': note, 'full': full, 'amount': amount};
}

class Disc {
  Disc(this.kind, this.id, this.label, this.amount);
  final String kind; // refIn | refOut | reward
  final Object? id;
  final String label;
  final int amount;
}

class Invoice {
  Invoice({
    required this.lines,
    required this.sub,
    required this.promo,
    required this.discounts,
    required this.waiting,
    required this.disc,
    required this.credit,
    required this.adjustments,
    required this.total,
  });
  final List<InvLine> lines;
  final int sub, promo, disc, credit, total;
  final List<Disc> discounts, waiting;
  final List<Json> adjustments;
}

({int start, int end, int days}) monthBounds() {
  final d = DateTime.now();
  final start = DateTime(d.year, d.month, 1);
  final end = DateTime(d.year, d.month + 1, 1);
  // وەک Math.round ـی وێب (inDays لە کاتی گۆڕینی کاتژمێری هاوین ڕۆژێک کەم دەکاتەوە)
  return (start: start.millisecondsSinceEpoch, end: end.millisecondsSinceEpoch, days: (end.difference(start).inMinutes / 1440).round());
}

/// چەند ڕۆژی ئەم مانگە بەشدارییەک ڕاگیراوە
int pausedDays(Json sub) {
  final mb = monthBounds();
  var ms = 0;
  final log = asList(sub['pauseLog']).map(asMap).toList();
  for (final p in log) {
    final a = math.max(mb.start, ((p['from'] as num?) ?? 0).toInt());
    final b = math.min(mb.end, ((p['to'] as num?) ?? mb.end).toInt());
    if (b > a) ms += b - a;
  }
  final any = log.any((p) => ((p['to'] as num?) ?? nowMs()) > mb.start);
  return any ? math.max(1, (ms / 86400000).ceil()) : 0;
}

/// بڕی ئەم مانگەی بەشدارییەک (بە پێی ڕۆژی دەستپێکردن و ڕۆژە ڕاگیراوەکان). null ئەگەر هێشتا دەستی پێنەکردبێت
({double factor, List<String> notes, int amount})? monthShare(Json x) {
  final mb = monthBounds();
  var factor = 1.0;
  final notes = <String>[];
  final sd = str(x['startDate']);
  if (sd.length >= 10) {
    final p = sd.split('-').map(int.parse).toList();
    final st = DateTime(p[0], p[1], p[2]).millisecondsSinceEpoch;
    if (st >= mb.end) return null;
    if (st > mb.start) {
      factor = (mb.days - p[2] + 1) / mb.days;
      notes.add(Fmt.n('لە ${p[2]}ی مانگەوە'));
    }
  }
  final pd = pausedDays(x);
  if (pd > 0) {
    factor = math.max(0.0, factor - pd / mb.days);
    notes.add(Fmt.n('$pd ڕۆژ ڕاگیراو'));
  }
  return (factor: factor, notes: notes, amount: (((x['price'] as num?) ?? 0) * factor / 1000).round() * 1000);
}

/// ژمارەی گەشتەکانی (چوون و هاتنەوە جیا) بەشدارییەک لە مانگێکدا، لە ڕۆژی from ـەوە
int legsInMonth(Json sub, String mk, String? from, {bool ignoreStart = false, bool skipPast = false}) {
  final p = mk.split('-').map(int.parse).toList();
  final last = DateTime(p[0], p[1] + 1, 0).day;
  final x = ignoreStart ? {...sub, 'startDate': null} : sub;
  final now = DateTime.now();
  final hhmm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final today = Fmt.todayIso();
  var n = 0;
  for (var d = 1; d <= last; d++) {
    final dt = DateTime(p[0], p[1], d);
    final day = Fmt.todayIso(dt);
    if (from != null && day.compareTo(from) < 0) continue;
    if (!dayApplies(x, dt)) continue;
    for (final dir in const ['go', 'back']) {
      final t = dayTime(x, dir, dt);
      // گەشتی ئەمڕۆ کە کاتەکەی تێپەڕیوە حیساب ناکرێت
      if (t != null && !(skipPast && day == today && t.compareTo(hhmm) <= 0)) n++;
    }
  }
  return n;
}

extension YkBilling on Cloud {
  Json get billing => asMap(pax['billing']);

  List<Json> get payMethods {
    final l = meta['payMethods'];
    return (l is List && l.isNotEmpty ? l : kPayMethodsDefault).map(asMap).toList();
  }

  Json? payMethod(Object? id) => payMethods.where((m) => m['id'] == id).firstOrNull;

  String payName(Object? id) => str(payMethod(id)?['name']).isNotEmpty ? str(payMethod(id)!['name']) : (str(id).isEmpty ? '-' : str(id));

  int pointsFor(num total) => ((total / 1000) * ((config['pointsPer1000'] as num?) ?? 0)).floor();

  /* ---------------- کۆمیسیۆن ---------------- */

  ({String type, num pct, num fixed}) commissionRule([String? mk]) {
    mk ??= Fmt.monthKey();
    final n = config['commissionNext'];
    if (n is Map && n['from'] != null && mk.compareTo(str(n['from'])) >= 0) {
      return (type: str(n['type']), pct: (n['pct'] as num?) ?? 0, fixed: (n['fixed'] as num?) ?? 0);
    }
    return (type: str(config['commissionType']).isEmpty ? 'pct' : str(config['commissionType']), pct: (config['commission'] as num?) ?? 0, fixed: (config['commissionFixed'] as num?) ?? 0);
  }

  double riderWeight(Json x) {
    final n = math.max(1, ((x['riders'] as num?) ?? asList(x['memberIds']).length).toInt());
    if (x['mode'] == 'separate' || n == 1) return 1;
    return (1 + ((config['extraRiderFactor'] as num?) ?? 0) * (n - 1)).toDouble();
  }

  int feeFor(Json x, int amount, double factor) {
    final rule = commissionRule();
    if (rule.type == 'fixed') return math.min(amount, ((rule.fixed * riderWeight(x) * factor) / 250).round() * 250);
    return (amount * rule.pct).round();
  }

  /* ---------------- جزدان ---------------- */

  /// دێڕە پارەدانی مانگ (monthpay / legacy) بۆ بەشدارییەک لە مانگێکدا
  Json? payRec(Json sub, [String? mk]) {
    mk ??= Fmt.monthKey();
    for (final e in list('wallet')) {
      if ((e['type'] == 'monthpay' || e['type'] == 'legacy') && e['month'] == mk) {
        for (final l in asList(e['lines']).map(asMap)) {
          if (l['subId'] == sub['id']) return {...l, 'ref': e['id'], 'legacy': e['type'] == 'legacy'};
        }
      }
    }
    return null;
  }

  bool subPaid(Json sub, [String? mk]) => payRec(sub, mk) != null;

  /// دێڕەکانی جزدانم. ناردنێک کە بۆم هاتووە وەک دێڕی هاتوو (بڕی پۆزەتیڤ)
  List<Json> get myWallet {
    final out = <Json>[];
    for (final e in list('wallet')) {
      if (e['who'] == me) {
        out.add(e);
      } else if (e['type'] == 'xfer' && e['to'] == me) {
        out.add({...e, 'amount': -((e['amount'] as num?) ?? 0), 'incoming': true});
      }
    }
    out.sort((a, b) => ((b['at'] as num?) ?? 0).compareTo((a['at'] as num?) ?? 0));
    return out;
  }

  int get balance => list('wallet').fold<num>(0, (n, e) {
        if (e['who'] == me) return n + ((e['amount'] as num?) ?? 0);
        if (e['type'] == 'xfer' && e['to'] == me) return n - ((e['amount'] as num?) ?? 0);
        return n;
      }).toInt();

  int get pendingWithdraw => list('withdraws').where((w) => w['driverId'] == me && w['status'] == 'pending').fold<num>(0, (n, w) => n + ((w['amount'] as num?) ?? 0)).toInt();

  int get freeBalance => balance - pendingWithdraw;

  List<Json> get myTopupsPending => list('topups').where((x) => x['owner'] == me && x['status'] == 'pending').toList();

  List<Json> get myWithdrawsPending => list('withdraws').where((w) => w['driverId'] == me && w['status'] == 'pending').toList();

  /* ---------------- فاتورە ---------------- */

  /// ئەو بەشدارییانەی پارەی ئەم مانگەیان نەدراوە: بڕ لە ئەمڕۆوە تا کۆتایی مانگ
  /// [mk] مانگێکی تر (بۆ نموونە مانگی داهاتوو بۆ پارەدانی پێشوەختە)، [only] تەنها ئەم بەشدارییانە
  List<InvLine> dueLines({String? mk, Set<String>? only}) {
    final cur = Fmt.monthKey();
    mk ??= cur;
    // مانگی ئێستا لە ئەمڕۆوە، مانگی داهاتوو لە یەکەم ڕۆژیەوە
    final from = mk == cur ? Fmt.todayIso() : '$mk-01';
    final out = <InvLine>[];
    for (final x in mySubs.where((x) => x['status'] == 'active' && !subPaid(x, mk) && (only == null || only.contains(str(x['id']))))) {
      final full = legsInMonth(x, mk, null, ignoreStart: true);
      final sd = str(x['startDate']);
      final legs = legsInMonth(x, mk, sd.isNotEmpty && sd.compareTo(from) > 0 ? sd : from, skipPast: true);
      if (full == 0 || legs == 0) continue;
      final factor = legs / full;
      final amount = ((((x['price'] as num?) ?? 0) * factor) / 250).round() * 250;
      final d = driver(x['driverId']) ?? const {};
      out.add(InvLine(
        subId: str(x['id']),
        label: '${x['riderNames']}، ${str(d['name'])}',
        note: legs < full ? Fmt.n('$legs گەشتی ماوەی ئەم مانگە') : '',
        full: (x['price'] as num?) ?? 0,
        amount: amount,
        legs: legs,
        factor: factor,
      ));
    }
    return out;
  }

  /// فاتورەی ئەم مانگە. due = تەنها ئەوانەی پارەیان نەدراوە (جزدان)
  Invoice invoice({bool due = false, String? mk, Set<String>? only}) {
    final mb = monthBounds();
    final otherMonth = mk != null && mk != Fmt.monthKey();
    final lines = due
        ? dueLines(mk: mk, only: only)
        : mySubs
            .map((x) {
              final sh = monthShare(x);
              if (sh == null) return null;
              final d = driver(x['driverId']) ?? const {};
              return InvLine(subId: str(x['id']), label: '${x['riderNames']}، ${str(d['name'])}', note: sh.notes.join('، '), full: (x['price'] as num?) ?? 0, amount: sh.amount, factor: sh.factor);
            })
            .whereType<InvLine>()
            .toList();
    final sub = lines.fold<int>(0, (n, l) => n + l.amount);
    final b = billing;
    final pr = asMap(b['promo']);
    // کۆدی داشکاندنی هاوبەش تەنها بۆ فاتورەی مانگی ئێستایە
    final promo = pr.isNotEmpty && !otherMonth ? ((sub * ((pr['rate'] as num?) ?? 0)) / 1000).round() * 1000 : 0;
    // داشکاندنەکان: تەنها ئەوەی بە تەواوی جێی دەبێتەوە، ئەوانی تر بۆ مانگی داهاتوو دەمێننەوە
    final discounts = <Disc>[];
    final waiting = <Disc>[];
    var room = math.max(0, sub - promo);
    void take(Disc d) {
      if (d.amount > 0 && d.amount <= room) {
        room -= d.amount;
        discounts.add(d);
      } else if (d.amount > 0) {
        waiting.add(d);
      }
    }

    final invMk = mk ?? Fmt.monthKey();
    final asInv = refAsInvitee;
    if (asInv != null &&
        asInv['status'] == 'subscribed' &&
        asInv['inviteeUsedAt'] == null &&
        (asInv['month'] == null || str(asInv['month']).compareTo(invMk) <= 0) &&
        lines.any((l) => l.subId == asInv['subId'])) {
      take(Disc('refIn', asInv['id'] ?? me, 'داشکاندنی بانگهێشتی هاوڕێ، یەکەم مانگ', ((asInv['amount'] as num?) ?? 0).toInt()));
    }
    for (final r in list('referrals').where((r) => r['inviter'] == me && r['status'] == 'subscribed' && r['inviterUsedAt'] == null)) {
      take(Disc('refOut', r['id'] ?? r['invitee'], 'داشکاندنی بانگهێشت، ${str(r['inviteeName']).isEmpty ? 'هاوڕێ' : r['inviteeName']}', ((r['amount'] as num?) ?? 0).toInt()));
    }
    for (final p in asList(asMap(pax['rewards'])['pending']).map(asMap)) {
      final amount = p['kind'] == 'days' ? (((sub / mb.days) * ((p['amount'] as num?) ?? 0)) / 250).round() * 250 : ((p['amount'] as num?) ?? 0).toInt();
      take(Disc('reward', p['id'], 'پاداشت، ${p['title']}', amount));
    }
    final disc = discounts.fold<int>(0, (n, d) => n + d.amount);
    final adjustments = asList(b['adjustments']).map(asMap).toList();
    final adj = due ? 0 : adjustments.fold<num>(0, (n, a) => n + ((a['amount'] as num?) ?? 0)).toInt();
    final credit = math.min(adj, math.max(0, sub - promo - disc));
    return Invoice(
      lines: lines,
      sub: sub,
      promo: promo,
      discounts: discounts,
      waiting: waiting,
      disc: disc,
      credit: credit,
      adjustments: adjustments,
      total: math.max(0, sub - promo - disc - credit),
    );
  }

  /* ---------------- کردارەکان ---------------- */

  /// فاتورەی مانگی نوێ (یەک جار لە سەرەتای هەر مانگێک)
  Future<void> fixBilling() async {
    final b = billing;
    final mk = Fmt.monthKey();
    if (me == null || b.isEmpty) return;
    if (b['monthKey'] != mk) {
      await update('pax/$me', {
        'billing.monthKey': mk,
        'billing.month': kMonths[DateTime.now().month - 1],
        'billing.paid': false,
        'billing.promo': null,
      });
    }
    // جزدان: یەک جار لە مانگێکدا ئاگادار دەکرێتەوە کە پارەی مانگ ئامادە بکات (reconcilePassenger ـی core.js)
    if (walletOn && b['dueNotice'] != mk && dueLines().isNotEmpty) {
      final inv = invoice(due: true);
      try {
        await update('pax/$me', {'billing.dueNotice': mk});
        await addNotice(me!, {'kind': 'pay', 'title': 'پارەی مانگ ئامادە بکە', 'body': '${Fmt.money(inv.total)}، گەشتەکان دوای پارەدان دەست پێدەکەن', 'link': 'wallet'});
      } catch (_) {}
    }
  }

  Future<void> setPayMethod(String m) => update('pax/$me', {'billing.method': m});

  /// کۆدی داشکاندن: تەنها ئەو کۆدانەی بەڕێوەبەر لە هەواڵێکی چالاکدا داینابێت
  Future<String?> applyPromo(String code) async {
    final c = code.trim().toUpperCase();
    final n = list('news').where((x) => x['hidden'] != true && str(x['code']).isNotEmpty && str(x['code']).toUpperCase() == c).firstOrNull;
    if (n == null) return 'ئەم کۆدە دروست نییە';
    if (asMap(billing['promo']).isNotEmpty) return 'کۆدێکی داشکاندن پێشتر بەکارهاتووە';
    await update('pax/$me', {
      'billing.promo': {'code': c, 'rate': (((n['rate'] as num?) ?? 10)) / 100},
    });
    return null;
  }

  /// هاوبەشی قوتابخانە یان کۆمپانیا (ڕێژەیەک لە پارەدان)
  Future<void> _partnerEarn(int paid) async {
    final acc = account;
    if (acc == null || acc['partnerId'] == null || paid <= 0) return;
    final pt = partners.where((x) => x['id'] == acc['partnerId']).firstOrNull;
    if (pt == null || pt['status'] != 'active') return;
    final months = (pt['months'] as num?) ?? 0;
    final created = (acc['createdAt'] as num?) ?? 0;
    if (months > 0 && created > 0 && nowMs() - created > months * 30.5 * 24 * 3600000) return;
    final id = 'pe${shortId()}';
    final pct = (pt['pct'] as num?) ?? 0;
    try {
      await set('partnerEarnings/$id', {
        'id': id,
        'partnerId': pt['id'],
        'phone': passenger['phone'],
        'name': passenger['name'],
        'month': billing['month'],
        'paid': paid,
        'pct': pct,
        'amount': (paid * pct / 100).round(),
        'at': nowMs(),
        'settled': null,
        '_t': newStamp(),
      });
    } catch (_) {}
  }

  /// تۆمارکردنی پارەدانی مانگ: مێژوو، هاوبەش، داشکاندنە بەکارهاتووەکان، خاڵ
  Future<int> _recordPayment(Invoice inv, String method, {String? monthLabel, bool markPaid = true}) async {
    final pts = pointsFor(inv.total);
    final now = nowMs();
    final b = billing;
    final up = <String, dynamic>{
      if (markPaid) 'billing.paid': true,
      'billing.history': [
        {
          'month': monthLabel ?? b['month'],
          'total': inv.total,
          'at': now,
          'method': method,
          'lines': inv.lines.map((l) => l.toJson()).toList(),
          'promo': inv.promo,
          'disc': inv.disc,
          'discounts': inv.discounts.map((d) => {'label': d.label, 'amount': d.amount}).toList(),
          'credit': inv.credit,
          'name': passenger['name'],
        },
        ...asList(b['history']),
      ],
    };
    // قەرەبووەکان بەکارهاتن؛ ئەگەر لە فاتورەکە زیاتر بوون، ماوەکە بۆ مانگی داهاتوو دەمێنێتەوە
    if (!walletOn) {
      final adj = inv.adjustments.fold<num>(0, (n, a) => n + ((a['amount'] as num?) ?? 0));
      final rest = adj - inv.credit;
      up['billing.adjustments'] = rest > 0
          ? [
              {'id': 'adj${shortId()}', 'amount': rest, 'note': 'ماوەی قەرەبوو', 'at': now},
            ]
          : [];
    }
    final r = asMap(pax['rewards']);
    var pending = asList(r['pending']).map(asMap).toList();
    var used = asList(r['used']).map(asMap).toList();
    for (final d in inv.discounts) {
      try {
        if (d.kind == 'refIn') await update('referrals/$me', {'inviteeUsedAt': now});
        if (d.kind == 'refOut') {
          final ref = list('referrals').where((x) => (x['id'] ?? x['invitee']) == d.id).firstOrNull;
          if (ref != null) await update('referrals/${ref['invitee']}', {'inviterUsedAt': now});
        }
      } catch (_) {}
      if (d.kind == 'reward') {
        final p = pending.where((x) => x['id'] == d.id).firstOrNull;
        pending = pending.where((x) => x['id'] != d.id).toList();
        if (p != null) used = [{...p, 'value': d.amount, 'usedAt': now}, ...used].take(30).toList();
      }
    }
    up['rewards.pending'] = pending;
    up['rewards.used'] = used;
    if (pts > 0) up['rewards.points'] = FieldValue.increment(pts);
    await update('pax/$me', up);
    await _partnerEarn(inv.total);
    return pts;
  }

  /// پارەدانی فاتورە (بێ جزدان). یەکسا دواتر دەیپشکنێت
  Future<int> pay() async {
    final inv = invoice();
    final pts = await _recordPayment(inv, str(billing['method']).isEmpty ? 'cash' : str(billing['method']));
    await addNotice(me!, {'kind': 'pay', 'title': 'پارەدان تۆمار کرا', 'body': '${Fmt.money(inv.total)}${pts > 0 ? '، $pts خاڵی پاداشت زیاد کرا' : ''}'});
    return pts;
  }

  /// پارەدانی مانگ لە جزدان. هەڵە یان null
  /// [mk] مانگێکی تر (پێشوەختە)، [only] تەنها ئەم بەشدارییانە
  Future<String?> payMonth({String? mk, Set<String>? only}) async {
    final inv = invoice(due: true, mk: mk, only: only);
    if (inv.lines.isEmpty) return 'هیچ پارەیەکی ئەم مانگە نەماوە';
    if (balance < inv.total) return 'باڵانسی جزدانەکەت بەس نییە';
    final cur = Fmt.monthKey();
    mk ??= cur;
    final monthName = kMonths[int.parse(mk.split('-')[1]) - 1];
    final subIds = inv.lines.map((l) => l.subId).toList()..sort();
    final lines = <Json>[];
    for (final l in inv.lines) {
      final s = sub(l.subId);
      if (s == null) continue;
      lines.add({'subId': l.subId, 'driverId': s['driverId'], 'names': s['riderNames'], 'amt': l.amount, 'fee': feeFor(s, l.amount, l.factor), 'legs': l.legs});
    }
    final gross = lines.fold<num>(0, (n, l) => n + (l['amt'] as num)).toInt();
    final id = safeId('m_${mk}_${subIds.join('_')}');
    if (list('wallet').any((e) => e['id'] == id)) return 'پارەی ئەم مانگە پێشتر دراوە';
    final uid = me!;
    final bool wrote;
    try {
      wrote = await createOnce('wallet/$id', {
        'id': id,
        'who': uid,
        'role': 'p',
        'type': 'monthpay',
        'amount': -inv.total,
        'gross': gross,
        'discount': gross - inv.total,
        'month': mk,
        'lines': lines,
        'note': 'پارەی مانگ، $monthName',
        'title': inv.lines.map((l) => l.label).join('؛ '),
        'at': nowMs(),
        'by': 'passenger',
        '_r': Cloud.readers([uid, ...lines.map((l) => l['driverId'])]),
        '_t': newStamp(),
      });
    } catch (_) {
      return 'نەکرا، ئینتەرنێت بپشکنە و دووبارە هەوڵ بدەرەوە';
    }
    // ئەگەر لە ئامێرێکی تر پێشتر درابوو، مێژوو و خاڵ دووبارە تۆمار ناکرێن (هاوتای core.js)
    if (!wrote) return 'پارەی ئەم مانگە پێشتر دراوە';
    final pts = await _recordPayment(inv, 'wallet', monthLabel: monthName, markPaid: mk == cur);
    final name = str(passenger['name']);
    for (final l in lines) {
      final s = sub(l['subId']);
      if (s == null) continue;
      await addDNotice(str(s['driverId']), {'kind': 'pay', 'title': '$name پارەی مانگی دا', 'body': '${s['riderNames']}، گەشتەکان دەست پێدەکەن', 'link': 'riders'});
    }
    await addNotice(uid, {'kind': 'pay', 'title': 'پارەی $monthName درا', 'body': '${Fmt.money(inv.total)} لە جزدانەکەت${pts > 0 ? '، $pts خاڵی پاداشت' : ''}'});
    // پارەدانی پێشوەختەی مانگی داهاتوو: گەشتەکانی ئەمڕۆ پەیوەندییان پێیەوە نییە
    if (mk != cur) return null;
    // گەشتەکانی ئەمڕۆ هەر ئێستا دروست دەبن (هاوتای payMonthIn ـی core.js)؛ ئەو بەشدارییانەی
    // ئێستا پارەیان درا وەک دراو دادەنرێن، چونکە دێڕی جزدان لەوانەیە هێشتا نەگەیشتبێتە ئەم ئامێرە
    final paidIds = lines.map((l) => str(l['subId'])).toSet();
    for (final s in mySubs) {
      await genTrips(s, paid: paidIds.contains(str(s['id'])));
    }
    return null;
  }

  /// ژمارەی گەشتەکانی ماوەی مانگ لە ئەمڕۆوە (گەشتە دەستپێنەکراوەکانی ئەمڕۆ لەگەڵ)
  int legsLeft(Json sub) {
    final mk = Fmt.monthKey();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final today = list('trips').where((t) => t['subId'] == sub['id'] && t['day'] == Fmt.todayIso() && t['status'] == 'scheduled').length;
    return (monthOf(Fmt.todayIso(tomorrow)) == mk ? legsInMonth(sub, mk, Fmt.todayIso(tomorrow)) : 0) + today;
  }

  /// گەشتەکانی ماوەی ڕاگرتنێک لەم مانگەدا (لە ڕۆژی دوای ڕاگرتنەوە تا ڕۆژی پێش دەستپێکردنەوە)
  int legsPaused(Json sub, Json p) {
    final mk = Fmt.monthKey();
    final a0 = DateTime.fromMillisecondsSinceEpoch(((p['from'] as num?) ?? 0).toInt()).add(const Duration(days: 1));
    final b0 = DateTime.fromMillisecondsSinceEpoch(((p['to'] as num?) ?? nowMs()).toInt());
    final b = DateTime(b0.year, b0.month, b0.day);
    var n = 0;
    for (var d = DateTime(a0.year, a0.month, a0.day); d.isBefore(b); d = DateTime(d.year, d.month, d.day + 1)) {
      if (monthOf(Fmt.todayIso(d)) != mk || !dayApplies(sub, d)) continue;
      for (final dir in const ['go', 'back']) {
        if (dayTime(sub, dir, d) != null) n++;
      }
    }
    return n;
  }

  /// گەڕاندنەوەی پارەی ئەو گەشتانەی نەکران (هەڵوەشاندنەوە یان ڕاگرتن): داواکارییەک بۆ بەڕێوەبەر (سەرنشین خۆی ناتوانێت پارە بخاتە سەر جزدان)
  Future<void> refundRequest(Json sub, int legs, String why) async {
    final rec = payRec(sub);
    if (!walletOn || rec == null || rec['legacy'] == true || legs <= 0) return;
    final recLegs = ((rec['legs'] as num?) ?? 0).toInt();
    if (recLegs <= 0) return;
    final amt = (rec['amt'] as num?) ?? 0;
    final amount = ((amt * math.min(legs, recLegs)) / recLegs / 250).round() * 250;
    if (amount <= 0) return;
    final id = 'tp${shortId()}';
    final uid = me!;
    final name = str(passenger['name']);
    try {
      await set('topups/$id', {
        'id': id,
        'kind': 'refund',
        'owner': uid,
        'name': name,
        'phone': passenger['phone'],
        'amount': amount,
        'method': 'refund',
        'subId': sub['id'],
        'legs': legs,
        'note': '$why، ${sub['riderNames']}، ${Fmt.n(legs)} گەشت',
        'status': 'pending',
        'at': nowMs(),
        '_r': [uid],
        '_t': newStamp(),
      });
      await addANotice({'kind': 'pay', 'title': 'داوای گەڕاندنەوە: $name', 'body': '${Fmt.money(amount)}، $why', 'link': 'wallet'});
    } catch (_) {}
  }

  /// داواکاری زیادکردنی پارە (FIB، FastPay، کاش). بەڕێوەبەر پەسەندی دەکات
  Future<String?> requestTopup(int amount, String method, String ref, String? photo) async {
    final id = 'tp${shortId()}';
    final uid = me!;
    final name = str(passenger['name']);
    try {
      await set('topups/$id', {
        'id': id,
        'kind': 'topup',
        'amount': amount,
        'method': method,
        'ref': ref,
        'photo': photo,
        'status': 'pending',
        'at': nowMs(),
        'owner': uid,
        'role': 'p',
        'name': name,
        'phone': passenger['phone'],
        '_r': [uid],
        '_t': newStamp(),
      });
    } catch (_) {
      return null;
    }
    await addANotice({'kind': 'pay', 'title': 'زیادکردن: $name', 'body': '${Fmt.money(amount)}، ${payName(method)}${ref.isNotEmpty ? '، $ref' : ''}', 'link': 'wallet'});
    return id;
  }

  Future<void> cancelTopup(String id) => update('topups/$id', {'status': 'cancelled'});

  /// داوای ڕاکێشانی پارە. هەڵە یان null
  /// [onId] ناسنامەی داواکارییەکە دوای ناردن (بۆ پەڕەی دۆخ)
  Future<String?> requestWithdraw(int amount, String method, String account, {void Function(String id)? onId}) async {
    final min = ((config['withdrawMin'] as num?) ?? 0).toInt();
    final m = payMethod(method);
    if (amount <= 0) return 'بڕەکە بنووسە';
    if (amount > freeBalance) return 'زۆرترین ${Fmt.money(math.max(0, freeBalance))}';
    if (min > 0 && amount < min) return 'کەمترین بڕ ${Fmt.money(min)}';
    if (m == null || m['on'] == false) return 'شێوازی ڕاکێشان هەڵبژێرە';
    final acc = account.trim();
    if (m['account'] != false && acc.replaceAll(RegExp(r'\D'), '').length < 6) return 'ژمارەی هەژماری ${m['name']} بنووسە';
    final id = 'wd${shortId()}';
    final uid = me!;
    final name = str(passenger['name']);
    try {
      await set('withdraws/$id', {
        'id': id,
        'driverId': uid,
        'role': 'p',
        'name': name,
        'phone': passenger['phone'],
        'amount': amount,
        'method': method,
        'account': m['account'] == false ? '' : acc,
        'status': 'pending',
        'at': nowMs(),
        '_r': [uid],
        '_t': newStamp(),
      });
    } catch (_) {
      return 'نەنێردرا، دووبارە هەوڵ بدەرەوە';
    }
    await addANotice({
      'kind': 'pay',
      'title': 'داوای ڕاکێشان: $name',
      'body': '${Fmt.money(amount)}، ${payName(method)}${acc.isNotEmpty && m['account'] != false ? ' $acc' : ''}',
      'link': 'wallet',
    });
    onId?.call(id);
    return null;
  }

  Future<void> cancelWithdraw(String id) => update('withdraws/$id', {'status': 'cancelled'});

  /// دۆزینەوەی سەرنشینێک بە ژمارەی مۆبایل بۆ ناردنی پارە
  Future<({String? uid, String name, String phone, String? err})> lookupPeer(String phone) async {
    final p = cleanPhone(phone);
    if (!RegExp(r'^7\d{9}$').hasMatch(p)) return (uid: null, name: '', phone: p, err: 'ژمارەی مۆبایل دروست نییە');
    if (p == cleanPhone(str(passenger['phone']))) return (uid: null, name: '', phone: p, err: 'ناتوانیت بۆ خۆت بنێریت');
    try {
      for (final k in [p, '0$p']) {
        final d = await get('pdir/$k');
        if (d != null && d['uid'] != null && d['uid'] != me) return (uid: str(d['uid']), name: str(d['name']), phone: p, err: null);
      }
    } catch (_) {
      return (uid: null, name: '', phone: p, err: 'پەیوەندی نییە، دووبارە هەوڵ بدەرەوە');
    }
    return (uid: null, name: '', phone: p, err: 'هیچ سەرنشینێکی یەکسا بەم ژمارەیە نییە');
  }

  /// ناردنی پارە لە جزدانی خۆمەوە بۆ سەرنشینێکی تر. هەڵە یان null
  Future<String?> sendMoney(String peerUid, String peerName, int amount, String note) async {
    if (peerUid.isEmpty || peerUid == me) return 'وەرگر هەڵبژێرە';
    if (amount <= 0) return 'بڕەکە بنووسە';
    if (amount > freeBalance) return 'باڵانسەکەت بەس نییە (${Fmt.money(math.max(0, freeBalance))})';
    final uid = me!;
    final fromName = str(passenger['name']);
    final id = 'x${shortId()}';
    final n = note.trim().length > 80 ? note.trim().substring(0, 80) : note.trim();
    try {
      await set('wallet/$id', {
        'id': id,
        'who': uid,
        'role': 'p',
        'type': 'xfer',
        'to': peerUid,
        'toName': peerName,
        'fromName': fromName,
        'amount': -amount,
        'note': n,
        'at': nowMs(),
        'by': 'passenger',
        '_r': Cloud.readers([uid, peerUid]),
        '_t': newStamp(),
      });
    } catch (_) {
      return 'نەنێردرا، دووبارە هەوڵ بدەرەوە';
    }
    await addNotice(peerUid, {'kind': 'pay', 'title': '$fromName پارەی بۆ ناردیت', 'body': '${Fmt.money(amount)} چووە سەر جزدانەکەت${n.isNotEmpty ? '، $n' : ''}', 'link': 'wallet'});
    return null;
  }
}

/// ناونیشان و ئایکۆنی هەر جۆرێکی دێڕی جزدان (TK.txLabel)
({String icon, String title, String sub, bool bad}) txLabel(Cloud cloud, Json e) {
  final m = e['method'] != null ? cloud.payName(e['method']) : '';
  final note = str(e['note']);
  switch (e['type']) {
    case 'topup':
      return (icon: 'wallet', title: 'زیادکردن${m.isNotEmpty ? ' بە $m' : ''}', sub: note, bad: false);
    case 'monthpay':
      final names = asList(e['lines']).map((l) => str(asMap(l)['names'])).join('، ');
      return (icon: 'receipt', title: note.isNotEmpty ? note : 'پارەی مانگ', sub: names.isNotEmpty ? names : str(e['title']), bad: false);
    case 'skipref':
      return (icon: 'undo', title: 'گەڕانەوەی پارەی ڕۆژ', sub: note, bad: false);
    case 'comp':
      return (icon: 'shield', title: 'قەرەبوو: شۆفێر نەهات', sub: note, bad: false);
    case 'refund':
      return (icon: 'undo', title: 'گەڕاندنەوە', sub: note, bad: false);
    case 'adjust':
      return (icon: 'sliders', title: ((e['amount'] as num?) ?? 0) >= 0 ? 'زیادکردن لەلایەن یەکسا' : 'لێبڕین لەلایەن یەکسا', sub: note, bad: false);
    case 'legacy':
      return (icon: 'calendar', title: 'مانگی پێش جزدان', sub: note, bad: false);
    case 'penalty':
      return (icon: 'alert', title: 'سزا', sub: note, bad: true);
    case 'withdraw':
      return (icon: 'download', title: 'ڕاکێشان${m.isNotEmpty ? ' بۆ $m' : ''}', sub: note, bad: false);
    case 'xfer':
      return e['incoming'] == true
          ? (icon: 'send', title: 'وەرگرتن لە ${str(e['fromName'])}', sub: note.isNotEmpty ? note : 'ناردن لە جزدانێکی ترەوە', bad: false)
          : (icon: 'send', title: 'ناردن بۆ ${str(e['toName'])}', sub: note, bad: false);
  }
  return (icon: 'wallet', title: note.isNotEmpty ? note : str(e['type']), sub: '', bad: false);
}
