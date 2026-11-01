// کردارەکانی گەشت بۆ سەرنشین: هەڵسەنگاندن، «دەیەم»، جێگرەوە، «شۆفێر نەهات»، فریاکەوتن (core.js)
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'actions.dart';
import 'billing.dart';
import 'cloud.dart';
import 'format.dart';
import 'sel.dart';

/// چەند گەشت لە هەفتەیەکدا (TK.legsPerWeek)
int legsPerWeek(Json x) {
  if (hasPerDay(x)) {
    return asMap(x['perDay']).values.map(asMap).fold(0, (n, e) => n + (e['go'] != null ? 1 : 0) + (e['back'] != null ? 1 : 0));
  }
  final days = asList(x['days']).where((d) => d == true).length;
  return days * ((str(x['go']).isNotEmpty ? 1 : 0) + (str(x['back']).isNotEmpty ? 1 : 0));
}

extension YkTrips on Cloud {
  /// ئاگادارکردنەوەی بەڕێوەبەر (adminNotices)
  Future<void> addANotice(Map<String, dynamic> n) {
    final id = shortId();
    return set('adminNotices/$id', {'id': id, 'at': nowMs(), ...n, '_t': newStamp()});
  }

  /// هەڵسەنگاندنی شۆفێر دوای گەشت
  Future<void> rateDriver(String tripId, int stars, List<String> tags) async {
    final t = trip(tripId);
    if (t == null || t['ratedByPassenger'] != null) return;
    await update('trips/$tripId', {'ratedByPassenger': stars});
    final did = str(t['driverId']);
    final d = doc('dpub/$did');
    if (d != null) {
      final reviews = ((d['reviews'] as num?) ?? 0).toInt() + 1;
      final rating = ((((d['rating'] as num?) ?? 0) * (reviews - 1) + stars) / reviews * 10).round() / 10;
      final list = asList(d['tags']).map((x) => Map<String, dynamic>.from(asMap(x))).toList();
      for (final label in tags) {
        final i = list.indexWhere((x) => x['label'] == label);
        if (i >= 0) {
          list[i]['count'] = ((list[i]['count'] as num?) ?? 0) + 1;
        } else {
          list.add({'label': label, 'count': 1});
        }
      }
      try {
        await update('dpub/$did', {'reviews': reviews, 'rating': rating, 'tags': list});
      } catch (_) {
        // ئەگەر ڕێگەپێنەدرا، هەڵسەنگاندنەکە لەسەر گەشتەکە دەمێنێتەوە
      }
    }
    final pts = (config['pointsPerRating'] as num?) ?? 0;
    if (pts > 0) await update('pax/$me', {'rewards.points': FieldValue.increment(pts)});
  }

  /// هەڵوەشاندنەوەی «نایەم»
  Future<String?> unskipTrip(String id) async {
    final t = trip(id);
    if (t == null || t['status'] != 'skipped') return null;
    if (t['runId'] != null) {
      final run = list('trips').where((x) => x['runId'] == t['runId']);
      if (run.any((x) => x['status'] == 'active' || x['status'] == 'done' || x['status'] == 'absent')) return 'شۆفێر بەڕێ کەوتووە، نامەی بۆ بنێرە';
    }
    await update('trips/$id', {'status': 'scheduled'});
    final stops = stopsOf(t);
    final names = stops.isEmpty ? '' : str(stops.first['riders']);
    final did = str(t['driverId']);
    await addSystemMessage(did, '$names بۆ ${t['dir'] == 'back' ? 'هاتنەوە' : 'چوون'} دێن (هەڵوەشاندنەوەی «نایەم»)');
    await addDNotice(did, {'kind': 'ok', 'title': '$names دێن', 'body': 'گەشتی ${Fmt.clock(str(t['time']))} دەگەڕێتەوە خشتە', 'link': 'today'});
    return null;
  }

  /// ڕازیبوون بە شۆفێری جێگرەوە
  Future<void> approveSwap(String tripId) => update('trips/$tripId', {'swapOk': true});

  /// ڕەتکردنەوەی جێگرەوە: گەشتەکە دەگەڕێتەوە بۆ شۆفێری یەکەم
  Future<void> rejectSwap(String tripId) async {
    final t = trip(tripId);
    if (t == null || t['originalDriverId'] == null || t['status'] != 'scheduled') return;
    final taker = str(t['driverId']);
    final orig = str(t['originalDriverId']);
    final run = t['runId'] == null ? [t] : list('trips').where((x) => x['runId'] == t['runId'] && x['owner'] == me).toList();
    for (final x in run.where((x) => x['originalDriverId'] == orig)) {
      await update('trips/${x['id']}', {
        'driverId': orig,
        'originalDriverId': null,
        'swapPay': null,
        'swapId': null,
        'swapOk': null,
        '_r': Cloud.readers([x['owner'], orig]),
      });
    }
    if (t['swapId'] != null) {
      try {
        await update('swaps/${t['swapId']}', {'status': 'rejected'});
      } catch (_) {}
    }
    final od = driver(orig);
    await addNotice(me!, {'kind': 'info', 'title': 'جێگرەوەکە ڕەتکرایەوە', 'body': '${str(od?['name']).isEmpty ? 'شۆفێرەکەت' : od!['name']} ئاگادار کرایەوە'});
    await addDNotice(orig, {
      'kind': 'info',
      'title': 'سەرنشین جێگرەوەکەی ڕەتکردەوە',
      'body': '${t['title']}، ${Fmt.clock(str(t['time']))}، دەبێت خۆت بڕۆیت',
      'link': 'trip/$tripId',
    });
    await addDNotice(taker, {'kind': 'info', 'title': 'گەشتی جێگرەوە لابرا', 'body': '${t['title']}، سەرنشین شۆفێری خۆی دەوێت', 'link': 'today'});
  }

  /// «شۆفێر نەهات»: تەنها ١٠ خولەک دوای کاتی گەشت
  Future<String?> reportNoShow(String tripId, String note) async {
    final t = trip(tripId);
    if (t == null || t['status'] != 'scheduled') return 'ئەم گەشتە ناتوانرێت ڕاپۆرت بکرێت';
    if (minutesUntil(str(t['time'])) > -10) {
      return 'دەتوانیت ١٠ خولەک دوای کاتی گەشتەکە (${Fmt.clock(addMin(str(t['time']), 10))}) ڕاپۆرت بکەیت';
    }
    final c = config;
    final penalty = (c['noShowPenalty'] as num?) ?? 0;
    final did = str(t['driverId']);
    final s = sub(t['subId']);
    final name = str(passenger['name']);
    final phone = str(passenger['phone']);
    final day = str(t['day'] ?? Fmt.todayIso());
    await update('trips/$tripId', {'status': 'noshow'});
    final rid = 'r${shortId()}';
    if (walletOn) {
      // بەهای گەشتێک بۆ شۆفێر (legValue ـی core.js): لە پارەی دراوی ئەو مانگە، دوای کۆمیسیۆن، بە سەر ژمارەی گەشتەکاندا
      final rec = s == null ? null : payRec(s, monthOf(day));
      final recLegs = ((rec?['legs'] as num?) ?? 0).toInt();
      final legValue = rec == null || rec['legacy'] == true || recLegs <= 0
          ? 0
          : ((((rec['amt'] as num?) ?? 0) - ((rec['fee'] as num?) ?? 0)) / recLegs).round();
      await set('reports/$rid', {
        'id': rid, 'type': 'noshow', 'wallet': true, 'tripId': tripId, 'subId': t['subId'], 'day': day, 'dir': t['dir'],
        'driverId': did, 'by': name, 'phone': phone, 'note': note, 'penalty': penalty,
        'credit': math.min((c['noShowComp'] as num?) ?? 0, penalty), 'legValue': legValue, 'status': 'open', 'at': nowMs(), 'title': t['title'],
        '_t': newStamp(),
      });
      await addNotice(me!, {'kind': 'info', 'title': 'ڕاپۆرتەکەت نێردرا', 'body': 'یەکسا دەیپشکنێت. ئەگەر پەسەند کرا، قەرەبووەکە دەچێتە سەر جزدانەکەت'});
      await addDNotice(did, {'kind': 'info', 'red': true, 'title': 'ڕاپۆرتی نەهاتن', 'body': '${t['title']}، یەکسا دەیپشکنێت. ئەگەر هەڵەیە پەیوەندی بە یەکسا بکە', 'link': 'support'});
    } else {
      final perTrip = s == null ? 0 : ((s['price'] as num?) ?? 0) / math.max(1, legsPerWeek(s) * 4.3);
      final credit = math.max(((c['noShowCreditMin'] as num?) ?? 0).toInt(), (perTrip / 500).round() * 500);
      final adjId = 'a${shortId()}';
      await update('pax/$me', {
        'billing.adjustments': FieldValue.arrayUnion([
          {'id': adjId, 'amount': credit, 'note': 'قەرەبوو: شۆفێر نەهات، ${t['title']}', 'at': nowMs()},
        ]),
      });
      final lid = 'l${shortId()}';
      try {
        await set('ledger/$lid', {
          'id': lid, 'driverId': did, 'type': 'penalty', 'amount': -penalty,
          'note': 'نەهاتن بۆ ${t['title']}، ${Fmt.clock(str(t['time']))}', 'at': nowMs(), 'tripId': tripId,
          '_r': [did], '_t': newStamp(),
        });
      } catch (_) {}
      await set('reports/$rid', {
        'id': rid, 'type': 'noshow', 'tripId': tripId, 'driverId': did, 'by': name, 'phone': phone, 'note': note,
        'credit': credit, 'penalty': penalty, 'adjId': adjId, 'ledgerId': lid, 'status': 'open', 'at': nowMs(), '_t': newStamp(),
      });
      await addNotice(me!, {'kind': 'info', 'title': 'ڕاپۆرتەکەت تۆمار کرا', 'body': '${Fmt.money(credit)} قەرەبوو بۆ فاتورەی داهاتوو زیاد کرا'});
      await addDNotice(did, {
        'kind': 'info', 'red': true, 'title': 'ڕاپۆرتی نەهاتن',
        'body': '${t['title']}، ${Fmt.money(penalty)} سزا. ئەگەر هەڵەیە پەیوەندی بە پشتگیری بکە', 'link': 'earnings',
      });
    }
    await addANotice({'kind': 'report', 'red': true, 'title': 'ڕاپۆرتی «شۆفێر نەهات» لە $name', 'body': t['title'], 'link': 'reports'});
    return null;
  }

  /// سکاڵا / داوای یارمەتی (addTicket)
  Future<void> addTicket(String subject) async {
    final name = str(passenger['name']);
    final ticket = {
      'id': 1000 + math.Random().nextInt(9000),
      'subject': subject,
      'status': 'open',
      'at': nowMs(),
      'by': name,
      'phone': str(passenger['phone']),
    };
    await update('pax/$me', {
      'tickets': [ticket, ...asList(pax['tickets'])],
    });
    await addANotice({'kind': 'ticket', 'title': 'سکاڵا لە $name', 'body': subject, 'link': 'reports'});
  }
}
