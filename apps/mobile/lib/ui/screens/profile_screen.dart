import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../services/backend.dart';
import '../../theme.dart';
import '../legal.dart';
import '../widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Map<String, int>> usage = ref.read(backendProvider).aiUsageToday();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final backend = ref.watch(backendProvider);
    final content = ref.watch(contentProvider);
    final p = context.pal;
    const skillNames = {'vocab': 'Kelime', 'reading': 'Okuma', 'listening': 'Dinleme', 'writing': 'Yazılı ifade'};
    final stats = user.skillStats();

    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
        const Text('Profil', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SectionTitle('HESAP'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                switch (backend.account) {
                  AccountKind.email => backend.email ?? 'Hesap',
                  AccountKind.guest => 'Misafir',
                  AccountKind.none => AppConfig.hasBackend ? 'Bağlantı bekleniyor' : 'Çevrimdışı sürüm',
                },
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                switch (backend.account) {
                  AccountKind.email => backend.provider == 'google' ? 'Google ile giriş yapıldı. İlerlemen hesabına eşitleniyor.' : 'İlerlemen hesabına eşitleniyor.',
                  AccountKind.guest => 'İlerlemen bu cihazda ve misafir hesabında. Kaybetmemek için hesap oluştur.',
                  AccountKind.none => 'Veriler yalnız bu cihazda.',
                },
                style: TextStyle(color: p.muted),
              ),
              const SizedBox(height: 12),
              if (backend.account == AccountKind.guest) ...[
                FilledButton(onPressed: () => context.push('/auth'), child: const Text('Hesap oluştur')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => context.push('/auth?mode=login'), child: const Text('Var olan hesaba giriş yap')),
              ],
              if (backend.account == AccountKind.email)
                OutlinedButton(
                  onPressed: () async {
                    final ok = await _confirm(context, 'Çıkış yap?', 'Bu cihazdaki veriler silinir; hesabındaki ilerleme korunur.');
                    if (ok) await backend.signOut(user);
                  },
                  child: const Text('Çıkış yap'),
                ),
              if (backend.lastSyncAt != null) ...[
                const SizedBox(height: 8),
                Text('Son eşitleme: ${TimeOfDay.fromDateTime(backend.lastSyncAt!).format(context)}', style: TextStyle(color: p.muted, fontSize: 12)),
              ],
            ]),
          ),
        ),
        const SectionTitle('BECERİLER'),
        Card(
          child: Column(children: [
            for (final e in skillNames.entries)
              ListTile(
                title: Text(e.value),
                trailing: Text(
                  (stats[e.key]?.attempts ?? 0) < 10
                      ? 'Henüz yeterli veri yok'
                      : '%${((stats[e.key]!.unaided / stats[e.key]!.attempts) * 100).round()} yardımsız doğru · ${stats[e.key]!.attempts} deneme',
                  style: TextStyle(color: p.muted, fontSize: 13),
                ),
              ),
          ]),
        ),
        const SectionTitle('ALANLAR'),
        Card(
          child: Column(children: [
            for (final d in user.activeDomains)
              ListTile(
                leading: DomainDot(d.domainId),
                title: Text(content.domains[d.domainId]?['name_tr'] as String? ?? d.domainId),
                subtitle: Text('Seviye ${d.level} / 5'),
                onTap: () => context.push('/assessment/${d.domainId}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: 'Daha kolay', icon: const Icon(Icons.remove), onPressed: d.level > 1 ? () => user.setLevel(d.domainId, d.level - 1) : null),
                  IconButton(tooltip: 'Daha zor', icon: const Icon(Icons.add), onPressed: d.level < 5 ? () => user.setLevel(d.domainId, d.level + 1) : null),
                ]),
              ),
            ListTile(
              title: const Text('Seviye testini yeniden yapmak için alana dokun'),
              dense: true,
              textColor: p.muted,
            ),
            ListTile(title: const Text('Alanları düzenle'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/domains')),
          ]),
        ),
        const SectionTitle('AYARLAR'),
        Card(
          child: Column(children: [
            ListTile(
              title: const Text('Görünüm'),
              trailing: DropdownButton<String>(
                value: user.themeMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('Sistem')),
                  DropdownMenuItem(value: 'light', child: Text('Açık')),
                  DropdownMenuItem(value: 'dark', child: Text('Koyu')),
                ],
                onChanged: (v) => user.setTheme(v ?? 'system'),
              ),
            ),
            SwitchListTile(
              title: const Text('AI özellikleri'),
              subtitle: const Text('Sohbet, rol yapma, yazma değerlendirmesi ve konuşma pratiği. Açıkken yazdıkların ve ses kayıtların Groq (ABD) tarafından işlenir.'),
              value: user.aiConsent,
              onChanged: (v) => user.setAiConsent(v),
            ),
            SwitchListTile(
              title: const Text('Anonim kullanım istatistikleri'),
              subtitle: const Text('Hangi ekranların kullanıldığını hesabınla ilişkilendirmeden gönderir; uygulamayı iyileştirmemize yardım eder.'),
              value: user.usageStats,
              onChanged: (v) => user.setUsageStats(v),
            ),
            SwitchListTile(
              title: const Text('Ses efektleri'),
              subtitle: const Text('Doğru, yanlış ve düğme sesleri'),
              value: user.soundOn,
              onChanged: (v) => user.setSound(v),
            ),
            ListTile(
              title: const Text('Konuşma hızı'),
              subtitle: Slider(value: user.ttsRate, min: 0.2, max: 0.8, divisions: 6, onChanged: (v) => user.setTtsRate(v)),
              trailing: SpeakButton('This is how fast I will speak.'),
            ),
            if (ref.read(speakerProvider).voiceName != null)
              ListTile(title: const Text('İngilizce ses'), trailing: Text(ref.read(speakerProvider).voiceName!, style: TextStyle(color: p.muted))),
            FutureBuilder<Map<String, int>>(
              future: usage,
              builder: (_, snap) {
                final u = snap.data ?? const {};
                final guest = backend.account == AccountKind.guest;
                return ListTile(
                  title: const Text('Bugünkü AI kullanımı'),
                  subtitle: Text('Sohbet ${u['chat'] ?? 0}/${guest ? 10 : 20} · Değerlendirme ${u['eval'] ?? 0}/${guest ? 10 : 50}'),
                );
              },
            ),
          ]),
        ),
        const SectionTitle('VERİLERİN'),
        Card(
          child: Column(children: [
            for (final page in LegalPage.values)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(page.title),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => openLegal(context, page),
              ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Verilerimi dışa aktar'),
              subtitle: const Text('JSON olarak panoya kopyalanır'),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(user.exportJson())));
                if (context.mounted) toast(context, 'Verilerin panoya kopyalandı');
              },
            ),
            if (backend.signedIn)
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: p.danger),
                title: Text('Hesabımı ve verilerimi sil', style: TextStyle(color: p.danger)),
                onTap: () async {
                  final ok = await _confirm(context, 'Hesabını silmek istiyor musun?', 'Bütün ilerlemen, kayıtların ve sohbetlerin kalıcı olarak silinir. Bu işlem geri alınamaz.', danger: true);
                  if (!ok) return;
                  try {
                    await backend.deleteAccount(user);
                    if (context.mounted) toast(context, 'Hesabın silindi.');
                  } catch (e) {
                    if (context.mounted) toast(context, errorText(e));
                  }
                },
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(
          'Lingora test sürümü · içerik ${content.version}${content.showDrafts ? ' · taslaklar görünür' : ''}',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ]),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body, {bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: ctx.pal.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(danger ? 'Sil' : 'Tamam'),
        ),
      ],
    ),
  );
  return ok == true;
}
