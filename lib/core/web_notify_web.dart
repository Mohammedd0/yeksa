// وێب: ئاگادارکردنەوەی مۆبایل وەک وەشانی وێب (TK.askNotify / systemNotify ـی core.js).
// کاتێک ئەپەکە لە پشتەوەیە و ئاگادارکردنەوەیەکی نوێ دێت، بە service worker پیشان دەدرێت
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject? get _notification => globalContext['Notification'] as JSObject?;

bool get _secure => globalContext['isSecureContext']?.dartify() == true;

/// 'granted' | 'denied' | 'default' | 'unsupported' | 'insecure'
String notifyStatus() {
  final n = _notification;
  if (n == null) return 'unsupported';
  if (!_secure) return 'insecure';
  return (n['permission']?.dartify() ?? 'default').toString();
}

Future<String> askNotify() async {
  final n = _notification;
  if (n == null) return 'unsupported';
  if (!_secure) return 'insecure';
  try {
    final p = n.callMethod<JSPromise<JSString>>('requestPermission'.toJS);
    return (await p.toDart).toDart;
  } catch (_) {
    return notifyStatus();
  }
}

/// ئەپەکە لە پشتەوەیە (document.hidden)
bool appHidden() {
  final d = globalContext['document'] as JSObject?;
  return d?['hidden']?.dartify() == true;
}

void showSystemNotice(String id, String title, String body) {
  if (notifyStatus() != 'granted') return;
  final opts = <String, Object?>{'body': body, 'icon': 'icons/Icon-192.png', 'badge': 'icons/Icon-192.png', 'tag': id}.jsify();
  void fallback() {
    try {
      (_notification! as JSFunction).callAsConstructor<JSObject>(title.toJS, opts);
    } catch (_) {}
  }

  try {
    final nav = globalContext['navigator'] as JSObject;
    final sw = nav['serviceWorker'] as JSObject?;
    if (sw == null) return fallback();
    sw.callMethod<JSPromise<JSAny?>>('getRegistration'.toJS).toDart.then((reg) {
      if (reg == null) return fallback();
      (reg as JSObject).callMethod<JSAny?>('showNotification'.toJS, title.toJS, opts);
    }, onError: (_) => fallback());
  } catch (_) {
    fallback();
  }
}
