// کردارەکانی سەرنشین (actions ـی core.js). هەر کردارێک هەمان بەڵگەنامەکانی وەشانی وێب دەنووسێت.
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloud.dart';
import 'format.dart';
import 'sel.dart';

extension YkActions on Cloud {
  /// ئاگادارکردنەوەی شۆفێرێک (dnotices)
  Future<void> addDNotice(String driverId, Map<String, dynamic> n) {
    final id = shortId();
    return set('dnotices/$id', {
      'id': id,
      'at': nowMs(),
      'driverId': driverId,
      ...n,
      '_r': [driverId],
      '_t': newStamp(),
    });
  }

  /// نامەی سیستەم لە گفتوگۆی سەرنشین و شۆفێر (بۆ نموونە «ئەمڕۆ نایەن»)
  Future<void> addSystemMessage(String driverId, String text) {
    final id = shortId();
    return set('messages/$id', {
      'id': id,
      'driverId': driverId,
      'peer': me,
      'fromDriver': false,
      'system': true,
      'text': text,
      'at': nowMs(),
      'readP': true,
      'readD': false,
      '_r': Cloud.readers([driverId, me]),
      '_t': newStamp(),
    });
  }

  /// «نایەم»: یەک یان دوو گەشتی ئەمڕۆ (چوون و هاتنەوە)
  Future<void> skipTrips(List<String> ids, String reason) async {
    final cutoff = (config['skipCutoffMin'] as num).toInt();
    final trips = myTrips.where((t) => ids.contains(t['id']) && t['status'] == 'scheduled' && canSkip(t, cutoff)).toList();
    if (trips.isEmpty) return;
    for (final t in trips) {
      await update('trips/${t['id']}', {'status': 'skipped', 'skipReason': reason});
    }
    final t0 = trips.first;
    final stops = stopsOf(t0);
    final names = stops.isEmpty ? '' : str(stops.first['riders']);
    final what = trips.length > 1 ? 'چوون و هاتنەوە' : t0['dir'] == 'back' ? 'هاتنەوە' : 'چوون';
    final text = 'ئەمڕۆ $names بۆ $what نایەن${reason.isNotEmpty ? '، $reason' : ''}';
    final drivers = trips.map((t) => str(t['driverId'])).where((x) => x.isNotEmpty).toSet();
    for (final did in drivers) {
      await addSystemMessage(did, text);
      await addDNotice(did, {
        'kind': 'info',
        'title': '$names ئەمڕۆ نایەن',
        'body': '$what${reason.isNotEmpty ? '، $reason' : ''}، پێویست ناکات بڕۆیت',
        'link': 'today',
      });
    }
    await addNotice(me!, {'kind': 'info', 'title': 'شۆفێر ئاگادار کرایەوە', 'body': '$names ئەمڕۆ بۆ $what نایەن'});
  }

  Future<void> markNoticesRead() => update('pax/$me', {'readNoticesAt': nowMs()});

  Future<void> markNewsSeen(String id) async {
    final seen = asList(pax['seenNews']);
    if (seen.contains(id) || me == null) return;
    await update('pax/$me', {
      'seenNews': FieldValue.arrayUnion([id]),
    });
  }
}
