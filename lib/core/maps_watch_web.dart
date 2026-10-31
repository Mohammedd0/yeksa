// وێب: Google Maps کاتێک کلیلەکە ڕەت دەکرێتەوە (Billing، ڕێگەپێنەدراو) gm_authFailure بانگ دەکات
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void installMapsWatch(void Function(String why) onFail) {
  globalContext['gm_authFailure'] = (() => onFail('auth')).toJS;
  // دێڕی <script> ـی Google Maps لە web/index.html دانەنراوە یان بار نەبوو
  final JSAny? g = globalContext['google'];
  if (g.isUndefinedOrNull || !(g as JSObject).has('maps')) onFail('script');
}
