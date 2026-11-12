import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../srs/fsrs.dart';
import '../srs/session.dart';
import 'local_store.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

class UserDomain {
  final String domainId;
  bool active;
  int level;
  int sort;
  UserDomain(this.domainId, {this.active = true, this.level = 2, this.sort = 0});
  Map<String, Object?> toJson() => {'domain_id': domainId, 'active': active, 'level': level, 'sort': sort};
  factory UserDomain.fromJson(Map<String, Object?> j) =>
      UserDomain(j['domain_id'] as String, active: j['active'] as bool? ?? true, level: (j['level'] as num?)?.toInt() ?? 2, sort: (j['sort'] as num?)?.toInt() ?? 0);
}

class SavedItem {
  final String id;
  final String? targetId;
  final String? customId;
  final DateTime createdAt;
  bool deleted;
  SavedItem({required this.id, this.targetId, this.customId, required this.createdAt, this.deleted = false});
  Map<String, Object?> toJson() => {'id': id, 'target_id': targetId, 'custom_id': customId, 'created_at': createdAt.toIso8601String(), 'deleted': deleted};
  factory SavedItem.fromJson(Map<String, Object?> j) => SavedItem(
        id: j['id'] as String,
        targetId: j['target_id'] as String?,
        customId: j['custom_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        deleted: j['deleted'] as bool? ?? false,
      );
}

class CustomItem {
  final String id;
  String textEn;
  String? meaningTr;
  String? note;
  final String? domainId;
  final String source; // manual | extracted | ai
  bool deleted;
  CustomItem({required this.id, required this.textEn, this.meaningTr, this.note, this.domainId, required this.source, this.deleted = false});
  Map<String, Object?> toJson() =>
      {'id': id, 'text_en': textEn, 'meaning_tr': meaningTr, 'note': note, 'domain_id': domainId, 'source': source, 'deleted': deleted};
  factory CustomItem.fromJson(Map<String, Object?> j) => CustomItem(
        id: j['id'] as String,
        textEn: j['text_en'] as String,
        meaningTr: j['meaning_tr'] as String?,
        note: j['note'] as String?,
        domainId: j['domain_id'] as String?,
        source: j['source'] as String? ?? 'manual',
        deleted: j['deleted'] as bool? ?? false,
      );
}

class AnswerEvent {
  final String id;
  final String targetId;
  final String? exerciseId;
  final String? sessionId;
  final String domainId;
  final String skill;
  final Outcome outcome;
  final Rating rating;
  final int hintsUsed;
  final bool scheduled;
  final DateTime answeredAt;
  bool synced;

  AnswerEvent({
    required this.id,
    required this.targetId,
    required this.exerciseId,
    required this.sessionId,
    required this.domainId,
    required this.skill,
    required this.outcome,
    required this.rating,
    required this.hintsUsed,
    required this.scheduled,
    required this.answeredAt,
    this.synced = false,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'target_id': targetId,
        'exercise_id': exerciseId,
        'session_id': sessionId,
        'domain_id': domainId,
        'skill': skill,
        'outcome': outcomeDb(outcome),
        'rating': rating.value,
        'hints_used': hintsUsed,
        'scheduled': scheduled,
        'answered_at': answeredAt.toUtc().toIso8601String(),
        'synced': synced,
      };

  factory AnswerEvent.fromJson(Map<String, Object?> j) => AnswerEvent(
        id: j['id'] as String,
        targetId: j['target_id'] as String,
        exerciseId: j['exercise_id'] as String?,
        sessionId: j['session_id'] as String?,
        domainId: j['domain_id'] as String? ?? 'general',
        skill: j['skill'] as String? ?? 'vocab',
        outcome: Outcome.values.firstWhere((o) => outcomeDb(o) == j['outcome'], orElse: () => Outcome.incorrect),
        rating: RatingValue.fromValue((j['rating'] as num).toInt()),
        hintsUsed: (j['hints_used'] as num?)?.toInt() ?? 0,
        scheduled: j['scheduled'] as bool? ?? true,
        answeredAt: DateTime.parse(j['answered_at'] as String),
        synced: j['synced'] as bool? ?? false,
      );
}

class SkillStat {
  int attempts = 0;
  int unaided = 0;
}

/// Uygulamanın kullanıcı verisi: kartlar, cevap olayları, kayıtlar, alanlar ve ayarlar.
/// Her şey önce cihaza yazılır; eşitleme ayrı çalışır (sync.dart).
class UserData extends ChangeNotifier {
  final LocalStore store;
  final Fsrs fsrs;
  UserData(this.store, {this.fsrs = const Fsrs()});

  /// Hedefin alanını bulur (içerik deposundan); sunucudan gelen olaylarda kullanılır.
  String Function(String targetId)? domainOf;

  final Map<String, CardState> cards = {};
  final List<AnswerEvent> events = [];
  final List<UserDomain> domains = [];
  final List<SavedItem> saved = [];
  final List<CustomItem> custom = [];
  String themeMode = 'system';
  double ttsRate = 0.45;
  bool soundOn = true;
  int dailyGoal = 15; // günlük hedef: cevaplanan alıştırma + söylenen cümle sayısı
  int? reminderHour; // günlük hatırlatma saati (yalnız telefon uygulamasında); null = kapalı
  final Map<String, int> speakLog = {}; // gün (yyyy-MM-dd) → söylenen cümle
  final Map<String, List<int>> speakScores = {}; // gün → puanlar (%)
  final Set<String> assessed = {};
  bool onboarded = false;
  bool dirtyMeta = false;
  int termsVersion = 0; // kabul edilen kullanım şartları / gizlilik sürümü
  bool aiConsent = false; // AI özellikleri için yurt dışına aktarım açık rızası
  bool usageStats = true; // anonim kullanım istatistikleri
  String? learningGoal; // ilk açılışta seçilen hedef (is, sinav, seyahat, gunluk)

  Future<void> load() async {
    final cardRows = await store.allCards();
    cards
      ..clear()
      ..addAll(cardRows.map((k, v) => MapEntry(k, CardState.fromJson(v))));
    events
      ..clear()
      ..addAll((await store.allEvents()).map(AnswerEvent.fromJson));
    domains
      ..clear()
      ..addAll(_list(await store.getKv('domains')).map(UserDomain.fromJson));
    saved
      ..clear()
      ..addAll(_list(await store.getKv('saved')).map(SavedItem.fromJson));
    custom
      ..clear()
      ..addAll(_list(await store.getKv('custom')).map(CustomItem.fromJson));
    final settings = _map(await store.getKv('settings'));
    themeMode = settings['theme'] as String? ?? 'system';
    ttsRate = (settings['tts_rate'] as num?)?.toDouble() ?? 0.45;
    soundOn = settings['sound'] as bool? ?? true;
    dailyGoal = (settings['daily_goal'] as num?)?.toInt() ?? 15;
    reminderHour = (settings['reminder_hour'] as num?)?.toInt();
    final sl = _map(await store.getKv('speak_log'));
    speakLog
      ..clear()
      ..addAll(sl.map((k, v) => MapEntry(k, (v as num).toInt())));
    final ss = _map(await store.getKv('speak_scores'));
    speakScores
      ..clear()
      ..addAll(ss.map((k, v) => MapEntry(k, ((v as List?) ?? const []).map((e) => (e as num).toInt()).toList())));
    assessed
      ..clear()
      ..addAll(((settings['assessed'] as List?) ?? const []).cast<String>());
    onboarded = settings['onboarded'] as bool? ?? false;
    termsVersion = (settings['terms_version'] as num?)?.toInt() ?? 0;
    aiConsent = settings['ai_consent'] as bool? ?? false;
    learningGoal = settings['learning_goal'] as String?;
    usageStats = settings['usage_stats'] as bool? ?? true;
    dirtyMeta = (await store.getKv('dirty_meta')) == '1';
    notifyListeners();
  }

  static List<Map<String, Object?>> _list(String? raw) =>
      raw == null ? const [] : (jsonDecode(raw) as List).map((e) => (e as Map).cast<String, Object?>()).toList();
  static Map<String, Object?> _map(String? raw) => raw == null ? const {} : (jsonDecode(raw) as Map).cast<String, Object?>();

  Future<void> _saveMeta({bool dirty = true}) async {
    await store.putKv('domains', jsonEncode(domains.map((d) => d.toJson()).toList()));
    await store.putKv('saved', jsonEncode(saved.map((s) => s.toJson()).toList()));
    await store.putKv('custom', jsonEncode(custom.map((c) => c.toJson()).toList()));
    if (dirty) {
      dirtyMeta = true;
      await store.putKv('dirty_meta', '1');
    }
  }

  Future<void> _saveSettings() =>
      store.putKv('settings', jsonEncode({
        'theme': themeMode,
        'tts_rate': ttsRate,
        'sound': soundOn,
        'onboarded': onboarded,
        'assessed': assessed.toList(),
        'daily_goal': dailyGoal,
        if (reminderHour != null) 'reminder_hour': reminderHour,
        'terms_version': termsVersion,
        'ai_consent': aiConsent,
        'usage_stats': usageStats,
        if (learningGoal != null) 'learning_goal': learningGoal,
      }));

  Future<void> clearMetaDirty() async {
    dirtyMeta = false;
    await store.putKv('dirty_meta', '0');
  }

  // ------------------------------------------------------------ alanlar
  List<UserDomain> get activeDomains => domains.where((d) => d.active).toList()..sort((a, b) => a.sort.compareTo(b.sort));
  UserDomain? domain(String id) => domains.where((d) => d.domainId == id).firstOrNull;

  Future<void> setDomains(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final d = domain(ids[i]);
      if (d == null) {
        domains.add(UserDomain(ids[i], sort: i));
      } else {
        d.active = true;
        d.sort = i;
      }
    }
    for (final d in domains) {
      if (!ids.contains(d.domainId)) d.active = false;
    }
    await _saveMeta();
    notifyListeners();
  }

  Future<void> setLevel(String domainId, int level) async {
    final d = domain(domainId) ?? (UserDomain(domainId)..active = false);
    if (!domains.contains(d)) domains.add(d);
    d.level = level.clamp(1, 5);
    await _saveMeta();
    notifyListeners();
  }

  // ------------------------------------------------------------ ayarlar
  Future<void> completeOnboarding() async {
    onboarded = true;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setTheme(String mode) async {
    themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  /// Seviye testi bitti: seçilen seviye kaydedilir.
  Future<void> completeAssessment(String domainId, int level) async {
    assessed.add(domainId);
    await _saveSettings();
    await setLevel(domainId, level);
  }

  /// Kullanım şartları ve gizlilik metni sürümü. Metin değişince artırılır; kullanıcı yeniden onaylar.
  static const currentTermsVersion = 1;
  bool get needsConsent => termsVersion < currentTermsVersion;

  Future<void> acceptTerms({required bool ai}) async {
    termsVersion = currentTermsVersion;
    aiConsent = ai;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAiConsent(bool on) async {
    aiConsent = on;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setUsageStats(bool on) async {
    usageStats = on;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLearningGoal(String goal) async {
    learningGoal = goal;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setSound(bool on) async {
    soundOn = on;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDailyGoal(int g) async {
    dailyGoal = g.clamp(5, 100);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setReminderHour(int? h) async {
    reminderHour = h;
    await _saveSettings();
    notifyListeners();
  }

  // ------------------------------------------------------------ etkinlik, seri, ilerleme
  static String dayKey(DateTime t) {
    final l = t.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  /// Gün başına etkinlik sayısı (cevaplar + söylenen cümleler).
  Map<String, int> activityByDay() {
    final m = <String, int>{};
    for (final e in events) {
      final k = dayKey(e.answeredAt);
      m[k] = (m[k] ?? 0) + 1;
    }
    speakLog.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
    return m;
  }

  int todayCount([DateTime? now]) => activityByDay()[dayKey(now ?? DateTime.now())] ?? 0;

  /// Art arda çalışılan gün sayısı. Bugün henüz çalışılmadıysa dünden geriye sayılır.
  int streak([DateTime? now]) {
    final days = activityByDay();
    var d = (now ?? DateTime.now()).toLocal();
    d = DateTime(d.year, d.month, d.day);
    if ((days[dayKey(d)] ?? 0) == 0) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while ((days[dayKey(d)] ?? 0) > 0) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  int bestStreak() {
    final keys = activityByDay().entries.where((e) => e.value > 0).map((e) => DateTime.parse(e.key)).toList()..sort();
    var best = 0, cur = 0;
    DateTime? prev;
    for (final d in keys) {
      final gap = prev == null ? 0 : DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(prev.year, prev.month, prev.day)).inDays;
      cur = gap == 1 ? cur + 1 : 1;
      if (cur > best) best = cur;
      prev = d;
    }
    return best;
  }

  /// Son [days] günün etkinlik sayıları (eskiden yeniye).
  List<(DateTime, int)> lastDays(int days, [DateTime? now]) {
    final m = activityByDay();
    final t = (now ?? DateTime.now()).toLocal();
    return [
      for (var i = days - 1; i >= 0; i--)
        (() {
          final d = DateTime(t.year, t.month, t.day - i);
          return (d, m[dayKey(d)] ?? 0);
        })(),
    ];
  }

  Future<void> logSpeech(int scorePercent, [DateTime? now]) async {
    final k = dayKey(now ?? DateTime.now());
    speakLog[k] = (speakLog[k] ?? 0) + 1;
    (speakScores[k] ??= []).add(scorePercent.clamp(0, 100));
    await store.putKv('speak_log', jsonEncode(speakLog));
    await store.putKv('speak_scores', jsonEncode(speakScores));
    notifyListeners();
  }

  Future<void> setTtsRate(double r) async {
    ttsRate = r;
    await _saveSettings();
    notifyListeners();
  }

  // ------------------------------------------------------------ cevaplar
  /// Cevabı kaydeder; `scheduled` ise FSRS kart durumunu günceller.
  Future<AnswerEvent> recordAnswer({
    required String targetId,
    required String domainId,
    required String? exerciseId,
    required String? sessionId,
    required String skill,
    required Outcome outcome,
    required int hintsUsed,
    required bool scheduled,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now().toUtc();
    final rating = ratingFor(outcome, hintsUsed: hintsUsed);
    final e = AnswerEvent(
      id: newId(),
      targetId: targetId,
      exerciseId: exerciseId,
      sessionId: sessionId,
      domainId: domainId,
      skill: skill,
      outcome: outcome,
      rating: rating,
      hintsUsed: hintsUsed,
      scheduled: scheduled,
      answeredAt: now,
    );
    events.add(e);
    await store.addEvent(e.toJson());
    if (scheduled) {
      final next = fsrs.review(cards[targetId] ?? CardState.fresh(now), rating, now);
      cards[targetId] = next;
      await store.putCard(targetId, next.toJson());
    }
    notifyListeners();
    return e;
  }

  /// Kart durumlarını olay geçmişinden yeniden kurar (birleştirme ve yeni cihaz sonrası).
  Future<void> recomputeCards({Set<String>? only}) async {
    final byTarget = <String, List<AnswerEvent>>{};
    for (final e in events) {
      if (!e.scheduled) continue;
      if (only != null && !only.contains(e.targetId)) continue;
      byTarget.putIfAbsent(e.targetId, () => []).add(e);
    }
    for (final entry in byTarget.entries) {
      entry.value.sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
      var c = CardState.fresh(entry.value.first.answeredAt);
      for (final e in entry.value) {
        c = fsrs.review(c, e.rating, e.answeredAt);
      }
      cards[entry.key] = c;
      await store.putCard(entry.key, c.toJson());
    }
    notifyListeners();
  }

  /// Sunucudan gelen olayları ekler (yinelenenler atlanır).
  Future<int> mergeRemoteEvents(List<AnswerEvent> remote) async {
    final known = events.map((e) => e.id).toSet();
    var added = 0;
    for (final e in remote) {
      if (known.contains(e.id)) continue;
      e.synced = true;
      events.add(e);
      await store.addEvent(e.toJson());
      added++;
    }
    events.sort((a, b) => a.answeredAt.compareTo(b.answeredAt));
    return added;
  }

  // ------------------------------------------------------------ kayıtlar
  bool isSaved(String targetId) => saved.any((s) => s.targetId == targetId && !s.deleted);

  Future<void> toggleSaved(String targetId) async {
    final existing = saved.where((s) => s.targetId == targetId).firstOrNull;
    if (existing == null) {
      saved.add(SavedItem(id: newId(), targetId: targetId, createdAt: DateTime.now().toUtc()));
    } else {
      existing.deleted = !existing.deleted;
    }
    await _saveMeta();
    notifyListeners();
  }

  Future<CustomItem> addCustom({required String textEn, String? meaningTr, String? note, String? domainId, required String source}) async {
    final c = CustomItem(id: newId(), textEn: textEn.trim(), meaningTr: meaningTr, note: note, domainId: domainId, source: source);
    custom.add(c);
    saved.add(SavedItem(id: newId(), customId: c.id, createdAt: DateTime.now().toUtc()));
    await _saveMeta();
    notifyListeners();
    return c;
  }

  Future<void> deleteCustom(String id) async {
    for (final c in custom.where((c) => c.id == id)) {
      c.deleted = true;
    }
    for (final s in saved.where((s) => s.customId == id)) {
      s.deleted = true;
    }
    await _saveMeta();
    notifyListeners();
  }

  List<SavedItem> get visibleSaved => saved.where((s) => !s.deleted).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ------------------------------------------------------------ istatistik
  int dueCount(Iterable<String> targetIds, DateTime now) {
    final set = targetIds.toSet();
    return cards.entries.where((e) => set.contains(e.key) && e.value.phase != CardPhase.newCard && !e.value.due.isAfter(now)).length;
  }

  int startedCount(Iterable<String> targetIds) {
    final set = targetIds.toSet();
    return cards.keys.where(set.contains).length;
  }

  Map<String, SkillStat> skillStats({String? domainId}) {
    final m = <String, SkillStat>{};
    for (final e in events) {
      if (!e.scheduled) continue;
      if (domainId != null && e.domainId != domainId) continue;
      final s = m.putIfAbsent(e.skill, SkillStat.new);
      s.attempts++;
      if (e.outcome == Outcome.correct) s.unaided++;
    }
    return m;
  }

  /// Bu hafta (Pazartesiden itibaren, yerel saat) çalışılan günler.
  /// Etkinlik olan günler (cevap veya konuşma pratiği).
  Set<DateTime> activeDays() => activityByDay().entries.where((e) => e.value > 0).map((e) {
        final d = DateTime.parse(e.key);
        return DateTime(d.year, d.month, d.day);
      }).toSet();

  List<bool> firstAttemptsUnaided(String domainId) =>
      events.where((e) => e.scheduled && e.domainId == domainId).map((e) => e.outcome == Outcome.correct).toList();

  Future<void> wipe() async {
    await store.wipe();
    cards.clear();
    events.clear();
    domains.clear();
    saved.clear();
    custom.clear();
    onboarded = false;
    dirtyMeta = false;
    termsVersion = 0;
    aiConsent = false;
    learningGoal = null;
    notifyListeners();
  }

  Map<String, Object?> exportJson() => {
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'domains': domains.map((d) => d.toJson()).toList(),
        'saved': saved.map((s) => s.toJson()).toList(),
        'custom_items': custom.map((c) => c.toJson()).toList(),
        'cards': cards.map((k, v) => MapEntry(k, v.toJson())),
        'review_events': events.map((e) => e.toJson()).toList(),
      };
}
