// بنەڕەتەکان: یاساکان، شارەکان و پرۆفایلی بەتاڵ (هەمان core.js)
// بەڕێوەبەر لە پانێڵ دەیانگۆڕێت و لە meta/app دێن؛ ئەمانە تەنها کاتێک بەکاردێن کە هێشتا نەهاتوون.
import 'format.dart';

const String kAdminUid = 'H1rrhWrw1KRm0ZdnxK89QBetbaC3';

/// ژمارەی مۆبایل ← ئیمەیڵی ناوخۆیی (سەرنشین: p، شۆفێر: d)
String emailOf(String phone, String kind) => '$phone@$kind.taxikam.app';

const Map<String, dynamic> kConfigDefaults = {
  'commission': 0.12,
  'commissionType': 'pct',
  'commissionFixed': 10000,
  'commissionNext': null,
  'refOn': true,
  'refType': 'fixed',
  'refFixed': 5000,
  'refPct': 0.05,
  'refMax': 10000,
  'pointsPerRating': 20,
  'rewards': null,
  'faq': null,
  'contacts': <dynamic>[],
  'walletOn': false,
  'photosRequired': false,
  'skipEvery': 5,
  'skipRefundDays': 1,
  'noShowComp': 5000,
  'withdrawMin': 25000,
  'offerRange': 0.15,
  'requestHours': 48,
  'basePrice': 50000,
  'perKm': 7000,
  'oneWayFactor': 0.6,
  'privateFactor': 1.4,
  'familyFactor': 1.2,
  'kidsFactor': 1.1,
  'extraRiderFactor': 0.7,
  'skipCutoffMin': 30,
  'noShowPenalty': 5000,
  'noShowCreditMin': 4000,
  'bonusAmount': 50000,
  'bonusDays': 26,
  'debtLimit': 50000,
  'pointsPer1000': 1,
  'minDriverAge': 23,
  'minCarYear': 2010,
  'expiryWarnDays': 30,
  'securityValidDays': 180,
  'stopMin': 5,
  'poolWindowMin': 45,
  'startEarlyMin': 30,
  'absentWaitMin': 3,
  'autoCloseMin': 180,
  'nearAlertM': 500,
};

const List<Map<String, dynamic>> kCitiesDefaults = [
  {
    'id': 'erbil',
    'name': 'هەولێر',
    'districts': ['ناوەندی شار', 'عەینکاوە', 'خەبات', 'شەقڵاوە', 'سۆران', 'کۆیە', 'مەخموور', 'چۆمان', 'مێرگەسۆر'],
  },
  {
    'id': 'sulaimani',
    'name': 'سلێمانی',
    'districts': ['ناوەندی شار', 'بازیان', 'تانجەرۆ', 'دوکان', 'ڕانیە', 'پشدەر', 'پێنجوێن', 'شارەزوور', 'چەمچەماڵ', 'دەربەندیخان', 'ماوەت'],
  },
];

/// بەشەکانی pax/{uid} (ئاگادارکردنەوە و مێژوو کۆلێکشنی جیان: pnotices و phistory)
const List<String> kPaxFields = ['passenger', 'family', 'readNoticesAt', 'rewards', 'billing', 'tickets', 'seenNews', 'pins'];

/// پرۆفایلی بەتاڵی سەرنشین (emptyPassenger ـی core.js)، تەنها ئەو بەشانەی دەچنە pax/{uid}
Map<String, dynamic> emptyPax({String name = '', String phone = ''}) {
  final first = name.split(' ').first;
  final initial = name.isEmpty ? '' : name.substring(0, 1);
  final now = DateTime.now();
  return <String, dynamic>{
    'passenger': <String, dynamic>{'name': name, 'phone': phone, 'homeId': '', 'city': 'erbil', 'photo': null},
    'family': <String, dynamic>{
      'members': name.isEmpty
          ? <dynamic>[]
          : <dynamic>[
              <String, dynamic>{'id': 'm${shortId()}', 'name': first, 'initial': initial, 'kind': 'adult', 'relation': 'خاوەن ئەکاونت'},
            ],
      'guardians': name.isEmpty
          ? <dynamic>[]
          : <dynamic>[
              <String, dynamic>{'name': '$first (تۆ)', 'initial': initial},
            ],
    },
    'readNoticesAt': 0,
    'rewards': <String, dynamic>{'points': 0, 'code': '', 'redeemed': <dynamic>[], 'pending': <dynamic>[], 'used': <dynamic>[]},
    'billing': <String, dynamic>{
      'month': kMonths[now.month - 1],
      'monthKey': Fmt.monthKey(now),
      'adjustments': <dynamic>[],
      'method': 'cash',
      'paid': false,
      'promo': null,
      'history': <dynamic>[],
    },
    'tickets': <dynamic>[],
    'seenNews': <dynamic>[],
    'pins': <String, dynamic>{},
  };
}
