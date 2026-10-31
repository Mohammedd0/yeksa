// ڕەشنووسی بەشداری نوێ (U.draft ـی وەشانی وێب): سێ هەنگاو، پاشان داواکاری دروست دەبێت
import 'cloud.dart';
import 'format.dart';
import 'pricing.dart';
import 'sel.dart';

class Draft {
  Draft({this.prefDriver});

  int step = 1;
  List<String> memberIds = [];
  String mode = 'one'; // one | separate
  String rideType = 'shared'; // shared | private
  bool womanOnly = false;
  String fromId = '', toId = '';
  String fromNote = '', toNote = '';
  String fromQ = '', toQ = '';
  Map<String, double>? fromGeo, toGeo;
  String go = '07:30', backTime = '14:00';
  String dir = 'both'; // both | go | back
  late String startDate = Fmt.todayIso(DateTime.now().add(const Duration(days: 1)));
  List<bool> days = [false, true, true, true, true, true, false];

  /// کاتی جیاواز بۆ هەر ڕۆژێک: {"1": {"go": "07:30", "back": null}}
  Map<String, Map<String, String?>>? perDay;
  String note = '';
  String? prefDriver;
  String? replacesSub;

  /// ڕەشنووسی نوێ بە پێی ئەندامان و شوێنی ماڵ
  static Draft fresh(Cloud cloud, {String? prefDriver}) {
    final d = Draft(prefDriver: prefDriver);
    final mem = cloud.members;
    if (mem.length == 1) d.memberIds = [str(mem.first['id'])];
    final home = str(cloud.passenger['homeId']);
    if (home.isNotEmpty && cloud.place(home) != null) {
      d.fromId = home;
      final h = asMap(asMap(cloud.pax['pins'])['_home']);
      if (isGeo(h)) d.fromGeo = {'lat': (h['lat'] as num).toDouble(), 'lng': (h['lng'] as num).toDouble()};
    } else if (cloud.place('azadi') != null) {
      d.fromId = 'azadi';
    }
    return d;
  }

  String? idOf(String key) => key == 'from' ? fromId : toId;

  void setId(String key, String v) => key == 'from' ? fromId = v : toId = v;

  void setQ(String key, String v) => key == 'from' ? fromQ = v : toQ = v;

  void setGeo(String key, Map<String, double>? v) => key == 'from' ? fromGeo = v : toGeo = v;

  bool get schedOk => perDay != null ? !normPerDay(perDay!).empty : days.any((x) => x);

  bool get ready => memberIds.isNotEmpty && fromId.isNotEmpty && toId.isNotEmpty && schedOk;

  /// کاتەکان: یان یەک کات بۆ هەموو ڕۆژەکان، یان کاتی جیاواز بۆ هەر ڕۆژێک
  Json sched() {
    if (perDay != null) {
      final n = normPerDay(perDay!);
      if (!n.empty) return {'perDay': n.perDay, 'days': n.days, 'go': n.go, 'back': n.back};
    }
    return {'perDay': null, 'days': List<bool>.from(days), 'go': dir != 'back' ? go : null, 'back': dir != 'go' ? backTime : null};
  }

  String pdDefault(String d) => d == 'go' ? go : backTime;

  /// کردنەوە یان داخستنی خشتەی هەر ڕۆژێک
  void togglePerDay() {
    if (perDay != null) {
      perDay = null;
      return;
    }
    perDay = {};
    for (var i = 0; i < 7; i++) {
      if (days[i]) perDay!['$i'] = {'go': dir != 'back' ? go : null, 'back': dir != 'go' ? backTime : null};
    }
  }

  void toggleDay(int i) {
    days[i] = !days[i];
    if (perDay != null) {
      if (days[i]) {
        perDay!['$i'] ??= {'go': dir != 'back' ? go : null, 'back': dir != 'go' ? backTime : null};
      } else {
        perDay!.remove('$i');
      }
    }
  }

  void setDays(List<bool> v) {
    days = List<bool>.from(v);
    if (perDay != null) {
      perDay!.removeWhere((k, _) => !days[int.parse(k)]);
      for (var i = 0; i < 7; i++) {
        if (days[i]) perDay!['$i'] ??= {'go': dir != 'back' ? go : null, 'back': dir != 'go' ? backTime : null};
      }
    }
  }

  /// لابردن یان زیادکردنی چوون/هاتنەوەی ڕۆژێک لە خشتەکەدا
  void toggleLeg(int i, String d) {
    final e = Map<String, String?>.from(perDay?['$i'] ?? {'go': null, 'back': null});
    e[d] = e[d] == null ? pdDefault(d) : null;
    perDay?['$i'] = e;
  }

  void setLegTime(int i, String d, String v) {
    final e = Map<String, String?>.from(perDay?['$i'] ?? {'go': null, 'back': null});
    e[d] = v;
    perDay?['$i'] = e;
  }
}

/// ڕۆژە ئامادەکراوەکان: هەفتەی کاری هەرێم یەکشەممە تا پێنجشەممەیە
const kDayPresets = [('1-5', 'یەکشەممە تا پێنجشەممە'), ('0-5', 'شەممە تا پێنجشەممە'), ('0-6', 'هەموو ڕۆژێک')];

List<bool> presetDays(String k) {
  final p = k.split('-').map(int.parse).toList();
  return List.generate(7, (i) => i >= p[0] && i <= p[1]);
}

bool presetOn(List<bool> days, String k) {
  final p = presetDays(k);
  for (var i = 0; i < 7; i++) {
    if (p[i] != days[i]) return false;
  }
  return true;
}

/// جۆری گەشتی گروپێک: منداڵ هەرگیز لەگەڵ کەسی گەورەی نەناسراو سوار ناکرێت
String rideTypeFor(String chosen, List<Json> g) {
  final hasChild = g.any((m) => m['kind'] == 'child');
  final hasAdult = g.any((m) => m['kind'] != 'child');
  if (chosen == 'private') return 'private';
  if (hasChild && hasAdult) return 'family';
  if (hasChild) return 'kids';
  return 'shared';
}

extension YkDraft on Cloud {
  List<Json> draftMembers(Draft dr) => dr.memberIds.map(member).whereType<Json>().toList();

  /// نرخی مەزەندەکراوی هەر داواکارییەک (ئەگەر «تەکسی جیا» بێت بۆ هەر کەسێک یەکێک)
  List<({String names, int price, bool hasChild, int riders, String rideType})> draftQuote(Draft dr) {
    final mem = draftMembers(dr);
    final groups = dr.mode == 'separate' ? mem.map((m) => [m]).toList() : [mem];
    return groups.map((g) {
      final hasChild = g.any((m) => m['kind'] == 'child');
      final rt = rideTypeFor(dr.rideType, g);
      final price = priceFor({
        'fromId': dr.fromId,
        'toId': dr.toId,
        'fromGeo': dr.fromGeo,
        'toGeo': dr.toGeo,
        'mode': dr.mode,
        'rideType': rt,
        'riders': g.length,
        'hasChild': hasChild,
        ...dr.sched(),
      });
      return (names: Fmt.names(g.map((m) => str(m['name'])).toList()), price: price, hasChild: hasChild, riders: g.length, rideType: rt);
    }).toList();
  }

  /// شێوەیەکی داواکاری بۆ پشکنینی گونجانی شۆفێر
  Json draftAsReq(Draft dr, [String target = 'all']) {
    final mem = draftMembers(dr);
    return {
      'womanOnly': dr.womanOnly,
      'hasChild': mem.any((m) => m['kind'] == 'child'),
      'mode': dr.mode,
      'riders': dr.mode == 'one' ? mem.length : 1,
      'target': target,
      'city': passenger['city'] ?? 'erbil',
    };
  }
}
