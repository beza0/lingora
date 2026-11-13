import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../services/backend.dart';
import '../../srs/session.dart';
import '../../theme.dart';
import '../share_card.dart';
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
          // İlk açılış: hızlı bir ilk başarı
          if (user.events.isEmpty && user.activeDomains.isNotEmpty) ...[
            Card(
              color: p.primarySoft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Icon(Icons.rocket_launch_outlined, color: p.primary),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('İlk dersin hazır', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                  ]),
                  const SizedBox(height: 6),
                  Text('2 dakikada ilk kelimelerini öğren. Hata yapmaktan çekinme; bilmediklerin doğru zamanda tekrar karşına çıkacak.', style: TextStyle(color: p.text)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/session/${user.activeDomains.first.domainId}'),
                    child: const Text('Hemen başla'),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Seri, günlük hedef ve haftalık etkinlik
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Builder(builder: (context) {
                  final streak = user.streak();
                  final done = user.todayCount();
                  final goal = user.dailyGoal;
                  final reached = done >= goal;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/progress'),
                    child: Row(children: [
                      Text(streak > 0 ? '🔥' : '🌱', style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(streak > 0 ? '$streak günlük seri' : 'Seriye bugün başla', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: (done / goal).clamp(0.0, 1.0), minHeight: 8, backgroundColor: p.surface2, color: reached ? p.success : p.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(reached ? 'Günlük hedef tamam: $done / $goal' : 'Günlük hedef: $done / $goal', style: TextStyle(color: p.muted, fontSize: 13)),
                        ]),
                      ),
                      if (streak >= 2)
                        IconButton(
                          tooltip: 'Serini paylaş',
                          icon: Icon(Icons.ios_share, color: p.primary),
                          onPressed: () => shareStreak(context, streak, user.cards.length),
                        )
                      else
                        Icon(Icons.chevron_right, color: p.muted),
                    ]),
                  );
                }),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (var i = 0; i < 7; i++)
                    _DayDot(
                      label: const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'][i],
                      done: days.contains(monday.add(Duration(days: i))),
                      today: monday.add(Duration(days: i)) == DateTime(today.year, today.month, today.day),
                    ),
                ]),
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
                onSpeak: () => context.push('/speak/${d.domainId}'),
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
  final VoidCallback? onSpeak;
  const _DomainCard({
    this.onAssess,
    this.onSpeak,
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
          if (onSpeak != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: onSpeak, icon: const Icon(Icons.mic_none, size: 18), label: const Text('Konuşma pratiği')),
          ],
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
