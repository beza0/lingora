import 'package:flutter_test/flutter_test.dart';
import 'package:lingora/srs/fsrs.dart';
import 'package:lingora/srs/session.dart';

void main() {
  const f = Fsrs();
  final t0 = DateTime.utc(2026, 11, 8, 10);

  CardState replay(List<(Rating, DateTime)> history) {
    var c = CardState.fresh(history.first.$2);
    for (final (r, at) in history) {
      c = f.review(c, r, at);
    }
    return c;
  }

  test('yeni kart + Good → öğrenme adımı (10 dk)', () {
    final c = f.review(CardState.fresh(t0), Rating.good, t0);
    expect(c.phase, CardPhase.learning);
    expect(c.due, t0.add(const Duration(minutes: 10)));
  });

  test('aynı geçmiş iki kez oynatılınca aynı plan', () {
    final h = [(Rating.good, t0), (Rating.good, t0.add(const Duration(minutes: 10))), (Rating.hard, t0.add(const Duration(days: 3)))];
    final a = replay(h);
    final b = replay(h);
    expect(a.due, b.due);
    expect(a.stability, b.stability);
    expect(a.difficulty, b.difficulty);
  });

  test('öğrenme adımları bitince tekrar durumuna geçer', () {
    var c = f.review(CardState.fresh(t0), Rating.good, t0);
    c = f.review(c, Rating.good, t0.add(const Duration(minutes: 10)));
    expect(c.phase, CardPhase.review);
    expect(c.due.isAfter(t0.add(const Duration(hours: 23))), isTrue);
  });

  test('Hard aralığı Good aralığından kısadır', () {
    var c = f.review(CardState.fresh(t0), Rating.good, t0);
    c = f.review(c, Rating.good, t0.add(const Duration(minutes: 10)));
    final at = c.due;
    final hard = f.review(c, Rating.hard, at);
    final good = f.review(c, Rating.good, at);
    expect(hard.due.isBefore(good.due) || hard.due == good.due, isTrue);
    expect(hard.stability, lessThan(good.stability));
  });

  test('Again → hata sayısı artar, yeniden öğrenme', () {
    var c = f.review(CardState.fresh(t0), Rating.good, t0);
    c = f.review(c, Rating.good, t0.add(const Duration(minutes: 10)));
    final lapse = f.review(c, Rating.again, c.due);
    expect(lapse.lapses, 1);
    expect(lapse.phase, CardPhase.relearning);
    expect(lapse.due, c.due.add(const Duration(minutes: 10)));
  });

  test('30 gün ara sonra kart sıfırlanmaz, tekrar zamanı gelmiş görünür', () {
    var c = f.review(CardState.fresh(t0), Rating.good, t0);
    c = f.review(c, Rating.good, t0.add(const Duration(minutes: 10)));
    final later = t0.add(const Duration(days: 30));
    expect(statusOf(c, later), TargetStatus.due);
    expect(c.reps, 2);
  });

  test('aralık 365 günü geçmez', () {
    expect(f.nextIntervalDays(100000), 365);
    expect(f.nextIntervalDays(0.01), 1);
  });

  test('kart JSON gidiş-dönüş', () {
    final c = f.review(CardState.fresh(t0), Rating.good, t0);
    final back = CardState.fromJson(c.toJson());
    expect(back.due, c.due);
    expect(back.phase, c.phase);
    expect(back.step, c.step);
  });

  test('cevap → puan eşlemesi; Easy hiçbir zaman otomatik verilmez', () {
    expect(ratingFor(Outcome.correct, hintsUsed: 0), Rating.good);
    expect(ratingFor(Outcome.correctWithHint, hintsUsed: 1), Rating.hard);
    expect(ratingFor(Outcome.correctWithHint, hintsUsed: 2), Rating.again);
    expect(ratingFor(Outcome.minorSpelling, hintsUsed: 0), Rating.hard);
    expect(ratingFor(Outcome.incorrect, hintsUsed: 0), Rating.again);
    for (final o in Outcome.values) {
      expect(ratingFor(o, hintsUsed: 0), isNot(Rating.easy));
    }
  });
}
