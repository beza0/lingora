import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../data/content.dart';
import '../../services/backend.dart';
import '../../services/sound_fx.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Yazma görevi: kullanıcı 3–4 cümle yazar; AI ölçütlere göre değerlendirir.
/// AI yoksa örnek cevaplar ve ölçütlerle kendi kendini kontrol eder.
class WritingScreen extends ConsumerStatefulWidget {
  final String taskId;
  const WritingScreen({super.key, required this.taskId});
  @override
  ConsumerState<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends ConsumerState<WritingScreen> {
  final text = TextEditingController();
  bool busy = false;
  Map<String, Object?>? evaluation;
  String? source;
  ApiError? error;
  bool showSamples = false;

  Json? _find(ContentRepo c) {
    for (final l in c.writingByPack.values) {
      for (final w in l) {
        if (w['id'] == widget.taskId) return w;
      }
    }
    return null;
  }

  int get _sentences => RegExp(r'[.!?](\s|$)').allMatches(text.text.trim()).length;

  Future<void> _evaluate(Json task) async {
    final answer = text.text.trim();
    if (answer.length < 20) {
      toast(context, 'Biraz daha yaz: en az 2–3 cümle.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      evaluation = null;
    });
    final samples = ((task['sample_answers'] as List?) ?? const []).cast<String>();
    try {
      final r = await ref.read(backendProvider).evaluate(
            promptTr: task['prompt_tr'] as String,
            expected: samples.isEmpty ? '' : samples.first,
            accepted: samples.skip(1).toList(),
            answer: answer,
            skill: 'writing',
            rubric: ((task['rubric'] as List?) ?? const []).cast<String>(),
          );
      if (r['source'] == 'local') {
        evaluation = {'verdict': 'correct', 'explanation_tr': 'Cevabın örnek cevaplardan biriyle aynı.'};
        source = 'local';
      } else {
        evaluation = (r['evaluation'] as Map).cast<String, Object?>();
        source = 'ai';
      }
      final ok = evaluation!['verdict'] == 'correct' || evaluation!['verdict'] == 'acceptable';
      ref.read(soundProvider).play(ok ? Fx.correct : Fx.wrong);
    } on ApiError catch (e) {
      error = e;
      showSamples = true;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = _find(ref.watch(contentProvider));
    final p = context.pal;
    if (task == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Bulunamadı', body: ''));
    final rubric = ((task['rubric'] as List?) ?? const []).cast<String>();
    final samples = ((task['sample_answers'] as List?) ?? const []).cast<String>();
    final ev = evaluation;
    final verdict = ev?['verdict'] as String?;
    final (title, color, bg) = switch (verdict) {
      'correct' => ('Çok iyi', p.success, p.successSoft),
      'acceptable' => ('Doğru ve doğal', p.success, p.successSoft),
      'minor_error' => ('Anlaşılır, küçük hatalar var', p.hint, p.hintSoft),
      'incorrect' => ('Biraz daha çalışalım', p.danger, p.dangerSoft),
      _ => ('', p.text, p.surface),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Yazma görevi'), actions: [
        IconButton(icon: const Icon(Icons.flag_outlined), tooltip: 'Hata bildir', onPressed: () => showReportSheet(context, ref, entityType: 'writing_task', entityId: widget.taskId)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Row(children: [
          Expanded(child: Text(task['prompt_tr'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.35))),
          if ((task['status'] as String?) != 'published') const DraftBadge(),
        ]),
        if (rubric.isNotEmpty) ...[
          const SectionTitle('NELERE DİKKAT EDİLECEK'),
          for (final r in rubric)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_circle_outline, size: 18, color: p.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(r)),
              ]),
            ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: text,
          minLines: 5,
          maxLines: 10,
          maxLength: 1000,
          enabled: !busy,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'İngilizce yaz…', alignLabelWithHint: true),
        ),
        Text('$_sentences cümle', style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : () => _evaluate(task),
          child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Değerlendir'),
        ),
        if (ev != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color))),
                if (source == 'ai') const Pill('AI değerlendirmesi'),
              ]),
              if ((ev['explanation_tr'] as String?)?.isNotEmpty ?? false) ...[const SizedBox(height: 8), Text(ev['explanation_tr'] as String)],
              if ((ev['corrected'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                const Text('Düzeltilmiş hâli', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(ev['corrected'] as String, style: const TextStyle(height: 1.4))),
                  SpeakButton(ev['corrected'] as String, size: 20),
                ]),
              ],
              for (final a in ((ev['alternatives'] as List?) ?? const []).cast<String>()) ...[
                const SizedBox(height: 6),
                Row(children: [Expanded(child: Text('• $a', style: TextStyle(color: p.muted))), SpeakButton(a, size: 18)]),
              ],
              Text('AI hata yapabilir; emin olmadığın noktayı “AI\'a sor” ile sorabilirsin.', style: TextStyle(color: p.muted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('AI\'a sor'),
            onPressed: () => context.push('/chat/new', extra: {'kind': 'exercise', 'text': text.text.trim(), 'domain_id': ref.read(contentProvider).packsById[task['pack_id']]?['domain_id']}),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.hintSoft, borderRadius: BorderRadius.circular(14)),
            child: Text(
              error!.code == 'ai_not_configured'
                  ? 'AI değerlendirmesi şu an kullanılamıyor. Yazdığını aşağıdaki örnek cevaplar ve ölçütlerle karşılaştırabilirsin.'
                  : '${error!.message} Bu arada örnek cevaplara bakabilirsin.',
              style: TextStyle(color: p.hint),
            ),
          ),
        ],
        if (samples.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: () => setState(() => showSamples = !showSamples), child: Text(showSamples ? 'Örnek cevapları gizle' : 'Örnek cevapları göster')),
          if (showSamples)
            for (final s in samples)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                  child: Row(children: [Expanded(child: Text(s, style: const TextStyle(height: 1.4))), SpeakButton(s, size: 20)]),
                ),
              ),
        ],
      ]),
    );
  }
}
