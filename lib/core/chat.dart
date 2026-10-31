// نامەکانی سەرنشین و شۆفێر (sendMessage، unsendMessage، markThreadRead، threadsP ـی core.js)
import 'dart:collection'; // firstOrNull / lastOrNull
import 'cloud.dart';
import 'format.dart';
import 'sel.dart';

/// نامەی خۆت تەنها تا ٥ خولەک دەگەڕێنرێتەوە
const int kUnsendMs = 5 * 60000;

typedef Thread = ({String driverId, List<Json> msgs, Json last, int unread});

extension YkChat on Cloud {
  /// نامەکانی گفتوگۆیەک لەگەڵ شۆفێرێک، کۆن لە سەرەوە
  List<Json> threadMsgs(String driverId) {
    final l = list('messages').where((m) => m['peer'] == me && m['driverId'] == driverId).toList();
    l.sort((a, b) => ((a['at'] as num?) ?? 0).compareTo((b['at'] as num?) ?? 0));
    return l;
  }

  /// گفتوگۆکان، نوێترین لە سەرەوە
  List<Thread> get threads {
    final map = <String, List<Json>>{};
    for (final m in list('messages').where((m) => m['peer'] == me)) {
      map.putIfAbsent(str(m['driverId']), () => []).add(m);
    }
    final out = map.entries.map((e) {
      final msgs = e.value..sort((a, b) => ((a['at'] as num?) ?? 0).compareTo((b['at'] as num?) ?? 0));
      return (
        driverId: e.key,
        msgs: msgs,
        last: msgs.last,
        unread: msgs.where((m) => m['fromDriver'] == true && m['readP'] != true).length,
      );
    }).toList();
    out.sort((a, b) => ((b.last['at'] as num?) ?? 0).compareTo((a.last['at'] as num?) ?? 0));
    return out;
  }

  bool canUnsend(Json m) {
    if (m['system'] == true || m['unsent'] == true || m['voice'] != null) return false;
    final mine = m['fromDriver'] != true && m['peer'] == me;
    return mine && nowMs() - ((m['at'] as num?) ?? 0) < kUnsendMs;
  }

  /// ناردنی نامە بۆ شۆفێر
  Future<void> sendMessage(String driverId, String text) async {
    final t = text.trim();
    if (t.isEmpty || me == null) return;
    final id = shortId();
    final nid = shortId();
    // nid: ئاگادارکردنەوەکەی شۆفێر، بۆ ئەوەی ئەگەر نامەکە گەڕێنرایەوە دەقەکەی لەویش بسڕدرێتەوە
    final write = set('messages/$id', {
      'id': id,
      'driverId': driverId,
      'peer': me,
      'fromDriver': false,
      'text': t,
      'at': nowMs(),
      'readP': true,
      'readD': false,
      'nid': nid,
      '_r': Cloud.readers([driverId, me]),
      '_t': newStamp(),
    });
    final dn = set('dnotices/$nid', {
      'id': nid,
      'at': nowMs(),
      'driverId': driverId,
      'kind': 'chat',
      'title': 'نامە لە ${str(passenger['name']).isEmpty ? 'سەرنشین' : passenger['name']}',
      'body': t,
      'link': 'chat/${Uri.encodeComponent(me!)}',
      'msgId': id,
      '_r': [driverId],
      '_t': newStamp(),
    });
    await Future.wait([write, dn]);
  }

  /// گەڕاندنەوەی نامە. دەقی ڕاستەقینە تەنها بۆ بەڕێوەبەر هەڵدەگیرێت (بۆ سکاڵا و سەلامەتی)
  Future<String?> unsendMessage(String id) async {
    final m = list('messages').where((x) => x['id'] == id).firstOrNull;
    if (m == null || m['system'] == true || m['unsent'] == true || m['voice'] != null) return 'ئەم نامەیە ناگەڕێنرێتەوە';
    if (!canUnsend(m)) return 'تەنها تا ٥ خولەک دوای ناردن دەتوانیت نامە بگەڕێنیتەوە';
    final now = nowMs();
    final uid = 'u${shortId()}';
    await set('unsent/$uid', {
      'id': uid,
      'msgId': id,
      'text': m['text'],
      'sentAt': m['at'],
      'at': now,
      'driverId': m['driverId'],
      'peer': me,
      'fromDriver': false,
      'by': me,
      '_t': newStamp(),
    });
    await update('messages/$id', {'text': '', 'unsent': true, 'unsentAt': now});
    final nid = m['nid'];
    if (nid is String && nid.isNotEmpty) {
      try {
        await update('dnotices/$nid', {'body': 'ئەم نامەیە گەڕێنرایەوە'});
      } catch (_) {}
    }
    return null;
  }

  /// نامەکانی شۆفێر وەک خوێندراوە نیشان دەدرێن
  Future<void> markThreadRead(String driverId) async {
    final un = list('messages').where((m) => m['peer'] == me && m['driverId'] == driverId && m['fromDriver'] == true && m['readP'] != true).toList();
    for (final m in un) {
      try {
        await update('messages/${m['id']}', {'readP': true});
      } catch (_) {}
    }
  }

  /// شۆفێرانی بەشدارییەکانم کە هێشتا گفتوگۆمان نییە
  List<String> get subDriversNoThread {
    final have = threads.map((t) => t.driverId).toSet();
    return mySubs.map((x) => str(x['driverId'])).where((id) => id.isNotEmpty && !have.contains(id)).toSet().toList();
  }
}

