import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../data/content.dart';
import '../../services/sound_fx.dart';
import '../../srs/assessment.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Başlangıç seviye testi: 5–8 cümle, puan veya CEFR gösterilmez.
class AssessmentScreen extends ConsumerStatefulWidget {
  final String domainId;
  const AssessmentScreen({super.key, required this.domainId});
  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  late final AssessmentEngine engine = AssessmentEngine(ref.read(contentProvider), widget.domainId);
  AssessmentStep? step;
  Json? check; // doğrulama sorusu
  Understood? pending;
  int? picked;
  bool started = false;
  int? chosen;

  void _start() {
    setState(() {
      started = true;
      step = engine.next();
    });
  }

  void _say(Understood u) {
    ref.read(soundProvider).play(Fx.tap);
    final s = step!;
    if (engine.needsCheck(u)) {
      final q = ref.read(contentProvider).exercisesFor(s.targetId, type: 'meaning_choice');
      if (q.isNotEmpty) {
        setState(() {
          pending = u;
          check = q.first;
          picked = null;
        });
        return;
      }
    }
    _advance(u, null);
  }

  void _pick(int i) {
    if (picked != null) return;
    final ok = i == (check!['answer'] as Map)['index'];
    ref.read(soundProvider).play(ok ? Fx.correct : Fx.wrong);
    setState(() => picked = i);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _advance(pending!, ok);
    });
  }

  void _advance(Understood u, bool? verified) {
    engine.answer(u, verified: verified);
    setState(() {
      check = null;
      pending = null;
      picked = null;
      step = engine.next();
      if (step == null) {
        chosen = engine.result;
        ref.read(soundProvider).play(Fx.complete);
      }
    });
  }

  Future<void> _finish() async {
    final user = ref.read(userProvider);
    final level = chosen ?? engine.result;
    await user.completeAssessment(widget.domainId, level);
    ref.read(backendProvider).saveAssessment(
          domainId: widget.domainId,
          steps: engine.steps.map((s) => s.toJson()).toList(),
          result: engine.result,
          chosen: level,
        );
    ref.read(backendProvider).sync(user);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final p = context.pal;
    final domainName = content.domains[widget.domainId]?['name_tr'] as String? ?? '';
    final total = engine.maxSteps;

    Widget body;
    if (!started) {
      body = _Intro(domainName: domainName, onStart: _start, onSkip: () async {
        await ref.read(userProvider).completeAssessment(widget.domainId, ref.read(userProvider).domain(widget.domainId)?.level ?? 2);
        if (context.mounted) context.pop();
      });
    } else if (step == null) {
      final r = engine.result;
      body = ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 24),
        Icon(Icons.insights_outlined, size: 52, color: p.primary),
        const SizedBox(height: 12),
        Text('$domainName için başlangıç noktan', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(AssessmentEngine.summary(r), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: p.muted, height: 1.4)),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('Başlangıç seviyesi', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(tooltip: 'Daha kolay', onPressed: (chosen ?? r) > 1 ? () => setState(() => chosen = (chosen ?? r) - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
                Text('${chosen ?? r} / 5', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.primary)),
                IconButton(tooltip: 'Daha zor', onPressed: (chosen ?? r) < 5 ? () => setState(() => chosen = (chosen ?? r) + 1) : null, icon: const Icon(Icons.add_circle_outline)),
              ]),
              Text('İstersen değiştirebilirsin; çalıştıkça uygulama da kendini ayarlar.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
        ),
      ]);
    } else {
      final v = content.view(step!.targetId)!;
      body = ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
        Text('${engine.steps.length}. cümle', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text(v.exampleEn, style: const TextStyle(fontSize: 21, height: 1.4, fontWeight: FontWeight.w600))),
            SpeakButton(v.exampleEn),
          ]),
        ),
        const SizedBox(height: 20),
        if (check == null) ...[
          const Text('Bu cümleyi anladın mı?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          FilledButton(onPressed: () => _say(Understood.yes), child: const Text('Anladım')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _say(Understood.partly), child: const Text('Kısmen')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _say(Understood.no), child: const Text('Anlamadım')),
        ] else ...[
          Text((check!['prompt'] as Map)['instruction_tr'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
          if ((check!['prompt'] as Map)['text'] != null && (check!['prompt'] as Map)['sentence'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('“${(check!['prompt'] as Map)['text']}”', style: TextStyle(color: p.primaryText, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          const SizedBox(height: 10),
          for (var i = 0; i < ((check!['prompt'] as Map)['options'] as List).length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  side: BorderSide(
                    width: picked == null ? 1 : 2,
                    color: picked == null
                        ? p.border
                        : i == (check!['answer'] as Map)['index']
                            ? p.success
                            : i == picked
                                ? p.danger
                                : p.border,
                  ),
                ),
                onPressed: () => _pick(i),
                child: Text(((check!['prompt'] as Map)['options'] as List)[i] as String),
              ),
            ),
        ],
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Seviye · $domainName'),
        bottom: started && step != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(6),
                child: LinearProgressIndicator(value: engine.steps.length / total, minHeight: 4, backgroundColor: p.surface2),
              )
            : null,
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: started && step == null
          ? SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: FilledButton(onPressed: _finish, child: const Text('Bu seviyeden başla'))))
          : null,
    );
  }
}

class _Intro extends StatelessWidget {
  final String domainName;
  final VoidCallback onStart;
  final VoidCallback onSkip;
  const _Intro({required this.domainName, required this.onStart, required this.onSkip});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Spacer(),
        Icon(Icons.tune, size: 48, color: p.primary),
        const SizedBox(height: 16),
        Text('$domainName seviyeni belirleyelim', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(
          'Birkaç kısa cümle göstereceğiz. Her birinde anlayıp anlamadığını söyle; bazen kısa bir anlam sorusuyla kontrol ederiz. '
          'Yaklaşık 1–2 dakika sürer, puan verilmez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 16, height: 1.4),
        ),
        const Spacer(flex: 2),
        FilledButton(onPressed: onStart, child: const Text('Başla')),
        const SizedBox(height: 8),
        TextButton(onPressed: onSkip, child: const Text('Şimdi değil, seviye 2\'den başla')),
      ]),
    );
  }
}
