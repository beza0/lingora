import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../srs/fsrs.dart';
import '../../theme.dart';
import '../widgets.dart';

class PackScreen extends ConsumerWidget {
  final String packId;
  const PackScreen({super.key, required this.packId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final user = ref.watch(userProvider);
    final p = context.pal;
    final pack = content.packsById[packId];
    if (pack == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Bulunamadı', body: ''));
    final targets = (content.packTargets[packId] ?? const <String>[]).where((t) => content.visible(content.targets[t])).toList();
    final words = targets.where((t) => content.targets[t]?['kind'] == 'sense').toList();
    final patterns = targets.where((t) => content.targets[t]?['kind'] == 'pattern').toList();
    final now = DateTime.now().toUtc();
    final scenarios = (content.scenariosByPack[packId] ?? const []).where(content.visible).toList();
    final readings = (content.readingsByPack[packId] ?? const []).where(content.visible).toList();
    final grammar = (content.packGrammar[packId] ?? const <String>[]).map((g) => content.grammar[g]).where(content.visible).toList();

    Widget targetTile(String id) {
      final v = content.view(id)!;
      final st = statusOf(user.cards[id], now);
      return ListTile(
        title: Text(v.headline, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(v.meaningTr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted)),
        trailing: Text(statusLabel(st), style: TextStyle(fontSize: 12, color: st == TargetStatus.due ? p.primaryText : p.muted)),
        onTap: () => context.push('/target/$id'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(pack['title_tr'] as String)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Row(children: [
          Expanded(child: Text(pack['description_tr'] as String, style: TextStyle(color: p.muted))),
          if ((pack['status'] as String?) != 'published') const DraftBadge(),
        ]),
        if (scenarios.isNotEmpty || readings.isNotEmpty) ...[
          const SectionTitle('UYGULA'),
          Card(
            child: Column(children: [
              for (final s in scenarios)
                ListTile(
                  leading: Icon(Icons.forum_outlined, color: p.primary),
                  title: Text(s['title_tr'] as String),
                  subtitle: const Text('Senaryo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/scenario/${s['id']}'),
                ),
              for (final r in readings)
                ListTile(
                  leading: Icon(Icons.article_outlined, color: p.primary),
                  title: Text(r['title'] as String),
                  subtitle: Text('Okuma · ${r['kind']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/reading/${r['id']}'),
                ),
            ]),
          ),
        ],
        if (words.isNotEmpty) ...[
          SectionTitle('KELİME VE İFADELER (${words.length})'),
          Card(child: Column(children: [for (final t in words) targetTile(t)])),
        ],
        if (patterns.isNotEmpty) ...[
          SectionTitle('KALIPLAR (${patterns.length})'),
          Card(child: Column(children: [for (final t in patterns) targetTile(t)])),
        ],
        if (grammar.isNotEmpty) ...[
          const SectionTitle('YAPI NOTLARI'),
          for (final g in grammar)
            Card(
              child: ExpansionTile(
                shape: const Border(),
                title: Text(g!['title_tr'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g['short_tr'] as String),
                  const SizedBox(height: 8),
                  Text(g['long_tr'] as String, style: TextStyle(color: p.muted)),
                  for (final e in ((g['examples'] as List?) ?? const []).cast<Map>()) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Text('${e['en']}\n${e['tr']}')),
                      SpeakButton(e['en'] as String, size: 18),
                    ]),
                  ],
                ],
              ),
            ),
        ],
      ]),
    );
  }
}
