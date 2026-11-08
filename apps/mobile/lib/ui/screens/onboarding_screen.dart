import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool picking = false;
  @override
  Widget build(BuildContext context) {
    if (picking) return const DomainPickerScreen(editing: false);
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            Text('Lingora', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: p.primary)),
            const SizedBox(height: 8),
            const Text('İngilizce, senin alanında.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text(
              'İşinde ve sınavında gerçekten kullanacağın kelime ve kalıpları, kısa günlük çalışmalarla öğren. '
              'Unutmaya başladığın şeyler doğru zamanda tekrar karşına çıkar.',
              style: TextStyle(fontSize: 16, color: p.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.hintSoft, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'Bu bir test sürümüdür. İçerik henüz bir uzman tarafından incelenmedi; hata görürsen “Hata bildir” ile haber ver.',
                style: TextStyle(color: p.hint),
              ),
            ),
            const Spacer(flex: 2),
            FilledButton(onPressed: () => setState(() => picking = true), child: const Text('Başla')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => context.push('/auth?mode=login'), child: const Text('Zaten hesabım var')),
          ]),
        ),
      ),
    );
  }
}

class DomainPickerScreen extends ConsumerStatefulWidget {
  final bool editing;
  const DomainPickerScreen({super.key, required this.editing});
  @override
  ConsumerState<DomainPickerScreen> createState() => _DomainPickerScreenState();
}

class _DomainPickerScreenState extends ConsumerState<DomainPickerScreen> {
  late final List<String> selected = ref.read(userProvider).activeDomains.map((d) => d.domainId).toList();

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing ? 'Alanlarım' : 'Alanlarını seç')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        if (!widget.editing) ...[
          const Text('Hangi alanlarda çalışmak istersin?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
        ],
        Text('Birden fazla seçebilirsin. Sıra, ana sayfadaki sırayı belirler.', style: TextStyle(color: p.muted)),
        const SizedBox(height: 16),
        for (final d in content.domainList) ...[
          _DomainTile(
            id: d['id'] as String,
            name: d['name_tr'] as String,
            description: d['description_tr'] as String,
            order: selected.indexOf(d['id'] as String),
            onTap: () => setState(() {
              final id = d['id'] as String;
              selected.contains(id) ? selected.remove(id) : selected.add(id);
            }),
          ),
          const SizedBox(height: 10),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () async {
                    final user = ref.read(userProvider);
                    await user.setDomains(selected);
                    if (!widget.editing) await user.completeOnboarding();
                    ref.read(backendProvider).sync(user);
                    if (context.mounted) widget.editing ? context.pop() : context.go('/home');
                  },
            child: Text(widget.editing ? 'Kaydet' : 'Devam'),
          ),
        ),
      ),
    );
  }
}

class _DomainTile extends StatelessWidget {
  final String id, name, description;
  final int order;
  final VoidCallback onTap;
  const _DomainTile({required this.id, required this.name, required this.description, required this.order, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final on = order >= 0;
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: on ? p.primarySoft : p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? p.primary : p.border, width: on ? 2 : 1),
          ),
          child: Row(children: [
            DomainDot(id, size: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(color: p.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            if (on)
              CircleAvatar(radius: 14, backgroundColor: p.primary, child: Text('${order + 1}', style: TextStyle(color: p.primaryInk, fontWeight: FontWeight.w700)))
            else
              Icon(Icons.add_circle_outline, color: p.muted),
          ]),
        ),
      ),
    );
  }
}
