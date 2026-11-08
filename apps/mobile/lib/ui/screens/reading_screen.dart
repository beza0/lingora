import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_state.dart';
import '../../data/content.dart';
import '../../theme.dart';
import '../widgets.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  final String readingId;
  const ReadingScreen({super.key, required this.readingId});
  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  final shown = <int>{};
  final answers = <int, int>{};

  Json? _find(ContentRepo c) {
    for (final l in c.readingsByPack.values) {
      for (final r in l) {
        if (r['id'] == widget.readingId) return r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final r = _find(ref.watch(contentProvider));
    final p = context.pal;
    if (r == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Bulunamadı', body: ''));
    final sentences = ((r['sentences'] as List?) ?? const []).cast<Map>();
    final glossary = ((r['glossary'] as List?) ?? const []).cast<Map>();
    final questions = ((r['questions'] as List?) ?? const []).cast<Map>();
    return Scaffold(
      appBar: AppBar(title: Text(r['kind'] as String? ?? 'Okuma'), actions: [
        IconButton(icon: const Icon(Icons.flag_outlined), tooltip: 'Hata bildir', onPressed: () => showReportSheet(context, ref, entityType: 'reading', entityId: r['id'] as String)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Row(children: [
          Expanded(child: Text(r['title'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          if ((r['status'] as String?) != 'published') const DraftBadge(),
        ]),
        const SizedBox(height: 6),
        Text('Türkçesini görmek için cümleye dokun.', style: TextStyle(color: p.muted, fontSize: 13)),
        const SizedBox(height: 12),
        for (var i = 0; i < sentences.length; i++)
          InkWell(
            onTap: () => setState(() => shown.contains(i) ? shown.remove(i) : shown.add(i)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(sentences[i]['en'] as String, style: const TextStyle(fontSize: 17, height: 1.45))),
                  SpeakButton(sentences[i]['en'] as String, size: 18),
                ]),
                if (shown.contains(i)) Text(sentences[i]['tr'] as String, style: TextStyle(color: p.muted)),
              ]),
            ),
          ),
        if (glossary.isNotEmpty) ...[
          const SectionTitle('SÖZLÜK'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final g in glossary) Pill('${g['term']} · ${g['tr']}')]),
        ],
        if (questions.isNotEmpty) ...[
          const SectionTitle('SORULAR'),
          for (var qi = 0; qi < questions.length; qi++) ...[
            Text(questions[qi]['q_tr'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (var oi = 0; oi < (questions[qi]['options'] as List).length; oi++)
              Builder(builder: (context) {
                final chosen = answers[qi];
                final right = questions[qi]['answer'] as int;
                final color = chosen == null
                    ? p.border
                    : oi == right
                        ? p.success
                        : oi == chosen
                            ? p.danger
                            : p.border;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: BorderSide(color: color, width: chosen == null ? 1 : 2), alignment: Alignment.centerLeft),
                    onPressed: chosen == null ? () => setState(() => answers[qi] = oi) : null,
                    child: Text((questions[qi]['options'] as List)[oi] as String),
                  ),
                );
              }),
            if (answers[qi] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${answers[qi] == questions[qi]['answer'] ? 'Doğru.' : 'Doğru cevap işaretlendi.'} Metinde: ${questions[qi]['why_tr']}',
                  style: TextStyle(color: p.muted),
                ),
              ),
          ],
        ],
      ]),
    );
  }
}
