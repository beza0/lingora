import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../data/content.dart';
import '../../srs/fsrs.dart';
import '../../theme.dart';
import '../widgets.dart';

class TargetScreen extends ConsumerWidget {
  final String targetId;
  const TargetScreen({super.key, required this.targetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final user = ref.watch(userProvider);
    final v = content.view(targetId);
    if (v == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Bulunamadı', body: 'Bu içerik artık yok.'));
    final saved = user.isSaved(targetId);
    final status = statusOf(user.cards[targetId], DateTime.now().toUtc());
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          tooltip: saved ? 'Koleksiyondan çıkar' : 'Koleksiyona ekle',
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () async {
            await user.toggleSaved(targetId);
            if (context.mounted) toast(context, saved ? 'Koleksiyondan çıkarıldı' : 'Koleksiyona eklendi');
          },
        ),
        IconButton(
          tooltip: 'Hata bildir',
          icon: const Icon(Icons.flag_outlined),
          onPressed: () => showReportSheet(context, ref, entityType: 'learning_target', entityId: targetId),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        TargetDetails(view: v),
        const SizedBox(height: 12),
        Row(children: [Pill(statusLabel(status))]),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Bunu AI\'a sor'),
          onPressed: () => context.push('/chat/new', extra: {
            'kind': 'target',
            'text': v.headline,
            'meaning_tr': v.meaningTr,
            'pack_title': content.packsById[content.targetPack[targetId]]?['title_tr'],
            'domain_id': v.domainId,
          }),
        ),
      ]),
    );
  }
}

/// Bir hedefin bütün bilgisi: tanıtım kartında ve ayrıntı sayfasında kullanılır.
class TargetDetails extends ConsumerWidget {
  final TargetView view;
  final bool compact;
  const TargetDetails({super.key, required this.view, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = view;
    final p = context.pal;
    final content = ref.watch(contentProvider);
    final grammar = v.grammarNoteId == null ? null : content.grammar[v.grammarNoteId];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Text(v.headline, style: TextStyle(fontSize: v.isPattern ? 22 : 30, fontWeight: FontWeight.w800))),
        if (!v.isPattern) SpeakButton(v.headline, size: 26),
      ]),
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (v.pos != null && v.pos!.isNotEmpty) Text(posLabel(v.pos), style: TextStyle(color: p.muted, fontStyle: FontStyle.italic)),
        for (final t in v.toneTags.take(3)) Pill(t),
        if (v.isDraft) const DraftBadge(),
      ]),
      const SizedBox(height: 12),
      Text(v.meaningTr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      if (v.exampleEn.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(v.exampleEn, style: const TextStyle(fontSize: 17, height: 1.4))),
              SpeakButton(v.exampleEn, size: 20),
            ]),
            const SizedBox(height: 4),
            Text(v.exampleTr, style: TextStyle(color: p.muted)),
          ]),
        ),
      ],
      if (v.chunks.isNotEmpty) ...[
        const SectionTitle('PARÇALAR'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in v.chunks) Pill('${c['en']} · ${c['tr']}'),
        ]),
      ],
      if (v.slots.isNotEmpty) ...[
        const SectionTitle('BAŞKA ÖRNEKLER'),
        for (final s in v.slots.take(compact ? 2 : 6))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${s['text_en']} — ${s['text_tr']}'),
          ),
      ],
      if (v.collocations.isNotEmpty) ...[
        const SectionTitle('SIK BİRLİKTE'),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final c in v.collocations) Pill(c)]),
      ],
      if (!compact) ...[
        if (v.synonyms.isNotEmpty) ...[
          const SectionTitle('YAKIN ANLAMLI'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final c in v.synonyms) Pill(c)]),
        ],
        if (v.antonyms.isNotEmpty) ...[
          const SectionTitle('ZIT ANLAMLI'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final c in v.antonyms) Pill(c)]),
        ],
        if (v.family.isNotEmpty) ...[
          const SectionTitle('AİLE'),
          for (final f in v.family) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $f')),
        ],
        if (v.confusables.isNotEmpty) ...[
          const SectionTitle('KARIŞTIRILAN'),
          for (final c in v.confusables)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${c['word']}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: '${c['note_tr']}'),
              ])),
            ),
        ],
        if (v.otherMeaningsTr != null) ...[
          const SectionTitle('DİĞER ANLAMLARI'),
          Text(v.otherMeaningsTr!, style: TextStyle(color: p.muted)),
        ],
      ],
      if (grammar != null) ...[
        const SectionTitle('YAPI NOTU'),
        Text(grammar['title_tr'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(grammar['short_tr'] as String),
        if (!compact) ...[const SizedBox(height: 6), Text(grammar['long_tr'] as String, style: TextStyle(color: p.muted))],
      ],
    ]);
  }
}
