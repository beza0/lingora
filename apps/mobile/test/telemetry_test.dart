import 'package:flutter_test/flutter_test.dart';
import 'package:lingora/services/telemetry.dart';

void main() {
  test('hata metninden e-posta, belirteç ve uzun sayılar ayıklanır', () {
    final s = Telemetry.scrub('user beyza@example.com token eyJabc.def123.ghi456 id 12345678 ok 42');
    expect(s, isNot(contains('beyza@example.com')));
    expect(s, contains('<e-posta>'));
    expect(s, contains('<token>'));
    expect(s, contains('<sayı>'));
    expect(s, contains('ok 42'));
  });
}
