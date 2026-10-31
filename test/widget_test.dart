// تاقیکردنەوەی سادە بۆ فۆرماتکردن (Firebase پێویست نییە)
import 'package:flutter_test/flutter_test.dart';
import 'package:yeksa/core/format.dart';

void main() {
  test('ژمارەی مۆبایل', () {
    expect(cleanPhone('0770 049 1654'), '7700491654');
    expect(cleanPhone('+964 770 049 1654'), '7700491654');
    expect(cleanPhone('٠٧٧٠٠٤٩١٦٥٤'), '7700491654');
    expect(Fmt.phone('7700491654'), '0770 049 1654');
  });
}
