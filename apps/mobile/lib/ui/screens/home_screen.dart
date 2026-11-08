import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../services/backend.dart';
import '../../srs/session.dart';
import '../../theme.dart';
import '../widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final content = ref.watch(contentProvider);
    final backend = ref.watch(backendProvider);
    final p = context.pal;
    final now = DateTime.now().toUtc();
    final days = user.activeDays();
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => backend.sync(user),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          Row(children: [
            Expanded(child: Text('Bugün', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.text))),
            if (backend.syncing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 12),
          // Haftalık etkinlik
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var i = 0; i < 7; i++)
                  _DayDot(
                    label: const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'][i],
                    done: days.contains(monday.add(Duration(days: i))),
                    today: monday.add(Duration(days: i)) == DateTime(today.year, today.month, today.day),
                  ),
              ]),
            ),
          ),
          if (backend.account == AccountKind.guest && user.events.length >= 20) ...[
            const SizedBox(height: 12),
            _Banner(
              text: 'Misafir olarak çalışıyorsun. İlerlemeni kaybetmemek için hesap oluştur.',
              action: 'Hesap oluştur',
              onTap: () => context.push('/auth'),
            ),
          ],
          SectionTitle('Alanların', trailing: TextButton(onPressed: () => context.push('/domains'), child: const Text('Düzenle'))),
          for (final d in user.activeDomains) ...[
            Builder(builder: (context) {
              final targets = content.targetsForDomain(d.domainId);
              final plan = buildSession(content: content, domainId: d.domainId, cards: user.cards, level: d.level, now: now);
              final due = user.dueCount(targets, now);
              final started = user.startedCount(targets);
              final domain = content.domains[d.domainId];
              return _DomainCard(
                domainId: d.domainId,
                name: domain?['name_tr'] as String? ?? d.domainId,
                due: due,
                newCount: plan.newTargets.length,
                started: started,
                total: targets.length,
                minutes: (plan.estimate.inSeconds / 60).ceil(),
                reduced: plan.reducedNew,
                onStart: plan.isEmpty ? null : () => context.push('/session/${d.domainId}'),
                onAssess: user.assessed.contains(d.domainId) ? null : () => context.push('/assessment/${d.domainId}'),
              );
            }),
            const SizedBox(height: 12),
          ],
          if (user.activeDomains.isEmpty)
            EmptyState(
              icon: Icons.layers_outlined,
              title: 'Henüz alan seçmedin',
              body: 'Çalışmak istediğin alanları seç; günlük planın buna göre oluşur.',
              action: FilledButton(onPressed: () => context.push('/domains'), child: const Text('Alan seç')),
            ),
          if (backend.lastSyncError != null && backend.signedIn) ...[
            const SizedBox(height: 8),
            Text('Eşitleme bekliyor; bağlantı gelince otomatik denenecek.', style: TextStyle(color: p.muted, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool today;
  const _DayDot({required this.label, required this.done, required this.today});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Column(children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: done ? p.success : p.surface2,
          shape: BoxShape.circle,
          border: Border.all(color: today ? p.primary : p.border, width: today ? 2 : 1),
        ),
        child: done ? Icon(Icons.check, size: 16, color: p.surface) : null,
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
    ]);
  }
}

class _DomainCard extends StatelessWidget {
  final String domainId, name;
  final int due, newCount, started, total, minutes;
  final bool reduced;
  final VoidCallback? onStart;
  final VoidCallback? onAssess;
  const _DomainCard({
    this.onAssess,
    required this.domainId,
    required this.name,
    required this.due,
    required this.newCount,
    required this.started,
    required this.total,
    required this.minutes,
    required this.reduced,
    required this.onStart,
  });
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            DomainDot(domainId, size: 12),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Pill('$due tekrar', bg: due > 0 ? p.primarySoft : null, color: due > 0 ? p.primaryText : null),
            Pill('$newCount yeni'),
            Pill('$started / $total başlandı'),
          ]),
          if (reduced) ...[
            const SizedBox(height: 8),
            Text('Bekleyen tekrar çok olduğu için bugün daha az yeni hedef var.', style: TextStyle(color: p.muted, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          if (onAssess != null) ...[
            OutlinedButton.icon(onPressed: onAssess, icon: const Icon(Icons.tune, size: 18), label: const Text('Seviyeni belirle · 1–2 dk')),
            const SizedBox(height: 8),
          ],
          FilledButton(
            onPressed: onStart,
            child: Text(onStart == null ? 'Bugünlük bu kadar' : 'Çalış · yaklaşık $minutes dk · tahmini'),
          ),
        ]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text, action;
  final VoidCallback onTap;
  const _Banner({required this.text, required this.action, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(color: p.primaryText))),
        TextButton(onPressed: onTap, child: Text(action)),
      ]),
    );
  }
}

/// Oturum bitiminde ölçüm için kullanılan yardımcı (alan seviyesi ayarı).
int nextLevel(int level, List<bool> attempts) => adjustLevel(level, attempts);
