import 'package:flutter_test/flutter_test.dart';
import 'package:lingora/srs/answer_check.dart';

/// Sunucudaki evaluation.ts ile aynı sonuçları vermeli (supabase/functions/test/handlers.test.ts).
void main() {
  test('normalleştirme: kısaltmalar, noktalama, boşluk', () {
    expect(normalizeAnswer('  I am   working on it. '), "i'm working on it");
    expect(normalizeAnswer('It is “done”!'), "it's done");
    expect(normalizeAnswer('We DO NOT know'), "we don't know");
    expect(normalizeAnswer('I’ll check'), "i'll check");
  });

  test('aynı cevap doğru', () {
    final r = localCheck("I'm working on the login page", ['I am working on the login page.']);
    expect(r.outcome, LocalOutcome.correct);
  });

  test('tek harf hatası: küçük yazım hatası', () {
    expect(localCheck('isue', ['issue']).outcome, LocalOutcome.minorSpelling);
  });

  test('uzun cevapta iki harfe kadar hata kabul', () {
    expect(localCheck('I am workng on the logn page', ['I am working on the login page.']).outcome, LocalOutcome.minorSpelling);
  });

  test('farklı cevap bilinmiyor', () {
    expect(localCheck('meeting late me', ['I will be late for the meeting.']).outcome, LocalOutcome.unknown);
    expect(localCheck('', ['issue']).outcome, LocalOutcome.unknown);
  });

  test('levenshtein', () {
    expect(levenshtein('kitten', 'sitting'), 3);
    expect(levenshtein('', 'abc'), 3);
    expect(levenshtein('abc', 'abc'), 0);
  });
}
