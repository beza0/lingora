import 'dart:math' as math;

import '../data/content.dart';
import 'fsrs.dart';

/// Cevabın sonucu ve FSRS puanı (docs/srs.md "Cevaptan puana").
enum Outcome { correct, correctWithHint, minorSpelling, incorrect }

String outcomeDb(Outcome o) => switch (o) {
      Outcome.correct => 'correct',
      Outcome.correctWithHint => 'correct_with_hint',
      Outcome.minorSpelling => 'minor_spelling',
      Outcome.incorrect => 'incorrect',
    };

Rating ratingFor(Outcome o, {required int hintsUsed, int maxHints = 2}) {
  if (o == Outcome.incorrect) return Rating.again;
  if (o == Outcome.correctWithHint && hintsUsed >= maxHints) return Rating.again;
  if (o == Outcome.correctWithHint || o == Outcome.minorSpelling) return Rating.hard;
  return Rating.good;
}

enum StepKind { intro, exercise }

class SessionStep {
  final StepKind kind;
  final String targetId;
  final String? exerciseId;
  final bool isNew;
  final bool isRetry;
  const SessionStep(this.kind, this.targetId, {this.exerciseId, this.isNew = false, this.isRetry = false});
}

class SessionPlan {
  final String domainId;
  final List<SessionStep> steps;
  final List<String> newTargets;
  final List<String> dueTargets;
  final bool reducedNew;
  const SessionPlan({required this.domainId, required this.steps, required this.newTargets, required this.dueTargets, required this.reducedNew});

  Duration get estimate => Duration(seconds: newTargets.length * 45 + dueTargets.length * 15);
  bool get isEmpty => steps.isEmpty;
}

/// Tekrar sırasında soru türünü değiştirmek için sıra.
const _reviewRotation = ['cloze_choice', 'recall_typing', 'listen_choice', 'meaning_choice', 'tr_to_en'];
const _patternRotation = ['tr_to_en', 'cloze_choice', 'meaning_choice'];

/// Hedef için uygun bir alıştırma seçer; [avoid] verilirse farklı türü tercih eder.
Json? pickExercise(ContentRepo c, String targetId, int reps, {String? avoidType, bool production = false}) {
  final all = c.exercisesFor(targetId).where((e) => e['type'] != 'matching' && e['type'] != 'dialogue_choice').toList();
  if (all.isEmpty) return null;
  if (production) {
    for (final t in ['recall_typing', 'tr_to_en']) {
      final m = all.where((e) => e['type'] == t).toList();
      if (m.isNotEmpty) return m.first;
    }
  }
  final isPattern = c.targets[targetId]?['kind'] == 'pattern';
  final rot = isPattern ? _patternRotation : _reviewRotation;
  for (var i = 0; i < rot.length; i++) {
    final type = rot[(reps + i) % rot.length];
    if (type == avoidType) continue;
    final m = all.where((e) => e['type'] == type).toList();
    if (m.isNotEmpty) return m.first;
  }
  return all.first;
}

/// Oturum kurucu (docs/srs.md): en fazla 10 tekrar (hatırlama olasılığı düşük olan önce) + yaklaşık 5 yeni hedef.
SessionPlan buildSession({
  required ContentRepo content,
  required String domainId,
  required Map<String, CardState> cards,
  required int level,
  required DateTime now,
  Fsrs fsrs = const Fsrs(),
  int maxReviews = 10,
  int newCount = 5,
}) {
  final domainTargets = content.targetsForDomain(domainId);
  final inDomain = domainTargets.toSet();
  final due = cards.entries
      .where((e) => inDomain.contains(e.key) && e.value.phase != CardPhase.newCard && !e.value.due.isAfter(now))
      .toList()
    ..sort((a, b) => fsrs.recallProbability(a.value, now).compareTo(fsrs.recallProbability(b.value, now)));
  final totalDue = due.length;
  final dueIds = due.take(maxReviews).map((e) => e.key).toList();

  final reduced = totalDue > 50;
  final wantNew = reduced ? math.min(3, newCount) : newCount;
  final newIds = <String>[];
  for (final t in domainTargets) {
    if (newIds.length >= wantNew) break;
    if (cards.containsKey(t)) continue;
    final diff = (content.targets[t]?['difficulty'] as int?) ?? 1;
    if (diff <= level + 1) newIds.add(t);
  }
  // Seviyeye uygun yeni hedef kalmadıysa sıradaki hedeflerden tamamla
  if (newIds.length < wantNew) {
    for (final t in domainTargets) {
      if (newIds.length >= wantNew) break;
      if (!cards.containsKey(t) && !newIds.contains(t)) newIds.add(t);
    }
  }

  final steps = <SessionStep>[];
  final reviews = <SessionStep>[];
  for (final id in dueIds) {
    final ex = pickExercise(content, id, cards[id]?.reps ?? 0);
    if (ex != null) reviews.add(SessionStep(StepKind.exercise, id, exerciseId: ex['id'] as String));
  }
  // Yeni hedefler: tanıtım + bir alıştırma; tekrarlar araya serpiştirilir.
  var r = 0;
  for (final id in newIds) {
    steps.add(SessionStep(StepKind.intro, id, isNew: true));
    final meaning = content.exercisesFor(id, type: 'meaning_choice');
    final first = meaning.isNotEmpty ? meaning.first : pickExercise(content, id, 0); // anlam sorusuyla başla
    if (first != null) steps.add(SessionStep(StepKind.exercise, id, exerciseId: first['id'] as String, isNew: true));
    if (r < reviews.length) steps.add(reviews[r++]);
  }
  while (r < reviews.length) {
    steps.add(reviews[r++]);
  }
  // İkinci alıştırma: yeni hedeflerin boşluk doldurma sorusu sona doğru
  for (final id in newIds) {
    final second = pickExercise(content, id, 0, avoidType: 'meaning_choice');
    if (second != null) steps.add(SessionStep(StepKind.exercise, id, exerciseId: second['id'] as String, isNew: true, isRetry: true));
  }
  return SessionPlan(domainId: domainId, steps: steps, newTargets: newIds, dueTargets: dueIds, reducedNew: reduced);
}

/// Alan seviyesi ayarı: son 20 ilk denemede yardımsız doğru oranı (docs/srs.md).
int adjustLevel(int level, List<bool> lastFirstAttemptsUnaided) {
  if (lastFirstAttemptsUnaided.length < 10) return level;
  final recent = lastFirstAttemptsUnaided.length > 20 ? lastFirstAttemptsUnaided.sublist(lastFirstAttemptsUnaided.length - 20) : lastFirstAttemptsUnaided;
  final rate = recent.where((x) => x).length / recent.length;
  if (rate > 0.85) return (level + 1).clamp(1, 5);
  if (rate < 0.60) return (level - 1).clamp(1, 5);
  return level;
}
