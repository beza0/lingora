import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_state.dart';
import '../../data/content.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Senaryo: karşı tarafın repliklerini okur/dinlersin, kendi sıranda en uygun yanıtı seçersin.
class ScenarioScreen extends ConsumerStatefulWidget {
  final String scenarioId;
  const ScenarioScreen({super.key, required this.scenarioId});
  @override
  ConsumerState<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends ConsumerState<ScenarioScreen> {
  int turn = 0;
  final picks = <int, int>{};
  int good = 0;

  Json? _find(ContentRepo c) {
    for (final l in c.scenariosByPack.values) {
      for (final s in l) {
        if (s['id'] == widget.scenarioId) return s;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = _find(ref.watch(contentProvider));
    final p = context.pal;
    if (s == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Bulunamadı', body: ''));
    final turns = ((s['turns'] as List?) ?? const []).cast<Map>();
    final visible = <Widget>[];
    var waiting = false;
    for (var i = 0; i < turns.length && i <= turn; i++) {
      final t = turns[i];
      if (t['choose'] == null) {
        visible.add(_Bubble(speaker: t['speaker'] as String? ?? '', en: t['en'] as String, tr: t['tr'] as String?, mine: false));
        if (i == turn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && turn == i && i < turns.length - 1) setState(() => turn++);
          });
        }
      } else {
        final options = (t['choose'] as List).cast<Map>();
        final pick = picks[i];
        if (pick == null) {
          waiting = true;
          visible.add(Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(t['q'] as String? ?? 'En uygun yanıt hangisi?', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
          ));
          for (var oi = 0; oi < options.length; oi++) {
            visible.add(Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(14)),
                onPressed: () => setState(() {
                  picks[i] = oi;
                  if (options[oi]['correct'] == true) good++;
                  turn = i + 1;
                }),
                child: Text(options[oi]['en'] as String),
              ),
            ));
          }
          break;
        } else {
          final o = options[pick];
          final ok = o['correct'] == true;
          final right = options.firstWhere((x) => x['correct'] == true, orElse: () => o);
          visible.add(_Bubble(speaker: 'Sen', en: right['en'] as String, tr: null, mine: true));
          visible.add(Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ok ? p.successSoft : p.dangerSoft, borderRadius: BorderRadius.circular(10)),
            child: Text(ok ? 'Doğru. ${o['why_tr'] ?? ''}' : 'Seçtiğin: “${o['en']}”. ${o['why_tr'] ?? ''}'),
          ));
        }
      }
    }
    final finished = !waiting && turn >= turns.length - 1 && turns.isNotEmpty && (turns.last['choose'] == null || picks.containsKey(turns.length - 1));
    final choices = picks.length;
    return Scaffold(
      appBar: AppBar(title: Text(s['title_tr'] as String)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text(s['situation_tr'] as String)),
            if ((s['status'] as String?) != 'published') const DraftBadge(),
          ]),
        ),
        const SizedBox(height: 16),
        ...visible,
        if (finished) ...[
          const SizedBox(height: 12),
          Text('Senaryo bitti: $choices seçimden $good doğru.', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => setState(() {
                turn = 0;
                picks.clear();
                good = 0;
              }), child: const Text('Baştan başla')),
        ],
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String speaker, en;
  final String? tr;
  final bool mine;
  const _Bubble({required this.speaker, required this.en, required this.tr, required this.mine});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: mine ? p.primarySoft : p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(speaker, style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w700)),
          Row(children: [
            Expanded(child: Text(en, style: const TextStyle(fontSize: 16))),
            SpeakButton(en, size: 18),
          ]),
          if (tr != null) Text(tr!, style: TextStyle(color: p.muted, fontSize: 13)),
        ]),
      ),
    );
  }
}
