import 'package:flutter_test/flutter_test.dart';
import 'package:yeksa/core/invite_link.dart';

void main() {
  test('کۆدی بانگهێشت لە لینکی هاوبەش', () {
    expect(refFromUri(Uri.parse('https://mohammedd0.github.io/yeksa/#/register?ref=TESTP5')), 'TESTP5');
    expect(refFromUri(Uri.parse('https://x.app/yeksa/#/register?ref=school%201')), 'SCHOOL1');
    expect(refFromUri(Uri.parse('https://x.app/yeksa/?ref=abc9')), 'ABC9');
    expect(refFromUri(Uri.parse('https://x.app/yeksa/#/register')), isNull);
    expect(refFromUri(Uri.parse('https://x.app/yeksa/')), isNull);
  });
}
