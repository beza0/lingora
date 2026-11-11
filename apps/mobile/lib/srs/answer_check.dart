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

/// Konuşma karşılaştırması: beklenen cümlenin her kelimesi duyulan metinde (sırayla) var mı?
class SpeechWord {
  final String word; // ekranda gösterilecek hâli (noktalama dahil)
  final bool heard;
  const SpeechWord(this.word, this.heard);
}

class SpeechMatch {
  final List<SpeechWord> words;
  final String heard;
  const SpeechMatch(this.words, this.heard);
  int get matched => words.where((w) => w.heard).length;
  double get score => words.isEmpty ? 0 : matched / words.length;
  bool get good => score >= 0.8;
  bool get perfect => score >= 0.99;
}

const _contractions = {
  "i'm": 'i am', "you're": 'you are', "we're": 'we are', "they're": 'they are', "it's": 'it is', "that's": 'that is',
  "there's": 'there is', "what's": 'what is', "let's": 'let us', "don't": 'do not', "doesn't": 'does not', "didn't": 'did not',
  "can't": 'can not', "cannot": 'can not', "won't": 'will not', "isn't": 'is not', "aren't": 'are not', "wasn't": 'was not',
  "i've": 'i have', "we've": 'we have', "i'd": 'i would', "i'll": 'i will', "we'll": 'we will', "you'll": 'you will', "haven't": 'have not',
};

/// Konuşma için sadeleştirme: küçük harf, noktalama yok, kısaltmalar açık.
List<String> _speechTokens(String s) {
  final t = s.toLowerCase().replaceAll(RegExp('[’‘`]'), "'").replaceAll(RegExp(r"[^a-z0-9' ]"), ' ');
  final out = <String>[];
  for (final w in t.split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    final x = _contractions[w];
    if (x != null) {
      out.addAll(x.split(' '));
    } else {
      out.add(w.replaceAll("'", ''));
    }
  }
  return out;
}

String _numberWords(String s) {
  const n = {'0': 'zero', '1': 'one', '2': 'two', '3': 'three', '4': 'four', '5': 'five', '6': 'six', '7': 'seven', '8': 'eight', '9': 'nine', '10': 'ten', '12': 'twelve', '20': 'twenty', '30': 'thirty'};
  return s.split(RegExp(r'\s+')).map((w) {
    final core = w.replaceAll(RegExp(r'[^0-9]'), '');
    return core.isNotEmpty && core.length == w.replaceAll(RegExp(r'[.,!?;:]'), '').length ? (n[core] ?? w) : w;
  }).join(' ');
}

/// En uzun ortak alt dizi ile eşleştirir; küçük yazım farkları (1 harf) duyulmuş sayılır.
SpeechMatch matchSpeech(String expected, String heard) {
  final display = expected.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  // Her ekran kelimesi bir veya daha fazla karşılaştırma parçasına açılır ("I'm" → i, am)
  final exp = <String>[];
  final owner = <int>[];
  for (var k = 0; k < display.length; k++) {
    for (final t in _speechTokens(_numberWords(display[k]))) {
      exp.add(t);
      owner.add(k);
    }
  }
  final got = _speechTokens(_numberWords(heard));
  bool same(String a, String b) => a == b || (a.length > 3 && levenshtein(a, b) <= 1);
  final n = exp.length, m = got.length;
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = same(exp[i], got[j]) ? dp[i + 1][j + 1] + 1 : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }
  final ok = List<bool>.filled(n, false);
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (same(exp[i], got[j]) && dp[i][j] == dp[i + 1][j + 1] + 1) {
      ok[i] = true;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  final words = <SpeechWord>[];
  for (var k = 0; k < display.length; k++) {
    final parts = [for (var x = 0; x < n; x++) if (owner[x] == k) x];
    if (parts.isEmpty) continue; // yalnız noktalama
    words.add(SpeechWord(display[k], parts.every((x) => ok[x])));
  }
  return SpeechMatch(words, heard);
}
