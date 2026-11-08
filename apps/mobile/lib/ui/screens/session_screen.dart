import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../data/content.dart';
import '../../data/user_data.dart';
import '../../services/backend.dart';
import '../../srs/answer_check.dart';
import '../../srs/session.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'target_screen.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final String domainId;
  const SessionScreen({super.key, required this.domainId});
  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _Result {
  final Outcome outcome;
  final String? expected;
  final String? note; // seçilen yanlış seçeneğin açıklaması veya AI açıklaması
  final String? source; // local | ai | self
  final String? corrected;
  final bool englishAnswer;
  const _Result(this.outcome, {this.expected, this.note, this.source, this.corrected, this.englishAnswer = true});
  bool get ok => outcome != Outcome.incorrect;
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  late List<SessionStep> steps;
  late SessionPlan plan;
  final sessionId = newId();
  final scheduledDone = <String>{};
  final firstAttempts = <bool>[];
  int index = 0;
  int correct = 0;
  int answered = 0;
  final startedAt = DateTime.now();

  // geçerli adımın durumu
  int hintsUsed = 0;
  int? selected;
  _Result? result;
  bool checking = false;
  final typed = TextEditingController();
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    final level = user.domain(widget.domainId)?.level ?? 2;
    plan = buildSession(content: ref.read(contentProvider), domainId: widget.domainId, cards: user.cards, level: level, now: DateTime.now().toUtc());
    steps = List.of(plan.steps);
  }

  @override
  void dispose() {
    typed.dispose();
    focus.dispose();
    super.dispose();
  }

  SessionStep? get step => index < steps.length ? steps[index] : null;

  void _next() {
    setState(() {
      index++;
      hintsUsed = 0;
      selected = null;
      result = null;
      checking = false;
      typed.clear();
    });
    if (index >= steps.length) _finish();
  }

  Future<void> _finish() async {
    final user = ref.read(userProvider);
    final d = user.domain(widget.domainId);
    if (d != null && firstAttempts.isNotEmpty) {
      final next = adjustLevel(d.level, user.firstAttemptsUnaided(widget.domainId));
      if (next != d.level) await user.setLevel(widget.domainId, next);
    }
    ref.read(backendProvider).sync(user);
  }

  Future<void> _record(SessionStep s, Json ex, _Result r) async {
    final user = ref.read(userProvider);
    final scheduled = !s.isRetry && !scheduledDone.contains(s.targetId);
    if (scheduled) {
      scheduledDone.add(s.targetId);
      firstAttempts.add(r.outcome == Outcome.correct);
    }
    answered++;
    if (r.ok) correct++;
    await user.recordAnswer(
      targetId: s.targetId,
      domainId: widget.domainId,
      exerciseId: ex['id'] as String,
      sessionId: sessionId,
      skill: ex['skill'] as String? ?? 'vocab',
      outcome: r.outcome,
      hintsUsed: hintsUsed,
      scheduled: scheduled,
    );
    if (!r.ok) {
      // Yanlış: aynı hedef birkaç adım sonra farklı bir soruyla yeniden gelir.
      final content = ref.read(contentProvider);
      final again = pickExercise(content, s.targetId, (user.cards[s.targetId]?.reps ?? 0) + 1, avoidType: ex['type'] as String);
      if (again != null) {
        final pos = (index + 4).clamp(0, steps.length);
        steps.insert(pos, SessionStep(StepKind.exercise, s.targetId, exerciseId: again['id'] as String, isRetry: true));
      }
    }
  }

  Future<void> _answerChoice(SessionStep s, Json ex, int i) async {
    if (result != null) return;
    final answer = (ex['answer'] as Map)['index'] as int;
    final options = ((ex['prompt'] as Map)['options'] as List).cast<String>();
    final ok = i == answer;
    final notes = (ex['distractor_notes'] as Map?)?.cast<String, Object?>() ?? const {};
    final r = _Result(
      ok ? (hintsUsed > 0 ? Outcome.correctWithHint : Outcome.correct) : Outcome.incorrect,
      expected: options[answer],
      note: ok ? null : notes[options[i]] as String?,
      source: 'local',
      englishAnswer: ex['type'] == 'cloze_choice' || ex['type'] == 'dialogue_choice',
    );
    setState(() {
      selected = i;
      result = r;
    });
    await _record(s, ex, r);
  }

  Future<void> _answerTyped(SessionStep s, Json ex) async {
    final text = typed.text.trim();
    if (text.isEmpty || result != null || checking) return;
    final answer = (ex['answer'] as Map)['text'] as String;
    final accepted = <String>{answer, ...((ex['accepted_answers'] as List?) ?? const []).cast<String>()}.toList();
    final local = localCheck(text, accepted);
    _Result? r;
    if (local.outcome == LocalOutcome.correct) {
      r = _Result(hintsUsed > 0 ? Outcome.correctWithHint : Outcome.correct, expected: answer, source: 'local');
    } else if (local.outcome == LocalOutcome.minorSpelling) {
      r = _Result(Outcome.minorSpelling, expected: local.matched ?? answer, note: 'Küçük bir yazım farkı var.', source: 'local');
    } else if (ex['type'] == 'tr_to_en') {
      setState(() => checking = true);
      try {
        final prompt = ex['prompt'] as Map;
        final res = await ref.read(backendProvider).evaluate(
              promptTr: '“${prompt['text_tr']}” cümlesinin İngilizcesini yaz.',
              expected: answer,
              accepted: accepted,
              answer: text,
              skill: 'writing',
            );
        if (res['source'] == 'local') {
          final o = res['outcome'] == 'correct' ? Outcome.correct : Outcome.minorSpelling;
          r = _Result(o, expected: answer, source: 'local');
        } else {
          final ev = (res['evaluation'] as Map).cast<String, Object?>();
          final verdict = ev['verdict'] as String;
          final o = switch (verdict) {
            'correct' || 'acceptable' => hintsUsed > 0 ? Outcome.correctWithHint : Outcome.correct,
            'minor_error' => Outcome.minorSpelling,
            _ => Outcome.incorrect,
          };
          r = _Result(o, expected: answer, note: ev['explanation_tr'] as String?, corrected: ev['corrected'] as String?, source: 'ai');
        }
      } on ApiError catch (e) {
        // AI yoksa kullanıcı kendi cevabını örnek cevapla karşılaştırır.
        if (!mounted) return;
        setState(() => checking = false);
        final self = await _selfGrade(answer, e);
        if (self == null) return;
        r = _Result(self ? Outcome.minorSpelling : Outcome.incorrect, expected: answer, source: 'self');
      } finally {
        if (mounted) setState(() => checking = false);
      }
    } else {
      r = _Result(Outcome.incorrect, expected: answer, source: 'local');
    }
    if (!mounted) return;
    setState(() => result = r);
    await _record(s, ex, r);
  }

  Future<bool?> _selfGrade(String expected, ApiError e) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cevabını karşılaştır'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.code == 'ai_not_configured' ? 'AI değerlendirmesi şu an kullanılamıyor.' : e.message),
            const SizedBox(height: 12),
            const Text('Örnek cevap:', style: TextStyle(fontWeight: FontWeight.w600)),
            Text(expected),
            const SizedBox(height: 12),
            const Text('Senin cevabın aynı anlamı doğru bir dille veriyor mu?'),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hayır')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet')),
          ],
        ),
      );

  void _iKnowIt(SessionStep s) {
    final content = ref.read(contentProvider);
    final prod = pickExercise(content, s.targetId, 0, production: true);
    setState(() {
      for (var i = steps.length - 1; i > index; i--) {
        if (steps[i].targetId == s.targetId && steps[i].isNew) steps.removeAt(i);
      }
      if (prod != null) steps.insert(index + 1, SessionStep(StepKind.exercise, s.targetId, exerciseId: prod['id'] as String));
    });
    _next();
  }

  Future<bool> _confirmExit() async {
    if (step == null || answered == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çalışmayı bitir?'),
        content: const Text('Şimdiye kadarki cevapların kaydedildi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Devam et')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bitir')),
        ],
      ),
    );
    if (ok == true) await _finish();
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final p = context.pal;
    final s = step;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kapat',
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _confirmExit() && context.mounted) context.pop();
            },
          ),
          title: s == null
              ? null
              : ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: steps.isEmpty ? 0 : index / steps.length, minHeight: 8, backgroundColor: p.surface2),
                ),
        ),
        body: SafeArea(
          child: s == null
              ? _Summary(
                  correct: correct,
                  answered: answered,
                  newCount: plan.newTargets.length,
                  reviewCount: plan.dueTargets.length,
                  minutes: DateTime.now().difference(startedAt).inMinutes,
                  empty: plan.isEmpty,
                )
              : s.kind == StepKind.intro
                  ? _Intro(view: content.view(s.targetId), onNext: _next, onKnow: () => _iKnowIt(s))
                  : _exercise(content, s),
        ),
      ),
    );
  }

  Widget _exercise(ContentRepo content, SessionStep s) {
    final ex = content.exercises[s.exerciseId];
    if (ex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _next());
      return const SizedBox.shrink();
    }
    final p = context.pal;
    final prompt = (ex['prompt'] as Map).cast<String, Object?>();
    final type = ex['type'] as String;
    final hints = ((prompt['hints_tr'] as List?) ?? const []).cast<String>();
    final typing = type == 'recall_typing' || type == 'tr_to_en';
    final isDraft = (ex['status'] as String? ?? 'draft') != 'published';

    final body = <Widget>[
      Row(children: [
        Expanded(child: Text(prompt['instruction_tr'] as String? ?? '', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600))),
        if (isDraft) const DraftBadge(),
      ]),
      const SizedBox(height: 16),
    ];

    switch (type) {
      case 'meaning_choice':
        body.add(Row(children: [
          Expanded(child: Text(prompt['text'] as String, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
          SpeakButton(prompt['text'] as String),
        ]));
        if (prompt['sentence'] != null) {
          body.add(const SizedBox(height: 8));
          body.add(_SentenceLine(prompt['sentence'] as String));
        }
      case 'cloze_choice':
      case 'recall_typing':
        body.add(_Blank(prompt['sentence'] as String, filled: result != null ? ((ex['answer'] as Map)['text'] as String?) : null));
        if (prompt['sentence_tr'] != null) {
          body.add(const SizedBox(height: 8));
          body.add(Text(prompt['sentence_tr'] as String, style: TextStyle(color: p.muted, fontSize: 15)));
        }
      case 'listen_choice':
        body.add(Center(
          child: FilledButton.tonalIcon(
            onPressed: () => ref.read(speakerProvider).speak(prompt['audio_text'] as String, rate: ref.read(userProvider).ttsRate),
            icon: const Icon(Icons.volume_up),
            label: const Text('Dinle'),
          ),
        ));
        if (result != null) {
          body.add(const SizedBox(height: 10));
          body.add(_SentenceLine(prompt['audio_text'] as String));
        }
      case 'tr_to_en':
        body.add(Text(prompt['text_tr'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)));
      case 'dialogue_choice':
        for (final line in ((prompt['context'] as List?) ?? const []).cast<Map>()) {
          body.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${line['speaker']}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              Expanded(child: Text(line['en'] as String, style: const TextStyle(fontSize: 16))),
              SpeakButton(line['en'] as String, size: 18),
            ]),
          ));
        }
      default:
        body.add(Text(type));
    }

    // İpuçları
    if (hints.isNotEmpty && result == null) {
      body.add(const SizedBox(height: 12));
      for (var i = 0; i < hintsUsed && i < hints.length; i++) {
        body.add(Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.hintSoft, borderRadius: BorderRadius.circular(10)),
          child: Text('İpucu ${i + 1}: ${hints[i]}', style: TextStyle(color: p.hint)),
        ));
      }
      if (hintsUsed < hints.length && hintsUsed < 2) {
        body.add(Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => hintsUsed++), icon: const Icon(Icons.lightbulb_outline), label: const Text('İpucu')),
        ));
      }
    }
    body.add(const SizedBox(height: 16));

    // Cevap alanı
    if (typing) {
      body.add(TextField(
        controller: typed,
        focusNode: focus,
        enabled: result == null && !checking,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _answerTyped(s, ex),
        decoration: const InputDecoration(hintText: 'Cevabını yaz'),
      ));
    } else {
      final options = ((prompt['options'] as List?) ?? const []).cast<String>();
      final answerIndex = (ex['answer'] as Map)['index'] as int?;
      for (var i = 0; i < options.length; i++) {
        body.add(_OptionButton(
          text: options[i],
          state: result == null
              ? _Opt.idle
              : i == answerIndex
                  ? _Opt.correct
                  : i == selected
                      ? _Opt.wrong
                      : _Opt.dim,
          onTap: () => _answerChoice(s, ex, i),
        ));
      }
    }

    if (result != null) {
      body.add(const SizedBox(height: 12));
      body.add(_Feedback(
        result: result!,
        explanation: ex['explanation_tr'] as String?,
        onReport: () => showReportSheet(context, ref, entityType: 'exercise', entityId: ex['id'] as String),
        onAsk: () {
          final v = content.view(s.targetId);
          context.push('/chat/new', extra: {
            'kind': 'exercise',
            'text': v?.exampleEn ?? (prompt['sentence'] ?? prompt['text_tr'] ?? '').toString(),
            'meaning_tr': v?.meaningTr,
            'domain_id': widget.domainId,
          });
        },
      ));
    }

    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: body)),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: result != null
            ? FilledButton(onPressed: _next, child: const Text('Devam'))
            : typing
                ? FilledButton(
                    onPressed: checking ? null : () => _answerTyped(s, ex),
                    child: checking ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kontrol et'),
                  )
                : const SizedBox.shrink(),
      ),
    ]);
  }
}

class _SentenceLine extends StatelessWidget {
  final String text;
  const _SentenceLine(this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 17, height: 1.4))),
        SpeakButton(text, size: 20),
      ]);
}

class _Blank extends StatelessWidget {
  final String sentence;
  final String? filled;
  const _Blank(this.sentence, {this.filled});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final parts = sentence.split('____');
    return Text.rich(
      TextSpan(style: TextStyle(fontSize: 20, height: 1.5, color: p.text), children: [
        for (var i = 0; i < parts.length; i++) ...[
          TextSpan(text: parts[i]),
          if (i < parts.length - 1)
            TextSpan(
              text: filled ?? ' _____ ',
              style: TextStyle(fontWeight: FontWeight.w800, color: filled != null ? p.success : p.primary, decoration: filled == null ? null : TextDecoration.underline),
            ),
        ],
      ]),
    );
  }
}

enum _Opt { idle, correct, wrong, dim }

class _OptionButton extends StatelessWidget {
  final String text;
  final _Opt state;
  final VoidCallback onTap;
  const _OptionButton({required this.text, required this.state, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (bg, border, fg) = switch (state) {
      _Opt.idle => (p.surface, p.border, p.text),
      _Opt.correct => (p.successSoft, p.success, p.success),
      _Opt.wrong => (p.dangerSoft, p.danger, p.danger),
      _Opt.dim => (p.surface, p.border, p.muted),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: border, width: state == _Opt.idle ? 1 : 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: state == _Opt.idle ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: fg))),
                if (state == _Opt.correct) Icon(Icons.check_circle, color: p.success),
                if (state == _Opt.wrong) Icon(Icons.cancel, color: p.danger),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  final _Result result;
  final String? explanation;
  final VoidCallback onReport;
  final VoidCallback onAsk;
  const _Feedback({required this.result, required this.explanation, required this.onReport, required this.onAsk});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ok = result.ok;
    final title = switch (result.outcome) {
      Outcome.correct => 'Doğru',
      Outcome.correctWithHint => 'Doğru (ipucuyla)',
      Outcome.minorSpelling => 'Anlam doğru, küçük bir hata var',
      Outcome.incorrect => 'Henüz değil',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ok ? p.successSoft : p.dangerSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle : Icons.info_outline, color: ok ? p.success : p.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: ok ? p.success : p.danger, fontSize: 16))),
          if (result.source == 'ai') const Pill('AI değerlendirmesi'),
          if (result.source == 'self') const Pill('Kendi değerlendirmen'),
        ]),
        if (result.expected != null && result.outcome != Outcome.correct) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Doğru cevap: ${result.corrected ?? result.expected}', style: const TextStyle(fontWeight: FontWeight.w600))),
            if (result.englishAnswer) SpeakButton(result.corrected ?? result.expected!, size: 18),
          ]),
        ],
        if (result.note != null) ...[const SizedBox(height: 6), Text(result.note!)],
        if (explanation != null && explanation!.isNotEmpty) ...[const SizedBox(height: 6), Text(explanation!, style: TextStyle(color: p.muted))],
        const SizedBox(height: 4),
        Wrap(spacing: 4, children: [
          TextButton.icon(onPressed: onAsk, icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text('AI\'a sor')),
          TextButton.icon(onPressed: onReport, icon: const Icon(Icons.flag_outlined, size: 18), label: const Text('Hata bildir')),
        ]),
      ]),
    );
  }
}

class _Intro extends StatelessWidget {
  final TargetView? view;
  final VoidCallback onNext;
  final VoidCallback onKnow;
  const _Intro({required this.view, required this.onNext, required this.onKnow});
  @override
  Widget build(BuildContext context) {
    final v = view;
    if (v == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onNext());
      return const SizedBox.shrink();
    }
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
          Text(v.isPattern ? 'Yeni kalıp' : 'Yeni', style: TextStyle(color: context.pal.primaryText, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TargetDetails(view: v, compact: true),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: onKnow, child: const Text('Biliyorum'))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: FilledButton(onPressed: onNext, child: const Text('Anladım, devam'))),
        ]),
      ),
    ]);
  }
}

class _Summary extends StatelessWidget {
  final int correct, answered, newCount, reviewCount, minutes;
  final bool empty;
  const _Summary({required this.correct, required this.answered, required this.newCount, required this.reviewCount, required this.minutes, required this.empty});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    if (empty) {
      return EmptyState(
        icon: Icons.check_circle_outline,
        title: 'Şimdilik çalışılacak bir şey yok',
        body: 'Tekrar zamanı gelen hedef yok ve bu alandaki yeni hedefler bitti.',
        action: FilledButton(onPressed: () => context.pop(), child: const Text('Ana sayfaya dön')),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Spacer(),
        Icon(Icons.emoji_events_outlined, size: 56, color: p.primary),
        const SizedBox(height: 12),
        const Text('Bölüm tamam', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Doğru cevap', '$correct / $answered'),
              _row('Yeni hedef', '$newCount'),
              _row('Tekrar', '$reviewCount'),
              _row('Süre', minutes < 1 ? '1 dakikadan az' : '$minutes dakika'),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text('Yanlış yaptıkların ve yeni öğrendiklerin uygun zamanda tekrar karşına çıkacak.', textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        const Spacer(),
        FilledButton(onPressed: () => context.pop(), child: const Text('Bitir')),
      ]),
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: Text(a)), Text(b, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}
