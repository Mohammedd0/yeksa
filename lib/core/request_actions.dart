// داواکاری، هەڵبژاردنی شۆفێر و گەشتی ڕۆژانە (createRequests، cancelRequest، chooseOffer، rebroadcast، genTrips ـی core.js)
import 'dart:collection'; // firstOrNull / lastOrNull
import 'actions.dart';
import 'billing.dart';
import 'cloud.dart';
import 'draft.dart';
import 'format.dart';
import 'pricing.dart';
import 'sel.dart';

String _first(Object? s) => str(s).split('، ').first; // i18n-keep

extension YkRequests on Cloud {
  Json? request(Object? id) {
    for (final r in list('requests')) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  /// _r ـی داواکاری: خاوەن، شۆفێری دیاریکراو، شۆفێری هەڵبژێردراو و هەموو ئەوانەی نرخیان ناردووە
  static List<String> requestReaders(Json r) => Cloud.readers([
        r['owner'],
        r['target'] != 'all' ? r['target'] : null,
        r['chosenDriverId'],
        ...asList(r['offers']).map((o) => asMap(o)['driverId']),
      ]);

  /// دروستکردنی داواکاری (بڵاوکردنەوە یان ڕاستەوخۆ). «تەکسی جیا» = بۆ هەر کەسێک یەک داواکاری
  Future<List<String>> createRequests(Draft dr, String target) async {
    final uid = me!;
    final mem = draftMembers(dr);
    final groups = dr.mode == 'separate' ? mem.map((m) => [m]).toList() : [mem];
    final groupId = shortId();
    final now = nowMs();
    final hours = (config['requestHours'] as num?) ?? 48;
    final from = place(dr.fromId), to = place(dr.toId);
    final fromGeo = isGeo(dr.fromGeo) ? dr.fromGeo : null;
    final toGeo = isGeo(dr.toGeo) ? dr.toGeo : null;
    final km = (distance(dr.fromId, dr.toId, fromGeo, toGeo) * 10).round() / 10;
    final sched = dr.sched();
    final ownerName = str(passenger['name']).split(' ').first;
    final city = passenger['city'] ?? 'erbil';
    final ids = <String>[];
    final reqs = <Json>[];
    final pins = <String, dynamic>{};
    var i = 0;
    for (final g in groups) {
      final hasChild = g.any((m) => m['kind'] == 'child');
      final rt = rideTypeFor(dr.rideType, g);
      final base = {
        'fromId': dr.fromId,
        'toId': dr.toId,
        ...sched,
        'mode': dr.mode,
        'rideType': rt,
        'riders': g.length,
        'hasChild': hasChild,
        'km': km,
      };
      final r = <String, dynamic>{
        'id': 'q${shortId()}',
        'groupId': groupId,
        'owner': uid,
        'ownerName': ownerName,
        'city': city,
        'memberIds': g.map((m) => m['id']).toList(),
        'riders': g.length,
        'riderNames': inKu(() => Fmt.names(g.map((m) => str(m['name'])).toList())), // stored: Kurdish joining
        'hasChild': hasChild,
        'fromId': dr.fromId,
        'toId': dr.toId,
        'from': '${str(from?['name'])}${dr.fromNote.trim().isNotEmpty ? '، ${dr.fromNote.trim()}' : ''}', // i18n-keep
        'to': '${str(to?['name'])}${dr.toNote.trim().isNotEmpty ? '، ${dr.toNote.trim()}' : ''}', // i18n-keep
        'km': km,
        'go': sched['go'],
        'back': sched['back'],
        'days': sched['days'],
        'perDay': sched['perDay'],
        'replacesSub': dr.replacesSub,
        'startDate': dr.startDate,
        'mode': dr.mode,
        'rideType': rt,
        'womanOnly': dr.womanOnly,
        'note': dr.note.trim(),
        'price': priceFor(base),
        'target': target,
        'status': 'open',
        'createdAt': now,
        'expiresAt': now + (hours * 3600000).round(),
        'offers': [],
        'declined': [],
      };
      r['_r'] = requestReaders(r);
      r['_t'] = newStamp(1000 - i++); // نوێترین لە سەرەوە (ARR = -1)
      ids.add(r['id'] as String);
      reqs.add(r);
      if (fromGeo != null || toGeo != null) pins[r['id'] as String] = {'from': fromGeo, 'to': toGeo};
    }
    for (final r in reqs) {
      await set('requests/${r['id']}', r);
    }
    // شوێنی ورد تەنها لای سەرنشین دەمێنێتەوە (pins)؛ شۆفێران تەنها ناوی شوێن دەبینن
    final paxUp = <String, dynamic>{};
    pins.forEach((k, v) => paxUp['pins.$k'] = v);
    if (fromGeo != null && dr.fromId.isNotEmpty && dr.fromId == passenger['homeId']) {
      paxUp['pins._home'] = {'lat': fromGeo['lat'], 'lng': fromGeo['lng']};
    }
    if (paxUp.isNotEmpty) await update('pax/$uid', paxUp);
    // شۆفێرە ئامادەکان ئاگادار دەکرێنەوە ئەگەر داواکارییەکە بۆیان بگونجێت
    for (final r in reqs) {
      for (final d in drivers) {
        if (d['online'] == true && fits(d, r)) {
          await addDNotice(str(d['id']), inKu(() => {
            'kind': 'offer',
            'title': r['target'] == d['id'] ? 'داواکاری ڕاستەوخۆ لە $ownerName' : 'داواکاری نوێ لە $ownerName', // i18n-keep
            'body': '${r['riderNames']}، ${_first(r['from'])} ← ${_first(r['to'])}، ${Fmt.money(r['price'] as num)}', // i18n-keep
            'link': 'requests',
          }));
        }
      }
    }
    return ids;
  }

  Future<void> cancelRequest(String id) async {
    final r = request(id);
    if (r == null || r['status'] != 'open') return;
    final offers = asList(r['offers']).map((o) {
      final m = Map<String, dynamic>.from(asMap(o));
      if (m['status'] == 'pending') m['status'] = 'lost';
      return m;
    }).toList();
    await update('requests/$id', {'status': 'closed', 'closedReason': 'cancel', 'offers': offers});
    for (final o in offers) {
      await addDNotice(str(o['driverId']), {
        'kind': 'info',
        'title': 'داواکارییەک هەڵوەشێنرایەوە', // i18n-keep
        'body': '${r['ownerName']}، ${_first(r['to'])}', // i18n-keep
        'link': 'requests',
      });
    }
  }

  /// داواکاری ڕاستەوخۆی داخراو دەکرێتەوە بە بڵاوکردنەوە بۆ هەمووان
  Future<void> rebroadcast(String id) async {
    final r = request(id);
    if (r == null) return;
    final now = nowMs();
    final hours = (config['requestHours'] as num?) ?? 48;
    final next = {...r, 'target': 'all', 'status': 'open', 'closedReason': null};
    await update('requests/$id', {
      'target': 'all',
      'status': 'open',
      'closedReason': null,
      'createdAt': now,
      'expiresAt': now + (hours * 3600000).round(),
      '_r': requestReaders(next),
    });
    final declined = asList(r['declined']);
    for (final d in drivers) {
      if (d['online'] == true && fits(d, next) && !declined.contains(d['id'])) {
        await addDNotice(str(d['id']), {
          'kind': 'offer',
          'title': 'داواکاری نوێ لە ${r['ownerName']}', // i18n-keep
          'body': '${r['riderNames']}، ${_first(r['from'])} ← ${_first(r['to'])}', // i18n-keep
          'link': 'requests',
        });
      }
    }
  }

  /// ناوی یەکەم و ڕەگەزی ئەندامانی بەشدارییەک (familyPeople)
  List<Json> familyPeople(List<dynamic> memberIds) => memberIds.map(member).whereType<Json>().map((m) {
        final w = m['woman'];
        return <String, dynamic>{
          'n': str(m['name']).split(' ').first,
          'w': w == true ? 1 : w == false ? 0 : null,
          'kid': m['kind'] == 'child' ? 1 : 0,
        };
      }).toList();

  /// سەرنشین شۆفێرێک لەناو ئەوانەی نرخیان ناردووە هەڵدەبژێرێت
  Future<String?> chooseOffer(String reqId, String driverId) async {
    final r = request(reqId);
    if (r == null || r['status'] != 'open') return null;
    final offers = asList(r['offers']).map((o) => Map<String, dynamic>.from(asMap(o))).toList();
    final offer = offers.where((o) => o['driverId'] == driverId).firstOrNull;
    if (offer == null) return null;
    for (final o in offers) {
      o['status'] = o['driverId'] == driverId ? 'chosen' : 'lost';
    }
    final d = driver(driverId);
    final uid = me!;
    final price = offer['price'] as num;
    final sub = <String, dynamic>{
      'id': 'sub${shortId()}',
      'reqId': reqId,
      'owner': uid,
      'memberIds': r['memberIds'],
      'riderNames': r['riderNames'],
      'hasChild': r['hasChild'],
      'driverId': driverId,
      'from': r['from'],
      'to': r['to'],
      'go': r['go'],
      'back': r['back'],
      'km': r['km'],
      'days': r['days'],
      'perDay': r['perDay'],
      'mode': r['mode'],
      'riders': r['riders'],
      'rideType': r['rideType'],
      'womanOnly': r['womanOnly'],
      'note': r['note'] ?? '',
      'price': price,
      'status': 'active',
      'startDate': r['startDate'],
      'pauseLog': [],
      'createdAt': nowMs(),
      'ownerName': r['ownerName'] ?? '',
    };
    // وێنەی سەرنشین تەنها لە بەشدارییەکەدایە، کە تەنها خۆی و شۆفێرەکەی دەیبینن
    final photo = passenger['photo'];
    if (photo is String && photo.isNotEmpty) sub['ownerPhoto'] = photo;
    // شوێنی ورد تەنها دوای هەڵبژاردن دەدرێت بە شۆفێر
    final pg = asMap(asMap(pax['pins'])[reqId]);
    final fg = isGeo(pg['from']) ? asMap(pg['from']) : placeGeo(r['fromId']);
    final tg = isGeo(pg['to']) ? asMap(pg['to']) : placeGeo(r['toId']);
    if (fg != null) sub['fromGeo'] = {'lat': fg['lat'], 'lng': fg['lng']};
    if (tg != null) sub['toGeo'] = {'lat': tg['lat'], 'lng': tg['lng']};
    sub['people'] = familyPeople(asList(r['memberIds']));
    sub['_r'] = Cloud.readers([uid, driverId]);
    sub['_t'] = newStamp();

    final upd = {...r, 'status': 'matched', 'chosenDriverId': driverId, 'offers': offers};
    await update('requests/$reqId', {
      'status': 'matched',
      'chosenDriverId': driverId,
      'offers': offers,
      '_r': requestReaders(upd),
    });
    await set('subscriptions/${sub['id']}', sub);
    await genTrips(sub);

    // بانگهێشت: یەکەم بەشداری هەردووکیان داشکاندن پێدەبەخشێت
    final ref = refAsInvitee;
    if (ref != null && r['replacesSub'] != null && ref['subId'] == r['replacesSub']) {
      await update('referrals/$uid', {'subId': sub['id']});
    } else if (ref != null && ref['status'] == 'joined' && config['refOn'] == true) {
      final amount = refAmount(price);
      await update('referrals/$uid', {
        'status': 'subscribed',
        'subId': sub['id'],
        'amount': amount,
        'month': str(sub['startDate'] ?? Fmt.todayIso()).substring(0, 7),
        'subAt': nowMs(),
      });
      final inviter = str(ref['inviter']);
      if (inviter.isNotEmpty) {
        await addNotice(inviter, inKu(() => {
          'kind': 'info',
          'title': '${str(ref['inviteeName']).isEmpty ? 'هاوڕێکەت' : ref['inviteeName']} بەشداری کرد', // i18n-keep
          'body': '${Fmt.money(amount)} داشکاندن لە فاتورەی داهاتووت دەبڕدرێت', // i18n-keep
          'link': 'rewards',
        }));
      }
    }
    if (r['replacesSub'] != null) await endSub(str(r['replacesSub']), 'change');
    // کورسییە بەتاڵەکانی شۆفێر کەم دەکرێنەوە (وەک وێب؛ یاساکان تەنها freeSeats ڕێگە دەدەن)
    final seats = d?['freeSeats'];
    if (seats is num) {
      final used = r['mode'] == 'one' ? ((r['riders'] as num?) ?? 1).toInt() : 1;
      final left = (seats.toInt() - used).clamp(0, 20).toInt();
      try {
        await update('dpub/$driverId', {'freeSeats': left});
      } catch (_) {}
    }

    final dName = str(d?['name']).isEmpty ? 'شۆفێر' : str(d!['name']); // i18n-keep
    await addNotice(uid, inKu(() => {
      'kind': 'info',
      'title': 'بەشدارییەکەت چالاک کرا', // i18n-keep
      'body': '${r['riderNames']} لەگەڵ $dName، ${Fmt.money(price)} مانگانە', // i18n-keep
    }));
    await addDNotice(driverId, inKu(() => {
      'kind': 'ok',
      'title': '${r['ownerName']} تۆی هەڵبژارد', // i18n-keep
      'body': '${r['from']} ← ${r['to']}، ${Fmt.money(price)} مانگانە', // i18n-keep
      'link': 'routes',
    }));
    for (final o in offers.where((o) => o['driverId'] != driverId)) {
      await addDNotice(str(o['driverId']), {
        'kind': 'info',
        'title': 'سەرنشین شۆفێرێکی تری هەڵبژارد', // i18n-keep
        'body': '${r['ownerName']}، ${_first(r['from'])} ← ${_first(r['to'])}. داواکارییەکە داخرا.', // i18n-keep
        'link': 'requests',
      });
    }
    return sub['id'] as String;
  }

  /// کۆتاییهێنان بە بەشداری: گەشتە نەکراوەکان لادەبرێن، مێژوو دەمێنێتەوە
  /// (گەڕاندنەوەی پارەی جزدان لە قۆناغی ٥دا زیاد دەکرێت)
  Future<void> endSub(String id, String why) async {
    final x = sub(id);
    if (x == null) return;
    final uid = me!;
    // جزدان: پارەی گەشتە ماوەکانی ئەم مانگە دەگەڕێتەوە (بەڕێوەبەر پەسەندی دەکات)
    await refundRequest(x, x['status'] == 'paused' ? 0 : legsLeft(x), why == 'change' ? 'گۆڕینی شۆفێر' : 'هەڵوەشاندنەوەی بەشداری'); // i18n-keep
    await delete('subscriptions/$id');
    if (why != 'change') {
      for (final ref in list('referrals')) {
        if (ref['subId'] == id && ref['status'] == 'subscribed' && ref['inviteeUsedAt'] == null && ref['invitee'] == uid) {
          await update('referrals/$uid', {'status': 'cancelled'});
        }
      }
    }
    for (final t in list('trips')) {
      if (t['subId'] == id && t['status'] != 'active' && t['status'] != 'done') await delete('trips/${t['id']}');
    }
    final names = str(x['riderNames']);
    final did = str(x['driverId']);
    final reason = why == 'change' ? 'شۆفێری گۆڕی' : why == 'deleted' ? 'هەژمارەکەی سڕییەوە' : 'بەشدارییەکەی هەڵوەشاندەوە'; // i18n-keep
    final who = why == 'deleted' ? 'سەرنشینێک' : str(passenger['name']).split(' ').first; // i18n-keep
    await addSystemMessage(did, '$who $reason ($names، ${x['to']})'); // i18n-keep
    await addDNotice(did, {'kind': 'info', 'title': '$who $reason', 'body': '$names، ${x['to']}، گەشتەکانی داهاتوو لابران'}); // i18n-keep
  }

  /* ---------------- گەشتی ڕۆژانە ---------------- */

  Json _partOf(Json sub) => {
        'subId': sub['id'],
        'owner': sub['owner'] ?? me,
        'riders': sub['riderNames'],
        'memberIds': List.from(asList(sub['memberIds'])),
        'people': sub['people'] is List ? sub['people'] : familyPeople(asList(sub['memberIds'])),
      };

  Json _stop(String id, String place, String kind, Json sub, String time) {
    final p = _partOf(sub);
    return {
      'id': id,
      'place': place,
      'kind': kind,
      'parts': [p],
      'time': time,
      'done': false,
      'subIds': [p['subId']],
      'memberIds': p['memberIds'],
      'people': p['people'],
      'riders': p['riders'],
    };
  }

  /// وێستگەکانی گەشتێکی تاک (soloStops)
  List<Json> soloStops(Json sub, String dir, String time) {
    final leg = subLeg(sub, dir);
    final km = sub['km'] as num?;
    final mins = km != null && km > 0 ? (km * 2.5 + 8).round() : 20;
    return [_stop('s1', leg.from, 'pickup', sub, time), _stop('s2', leg.to, 'dropoff', sub, addMin(time, mins))];
  }

  bool _routedIn(Json sub, String dir) {
    final win = (config['poolWindowMin'] as num).toInt();
    return list('routes').any((r) => r['dir'] == dir && asList(r['subIds']).contains(sub['id']) && inRouteOn(sub, dir, win));
  }

  /// دروستکردنی گەشتەکانی ئەمڕۆی بەشدارییەک. ئەگەر لە ڕۆتێکدایە، شۆفێرەکە دروستی دەکات
  /// [paid] = true کاتێک پارەی ئەم مانگە هەر ئێستا درا و دێڕەکە هێشتا نەگەیشتۆتە ئەم ئامێرە
  Future<void> genTrips(Json sub, {bool paid = false}) async {
    if (sub['status'] != 'active' || !dayApplies(sub)) return;
    final day = Fmt.todayIso();
    // جزدان: پێش پارەدانی ئەم مانگە گەشت دروست نابێت
    if (walletOn && !paid && !subPaid(sub, monthOf(day))) return;
    final owner = str(sub['owner']);
    for (final dir in const ['go', 'back']) {
      final time = dayTime(sub, dir);
      if (time == null || _routedIn(sub, dir)) continue;
      final id = 't_${sub['id']}_${day}_$dir';
      if (list('trips').any((t) => t['id'] == id || (t['subId'] == sub['id'] && t['day'] == day && t['dir'] == dir))) continue;
      final trip = {
        'id': id,
        'day': day,
        'dir': dir,
        'driverId': sub['driverId'],
        'subId': sub['id'],
        'reqId': sub['reqId'],
        'owner': owner,
        'title': dir == 'back' ? 'هاتنەوە، ${sub['riderNames']}' : '${sub['riderNames']}، ${_first(sub['to'])}', // i18n-keep
        'memberIds': List.from(asList(sub['memberIds'])),
        'kind': sub['hasChild'] == true ? 'kids' : sub['rideType'] == 'private' ? 'private' : 'shared',
        'time': time,
        'status': 'scheduled',
        'stops': soloStops(sub, dir, time),
        '_r': Cloud.readers([owner, sub['driverId']]),
        '_t': newStamp(dir == 'go' ? 1 : 2),
      };
      try {
        await createOnce('trips/$id', trip);
      } catch (_) {
        // بێ ئینتەرنێت: جاری داهاتوو دووبارە هەوڵ دەدرێتەوە
      }
    }
  }

  /// گەشتەکانی ئەمڕۆی هەموو بەشدارییەکانم (هەر جارێک ئەپ دەکرێتەوە و هەر چەند خولەکێک)
  Future<void> genTodayTrips() async {
    for (final s in mySubs) {
      await genTrips(s);
    }
  }
}
