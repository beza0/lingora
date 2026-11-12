import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_state.dart';
import '../../services/telemetry.dart';
import '../../theme.dart';
import '../legal.dart';

/// Kullanım şartları ve gizlilik onayı; AI özellikleri için ayrı, isteğe bağlı açık rıza (KVKK m. 9).
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});
  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool terms = false;
  bool ai = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(userProvider);
    // Şartlar güncellendiyse önceki AI tercihi korunur
    if (u.termsVersion > 0) ai = u.aiConsent;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final updated = ref.watch(userProvider).termsVersion > 0;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: [
          Text(updated ? 'Metinlerimiz güncellendi' : 'Başlamadan önce', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Verilerini nasıl kullandığımızı kısaca anlatalım.', style: TextStyle(color: p.muted)),
          const SizedBox(height: 20),
          _Point(icon: Icons.lock_outline, text: 'Reklam yok, verin satılmaz. İlerlemen yalnız hesabında ve cihazında tutulur.'),
          _Point(icon: Icons.mic_none, text: 'Ses kayıtların saklanmaz; yalnız yazıya çevrilmek için gönderilir.'),
          _Point(icon: Icons.delete_outline, text: 'Hesabını ve tüm verini istediğin an Profil ekranından silebilirsin.'),
          const SizedBox(height: 8),
          Wrap(spacing: 16, children: const [LegalLink(LegalPage.privacy), LegalLink(LegalPage.kvkk), LegalLink(LegalPage.terms)]),
          const Divider(height: 32),
          CheckboxListTile(
            value: terms,
            onChanged: (v) => setState(() => terms = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Kullanım şartlarını ve gizlilik politikasını okudum, kabul ediyorum.'),
            subtitle: const Text('Zorunlu'),
          ),
          SwitchListTile(
            value: ai,
            onChanged: (v) => setState(() => ai = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('AI özellikleri (isteğe bağlı)'),
            subtitle: const Text(
              'AI sohbet, rol yapma, yazma değerlendirmesi ve konuşma pratiği için yazdıklarımın ve ses kayıtlarımın '
              'işlenmek üzere yurt dışındaki hizmet sağlayıcıya (Groq, ABD) aktarılmasına açık rıza veriyorum. '
              'Kapalıysa bu özellikler çalışmaz; istediğin zaman Profil → Ayarlar\'dan değiştirebilirsin.',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: !terms || busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await ref.read(userProvider).acceptTerms(ai: ai);
                    Telemetry.instance.event('consent', {'ai': ai});
                  },
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Devam et'),
          ),
        ]),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Point({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22, color: context.pal.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      );
}
