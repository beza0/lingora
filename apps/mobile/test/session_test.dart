import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingora/data/content.dart';
import 'package:lingora/data/local_store.dart';
import 'package:lingora/data/user_data.dart';
import 'package:lingora/srs/fsrs.dart';
import 'package:lingora/srs/session.dart';

void main() {
  late ContentRepo content;
  final now = DateTime.utc(2026, 11, 8, 10);

  setUpAll(() {
    content = ContentRepo.fromJsonString(File('assets/content/content.json').readAsStringSync());
  });

  test('içerik paketi: 4 alan, 12 paket, 360 hedef, her hedefin görünümü var', () {
    expect(content.domainList.length, 4);
    expect(content.packs.length, 12);
    expect(content.targets.length, 360);
    for (final id in content.targets.keys) {
      final v = content.view(id);
      expect(v, isNotNull, reason: id);
      expect(v!.headline, isNotEmpty);
      expect(v.meaningTr, isNotEmpty);
    }
  });

  test('her alanda 90 hedef, paket sırasıyla', () {
    for (final d in ['general', 'software', 'engineering', 'yds']) {
      expect(content.targetsForDomain(d).length, 90, reason: d);
    }
  });

  test('alıştırmaların cevabı seçeneklerin içinde', () {
    for (final e in content.exercises.values) {
      final prompt = e['prompt'] as Map;
      final answer = e['answer'] as Map;
      if (prompt['options'] != null) {
        final i = answer['index'] as int;
        expect(i, inInclusiveRange(0, (prompt['options'] as List).length - 1), reason: e['id'] as String);
      }
    }
  });

  test('ilk oturum: 5 yeni hedef, tanıtım + alıştırmalar, tekrar yok', () {
    final plan = buildSession(content: content, domainId: 'software', cards: {}, level: 2, now: now);
    expect(plan.newTargets.length, 5);
    expect(plan.dueTargets, isEmpty);
    expect(plan.steps.where((s) => s.kind == StepKind.intro).length, 5);
    expect(plan.steps.first.kind, StepKind.intro);
    for (final s in plan.steps.where((s) => s.kind == StepKind.exercise)) {
      expect(content.exercises.containsKey(s.exerciseId), isTrue);
    }
  });

  test('tekrar zamanı gelen kartlar önce, en fazla 10', () {
    final cards = <String, CardState>{};
    final ids = content.targetsForDomain('general').take(15).toList();
    for (final id in ids) {
      var c = const Fsrs().review(CardState.fresh(now.subtract(const Duration(days: 20))), Rating.good, now.subtract(const Duration(days: 20)));
      c = const Fsrs().review(c, Rating.good, now.subtract(const Duration(days: 20)).add(const Duration(minutes: 10)));
      cards[id] = c;
    }
    final plan = buildSession(content: content, domainId: 'general', cards: cards, level: 2, now: now);
    expect(plan.dueTargets.length, 10);
    expect(plan.newTargets.every((t) => !cards.containsKey(t)), isTrue);
  });

  test('50+ bekleyen tekrar varsa yeni hedef 3e iner', () {
    final cards = <String, CardState>{};
    final past = now.subtract(const Duration(days: 30));
    for (final id in content.targetsForDomain('yds').take(60)) {
      cards[id] = const Fsrs().review(CardState.fresh(past), Rating.good, past);
    }
    final plan = buildSession(content: content, domainId: 'yds', cards: cards, level: 2, now: now);
    expect(plan.reducedNew, isTrue);
    expect(plan.newTargets.length, 3);
  });

  test('seviye ayarı', () {
    expect(adjustLevel(2, List.filled(20, true)), 3);
    expect(adjustLevel(2, List.filled(20, false)), 1);
    expect(adjustLevel(2, List.filled(5, false)), 2);
    expect(adjustLevel(5, List.filled(20, true)), 5);
  });

  test('kullanıcı verisi: cevap kaydı, kart güncelleme, yeniden hesaplama aynı sonucu verir', () async {
    final u = UserData(MemoryStore());
    await u.load();
    final id = content.targetsForDomain('software').first;
    await u.recordAnswer(targetId: id, domainId: 'software', exerciseId: null, sessionId: 's', skill: 'vocab', outcome: Outcome.correct, hintsUsed: 0, scheduled: true, at: now);
    await u.recordAnswer(targetId: id, domainId: 'software', exerciseId: null, sessionId: 's', skill: 'vocab', outcome: Outcome.incorrect, hintsUsed: 0, scheduled: false, at: now.add(const Duration(minutes: 1)));
    await u.recordAnswer(targetId: id, domainId: 'software', exerciseId: null, sessionId: 's', skill: 'vocab', outcome: Outcome.correct, hintsUsed: 0, scheduled: true, at: now.add(const Duration(minutes: 11)));
    final live = u.cards[id]!;
    u.cards.clear();
    await u.recomputeCards();
    expect(u.cards[id]!.due, live.due);
    expect(u.cards[id]!.reps, 2); // planlanmayan deneme sayılmaz
    expect(u.events.length, 3);
  });

  test('kaydetme kart durumunu değiştirmez', () async {
    final u = UserData(MemoryStore());
    await u.load();
    final id = content.targetsForDomain('general').first;
    await u.toggleSaved(id);
    expect(u.isSaved(id), isTrue);
    expect(u.cards.containsKey(id), isFalse);
    await u.toggleSaved(id);
    expect(u.isSaved(id), isFalse);
  });
}
