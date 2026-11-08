import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Cümle Rehberi: duruma göre hazır cümleler (situations → situation_items).
class PhrasebookScreen extends ConsumerWidget {
  final String domainId;
  const PhrasebookScreen({super.key, required this.domainId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final p = context.pal;
    final tops = content.topSituations(domainId);
    return Scaffold(
      appBar: AppBar(title: Text('Cümle Rehberi · ${content.domains[domainId]?['name_tr'] ?? ''}')),
      body: tops.isEmpty
          ? const EmptyState(icon: Icons.menu_book_outlined, title: 'Henüz yok', body: 'Bu alan için durum listesi hazırlanmadı.')
          : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
              for (final top in tops) ...[
                SectionTitle((top['name_tr'] as String).toUpperCase()),
                for (final child in [top, ...content.childSituations(top['id'] as String)])
                  if ((content.situationItems[child['id']] ?? const []).isNotEmpty)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        shape: const Border(),
                        title: Text(child['name_tr'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                        children: [
                          for (final t in content.situationItems[child['id']]!)
                            Builder(builder: (context) {
                              final v = content.view(t);
                              if (v == null || !content.visible(content.targets[t])) return const SizedBox.shrink();
                              final line = v.exampleEn.isNotEmpty ? v.exampleEn : v.headline;
                              return ListTile(
                                title: Text(line),
                                subtitle: Text(v.exampleTr.isNotEmpty ? v.exampleTr : v.meaningTr, style: TextStyle(color: p.muted)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [SpeakButton(line, size: 20), CopyButton(line)]),
                                onTap: () => context.push('/target/$t'),
                              );
                            }),
                        ],
                      ),
                    ),
              ],
            ]),
    );
  }
}
