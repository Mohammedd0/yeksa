// چوونەژوورەوە، تۆمارکردن و چوونەدەرەوە (هەمان actions.login / register ـی core.js)
//
// سەرنشین بە ژمارەی مۆبایل و وشەی نهێنی دەچێتە ژوورەوە. لە پشتەوە ژمارەکە دەبێت بە ئیمەیڵێکی
// ناوخۆیی وەک 7501234567@p.taxikam.app، بۆیە هەمان هەژمارەکانی وەشانی وێب لێرەش کار دەکەن.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'cloud.dart';
import 'defaults.dart';
import 'format.dart';

/// ئەنجامی پشکنینی کۆدی بانگهێشت
class Invite {
  final Map<String, dynamic>? partner; // کۆدی هاوبەش (قوتابخانە، کۆمپانیا)
  final Map<String, dynamic>? friend; // {uid, name, code}
  final bool bad;
  final bool offline;
  const Invite({this.partner, this.friend, this.bad = false, this.offline = false});
}

class AuthService {
  AuthService(this.cloud);
  final Cloud cloud;

  final Map<String, Invite> _inviteCache = {};

  /// لە کاتی چوونەژوورەوە یان تۆمارکردندا: AuthGate هەمان پەڕە دەهێڵێتەوە تا کارەکە تەواو دەبێت
  final ValueNotifier<bool> busy = ValueNotifier(false);

  Future<T> _busy<T>(Future<T> Function() fn) async {
    busy.value = true;
    try {
      return await fn();
    } finally {
      busy.value = false;
    }
  }

  FirebaseAuth get _auth => cloud.auth;

  /// هەڵەکانی Firebase بە کوردی
  static String authErr(Object e) {
    final c = e is FirebaseException ? e.code : '$e';
    if (RegExp('invalid-credential|wrong-password|user-not-found|invalid-login|invalid-email').hasMatch(c)) return 'ژمارە یان وشەی نهێنی هەڵەیە';
    if (c.contains('email-already-in-use')) return 'ئەم ژمارەیە پێشتر تۆمار کراوە. بچۆ ژوورەوە';
    if (c.contains('weak-password')) return 'وشەی نهێنی دەبێت لانیکەم ٦ پیت بێت';
    if (c.contains('too-many-requests')) return 'زۆر هەوڵت دا. چەند خولەکێک چاوەڕێ بکە';
    if (c.contains('network')) return 'ئینتەرنێت نییە. دووبارە هەوڵ بدەرەوە';
    if (c.contains('operation-not-allowed')) return 'چوونەژوورەوە بە ئیمەیڵ و وشەی نهێنی لە Firebase چالاک نەکراوە';
    if (RegExp('no-user|requires-recent-login').hasMatch(c)) return 'دووبارە بچۆ ژوورەوە';
    return 'هەڵەیەک ڕوویدا ($c)';
  }

  /// چوونەژوورەوە بە ژمارە. ئەگەر هەژمارێکی کۆن بە ژمارەی 0ـدار دروست کرابێت، ئەویش تاقی دەکرێتەوە
  Future<User> _signInPhone(String p, String pass) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(email: emailOf(p, 'p'), password: pass);
      return c.user!;
    } on FirebaseAuthException catch (e) {
      if (!RegExp('user-not-found|invalid-credential|invalid-login').hasMatch(e.code)) rethrow;
      try {
        final c = await _auth.signInWithEmailAndPassword(email: emailOf('0$p', 'p'), password: pass);
        return c.user!;
      } catch (_) {
        throw e;
      }
    }
  }

  /// چوونەژوورەوە. هەڵە دەگەڕێنێتەوە، یان null ئەگەر سەرکەوتوو بوو
  Future<String?> login(String phone, String pass) => _busy(() => _login(phone, pass));

  Future<String?> _login(String phone, String pass) async {
    final p = cleanPhone(phone);
    if (!RegExp(r'^7\d{9}$').hasMatch(p)) return 'ژمارەی مۆبایل دروست نییە (وەک 7xx xxx xxxx)';
    if (pass.isEmpty) return 'وشەی نهێنی بنووسە';
    User u;
    try {
      u = await _signInPhone(p, pass);
    } catch (e) {
      return authErr(e);
    }
    await cloud.whenReady(u.uid);
    final acc = cloud.account;
    if (acc != null && acc['blocked'] == true) {
      await _auth.signOut();
      return 'ئەم ئەکاونتە ڕاگیراوە. پەیوەندی بە پشتگیری بکە';
    }
    try {
      // ئەگەر تۆمارکردن نیوەچڵ مابوو (ئینتەرنێت بڕا)، هەژمارەکە تەواو دەکرێت
      if (acc == null) {
        await cloud.set('accounts/${u.uid}', {
          'phone': p,
          'name': cloud.passenger['name'] ?? '',
          'city': cloud.passenger['city'] ?? 'erbil',
          'createdAt': nowMs(),
          'partnerId': null,
        });
      }
      if (cloud.pax.isNotEmpty && (cloud.passenger['phone'] ?? '') == '') {
        await cloud.update('pax/${u.uid}', {'passenger.phone': p});
      }
    } catch (_) {
      // دواتر دووبارە هەوڵ دەدرێتەوە
    }
    return null;
  }

  /// کۆدی بانگهێشت دەناسێتەوە: هاوبەش، هاوڕێ، یان هەڵە. بەتاڵ = null
  Future<Invite?> resolveInvite(String? code) async {
    final c = (code ?? '').trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (c.isEmpty) return null;
    final partner = cloud.partnerByCode(c);
    if (partner != null) return Invite(partner: partner);
    if (!RegExp(r'^[A-Z0-9]{4,10}$').hasMatch(c)) return const Invite(bad: true);
    final cached = _inviteCache[c];
    if (cached != null) return cached;
    var out = const Invite(bad: true);
    try {
      final d = await cloud.get('refcodes/$c');
      if (d != null && d['uid'] != null) {
        out = Invite(friend: {'uid': d['uid'], 'name': d['name'] ?? '', 'code': c});
      }
    } catch (_) {
      return const Invite(bad: true, offline: true);
    }
    _inviteCache[c] = out;
    return out;
  }

  /// بڕی داشکاندنی بانگهێشت بە دەق (بۆ نموونە «٥٬٠٠٠ دینار» یان «٥٪»)
  String refText() {
    final c = cloud.config;
    if (c['refType'] == 'pct') {
      return Fmt.n('${((c['refPct'] as num) * 100).round()}٪');
    }
    return Fmt.money(c['refFixed'] as num);
  }

  /// دروستکردنی ئەکاونتی نوێ
  Future<String?> register({
    required String name,
    required String phone,
    required String pass,
    String ref = '',
    String city = 'erbil',
    String gender = '',
  }) =>
      _busy(() => _register(name: name, phone: phone, pass: pass, ref: ref, city: city, gender: gender));

  Future<String?> _register({
    required String name,
    required String phone,
    required String pass,
    required String ref,
    required String city,
    required String gender,
  }) async {
    final p = cleanPhone(phone);
    final nm = name.trim();
    if (nm.split(RegExp(r'\s+')).length < 2) return 'ناوی تەواوت بنووسە (ناو و ناوی باوک)';
    if (!RegExp(r'^7\d{9}$').hasMatch(p)) return 'ژمارەی مۆبایل دروست نییە (وەک 7xx xxx xxxx)';
    if (pass.length < 6) return 'وشەی نهێنی دەبێت لانیکەم ٦ پیت یان ژمارە بێت';
    if (gender != 'm' && gender != 'f') return 'ڕەگەز هەڵبژێرە (نێر یان مێ)';

    final inv = await resolveInvite(ref);
    if (inv != null && inv.bad) return 'کۆدی بانگهێشت نەدۆزرایەوە. دڵنیابە لە کۆدەکە یان بەتاڵی بهێڵەوە';
    final partner = inv?.partner;
    final friend = inv?.friend;

    User u;
    try {
      final c = await _auth.createUserWithEmailAndPassword(email: emailOf(p, 'p'), password: pass);
      u = c.user!;
    } catch (e) {
      return authErr(e);
    }
    await cloud.whenReady(u.uid);

    final first = nm.split(' ').first;
    final friendOk = friend != null && friend['uid'] != u.uid && cloud.config['refOn'] == true;

    // ١. هەژمار (تەنها خۆی و بەڕێوەبەر دەیبینن)
    final account = <String, dynamic>{
      'phone': p,
      'name': nm,
      'city': city,
      'createdAt': nowMs(),
      'partnerId': partner?['id'],
      'refBy': friend != null && friend['uid'] != u.uid ? friend['uid'] : null,
    };
    // ٢. پرۆفایلی سەرنشین
    final pax = emptyPax(name: nm, phone: p);
    (pax['passenger'] as Map)['city'] = city;
    (pax['passenger'] as Map)['gender'] = gender;
    final members = (pax['family'] as Map)['members'] as List;
    if (members.isNotEmpty) (members.first as Map)['woman'] = gender == 'f';

    try {
      await cloud.set('accounts/${u.uid}', account);
      await cloud.set('pax/${u.uid}', pax);

      // ٣. بانگهێشتی هاوڕێ: هەردووکیان داشکاندن وەردەگرن کاتێک بەشداری دەکات
      if (friendOk) {
        await cloud.set('referrals/${u.uid}', {
          'id': u.uid,
          'inviter': friend['uid'],
          'invitee': u.uid,
          'inviterName': friend['name'] ?? '',
          'inviteeName': first,
          'code': friend['code'],
          'status': 'joined',
          'amount': null,
          'at': nowMs(),
          '_r': Cloud.readers([friend['uid'], u.uid]),
          '_t': cloud.newStamp(),
        });
        await cloud.addNotice(friend['uid'] as String, {
          'kind': 'info',
          'title': '$first بە کۆدەکەت هات',
          'body': 'کاتێک بەشداری بکات، هەردووکتان داشکاندن وەردەگرن',
          'link': 'rewards',
        });
      }

      // ٤. بەخێرهاتن
      await cloud.addNotice(u.uid, {
        'kind': 'info',
        'title': 'بەخێربێیت $first',
        'body': 'یەکەم بەشداری مانگانەت دروست بکە. شوێن و کات دیاری بکە و شۆفێرەکان نرخت بۆ دەنێرن.',
      });
      if (friendOk) {
        await cloud.addNotice(u.uid, {
          'kind': 'info',
          'title': 'بانگهێشتی ${(friend['name'] as String?)?.isNotEmpty == true ? friend['name'] : 'هاوڕێکەت'}',
          'body': '${refText()} داشکاندن لە یەکەم مانگی بەشدارییەکەت',
          'link': 'rewards',
        });
      }
    } catch (e) {
      return authErr(e);
    }
    // کۆدی بانگهێشتی خۆی (لە پشتەوە)
    ensureRefCode();
    return null;
  }

  bool _refBusy = false;

  /// کۆدی بانگهێشتی تایبەت (وەک YK7Q4M)، یەک جار دروست دەکرێت و دووبارە نابێتەوە
  Future<void> ensureRefCode() async {
    final me = cloud.me;
    if (_refBusy || me == null) return;
    final r = (cloud.pax['rewards'] as Map?) ?? {};
    if ((r['code'] ?? '') != '' && r['codeOk'] == true) return;
    _refBusy = true;
    try {
      for (var i = 0; i < 6; i++) {
        final code = newRefCode();
        await cloud.createOnce('refcodes/$code', {'uid': me, 'name': '${cloud.passenger['name'] ?? ''}'.split(' ').first});
        final got = await cloud.get('refcodes/$code');
        if (got != null && got['uid'] == me) {
          await cloud.update('pax/$me', {'rewards.code': code, 'rewards.codeOk': true});
          return;
        }
      }
    } catch (_) {
      // دواتر هەوڵ دەدرێتەوە
    } finally {
      _refBusy = false;
    }
  }

  /// تۆماری ژمارەکەم لە pdir (بۆ ئەوەی کەسانی تر بە ژمارە بمدۆزنەوە و پارەم بۆ بنێرن). تەنها کاتێک جزدان چالاکە
  bool _dirDone = false;
  Future<void> ensureDir() async {
    final u = cloud.user;
    final name = '${cloud.passenger['name'] ?? ''}';
    if (_dirDone || u == null || u.email == null || !cloud.walletOn || name.isEmpty) return;
    _dirDone = true;
    final parts = u.email!.split('@');
    if (parts.length != 2 || parts[1] != 'p.taxikam.app') return;
    try {
      final cur = await cloud.get('pdir/${parts[0]}');
      if (cur == null || cur['uid'] != u.uid || cur['name'] != name) {
        await cloud.set('pdir/${parts[0]}', {'uid': u.uid, 'name': name});
      }
    } catch (_) {
      _dirDone = false;
    }
  }

  /// گۆڕینی وشەی نهێنی
  Future<String?> changePassword(String oldPass, String newPass) async {
    if (newPass.length < 6) return 'وشەی نهێنی نوێ دەبێت لانیکەم ٦ پیت بێت';
    final u = _auth.currentUser;
    if (u == null) return 'دووبارە بچۆ ژوورەوە';
    try {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: oldPass));
      await u.updatePassword(newPass);
      return null;
    } on FirebaseAuthException catch (e) {
      return RegExp('invalid-credential|wrong-password').hasMatch(e.code) ? 'وشەی نهێنی ئێستا هەڵەیە' : authErr(e);
    }
  }

  /// چوونەدەرەوە و سڕینەوەی کۆپی ناوخۆی زانیارییەکان لەسەر ئەم مۆبایلە
  Future<void> logout() async {
    try {
      await cloud.db.waitForPendingWrites().timeout(const Duration(seconds: 3));
    } catch (_) {}
    await _auth.signOut();
    _dirDone = false;
    try {
      await cloud.db.clearPersistence();
    } catch (_) {
      // کاتێک گوێگر کراوەیە ناسڕدرێتەوە؛ کێشە نییە، هەژماری داهاتوو زانیاری خۆی دەبینێت
    }
  }
}
