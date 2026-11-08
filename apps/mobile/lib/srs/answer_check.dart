/// Cevap karşılaştırma. Sunucudaki `supabase/functions/_shared/evaluation.ts` ile aynı kurallar (docs/api-contract.md §3).
enum LocalOutcome { correct, minorSpelling, unknown }

class LocalResult {
  final LocalOutcome outcome;
  final String? matched;
  const LocalResult(this.outcome, [this.matched]);
}

String normalizeAnswer(String s) {
  var t = s.toLowerCase().replaceAll(RegExp('[’‘`]'), "'");
  const pairs = {
    'i am': "i'm",
    'you are': "you're",
    'we are': "we're",
    'it is': "it's",
    'do not': "don't",
    'does not': "doesn't",
    'i have': "i've",
    'i would': "i'd",
    'i will': "i'll",
  };
  pairs.forEach((k, v) {
    t = t.replaceAll(RegExp('\\b$k\\b'), v);
  });
  t = t.replaceAll(RegExp(r'[.,!?;:"“”]'), '');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

int levenshtein(String a, String b) {
  final prev = List<int>.generate(b.length + 1, (j) => j);
  final cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = cur[j];
    }
  }
  return prev[b.length];
}

LocalResult localCheck(String answer, List<String> accepted) {
  final a = normalizeAnswer(answer);
  if (a.isEmpty) return const LocalResult(LocalOutcome.unknown);
  for (final acc in accepted) {
    if (a == normalizeAnswer(acc)) return LocalResult(LocalOutcome.correct, acc);
  }
  for (final acc in accepted) {
    final n = normalizeAnswer(acc);
    final limit = n.length > 12 ? 2 : 1;
    if (levenshtein(a, n) <= limit) return LocalResult(LocalOutcome.minorSpelling, acc);
  }
  return const LocalResult(LocalOutcome.unknown);
}
