{{flutter_js}}
{{flutter_build_config}}

// یەکسا: service worker ـی Flutter (کۆنبوو) تۆمار ناکرێت. ئەو خۆی دەسڕێتەوە و پەڕەکە
// نوێ دەکاتەوە، و لەگەڵ web/sw.js (ئاگادارکردنەوە) لەسەر هەمان scope یەکتری لادەبرد،
// ئەمەش پەڕەکەی بێ کۆتایی نوێ دەکردەوە. ئێستا تەنها sw.js تۆمار دەکرێت (index.html)
_flutter.loader.load();
