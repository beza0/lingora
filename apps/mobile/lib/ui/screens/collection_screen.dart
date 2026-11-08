import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final content = ref.watch(contentProvider);
    final p = context.pal;
    final items = user.visibleSaved;
    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Ekle'),
        ),
        body: items.isEmpty
            ? ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
                const Text('Koleksiyon', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 40),
                const EmptyState(
                  icon: Icons.bookmark_border,
                  title: 'Koleksiyonun boş',
                  body: 'Kelime sayfalarındaki yer imi simgesiyle ya da AI sohbetindeki ifadelerden kaydedebilirsin. Kendi ifadeni de ekleyebilirsin.',
                ),
              ])
            : ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 96), children: [
                const Text('Koleksiyon', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Card(
                  child: Column(children: [
                    for (final s in items)
                      if (s.targetId != null)
                        Builder(builder: (context) {
                          final v = content.view(s.targetId!);
                          if (v == null) return const SizedBox.shrink();
                          return ListTile(
                            leading: DomainDot(v.domainId),
                            title: Text(v.headline),
                            subtitle: Text(v.meaningTr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted)),
                            trailing: SpeakButton(v.isPattern ? v.exampleEn : v.headline, size: 20),
                            onTap: () => context.push('/target/${s.targetId}'),
                          );
                        })
                      else
                        Builder(builder: (context) {
                          final c = user.custom.where((c) => c.id == s.customId).firstOrNull;
                          if (c == null) return const SizedBox.shrink();
                          return ListTile(
                            leading: Icon(c.source == 'ai' ? Icons.auto_awesome_outlined : Icons.edit_note, color: p.muted),
                            title: Text(c.textEn),
                            subtitle: c.meaningTr == null ? Text(c.source == 'ai' ? 'AI sohbetinden' : 'Kendi ekledin', style: TextStyle(color: p.muted)) : Text(c.meaningTr!),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              SpeakButton(c.textEn, size: 20),
                              IconButton(
                                tooltip: 'Sil',
                                icon: Icon(Icons.delete_outline, color: p.muted),
                                onPressed: () => user.deleteCustom(c.id),
                              ),
                            ]),
                          );
                        }),
                  ]),
                ),
              ]),
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final en = TextEditingController();
    final tr = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İfade ekle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: en, maxLength: 300, decoration: const InputDecoration(labelText: 'İngilizce')),
          const SizedBox(height: 8),
          TextField(controller: tr, maxLength: 200, decoration: const InputDecoration(labelText: 'Türkçe anlamı (isteğe bağlı)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              if (en.text.trim().isEmpty) return;
              await ref.read(userProvider).addCustom(textEn: en.text, meaningTr: tr.text.trim().isEmpty ? null : tr.text.trim(), source: 'manual');
              ref.read(backendProvider).sync(ref.read(userProvider));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
