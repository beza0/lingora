import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../data/content.dart';
import '../../services/telemetry.dart';
import '../../theme.dart';
import '../widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0; // 0 karşılama, 1 hedef, 2 alanlar
  List<String> suggested = const [];
  @override
  Widget build(BuildContext context) {
    if (step == 2) return DomainPickerScreen(editing: false, suggested: suggested);
    if (step == 1) {
      return GoalScreen(
        onBack: () => setState(() => step = 0),
        onDone: (domains) => setState(() {
          suggested = domains;
          step = 2;
        }),
      );
    }
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
            FilledButton(onPressed: () => setState(() => step = 1), child: const Text('Başla')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => context.push('/auth?mode=login'), child: const Text('Zaten hesabım var')),
          ]),
        ),
      ),
    );
  }
}

/// İlk açılış: öğrenme amacı ve günlük hedef. Amaca göre alan önerir.
class GoalScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final void Function(List<String> suggestedDomains) onDone;
  const GoalScreen({super.key, required this.onBack, required this.onDone});
  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

const _goals = <(String, IconData, String, String, List<String>)>[
  ('is', Icons.work_outline, 'İş ve kariyer', 'Toplantı, e-posta, iş görüşmesi', ['general', 'software']),
  ('sinav', Icons.school_outlined, 'Sınav', 'YDS, YÖKDİL, akademik okuma', ['yds']),
  ('seyahat', Icons.flight_takeoff, 'Seyahat', 'Otel, havalimanı, yol sorma', ['tourism', 'general']),
  ('gunluk', Icons.forum_outlined, 'Günlük konuşma', 'Tanışma, alışveriş, sohbet', ['general']),
  ('meslek', Icons.medical_services_outlined, 'Mesleğim için', 'Mühendislik, sağlık, hukuk', ['engineering', 'health', 'law']),
  ('seviye', Icons.stairs_outlined, 'Seviyemi yükseltmek', 'A1–C2 gramer ve kelime dersleri', ['a2', 'b1']),
];

class _GoalScreenState extends ConsumerState<GoalScreen> {
  String? goal;
  int minutes = 10;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: widget.onBack), title: const Text('Hedefin')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        const Text('İngilizceyi en çok ne için istiyorsun?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Sana uygun alanları önereceğiz; sonra değiştirebilirsin.', style: TextStyle(color: p.muted)),
        const SizedBox(height: 16),
        for (final g in _goals) ...[
          Semantics(
            selected: goal == g.$1,
            button: true,
            child: Card(
              color: goal == g.$1 ? p.primarySoft : null,
              child: ListTile(
                leading: Icon(g.$2, color: p.primary),
                title: Text(g.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(g.$4),
                trailing: goal == g.$1 ? Icon(Icons.check_circle, color: p.primary) : null,
                onTap: () => setState(() => goal = g.$1),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 16),
        const Text('Günde ne kadar zaman ayırabilirsin?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 5, label: Text('5 dk')),
            ButtonSegment(value: 10, label: Text('10 dk')),
            ButtonSegment(value: 20, label: Text('20 dk')),
          ],
          selected: {minutes},
          onSelectionChanged: (v) => setState(() => minutes = v.first),
        ),
        const SizedBox(height: 8),
        Text('Kısa ama her gün çalışmak, uzun ama ara sıra çalışmaktan daha etkili.', style: TextStyle(color: p.muted, fontSize: 13)),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: goal == null
                ? null
                : () async {
                    final user = ref.read(userProvider);
                    await user.setLearningGoal(goal!);
                    // Dakikayı günlük hedef sayısına çevir: dakikada yaklaşık 3 alıştırma
                    await user.setDailyGoal(minutes * 3);
                    Telemetry.instance.event('goal', {'goal': goal, 'minutes': minutes});
                    widget.onDone(_goals.firstWhere((g) => g.$1 == goal).$5);
                  },
            child: const Text('Devam'),
          ),
        ),
      ),
    );
  }
}

class DomainPickerScreen extends ConsumerStatefulWidget {
  final bool editing;
  final List<String> suggested;
  const DomainPickerScreen({super.key, required this.editing, this.suggested = const []});
  @override
  ConsumerState<DomainPickerScreen> createState() => _DomainPickerScreenState();
}

class _DomainPickerScreenState extends ConsumerState<DomainPickerScreen> {
  late final List<String> selected = () {
    final current = ref.read(userProvider).activeDomains.map((d) => d.domainId).toList();
    if (current.isNotEmpty || widget.editing) return current;
    final known = ref.read(contentProvider).domainList.map((d) => d['id'] as String).toSet();
    return widget.suggested.where(known.contains).toList();
  }();

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final p = context.pal;
    final firstLevel = content.domainList.where((d) => ContentRepo.isLevelDomain(d['id'] as String)).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(widget.editing ? 'Alanlarım' : 'Alanlarını seç')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        if (!widget.editing) ...[
          const Text('Hangi alanlarda çalışmak istersin?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (widget.suggested.isNotEmpty) ...[
            Text('Hedefine göre önerdiklerimizi seçtik.', style: TextStyle(color: p.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
          ],
        ],
        Text('Birden fazla seçebilirsin. Sıra, ana sayfadaki sırayı belirler.', style: TextStyle(color: p.muted)),
        const SizedBox(height: 16),
        for (final d in content.domainList) ...[
          if (d == firstLevel) ...[
            const SizedBox(height: 8),
            const Text('Seviyeye göre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('A1’den C2’ye gramer, kelime ve kalıp dersleri. Seviyeni bilmiyorsan A2 veya B1 ile başla.', style: TextStyle(color: p.muted)),
            const SizedBox(height: 12),
          ] else if (d == content.domainList.first && firstLevel != null) ...[
            const Text('Alana göre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
          ],
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
                    if (!widget.editing) {
                      await user.completeOnboarding();
                      Telemetry.instance.event('onboarding_done', {'domains': selected.length});
                    }
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
