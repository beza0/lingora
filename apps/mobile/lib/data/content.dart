import 'dart:convert';

typedef Json = Map<String, dynamic>;

List<String> _strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

/// Öğrenme hedefinin ekranda gösterilen hâli (anlam ya da kalıp, alanına göre).
class TargetView {
  final String id;
  final String slug;
  final String kind; // sense | pattern
  final String domainId;
  final String headline; // sözcük/ifade ya da kalıp şablonu
  final String? pos;
  final String meaningTr;
  final String exampleEn;
  final String exampleTr;
  final List<String> collocations;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<Json> confusables;
  final List<String> family;
  final List<Json> chunks;
  final List<Json> slots;
  final String? otherMeaningsTr;
  final String? notesTr;
  final List<String> toneTags;
  final int difficulty;
  final bool isDraft;
  final String? grammarNoteId;

  const TargetView({
    required this.id,
    required this.slug,
    required this.kind,
    required this.domainId,
    required this.headline,
    required this.pos,
    required this.meaningTr,
    required this.exampleEn,
    required this.exampleTr,
    required this.collocations,
    required this.synonyms,
    required this.antonyms,
    required this.confusables,
    required this.family,
    required this.chunks,
    required this.slots,
    required this.otherMeaningsTr,
    required this.notesTr,
    required this.toneTags,
    required this.difficulty,
    required this.isDraft,
    required this.grammarNoteId,
  });

  bool get isPattern => kind == 'pattern';
}

/// Çevrimdışı içerik paketi (assets/content/content.json). Satırlar veritabanıyla birebir aynıdır.
class ContentRepo {
  final String version;
  final Map<String, Json> domains;
  final List<Json> packs;
  final Map<String, Json> packsById;
  final Map<String, List<String>> packTargets; // pack → hedefler (sıralı)
  final Map<String, String> targetPack; // hedef → paket
  final Map<String, Json> targets;
  final Map<String, Json> senses;
  final Map<String, Json> lexemes;
  final Map<String, Json> usagesBySenseDomain;
  final Map<String, Json> patterns;
  final Map<String, List<Json>> slotsByPattern;
  final Map<String, Json> exercises;
  final Map<String, List<Json>> exercisesByTarget;
  final Map<String, Json> grammar;
  final Map<String, List<String>> packGrammar;
  final Map<String, List<Json>> scenariosByPack;
  final Map<String, List<Json>> readingsByPack;
  final Map<String, List<Json>> writingByPack;
  final List<Json> situations;
  final Map<String, List<String>> situationItems;
  bool showDrafts;

  ContentRepo._({
    required this.version,
    required this.domains,
    required this.packs,
    required this.packsById,
    required this.packTargets,
    required this.targetPack,
    required this.targets,
    required this.senses,
    required this.lexemes,
    required this.usagesBySenseDomain,
    required this.patterns,
    required this.slotsByPattern,
    required this.exercises,
    required this.exercisesByTarget,
    required this.grammar,
    required this.packGrammar,
    required this.scenariosByPack,
    required this.readingsByPack,
    required this.writingByPack,
    required this.situations,
    required this.situationItems,
    required this.showDrafts,
  });

  factory ContentRepo.fromJsonString(String raw, {bool showDrafts = true}) {
    final d = jsonDecode(raw) as Json;
    List<Json> rows(String k) => ((d[k] as List?) ?? const []).cast<Json>();
    Map<String, Json> byId(String k) => {for (final r in rows(k)) r['id'] as String: r};
    Map<String, List<Json>> group(String k, String key) {
      final m = <String, List<Json>>{};
      for (final r in rows(k)) {
        m.putIfAbsent(r[key] as String, () => []).add(r);
      }
      return m;
    }

    final packs = rows('packs')..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    final pt = rows('pack_targets')..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    final packTargets = <String, List<String>>{};
    final targetPack = <String, String>{};
    for (final r in pt) {
      packTargets.putIfAbsent(r['pack_id'] as String, () => []).add(r['target_id'] as String);
      targetPack.putIfAbsent(r['target_id'] as String, () => r['pack_id'] as String);
    }
    final usages = <String, Json>{};
    for (final u in rows('sense_usages')) {
      usages['${u['sense_id']}|${u['domain_id']}'] = u;
    }
    final slots = group('pattern_slots', 'pattern_id');
    for (final l in slots.values) {
      l.sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    }
    final exercises = byId('exercises');
    final exByTarget = <String, List<Json>>{};
    for (final e in exercises.values) {
      exByTarget.putIfAbsent(e['target_id'] as String, () => []).add(e);
    }
    final pg = <String, List<String>>{};
    for (final r in rows('pack_grammar_notes')) {
      pg.putIfAbsent(r['pack_id'] as String, () => []).add(r['grammar_note_id'] as String);
    }
    final si = <String, List<String>>{};
    final siRows = rows('situation_items')..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    for (final r in siRows) {
      si.putIfAbsent(r['situation_id'] as String, () => []).add(r['target_id'] as String);
    }
    final situations = rows('situations')..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));

    return ContentRepo._(
      version: (d['content_version'] ?? '') as String,
      domains: byId('domains'),
      packs: packs,
      packsById: {for (final p in packs) p['id'] as String: p},
      packTargets: packTargets,
      targetPack: targetPack,
      targets: byId('learning_targets'),
      senses: byId('senses'),
      lexemes: byId('lexemes'),
      usagesBySenseDomain: usages,
      patterns: byId('patterns'),
      slotsByPattern: slots,
      exercises: exercises,
      exercisesByTarget: exByTarget,
      grammar: byId('grammar_notes'),
      packGrammar: pg,
      scenariosByPack: group('scenarios', 'pack_id'),
      readingsByPack: group('readings', 'pack_id'),
      writingByPack: group('writing_tasks', 'pack_id'),
      situations: situations,
      situationItems: si,
      showDrafts: showDrafts,
    );
  }

  /// Taslaklar yalnız test projesinde (`show_drafts = true`) görünür; arşivlenen hiçbir zaman görünmez.
  bool visible(Json? row) {
    if (row == null) return false;
    final s = row['status'] as String? ?? 'draft';
    if (s == 'archived') return false;
    return s == 'published' || showDrafts;
  }

  List<Json> get domainList {
    final l = domains.values.where(visible).toList()..sort((a, b) => (a['sort'] as int).compareTo(b['sort'] as int));
    return l;
  }

  /// CEFR seviye alanları (A1–C2); alan seçicide ayrı bölümde gösterilir.
  static const levelDomainIds = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'];
  static bool isLevelDomain(String id) => levelDomainIds.contains(id);

  List<Json> packsFor(String domainId) => packs.where((p) => p['domain_id'] == domainId && visible(p)).toList();

  /// Bir alanın hedefleri, paket sırasıyla.
  List<String> targetsForDomain(String domainId) {
    final out = <String>[];
    for (final p in packsFor(domainId)) {
      for (final t in packTargets[p['id']] ?? const <String>[]) {
        if (visible(targets[t])) out.add(t);
      }
    }
    return out;
  }

  String domainOfTarget(String targetId) => (targets[targetId]?['slug'] as String? ?? 'general:').split(':').first;

  List<Json> exercisesFor(String targetId, {String? type}) =>
      (exercisesByTarget[targetId] ?? const <Json>[]).where((e) => visible(e) && (type == null || e['type'] == type)).toList();

  TargetView? view(String targetId) {
    final t = targets[targetId];
    if (t == null) return null;
    final domain = domainOfTarget(targetId);
    final draft = (t['status'] as String? ?? 'draft') != 'published';
    if (t['kind'] == 'pattern') {
      final p = patterns[t['pattern_id']];
      if (p == null) return null;
      return TargetView(
        id: targetId,
        slug: t['slug'] as String,
        kind: 'pattern',
        domainId: domain,
        headline: p['template_en'] as String,
        pos: null,
        meaningTr: (p['template_tr'] as String?) ?? (p['example_tr'] as String),
        exampleEn: p['example_en'] as String,
        exampleTr: p['example_tr'] as String,
        collocations: const [],
        synonyms: const [],
        antonyms: const [],
        confusables: const [],
        family: const [],
        chunks: ((p['chunks'] as List?) ?? const []).cast<Json>(),
        slots: slotsByPattern[p['id']] ?? const [],
        otherMeaningsTr: null,
        notesTr: null,
        toneTags: _strings(p['tone_tags']),
        difficulty: t['difficulty'] as int,
        isDraft: draft,
        grammarNoteId: p['grammar_note_id'] as String?,
      );
    }
    final s = senses[t['sense_id']];
    if (s == null) return null;
    final l = lexemes[s['lexeme_id']];
    final u = usagesBySenseDomain['${s['id']}|$domain'];
    return TargetView(
      id: targetId,
      slug: t['slug'] as String,
      kind: 'sense',
      domainId: domain,
      headline: (l?['lemma'] as String?) ?? '',
      pos: l?['pos'] as String?,
      meaningTr: s['meaning_tr'] as String,
      exampleEn: (u?['example_en'] as String?) ?? '',
      exampleTr: (u?['example_tr'] as String?) ?? '',
      collocations: _strings(u?['collocations']),
      synonyms: _strings(u?['synonyms']),
      antonyms: _strings(u?['antonyms']),
      confusables: ((u?['confusables'] as List?) ?? const []).cast<Json>(),
      family: _strings(u?['family']),
      chunks: const [],
      slots: const [],
      otherMeaningsTr: u?['other_meanings_tr'] as String?,
      notesTr: s['notes_tr'] as String?,
      toneTags: _strings(u?['tone_tags']),
      difficulty: t['difficulty'] as int,
      isDraft: draft,
      grammarNoteId: null,
    );
  }

  /// Cümle Rehberi: bir alanın üst durumları ve alt durumları.
  List<Json> topSituations(String domainId) =>
      situations.where((s) => s['domain_id'] == domainId && s['parent_id'] == null && visible(s)).toList();
  List<Json> childSituations(String parentId) => situations.where((s) => s['parent_id'] == parentId && visible(s)).toList();
}

String posLabel(String? pos) => switch (pos) {
      'n' => 'isim',
      'v' => 'fiil',
      'adj' => 'sıfat',
      'adv' => 'zarf',
      'phrase' => 'ifade',
      'phrasal' => 'öbek fiil',
      'prep' => 'edat',
      'conj' => 'bağlaç',
      _ => pos ?? '',
    };
