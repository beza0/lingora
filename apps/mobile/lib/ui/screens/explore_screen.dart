import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final user = ref.watch(userProvider);
    final p = context.pal;
    final order = [
      ...user.activeDomains.map((d) => d.domainId),
      ...content.domainList.map((d) => d['id'] as String).where((id) => !user.activeDomains.any((d) => d.domainId == id)),
    ];
    final q = query.trim().toLowerCase();
    final results = q.length < 2
        ? const <String>[]
        : content.targets.keys.where((id) {
            final v = content.view(id);
            if (v == null || !content.visible(content.targets[id])) return false;
            return v.headline.toLowerCase().contains(q) || v.meaningTr.toLowerCase().contains(q);
          }).take(40).toList();

    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        const Text('Keşfet', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Kelime, kalıp veya Türkçe anlam ara'),
          onChanged: (v) => setState(() => query = v),
        ),
        if (q.length >= 2) ...[
          const SizedBox(height: 8),
          if (results.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Sonuç yok.', style: TextStyle(color: p.muted))),
          for (final id in results)
            Builder(builder: (context) {
              final v = content.view(id)!;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: DomainDot(v.domainId),
                title: Text(v.headline),
                subtitle: Text(v.meaningTr, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => context.push('/target/$id'),
              );
            }),
        ] else
          for (final domainId in order) ...[
            SectionTitle((content.domains[domainId]?['name_tr'] as String? ?? domainId).toUpperCase()),
            Card(
              child: Column(children: [
                for (final pack in content.packsFor(domainId))
                  ListTile(
                    leading: DomainDot(domainId),
                    title: Text(pack['title_tr'] as String),
                    subtitle: Text(
                      '${user.startedCount(content.packTargets[pack['id']] ?? const [])} / ${(content.packTargets[pack['id']] ?? const []).length} başlandı',
                      style: TextStyle(color: p.muted),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/pack/${pack['id']}'),
                  ),
                ListTile(
                  leading: Icon(Icons.school_outlined, color: p.domain(domainId)),
                  title: const Text('Gramer konuları'),
                  subtitle: Text('Bu alandaki bütün yapı dersleri', style: TextStyle(color: p.muted)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/grammar/$domainId'),
                ),
                ListTile(
                  leading: Icon(Icons.menu_book_outlined, color: p.domain(domainId)),
                  title: const Text('Cümle Rehberi'),
                  subtitle: Text('Duruma göre hazır cümleler', style: TextStyle(color: p.muted)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/phrasebook/$domainId'),
                ),
              ]),
            ),
          ],
      ]),
    );
  }
}
