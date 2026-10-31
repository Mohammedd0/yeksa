// خێزان، پرۆفایل، پاداشت، ڕاگرتنی بەشداری و سڕینەوەی هەژمار (core.js)
import 'dart:collection'; // firstOrNull / lastOrNull
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'actions.dart';
import 'auth.dart';
import 'billing.dart';
import 'cloud.dart';
import 'format.dart';
import 'request_actions.dart';
import 'sel.dart';
import 'trips.dart';

/// پاداشتە بنەڕەتییەکان (بەڕێوەبەر دەتوانێت بیانگۆڕێت)
const kRewardsDefault = [
  {'id': 'rw1', 'title': '١٠٬٠٠٠ دینار داشکاندن', 'cost': 500, 'kind': 'iqd', 'amount': 10000, 'repeat': true, 'on': true},
  {'id': 'rw2', 'title': '٢٥٬٠٠٠ دینار داشکاندن', 'cost': 1000, 'kind': 'iqd', 'amount': 25000, 'repeat': true, 'on': true},
  {'id': 'rw3', 'title': 'هەفتەیەکی بەخۆڕایی', 'cost': 2500, 'kind': 'days', 'amount': 7, 'repeat': true, 'on': true},
];

/// پرسیارە باوە بنەڕەتییەکان. aud: p سەرنشین، d شۆفێر، all هەردووکیان
const kFaqDefault = [
  {'id': 'fq1', 'aud': 'p', 'on': true, 'q': 'ئەگەر شۆفێرەکەم نەهات چی دەبێت؟', 'a': 'شۆفێرێکی جێگرەوە بە هەمان کات و نرخ دێت و پێشوەختە ئاگادار دەکرێیتەوە. ئەگەر دواکەوتن هەبوو، قەرەبووی ڕۆژەکە بۆ فاتورەی داهاتوو زیاد دەکرێت.'},
  {'id': 'fq2', 'aud': 'p', 'on': true, 'q': 'چۆن نرخ دیاری دەکرێت؟', 'a': 'ئەپەکە بە پێی دووری ڕێگا، ژمارەی ڕۆژەکان و ژمارەی سەرنشینەکان نرخێک پێشنیار دەکات. شۆفێرەکان دەتوانن تا {offerRange} کەمتر یان زیاتر نرخ بنێرن و تۆ هەڵدەبژێریت.'},
  {'id': 'fq3', 'aud': 'p', 'on': true, 'q': 'دەتوانم بەشدارییەکەم ڕابگرم؟', 'a': 'بەڵێ، لە بەشی بەشداری «ڕاگرتنی کاتی» دابگرە. بۆ ئەو ڕۆژانەی ڕاگیراوە پارە نادەیت.'},
  {'id': 'fq4', 'aud': 'p', 'on': true, 'q': 'چۆن پەیوەندی بە شۆفێرەکەمەوە بکەم؟', 'a': 'لە ناو ئەپ نامەی بۆ بنێرە، یان لە پەڕەی شۆفێرەکە پەیوەندی تەلەفۆنی پێوە بکە. ژمارەی مۆبایلی تۆ لای شۆفێر هەمیشە شاراوەیە.'},
];

extension YkAccount on Cloud {
  /* ---------------- خێزان ---------------- */

  Json get family => asMap(pax['family']);

  List<Json> get guardians => asList(family['guardians']).map(asMap).toList();

  Future<void> addMember(String name, String kind, bool woman, int? age) async {
    final list = [...members];
    list.add({
      'id': 'm${shortId()}',
      'name': name,
      'initial': name.substring(0, 1),
      'kind': kind,
      'woman': woman,
      if (kind == 'child' && age != null) 'age': age,
      'relation': kind == 'child' ? (woman ? 'کچ' : 'کوڕ') : 'ئەندامی خێزان',
    });
    await update('pax/$me', {'family.members': list});
  }

  Future<void> removeMember(String id) => update('pax/$me', {'family.members': members.where((m) => m['id'] != id).toList()});

  Future<void> addGuardian(String name) => update('pax/$me', {
        'family.guardians': [
          ...guardians,
          {'name': name, 'initial': name.substring(0, 1), 'woman': false},
        ],
      });

  /* ---------------- پرۆفایل ---------------- */

  Future<void> updateProfile(String name, String homeId, String city, String gender) async {
    final up = <String, dynamic>{'passenger.name': name, 'passenger.homeId': homeId};
    if (city.isNotEmpty) up['passenger.city'] = city;
    final list = [...members.map((m) => Map<String, dynamic>.from(m))];
    if (gender == 'm' || gender == 'f') {
      up['passenger.gender'] = gender;
      if (list.isNotEmpty) list[0]['woman'] = gender == 'f';
    }
    // ماڵی نوێ: شوێنی پێشووی سەر نەخشە ئیتر ڕاست نییە
    if (passenger['homeId'] != homeId && asMap(pax['pins'])['_home'] != null) up['pins._home'] = FieldValue.delete();
    if (list.isNotEmpty) {
      list[0]['name'] = name.split(' ').first;
      list[0]['initial'] = name.substring(0, 1);
    }
    up['family.members'] = list;
    await update('pax/$me', up);
    await update('accounts/$me', {'name': name, if (city.isNotEmpty) 'city': city});
  }

  /// وێنەی پرۆفایل. لە بەشدارییەکانیشی دادەنرێت بۆ ئەوەی شۆفێرەکەی بیبینێت
  Future<void> setMyPhoto(String? id) async {
    await update('pax/$me', {'passenger.photo': id});
    for (final s in mySubs) {
      await update('subscriptions/${s['id']}', {'ownerPhoto': id ?? FieldValue.delete()});
    }
  }

  /* ---------------- پاداشت ---------------- */

  Json get rewards => asMap(pax['rewards']);

  List<Json> get rewardsList {
    final l = config['rewards'];
    return (l is List ? l : kRewardsDefault).map(asMap).toList();
  }

  List<Json> get refsAsInviter => list('referrals').where((r) => r['inviter'] == me).toList();

  List<Json> get faqList {
    final l = config['faq'];
    return (l is List ? l : kFaqDefault).map(asMap).where((x) => x['on'] != false && (x['aud'] == 'p' || x['aud'] == 'all')).toList();
  }

  /// {offerRange} لە وەڵامدا دەبێتە ڕێژەی ئێستای ڕێکخستن
  String faqText(Object? t) => str(t).replaceAll('{offerRange}', Fmt.n('${(((config['offerRange'] as num?) ?? 0) * 100).round()}٪'));

  List<Json> get contacts {
    final l = config['contacts'];
    if (l is! List) return const [];
    return l.map(asMap).where((x) => str(x['phone']).isNotEmpty && (x['aud'] == 'p' || x['aud'] == null || x['aud'] == 'all')).toList();
  }

  /// گۆڕینەوەی خاڵ بە داشکاندن
  Future<Json?> redeem(String id) async {
    final x = rewardsList.where((y) => y['id'] == id && y['on'] != false).firstOrNull;
    final r = rewards;
    final points = (r['points'] as num?) ?? 0;
    final redeemed = asList(r['redeemed']);
    if (x == null || points < (x['cost'] as num) || (x['repeat'] != true && redeemed.contains(id))) return null;
    await update('pax/$me', {
      'rewards.points': FieldValue.increment(-(x['cost'] as num)),
      'rewards.redeemed': [...redeemed.where((y) => y != id), id],
      'rewards.pending': FieldValue.arrayUnion([
        {'id': 'rp${shortId()}', 'rid': x['id'], 'title': x['title'], 'kind': x['kind'], 'amount': x['amount'], 'at': nowMs()},
      ]),
    });
    return x;
  }

  /* ---------------- ڕاگرتنی بەشداری ---------------- */

  /// ڕاگرتن / دەستپێکردنەوە. شۆفێر ئاگادار دەکرێتەوە
  Future<void> toggleSubPause(String id) async {
    final s = sub(id);
    if (s == null) return;
    final paused = s['status'] != 'paused';
    final log = asList(s['pauseLog']).map((e) => Map<String, dynamic>.from(asMap(e))).toList();
    if (paused) {
      log.add({'from': nowMs(), 'to': null});
    } else if (log.isNotEmpty && log.last['to'] == null) {
      log.last['to'] = nowMs();
    }
    await update('subscriptions/$id', {'status': paused ? 'paused' : 'active', 'pauseLog': log});
    // دەستپێکردنەوە: پارەی ڕۆژە ڕاگیراوەکانی ئەم مانگە دەگەڕێتەوە (جزدان)
    if (!paused && log.isNotEmpty && log.last['to'] != null) await refundRequest(s, legsPaused(s, log.last), 'ڕاگرتنی کاتی');
    final names = str(s['riderNames']);
    final did = str(s['driverId']);
    final d = driver(did);
    final me0 = str(passenger['name']);
    await addNotice(me!, {'kind': 'info', 'title': paused ? 'بەشدارییەکە ڕاگیرا' : 'بەشدارییەکە دەستی پێکردەوە', 'body': '$names، ${str(d?['name'])} ئاگادار کرایەوە'});
    await addDNotice(did, {
      'kind': paused ? 'info' : 'ok',
      'title': paused ? '$me0 بەشدارییەکەی ڕاگرت' : '$me0 بەشدارییەکەی دەستپێکردەوە',
      'body': '$names، ${s['to']}${paused ? '، تا ئاگاداری دووەم گەشت نییە' : ''}',
      'link': 'today',
    });
    await addSystemMessage(did, paused ? 'بەشداری $names بۆ ${s['to']} ڕاگیرا' : 'بەشداری $names بۆ ${s['to']} دەستی پێکردەوە');
    // گەشتە نەکراوەکانی ئەمڕۆ لادەبرێن کاتێک ڕاگیرا؛ کاتێک دەستی پێکردەوە دروست دەکرێنەوە
    if (paused) {
      for (final t in list('trips').where((t) => t['subId'] == id && t['status'] == 'scheduled' && t['runId'] == null)) {
        try {
          await delete('trips/${t['id']}');
        } catch (_) {}
      }
    } else {
      final fresh = sub(id);
      if (fresh != null) await genTrips({...fresh, 'status': 'active'});
    }
  }

  /// گۆڕینی کات و ڕۆژەکانی بەشداری. شۆفێر ئاگادار دەکرێتەوە
  Future<void> updateSub(String id, Map<String, dynamic> patch) async {
    final s0 = sub(id);
    if (s0 == null) return;
    await update('subscriptions/$id', patch);
    final s = {...s0, ...patch};
    // گەشتەکانی ئەمڕۆ کە هێشتا دەستیان پێنەکردووە بە کاتی نوێ ڕێک دەخرێنەوە
    final today = Fmt.todayIso();
    for (final t in list('trips').where((t) => t['subId'] == id && t['status'] == 'scheduled' && (t['day'] == null || t['day'] == today))) {
      final time = dayApplies(s) ? dayTime(s, str(t['dir'])) : null;
      try {
        if (time == null) {
          await delete('trips/${t['id']}');
        } else if (t['runId'] == null && time != t['time']) {
          final shift = toMin(time) - toMin(str(t['time']));
          final stops = stopsOf(t).map((x) => {...x, 'time': addMin(str(x['time']), shift)}).toList();
          await update('trips/${t['id']}', {'time': time, 'stops': stops});
        }
      } catch (_) {}
    }
    await genTrips(s);
    final did = str(s['driverId']);
    final text = 'گۆڕانکاری لە بەشداری ${s['riderNames']}: ${fmtSchedule(s)}، ${fmtDays(asList(s['days']))}';
    await addSystemMessage(did, text);
    await addDNotice(did, {'kind': 'info', 'title': 'گۆڕانکاری لە بەشدارییەک', 'body': text, 'link': 'today'});
    await addNotice(me!, {'kind': 'info', 'title': 'گۆڕانکارییەکان پاشەکەوت کران', 'body': 'شۆفێرەکە ئاگادار کرایەوە'});
  }

  Future<void> cancelSub(String id) => endSub(id, 'cancel');

  /* ---------------- سڕینەوەی هەژمار ---------------- */

  /// سڕینەوەی هەمیشەیی. هەڵە بە کوردی دەگەڕێنێتەوە
  Future<String?> deleteMyAccount(String pass) async {
    final u = auth.currentUser;
    final uid = me;
    if (u == null || uid == null) return 'دووبارە بچۆ ژوورەوە';
    if (account?['blocked'] == true) return 'ئەم هەژمارە ڕاگیراوە. بۆ سڕینەوە پەیوەندی بە پشتگیری یەکسا بکە';
    if (list('trips').any((t) => t['owner'] == uid && t['status'] == 'active')) return 'گەشتێکت ئێستا لە ڕێگەیە. دوای تەواوبوونی هەوڵ بدەرەوە';
    if (walletOn && (balance > 0 || pendingWithdraw > 0)) return 'سەرەتا پارەی جزدانەکەت ڕابکێشە (یان بینێرە)، پاشان هەژمارەکە بسڕەوە';
    // وەک وێب: هەر داواکارییەکی چاوەڕێ (زیادکردن یان گەڕاندنەوە) ڕێگە لە سڕینەوە دەگرێت
    if (walletOn && myTopupsPending.isNotEmpty) {
      return 'داواکارییەکی زیادکردنت چاوەڕێیە. سەرەتا هەڵیبوەشێنەوە یان چاوەڕێی پەسەندکردن بکە';
    }
    try {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: pass));
    } on FirebaseAuthException catch (e) {
      return RegExp('invalid-credential|wrong-password').hasMatch(e.code) ? 'وشەی نهێنی هەڵەیە' : AuthService.authErr(e);
    }
    const fail = 'سڕینەوە تەواو نەبوو. ئینتەرنێت بپشکنە و دووبارە هەوڵ بدەرەوە';
    final name = str(passenger['name']);
    try {
      final key = str(u.email).split('@').first;
      if (key.isNotEmpty) {
        try {
          await delete('pdir/$key');
        } catch (_) {}
      }
      for (final s in [...mySubs]) {
        await endSub(str(s['id']), 'deleted');
      }
      // ناوەکان لە گەشتە کۆنەکانی خۆی لادەبرێن
      for (final t in list('trips').where((t) => t['owner'] == uid)) {
        final stops = stopsOf(t).map((st) {
          final parts = asList(st['parts']).map((p) {
            final m = Map<String, dynamic>.from(asMap(p));
            if (m['owner'] != uid) return m;
            m['riders'] = 'سڕاوە';
            m['people'] = asList(m['people']).map((x) => {...asMap(x), 'n': ''}).toList();
            return m;
          }).toList();
          return {
            ...st,
            if (st['parts'] is List) 'parts': parts,
            if (st['parts'] is List) 'riders': parts.map((p) => str(p['riders'])).join('، '),
            if (st['parts'] is List) 'people': parts.expand((p) => asList(p['people'])).toList(),
          };
        }).toList();
        try {
          await update('trips/${t['id']}', {'title': 'گەشتی بەکارهێنەری سڕاوە', 'stops': stops});
        } catch (_) {}
      }
      for (final r in list('requests').where((r) => r['owner'] == uid)) {
        final up = <String, dynamic>{'ownerName': 'بەکارهێنەری سڕاوە', 'riderNames': 'سڕاوە', 'note': ''};
        if (r['status'] == 'open') {
          up['status'] = 'closed';
          up['closedReason'] = 'cancel';
          up['offers'] = asList(r['offers']).map((o) {
            final m = Map<String, dynamic>.from(asMap(o));
            if (m['status'] == 'pending') m['status'] = 'lost';
            return m;
          }).toList();
        }
        try {
          await update('requests/${r['id']}', up);
        } catch (_) {}
      }
      for (final n in list('pnotices').where((n) => n['owner'] == uid)) {
        try {
          await delete('pnotices/${n['id']}');
        } catch (_) {}
      }
      for (final h in list('phistory').where((h) => h['owner'] == uid)) {
        try {
          await delete('phistory/${h['id']}');
        } catch (_) {}
      }
      await addANotice({'kind': 'info', 'title': 'سەرنشینێک هەژمارەکەی سڕییەوە', 'body': '$name. ئەگەر ڕاپۆرت یان تۆماری هاوبەشی هەبێت، لە پانێڵ بیانسڕەوە'});
      await db.waitForPendingWrites().timeout(const Duration(seconds: 30));
      await delete('pax/$uid');
      await delete('accounts/$uid');
      await u.delete();
    } catch (_) {
      return fail;
    }
    try {
      await auth.signOut();
      await db.clearPersistence();
    } catch (_) {}
    return null;
  }
}
