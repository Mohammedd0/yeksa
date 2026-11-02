// ڕێگای گەشت: کۆدکردن و کردنەوەی polyline (لە وێبیش: flutter test --platform chrome)
import 'package:flutter_test/flutter_test.dart';

import 'package:yeksa/core/route_path.dart';

void main() {
  test('encode/decode round trip with negative steps', () {
    final pts = [
      [36.1960, 44.0480],
      [36.2005, 44.0420],
      [36.2245, 43.9985],
      [36.1900, 44.1000],
      [-33.8688, 151.2093],
      [40.7128, -74.0060],
    ];
    final back = decodePath(encodePath(pts));
    expect(back.length, pts.length);
    for (var i = 0; i < pts.length; i++) {
      expect((back[i][0] - pts[i][0]).abs() < 1e-5, true, reason: 'lat $i ${back[i]}');
      expect((back[i][1] - pts[i][1]).abs() < 1e-5, true, reason: 'lng $i ${back[i]}');
    }
  });

  test('decodes Google reference polyline', () {
    final p = decodePath('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(p.length, 3);
    expect((p[1][0] - 40.7).abs() < 1e-5 && (p[1][1] + 120.95).abs() < 1e-5, true, reason: '$p');
  });
}
