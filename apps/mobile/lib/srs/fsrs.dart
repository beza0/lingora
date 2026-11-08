import 'dart:math' as math;

/// FSRS-5 (docs/srs.md). Rastgelelik yok: aynı olay geçmişi her cihazda aynı planı üretir.
enum Rating { again, hard, good, easy }

extension RatingValue on Rating {
  int get value => index + 1;
  static Rating fromValue(int v) => Rating.values[(v.clamp(1, 4)) - 1];
}

enum CardPhase { newCard, learning, review, relearning }

class CardState {
  final double stability;
  final double difficulty;
  final DateTime due;
  final int reps;
  final int lapses;
  final CardPhase phase;
  final int step;
  final DateTime? lastReview;

  const CardState({
    required this.stability,
    required this.difficulty,
    required this.due,
    required this.reps,
    required this.lapses,
    required this.phase,
    required this.step,
    required this.lastReview,
  });

  factory CardState.fresh(DateTime now) =>
      CardState(stability: 0, difficulty: 0, due: now, reps: 0, lapses: 0, phase: CardPhase.newCard, step: 0, lastReview: null);

  CardState copyWith({double? stability, double? difficulty, DateTime? due, int? reps, int? lapses, CardPhase? phase, int? step, DateTime? lastReview}) =>
      CardState(
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        due: due ?? this.due,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        phase: phase ?? this.phase,
        step: step ?? this.step,
        lastReview: lastReview ?? this.lastReview,
      );

  Map<String, Object?> toJson() => {
        'stability': stability,
        'difficulty': difficulty,
        'due_at': due.toUtc().toIso8601String(),
        'reps': reps,
        'lapses': lapses,
        'state': phase.index,
        'step': step,
        'last_review_at': lastReview?.toUtc().toIso8601String(),
      };

  factory CardState.fromJson(Map<String, Object?> j) => CardState(
        stability: (j['stability'] as num).toDouble(),
        difficulty: (j['difficulty'] as num).toDouble(),
        due: DateTime.parse(j['due_at'] as String),
        reps: (j['reps'] as num).toInt(),
        lapses: (j['lapses'] as num).toInt(),
        phase: CardPhase.values[(j['state'] as num).toInt().clamp(0, 3)],
        step: ((j['step'] as num?) ?? 0).toInt(),
        lastReview: j['last_review_at'] == null ? null : DateTime.parse(j['last_review_at'] as String),
      );
}

class Fsrs {
  static const List<double> w = [
    0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
    1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
  ];
  static const double decay = -0.5;
  static const double factor = 19 / 81;
  final double retention;
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int maxIntervalDays;

  const Fsrs({
    this.retention = 0.9,
    this.learningSteps = const [Duration(minutes: 1), Duration(minutes: 10)],
    this.relearningSteps = const [Duration(minutes: 10)],
    this.maxIntervalDays = 365,
  });

  double retrievability(double elapsedDays, double stability) {
    if (stability <= 0) return 0;
    return math.pow(1 + factor * elapsedDays / stability, decay).toDouble();
  }

  /// Kartın şu anki hatırlanma olasılığı (oturum sıralaması için).
  double recallProbability(CardState c, DateTime now) {
    if (c.phase == CardPhase.newCard || c.lastReview == null) return 0;
    final days = now.difference(c.lastReview!).inSeconds / 86400.0;
    return retrievability(math.max(0, days), c.stability);
  }

  int nextIntervalDays(double stability) {
    final raw = stability / factor * (math.pow(retention, 1 / decay) - 1);
    return raw.round().clamp(1, maxIntervalDays);
  }

  double _initStability(Rating r) => math.max(w[r.index], 0.1);
  double _initDifficulty(Rating r) => (w[4] - math.exp(w[5] * (r.value - 1)) + 1).clamp(1.0, 10.0);

  double _nextDifficulty(double d, Rating r) {
    final delta = -w[6] * (r.value - 3);
    final damped = d + delta * (10 - d) / 9;
    final reverted = w[7] * _initDifficulty(Rating.easy) + (1 - w[7]) * damped;
    return reverted.clamp(1.0, 10.0);
  }

  double _recallStability(double d, double s, double r, Rating rating) {
    final hard = rating == Rating.hard ? w[15] : 1.0;
    final easy = rating == Rating.easy ? w[16] : 1.0;
    return s * (math.exp(w[8]) * (11 - d) * math.pow(s, -w[9]) * (math.exp(w[10] * (1 - r)) - 1) * hard * easy + 1);
  }

  double _forgetStability(double d, double s, double r) {
    final v = w[11] * math.pow(d, -w[12]) * (math.pow(s + 1, w[13]) - 1) * math.exp(w[14] * (1 - r));
    return math.min(v, s);
  }

  double _shortTermStability(double s, Rating r) => math.max(0.1, s * math.exp(w[17] * (r.value - 3 + w[18])));

  CardState review(CardState c, Rating rating, DateTime now) {
    switch (c.phase) {
      case CardPhase.newCard:
        final s = _initStability(rating);
        final d = _initDifficulty(rating);
        final base = c.copyWith(stability: s, difficulty: d, reps: c.reps + 1, lastReview: now);
        return _learningStep(base, rating, now, learningSteps, CardPhase.learning, startStep: 0);
      case CardPhase.learning:
      case CardPhase.relearning:
        final s = _shortTermStability(c.stability, rating);
        final d = _nextDifficulty(c.difficulty, rating);
        final steps = c.phase == CardPhase.learning ? learningSteps : relearningSteps;
        final base = c.copyWith(stability: s, difficulty: d, reps: c.reps + 1, lastReview: now);
        return _learningStep(base, rating, now, steps, c.phase, startStep: c.step);
      case CardPhase.review:
        final last = c.lastReview ?? now;
        final elapsed = math.max(0.0, now.difference(last).inSeconds / 86400.0);
        final r = retrievability(elapsed, c.stability);
        final d = _nextDifficulty(c.difficulty, rating);
        if (rating == Rating.again) {
          final s = _forgetStability(c.difficulty, c.stability, r);
          return c.copyWith(
            stability: s,
            difficulty: d,
            reps: c.reps + 1,
            lapses: c.lapses + 1,
            phase: CardPhase.relearning,
            step: 0,
            lastReview: now,
            due: now.add(relearningSteps.first),
          );
        }
        final s = _recallStability(c.difficulty, c.stability, r, rating);
        return c.copyWith(
          stability: s,
          difficulty: d,
          reps: c.reps + 1,
          phase: CardPhase.review,
          step: 0,
          lastReview: now,
          due: now.add(Duration(days: nextIntervalDays(s))),
        );
    }
  }

  CardState _learningStep(CardState c, Rating rating, DateTime now, List<Duration> steps, CardPhase phase, {required int startStep}) {
    CardState graduate() => c.copyWith(phase: CardPhase.review, step: 0, due: now.add(Duration(days: nextIntervalDays(c.stability))));
    switch (rating) {
      case Rating.again:
        return c.copyWith(phase: phase, step: 0, due: now.add(steps.first));
      case Rating.hard:
        final cur = steps[startStep.clamp(0, steps.length - 1)];
        final next = startStep + 1 < steps.length ? steps[startStep + 1] : cur;
        final wait = startStep == 0 && steps.length > 1 ? Duration(seconds: (cur.inSeconds + next.inSeconds) ~/ 2) : cur;
        return c.copyWith(phase: phase, step: startStep, due: now.add(wait));
      case Rating.good:
        final nextStep = startStep + 1;
        if (nextStep >= steps.length) return graduate();
        return c.copyWith(phase: phase, step: nextStep, due: now.add(steps[nextStep]));
      case Rating.easy:
        return graduate();
    }
  }
}

/// Kullanıcıya gösterilen durum (docs/srs.md).
enum TargetStatus { fresh, due, learning, consolidating }

TargetStatus statusOf(CardState? c, DateTime now) {
  if (c == null || c.phase == CardPhase.newCard) return TargetStatus.fresh;
  if (!c.due.isAfter(now)) return TargetStatus.due;
  if (c.phase != CardPhase.review || c.stability < 21) return TargetStatus.learning;
  return TargetStatus.consolidating;
}

String statusLabel(TargetStatus s) => switch (s) {
      TargetStatus.fresh => 'Yeni',
      TargetStatus.due => 'Tekrar zamanı geldi',
      TargetStatus.learning => 'Öğreniliyor',
      TargetStatus.consolidating => 'Pekişiyor',
    };
