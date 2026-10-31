// «نایەم»: ئاگادارکردنەوەی شۆفێر کە ئەمڕۆ ناچن
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/actions.dart';
import '../core/cloud.dart';
import '../core/format.dart';
import '../core/sel.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

void showSkipSheet(BuildContext context, String tripId) {
  final cloud = context.read<Cloud>();
  final t = cloud.trip(tripId);
  if (t == null) return;
  // گەشتی هاوڕێی ئەم گەشتە (چوون ← هاتنەوە) لە هەمان بەشداری
  Json? found;
  for (final x in cloud.myTrips) {
    if (x['id'] != t['id'] && x['subId'] != null && x['subId'] == t['subId'] && x['status'] == 'scheduled') found = x;
  }
  final pair = found;
  var mode = 'this';
  var reason = '';
  var busy = false;
  const reasons = ['نەخۆشە', 'پشووە', 'خۆمان دەیبەین', 'گەشتمان هەیە'];
  final names = Fmt.names(cloud.names(asList(t['memberIds'])));

  showYkSheet(context, builder: (c) {
    return StatefulBuilder(builder: (c, setS) {
      final yk = c.yk;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('$names ئەمڕۆ نایەن؟', style: Ts.h2(c)),
        const SizedBox(height: 4),
        Text('شۆفێرەکە ئاگادار دەکرێتەوە و بۆ ئەم گەشتە نایەت.', style: Ts.muted(c, size: 14)),
        if (pair != null) ...[
          const SizedBox(height: 12),
          YkSeg<String>(
            options: [('this', t['dir'] == 'back' ? 'تەنها هاتنەوە' : 'تەنها چوون'), ('both', 'چوون و هاتنەوە')],
            value: mode,
            onChanged: (v) => setS(() => mode = v),
          ),
        ],
        const SizedBox(height: 14),
        Text('هۆکار (ئارەزوومەندانە)', style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w700, color: yk.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in reasons)
            GestureDetector(
              onTap: () => setS(() => reason = reason == r ? '' : r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: reason == r ? yk.act : yk.chip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(r, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: reason == r ? yk.actText : yk.text)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: busy
              ? null
              : () async {
                  setS(() => busy = true);
                  final ids = [str(t['id']), if (mode == 'both' && pair != null) str(pair['id'])];
                  await cloud.skipTrips(ids, reason);
                  if (c.mounted) Navigator.pop(c);
                  if (context.mounted) toast(context, 'شۆفێر ئاگادار کرایەوە');
                },
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: yk.danger, borderRadius: BorderRadius.circular(Yk.rMd)),
            child: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Text('ناردن بۆ شۆفێر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 8),
        YkButton('پاشگەزبوونەوە', kind: BtnKind.ghost, block: true, onPressed: () => Navigator.pop(c)),
      ]);
    });
  });
}
