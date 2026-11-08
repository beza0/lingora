import '../data/content.dart';

/// Başlangıç değerlendirmesi (docs/srs.md):
/// seviye 2'den başlar; kullanıcı Anladım / Kısmen / Anlamadım der. "Anladım" her zaman kısa bir anlam
/// sorusuyla doğrulanır; 1., 3. ve 5. adımlarda "Kısmen" de doğrulanır. Doğrulanmış anlama +1, diğerleri −1.
/// 8 adımda ya da en az 5 adımdan sonra iki yön değişikliği olunca biter. Sonuç: son üç adımın ortalaması.
enum Understood { yes, partly, no }

class AssessmentStep {
  final String targetId;
  final int level;
  Understood? answer;
  bool? verified;
  AssessmentStep(this.targetId, this.level);
  Map<String, Object?> toJson() => {'target_id': targetId, 'level': level, 'answer': answer?.name, 'verified': verified};
}

class AssessmentEngine {
  final ContentRepo content;
  final String domainId;
  final int maxSteps;
  int level = 2;
  int _changes = 0;
  int _lastDir = 0;
  final steps = <AssessmentStep>[];
  final _used = <String>{};

  AssessmentEngine(this.content, this.domainId, {this.maxSteps = 8});

  bool get done => steps.length >= maxSteps || (steps.length >= 5 && _changes >= 2) || (steps.isNotEmpty && steps.last.answer != null && _pool().isEmpty);
  AssessmentStep? get current => steps.isEmpty || steps.last.answer != null ? null : steps.last;

  /// İçerikte zorluk 1–3 arasında; daha yüksek seviyelerde en zor cümleler kullanılır.
  int get _difficulty => level.clamp(1, 3);

  List<String> _pool() => content.targetsForDomain(domainId).where((t) => !_used.contains(t)).toList();

  /// Sıradaki cümleyi seçer. Aynı zorlukta yoksa en yakın zorluğa bakar.
  AssessmentStep? next() {
    if (done) return null;
    final pool = _pool();
    if (pool.isEmpty) return null;
    String? pick;
    for (var gap = 0; gap <= 2 && pick == null; gap++) {
      for (final t in pool) {
        final d = (content.targets[t]?['difficulty'] as int?) ?? 1;
        final v = content.view(t);
        if (v == null || v.exampleEn.isEmpty) continue;
        if ((d - _difficulty).abs() == gap) {
          pick = t;
          break;
        }
      }
    }
    pick ??= pool.first;
    _used.add(pick);
    final s = AssessmentStep(pick, level);
    steps.add(s);
    return s;
  }

  /// Bu cevaptan sonra anlam sorusu sorulmalı mı?
  bool needsCheck(Understood u) {
    if (u == Understood.yes) return true;
    final n = steps.length; // 1'den başlayan adım numarası
    return u == Understood.partly && (n == 1 || n == 3 || n == 5);
  }

  void answer(Understood u, {bool? verified}) {
    final s = steps.last;
    s.answer = u;
    s.verified = verified;
    final up = u == Understood.yes && verified != false;
    final dir = up ? 1 : -1;
    if (_lastDir != 0 && dir != _lastDir) _changes++;
    _lastDir = dir;
    level = (level + dir).clamp(1, 5);
  }

  int get result {
    if (steps.isEmpty) return 2;
    final last = steps.where((s) => s.answer != null).toList();
    final tail = last.length > 3 ? last.sublist(last.length - 3) : last;
    if (tail.isEmpty) return 2;
    // Son adımın sonucunu da hesaba kat: son cevaptan sonraki seviye
    final levels = [...tail.map((s) => s.level), level];
    final avg = levels.reduce((a, b) => a + b) / levels.length;
    return avg.round().clamp(1, 5);
  }

  static String summary(int level) => switch (level) {
        1 => 'Temel kelimeleri tanıyorsun. Kısa ve sık kullanılan ifadelerle başlayacağız.',
        2 => 'Günlük ifadeleri çoğunlukla anlıyorsun. Alanına özgü kelimeleri bu temelin üstüne ekleyeceğiz.',
        3 => 'Alanındaki cümleleri büyük ölçüde anlıyorsun. Daha teknik kelimeler ve kalıplarla devam edeceğiz.',
        4 => 'Alanındaki cümleleri rahat anlıyorsun. Zor kalıplara ve doğru kullanıma odaklanacağız.',
        _ => 'Bu alandaki içeriğin çoğu sana kolay gelecek. En zor hedeflerden başlayacağız.',
      };
}
