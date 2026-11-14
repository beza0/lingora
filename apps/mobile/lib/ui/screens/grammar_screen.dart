import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Bir alandaki bütün gramer konuları, ünite sırasıyla. Seviye alanlarında (A1–C2) ders listesi gibi çalışır.
class GrammarScreen extends ConsumerWidget {
  final String domainId;
  const GrammarScreen({super.key, required this.domainId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final p = context.pal;
    final name = content.domains[domainId]?['name_tr'] as String? ?? domainId;
    final packs = content.packsFor(domainId)..sort((a, b) => ((a['sort'] as int?) ?? 0).compareTo((b['sort'] as int?) ?? 0));
    var n = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Gramer konuları')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Her konuyu oku, örnekleri dinle; sonra ünitenin alıştırmalarıyla pekiştir.', style: TextStyle(color: p.muted)),
        for (final pack in packs) ...[
          SectionTitle(
            (pack['title_tr'] as String).toUpperCase(),
            trailing: TextButton(onPressed: () => context.push('/pack/${pack['id']}'), child: const Text('Üniteye git')),
          ),
          for (final g in (content.packGrammar[pack['id']] ?? const <String>[]).map((id) => content.grammar[id]).where(content.visible))
            Card(
              child: ExpansionTile(
                shape: const Border(),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: p.surface2,
                  child: Text('${++n}', style: TextStyle(color: p.domain(domainId), fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                title: Text(g!['title_tr'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(g['short_tr'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 13)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g['short_tr'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(g['long_tr'] as String, style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 4),
                  for (final e in ((g['examples'] as List?) ?? const []).cast<Map>()) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e['en'] as String, style: TextStyle(color: p.primaryText, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(e['tr'] as String, style: TextStyle(color: p.muted, fontSize: 13)),
                          ]),
                        ),
                        SpeakButton(e['en'] as String, size: 18),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
        ],
        if (n == 0) Padding(padding: const EdgeInsets.all(16), child: Text('Bu alanda henüz gramer konusu yok.', style: TextStyle(color: p.muted))),
      ]),
    );
  }
}
