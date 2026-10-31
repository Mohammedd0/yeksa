// پەیوەندی بە Firebase (Auth + Firestore)، هاوتای «ستۆر»ـی core.js بۆ ئەپی سەرنشین.
//
// هەمان کۆلێکشن و هەمان شێوەی بەڵگەنامەکان بەکاردێنێت کە وەشانی وێب و پانێڵی بەڕێوەبەر بەکاری دێنن،
// بۆیە هەرسێکیان پێکەوە لەسەر یەک Firebase کار دەکەن.
//
// تێبینی گرنگ: هەر تۆمارێکی هاوبەش خانەی «_r»ـی هەیە (لیستی UIDـی ئەوانەی دەتوانن بیخوێننەوە)
// و «_t» (کاتی دروستبوون بۆ ڕیزبەندی). کاتێک تۆماری نوێ دەنووسرێت، دەبێت هەردووکیان هەبن.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'defaults.dart';
import 'format.dart';

/// ڕیزبەندی لیستەکان: 1 = کۆن لە سەرەتا، -1 = نوێ لە سەرەتا (ARR ـی core.js)
const Map<String, int> kArr = {
  'requests': -1, 'subscriptions': 1, 'trips': 1, 'routes': 1, 'messages': 1, 'swaps': -1,
  'pnotices': -1, 'phistory': -1, 'news': -1, 'partners': 1, 'referrals': -1,
  'wallet': -1, 'topups': -1, 'withdraws': -1,
};

/// کۆلێکشنەکانی سەرنشین کە بە «_r» دەخوێندرێنەوە
const List<String> kPassengerShared = [
  'requests', 'subscriptions', 'trips', 'routes', 'messages', 'swaps',
  'pnotices', 'phistory', 'referrals', 'wallet', 'topups', 'withdraws',
];

class _Spec {
  final String id;
  final String? doc;
  final String? col;
  final List<Object>? where; // [field, op, value]
  final bool public;
  const _Spec(this.id, {this.doc, this.col, this.where, this.public = false});
}

class _Entry {
  Map<String, dynamic> data;
  final Set<String> holders = {};
  _Entry(this.data);
}

class Cloud extends ChangeNotifier {
  Cloud({FirebaseAuth? auth, FirebaseFirestore? db})
      : auth = auth ?? FirebaseAuth.instance,
        db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore db;

  User? user;
  String? me; // UID
  bool authKnown = false;
  bool ready = false;
  String? error;

  final Map<String, _Entry> _docs = {}; // path ← تۆمار
  final Map<String, StreamSubscription> _subs = {};
  final Set<String> _waiting = {};
  final Set<String> _unsynced = {};
  StreamSubscription<User?>? _authSub;
  Timer? _notifyT;

  /* ---------------- دەستپێکردن ---------------- */

  void start() {
    _subscribe(_specs(null));
    _authSub = auth.authStateChanges().listen(_onAuth);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    for (final s in _subs.values) {
      s.cancel();
    }
    super.dispose();
  }

  /// تەنها هەژماری سەرنشین (ئیمەیڵی @p.taxikam.app) لەم ئەپەدا قبووڵ دەکرێت
  static bool roleOk(User? u) => u != null && RegExp(r'@p\.taxikam\.app$').hasMatch(u.email ?? '');

  void _onAuth(User? u) {
    if (u != null && !roleOk(u)) {
      auth.signOut();
      u = null;
    }
    final uid = u?.uid;
    if (authKnown && uid == me) return;
    authKnown = true;
    user = u;
    me = uid;
    ready = false;
    error = null;
    _unsubscribeAll(keepPublic: true);
    _subscribe(_specs(uid));
    _checkReady();
    _scheduleNotify();
    // ئەگەر سێرڤەر وەڵامی نەدایەوە (بێ ئینتەرنێت)، ئەپ بە زانیاری ناوخۆ دەکرێتەوە
    Future.delayed(const Duration(seconds: 9), () {
      if (me == uid && !ready) {
        _waiting.clear();
        _checkReady();
      }
    });
  }

  List<_Spec> _specs(String? uid) {
    final out = <_Spec>[
      const _Spec('meta', doc: 'meta/app', public: true),
      const _Spec('partners', col: 'partners', public: true),
    ];
    if (uid == null) return out;
    out.addAll([
      _Spec('pax', doc: 'pax/$uid'),
      _Spec('acc', doc: 'accounts/$uid'),
      const _Spec('dpub', col: 'dpub'),
      const _Spec('news', col: 'news'),
    ]);
    for (final c in kPassengerShared) {
      out.add(_Spec('$c:r', col: c, where: ['_r', 'array-contains', uid]));
    }
    // شوێنی زیندووی شۆفێر لە کاتی گەشتدا (live/{driverId})
    out.add(_Spec('live:r', col: 'live', where: ['_r', 'array-contains', uid]));
    return out;
  }

  void _subscribe(List<_Spec> list) {
    for (final sp in list) {
      if (_subs.containsKey(sp.id)) continue;
      // شوێنی زیندوو چاوەڕێ ناکرێت (ئەپەکە بێ ئەوەش ئامادەیە)
      if (!sp.id.startsWith('live')) {
        _waiting.add(sp.id);
        _unsynced.add(sp.id);
      }
      _subs[sp.id] = _listen(sp);
    }
  }

  StreamSubscription _listen(_Spec sp, {int wait = 2000}) {
    void onError(Object err) {
      final code = err is FirebaseException ? err.code : '$err';
      debugPrint('گوێگرتن سەرکەوتوو نەبوو ${sp.id} $code');
      error = code;
      _unsynced.remove(sp.id);
      if (!code.contains('permission')) {
        // دوای ماوەیەک دووبارە دەست پێدەکرێتەوە
        final owner = me;
        final next = wait * 2 > 60000 ? 60000 : wait * 2;
        Future.delayed(Duration(milliseconds: next), () {
          if (me != owner || !_subs.containsKey(sp.id)) return;
          _subs[sp.id]?.cancel();
          _subs[sp.id] = _listen(sp, wait: next);
        });
      }
      if (_waiting.remove(sp.id)) _checkReady();
      _scheduleNotify();
    }

    if (sp.doc != null) {
      return db.doc(sp.doc!).snapshots(includeMetadataChanges: true).listen((snap) {
        final path = sp.doc!;
        if (snap.exists) {
          _put(sp.id, path, snap.data() ?? {});
        } else {
          _drop(sp.id, path);
        }
        _afterSnap(sp.id, snap.metadata.isFromCache);
      }, onError: onError);
    }
    Query<Map<String, dynamic>> q = db.collection(sp.col!);
    if (sp.where != null) {
      final w = sp.where!;
      final field = w[0] as String;
      final op = w[1] as String;
      final v = w[2];
      if (op == 'array-contains') {
        q = q.where(field, arrayContains: v);
      } else if (op == '==') {
        q = q.where(field, isEqualTo: v);
      }
    }
    return q.snapshots(includeMetadataChanges: true).listen((snap) {
      for (final ch in snap.docChanges) {
        final path = '${sp.col}/${ch.doc.id}';
        if (ch.type == DocumentChangeType.removed) {
          _drop(sp.id, path);
        } else {
          _put(sp.id, path, ch.doc.data() ?? {});
        }
      }
      _afterSnap(sp.id, snap.metadata.isFromCache);
    }, onError: onError);
  }

  void _put(String lid, String path, Map<String, dynamic> data) {
    // _rx: کاتی گەیشتن بەم ئامێرە (کاتژمێری مۆبایلی شۆفێر لەوانەیە جیاواز بێت)
    if (path.startsWith('live/')) data = {...data, '_rx': DateTime.now().millisecondsSinceEpoch};
    final e = _docs[path] ?? _Entry(data);
    e.data = data;
    e.holders.add(lid);
    _docs[path] = e;
  }

  void _drop(String lid, String path) {
    final e = _docs[path];
    if (e == null) return;
    e.holders.remove(lid);
    if (e.holders.isEmpty) _docs.remove(path);
  }

  void _afterSnap(String lid, bool fromCache) {
    if (!fromCache) _unsynced.remove(lid);
    if (_waiting.remove(lid)) _checkReady();
    _scheduleNotify();
  }

  void _unsubscribeAll({bool keepPublic = false}) {
    final ids = _subs.keys.toList();
    for (final id in ids) {
      if (keepPublic && (id == 'meta' || id == 'partners')) continue;
      _subs.remove(id)?.cancel();
      _waiting.remove(id);
      _unsynced.remove(id);
      _docs.removeWhere((_, e) {
        e.holders.remove(id);
        return e.holders.isEmpty;
      });
    }
  }

  void _checkReady() {
    if (ready || !authKnown || _waiting.isNotEmpty) return;
    ready = true;
    _scheduleNotify();
  }

  /// هەموو گوێگرەکان وەڵامی سێرڤەریان هاتووە (نەک تەنها بیرگەی ناوخۆ)
  bool get synced => ready && _unsynced.isEmpty;

  /// چەند گۆڕانکاری پێکەوە دەبنە یەک نوێکردنەوەی شاشە
  void _scheduleNotify() {
    if (_notifyT != null) return;
    _notifyT = Timer(Duration.zero, () {
      _notifyT = null;
      notifyListeners();
    });
  }

  /// چاوەڕێکردن تا زانیارییەکانی هەژماری ئێستا بار دەبن (زۆرترین ٢٠ چرکە)
  Future<void> whenReady([String? uid]) async {
    final t0 = DateTime.now();
    while (!(ready && (uid == null || me == uid))) {
      if (DateTime.now().difference(t0).inSeconds > 20) return;
      await Future.delayed(const Duration(milliseconds: 60));
    }
  }

  /* ---------------- خوێندنەوە ---------------- */

  Map<String, dynamic>? doc(String path) => _docs[path]?.data;

  /// هەموو تۆمارەکانی کۆلێکشنێک، بە هەمان ڕیزبەندی وەشانی وێب (بە _t)
  List<Map<String, dynamic>> list(String col) {
    final out = <Map<String, dynamic>>[];
    final prefix = '$col/';
    _docs.forEach((path, e) {
      if (!path.startsWith(prefix)) return;
      final m = Map<String, dynamic>.from(e.data);
      m['id'] ??= path.substring(prefix.length);
      out.add(m);
    });
    final dir = kArr[col] ?? 1;
    out.sort((a, b) {
      final ta = (a['_t'] as num?) ?? 0;
      final tb = (b['_t'] as num?) ?? 0;
      final c = dir * ta.compareTo(tb);
      return c != 0 ? c : '${a['id']}'.compareTo('${b['id']}');
    });
    return out;
  }

  Map<String, dynamic> get meta => doc('meta/app') ?? const {};

  /// یاساکان: بنەڕەت + ئەوەی بەڕێوەبەر گۆڕیویەتی
  Map<String, dynamic> get config => {...kConfigDefaults, ...((meta['config'] as Map?)?.cast<String, dynamic>() ?? {})};

  List<Map<String, dynamic>> get cities {
    final c = meta['cities'];
    if (c is List && c.isNotEmpty) return c.map((x) => (x as Map).cast<String, dynamic>()).toList();
    return kCitiesDefaults;
  }

  Map<String, dynamic>? city(String? id) {
    for (final c in cities) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  List<Map<String, dynamic>> get partners => list('partners');

  /// کۆدی هاوبەش (قوتابخانە، زانکۆ، کۆمپانیا) کە چالاکە
  Map<String, dynamic>? partnerByCode(String? code) {
    final c = (code ?? '').trim().toUpperCase();
    if (c.isEmpty) return null;
    for (final p in partners) {
      if (p['code'] == c && p['status'] == 'active') return p;
    }
    return null;
  }

  /// هەژماری ئێستا (accounts/{uid}): ژمارە، ناو، شار، blocked...
  Map<String, dynamic>? get account => me == null ? null : doc('accounts/$me');

  /// بەشی تایبەتی سەرنشین (pax/{uid})
  Map<String, dynamic> get pax => (me == null ? null : doc('pax/$me')) ?? const {};

  Map<String, dynamic> get passenger => (pax['passenger'] as Map?)?.cast<String, dynamic>() ?? const {};

  bool get walletOn => config['walletOn'] == true;

  /* ---------------- نووسین ---------------- */

  /// کاتی دروستبوون بۆ تۆماری نوێ (_t ـی core.js: Date.now() * 1000)
  int newStamp([int offset = 1]) => nowMs() * 1000 + offset;

  /// لیستی خوێنەران: بێ دووبارە، بێ بەتاڵ، ڕیزکراو
  static List<String> readers(Iterable<Object?> ids) {
    final s = ids.whereType<String>().where((x) => x.isNotEmpty && x != 'me').toSet().toList()..sort();
    return s;
  }

  Future<void> set(String path, Map<String, dynamic> data) => db.doc(path).set(data);

  Future<void> update(String path, Map<String, dynamic> data) => db.doc(path).update(data);

  Future<void> delete(String path) => db.doc(path).delete();

  Future<Map<String, dynamic>?> get(String path) async {
    final s = await db.doc(path).get();
    return s.exists ? s.data() : null;
  }

  /// نوێکردنەوە (TK.refresh): پەیوەندی Firestore دەپچڕێت و دووبارە دەبەسترێتەوە تا هەموو
  /// گوێگرەکان زانیاری نوێ لە سێرڤەر وەربگرن
  Future<void> refresh() async {
    try {
      await db.disableNetwork();
      await db.enableNetwork().timeout(const Duration(seconds: 4));
    } catch (_) {
      // بێ ئینتەرنێت: زانیاری ناوخۆ دەمێنێتەوە
    }
    _scheduleNotify();
  }

  /// تەنها ئەگەر بوونی نەبوو دروست دەکرێت (create ـی cloud.js)
  /// دەگەڕێنێتەوە true ئەگەر نووسرا، false ئەگەر پێشتر هەبوو
  Future<bool> createOnce(String path, Map<String, dynamic> data) {
    return db.runTransaction<bool>((tx) async {
      final r = db.doc(path);
      final cur = await tx.get(r);
      if (cur.exists) return false;
      tx.set(r, data);
      return true;
    });
  }

  /// ئاگادارکردنەوەیەک بۆ سەرنشینێک (pnotices). owner = UID
  Future<void> addNotice(String owner, Map<String, dynamic> n) {
    final id = shortId();
    return set('pnotices/$id', {
      'id': id,
      'at': nowMs(),
      ...n,
      'owner': owner,
      '_r': [owner],
      '_t': newStamp(),
    });
  }
}
