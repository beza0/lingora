import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_state.dart';
import '../../services/reminders.dart';
import '../../srs/fsrs.dart';
import '../../theme.dart';
import '../widgets.dart';

/// İlerleme: seri, son 14 gün, öğrenme durumu, alan seviyeleri, konuşma puanı; günlük hedef ve hatırlatma ayarı.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final content = ref.watch(contentProvider);
    final p = context.pal;
    final now = DateTime.now().toUtc();
    final days = user.lastDays(14);
    final maxDay = days.fold<int>(1, (m, d) => d.$2 > m ? d.$2 : m);
    final weekTotal = days.skip(7).fold<int>(0, (s, d) => s + d.$2);
    final prevWeek = days.take(7).fold<int>(0, (s, d) => s + d.$2);

    var fresh = 0, learning = 0, consolidating = 0, due = 0;
    for (final c in user.cards.values) {
      switch (statusOf(c, now)) {
        case TargetStatus.fresh:
          fresh++;
        case TargetStatus.due:
          due++;
        case TargetStatus.learning:
          learning++;
        case TargetStatus.consolidating:
          consolidating++;
      }
    }
    final recentScores = [
      for (final d in days.skip(7)) ...(user.speakScores[UserDataKeys.day(d.$1)] ?? const <int>[]),
    ];
    final speakAvg = recentScores.isEmpty ? null : (recentScores.reduce((a, b) => a + b) / recentScores.length).round();

    return Scaffold(
      appBar: AppBar(title: const Text('İlerleme')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Row(children: [
          Expanded(child: _Stat(value: '${user.streak()}', label: 'günlük seri', icon: '🔥')),
          const SizedBox(width: 10),
          Expanded(child: _Stat(value: '${user.bestStreak()}', label: 'en uzun seri', icon: '🏆')),
          const SizedBox(width: 10),
          Expanded(child: _Stat(value: '${user.todayCount()}/${user.dailyGoal}', label: 'bugün', icon: '🎯')),
        ]),
        const SectionTitle('SON 14 GÜN'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
            child: Column(children: [
              SizedBox(
                height: 120,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final d in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (d.$2 > 0) Text('${d.$2}', style: TextStyle(fontSize: 9, color: p.muted)),
                          Container(
                            height: d.$2 == 0 ? 3 : 4 + 92 * d.$2 / maxDay,
                            decoration: BoxDecoration(
                              color: d.$2 >= user.dailyGoal ? p.success : (d.$2 > 0 ? p.primary : p.border),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              Row(children: [
                for (final d in days)
                  Expanded(child: Text(const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'][d.$1.weekday - 1], textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: p.muted))),
              ]),
              const SizedBox(height: 10),
              Text(
                prevWeek == 0
                    ? 'Bu hafta $weekTotal alıştırma ve cümle.'
                    : 'Bu hafta $weekTotal, geçen hafta $prevWeek. ${weekTotal >= prevWeek ? 'Güzel gidiyorsun.' : 'Biraz geride; kısa bir oturum bile seriyi korur.'}',
                style: TextStyle(color: p.muted, fontSize: 13),
              ),
            ]),
          ),
        ),
        const SectionTitle('ÖĞRENME DURUMU'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _Row('Pekişen', consolidating, p.success),
              _Row('Öğreniliyor', learning, p.primary),
              _Row('Tekrar zamanı gelen', due, p.hint),
              if (fresh > 0) _Row('Yeni (başlanmamış)', fresh, p.muted),
              const SizedBox(height: 6),
              Text('Toplam ${user.events.length} cevap · ${user.speakLog.values.fold<int>(0, (a, b) => a + b)} söylenen cümle${speakAvg != null ? ' · son 7 gün konuşma ortalaması %$speakAvg' : ''}',
                  style: TextStyle(color: p.muted, fontSize: 13)),
            ]),
          ),
        ),
        const SectionTitle('ALANLAR'),
        for (final d in user.activeDomains)
          Builder(builder: (context) {
            final targets = content.targetsForDomain(d.domainId);
            final started = user.startedCount(targets);
            final first = user.firstAttemptsUnaided(d.domainId);
            final recent = first.length > 30 ? first.sublist(first.length - 30) : first;
            final acc = recent.isEmpty ? null : (100 * recent.where((x) => x).length / recent.length).round();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    DomainDot(d.domainId, size: 10),
                    const SizedBox(width: 8),
                    Expanded(child: Text(content.domains[d.domainId]?['name_tr'] as String? ?? d.domainId, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Pill('Seviye ${d.level}/5'),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: targets.isEmpty ? 0 : started / targets.length, minHeight: 8, backgroundColor: p.surface2),
                  ),
                  const SizedBox(height: 6),
                  Text('$started / ${targets.length} hedef başlandı${acc != null ? ' · son cevaplarda ilk denemede doğru %$acc' : ''}', style: TextStyle(color: p.muted, fontSize: 13)),
                ]),
              ),
            );
          }),
        const SectionTitle('GÜNLÜK HEDEF'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in const [5, 10, 15, 25, 40])
            ChoiceChip(label: Text('$g'), selected: user.dailyGoal == g, onSelected: (_) => user.setDailyGoal(g)),
        ]),
        const SizedBox(height: 6),
        Text('Cevapladığın alıştırmalar ve söylediğin cümleler sayılır.', style: TextStyle(color: p.muted, fontSize: 13)),
        const SectionTitle('HATIRLATMA'),
        const _ReminderSetting(),
      ]),
    );
  }
}

/// Gün anahtarı için kısa yol (UserData.dayKey ile aynı biçim).
class UserDataKeys {
  static String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Stat extends StatelessWidget {
  final String value, label, icon;
  const _Stat({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final int n;
  final Color color;
  const _Row(this.label, this.n, this.color);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text('$n', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _ReminderSetting extends ConsumerWidget {
  const _ReminderSetting();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final p = context.pal;
    if (!Reminders.supported) {
      return Text('Günlük hatırlatma telefon uygulamasında çalışır. Web sürümünde Bugün ekranındaki seri sayacı seni takip eder.',
          style: TextStyle(color: p.muted, fontSize: 13));
    }
    final h = user.reminderHour;
    return Card(
      child: Column(children: [
        SwitchListTile(
          title: const Text('Günlük hatırlatma'),
          subtitle: Text(h == null ? 'Kapalı' : 'Her gün ${h.toString().padLeft(2, '0')}:00'),
          value: h != null,
          onChanged: (on) async {
            if (on) {
              final ok = await Reminders.schedule(20);
              if (ok) {
                await user.setReminderHour(20);
              } else if (context.mounted) {
                toast(context, 'Bildirim izni verilmedi. Ayarlar → Bildirimler → Lingora yolundan açabilirsin.');
              }
            } else {
              await Reminders.cancel();
              await user.setReminderHour(null);
            }
          },
        ),
        if (h != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(spacing: 8, children: [
              for (final hour in const [8, 12, 18, 20, 22])
                ChoiceChip(
                  label: Text('${hour.toString().padLeft(2, '0')}:00'),
                  selected: h == hour,
                  onSelected: (_) async {
                    if (await Reminders.schedule(hour)) await user.setReminderHour(hour);
                  },
                ),
            ]),
          ),
      ]),
    );
  }
}

