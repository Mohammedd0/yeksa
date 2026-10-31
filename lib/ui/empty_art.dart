// وێنەی پەڕە بەتاڵەکان (هەمان EMPTY_ART ـی core.js)، viewBox 0 0 220 180
// ئەم فایلە خۆکار لە core.js دروست کراوە، دەستکاری مەکە.

const String kEmptyBg = r'''<rect class="ea-p" x="30" y="20" width="170" height="44" rx="22"/><rect class="ea-p" x="10" y="74" width="200" height="44" rx="22"/><rect class="ea-p" x="40" y="128" width="150" height="40" rx="20"/>''';

const Map<String, String> kEmptyArt = {
  'megaphone': r'''<path class="ea-2" d="M62 78h22l46-28v84l-46-28H62a10 10 0 0 1-10-10V88a10 10 0 0 1 10-10z"/><rect class="ea-1" x="80" y="78" width="10" height="28"/><path class="ea-1" d="M68 106h16l6 28h-14z"/><path class="ea-l" d="M144 74q10 18 0 36M156 64q18 28 0 56"/><circle class="ea-1" cx="170" cy="40" r="12"/><path class="ea-l" d="M165 40h10"/>''',
  'chat': r'''<path class="ea-1" d="M50 40h90a14 14 0 0 1 14 14v40a14 14 0 0 1-14 14H82l-20 16v-16H50a14 14 0 0 1-14-14V54a14 14 0 0 1 14-14z"/><path class="ea-l" d="M56 62h70M56 78h50"/><path class="ea-2" d="M118 86h70a12 12 0 0 1 12 12v32a12 12 0 0 1-12 12h-8v14l-16-14h-46a12 12 0 0 1-12-12V98a12 12 0 0 1 12-12z"/><circle class="ea-d" cx="132" cy="114" r="4"/><circle class="ea-d" cx="150" cy="114" r="4"/><circle class="ea-d" cx="168" cy="114" r="4"/>''',
  'bell': r'''<path class="ea-1" d="M110 34a36 36 0 0 1 36 36v26l12 18H62l12-18V70a36 36 0 0 1 36-36z"/><path class="ea-2" d="M96 120a14 14 0 0 0 28 0z"/><rect class="ea-2" x="104" y="24" width="12" height="12" rx="6"/><path class="ea-l" d="M86 70a24 24 0 0 1 14-22M158 46l10-8M162 62h12M52 46l-10-8M48 62H36"/>''',
  'calendar': r'''<path class="ea-1" d="M46 54h128v24a12 12 0 0 0 0 24v24H46v-24a12 12 0 0 0 0-24z"/><path class="ea-l" d="M126 58v66" stroke-dasharray="5 6"/><path class="ea-l" d="M62 76h46M62 92h34M62 108h40"/><circle class="ea-2" cx="150" cy="90" r="14"/><path class="ea-l" d="M144 90l4 4 8-8"/>''',
  'route': r'''<path class="ea-2" d="M30 150 L86 40 h48 L190 150z"/><path class="ea-g" d="M110 52v14M110 80v16M110 112v20"/><path class="ea-1" d="M70 100h80l8 18v18a6 6 0 0 1-6 6h-6a6 6 0 0 1-6-6v-4H80v4a6 6 0 0 1-6 6h-6a6 6 0 0 1-6-6v-18z"/><path class="ea-2" d="M78 100l8-16h48l8 16z"/><circle class="ea-d" cx="80" cy="120" r="4"/><circle class="ea-d" cx="140" cy="120" r="4"/><path class="ea-l" d="M164 30v20M154 40h20"/>''',
  'search': r'''<rect class="ea-1" x="40" y="44" width="92" height="104" rx="12"/><circle class="ea-2" cx="70" cy="74" r="12"/><path class="ea-l" d="M90 70h28M90 82h18M56 106h60M56 122h44"/><circle class="ea-1" cx="146" cy="84" r="30"/><path class="ea-l" d="M168 106l22 22" stroke-width="8"/><path class="ea-l" d="M136 84h20"/>''',
  'users': r'''<circle class="ea-2" cx="140" cy="62" r="18"/><path class="ea-2" d="M108 132a32 32 0 0 1 64 0z"/><circle class="ea-1" cx="88" cy="70" r="22"/><path class="ea-1" d="M48 146a40 40 0 0 1 80 0z"/><path class="ea-l" d="M170 34v16M162 42h16"/>''',
  'tag': r'''<path class="ea-1" d="M52 60l52-20 64 64-48 48-64-64z"/><circle class="ea-2" cx="86" cy="70" r="10"/><path class="ea-l" d="M104 98l24 24M96 112l18 18"/><circle class="ea-2" cx="170" cy="46" r="12"/><path class="ea-l" d="M165 46h10M170 41v10"/>''',
  'news': r'''<rect class="ea-1" x="46" y="36" width="116" height="116" rx="14"/><rect class="ea-2" x="60" y="50" width="88" height="34" rx="8"/><path class="ea-l" d="M60 100h88M60 116h70M60 132h50"/><rect class="ea-2" x="148" y="26" width="34" height="24" rx="8"/>''',
  'clock': r'''<circle class="ea-1" cx="110" cy="92" r="52"/><circle class="ea-2" cx="110" cy="92" r="38"/><path class="ea-l" d="M110 70v24l16 10" stroke-width="4"/><circle class="ea-d" cx="110" cy="92" r="4"/><path class="ea-l" d="M168 52l12-10M52 52l-12-10"/>''',
};

const Map<String, String> kEmptyAlias = { 'doc': 'news', 'car': 'search', 'user': 'search', 'briefcase': 'search' };
