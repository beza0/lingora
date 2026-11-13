import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_state.dart';
import '../../services/backend.dart';
import '../../services/telemetry.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Premium tanıtımı. Ödeme henüz bağlı değil: mağaza hesapları açılınca App Store / Google Play
/// abonelikleri bağlanacak. Şimdilik ilgi kaydı alınır, plan yönetici tarafından atanabilir.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  late final Future<String> plan = ref.read(backendProvider).myPlan();
  bool interested = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final backend = ref.watch(backendProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lingora Premium')),
      body: FutureBuilder<String>(
        future: plan,
        builder: (context, snap) {
          final isPremium = snap.data == 'premium';
          return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7356F0), Color(0xFF4527C4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.workspace_premium, color: Color(0xFFFFB547), size: 36),
                const SizedBox(height: 8),
                Text(isPremium ? 'Premium üyesisin' : 'Daha çok pratik, daha hızlı ilerleme',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  isPremium ? 'Tüm Premium özellikleri hesabında açık. Teşekkürler!' : 'Temel çalışma her zaman ücretsiz. Premium, AI ile pratiği sınırsıza yakın hâle getirir.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            const SectionTitle('PREMIUM İLE'),
            Card(
              child: Column(children: const [
                _Benefit(icon: Icons.forum_outlined, title: '3 kat AI hakkı', body: 'Sohbet, rol yapma, yazma değerlendirmesi ve konuşma pratiğinde günlük hak üç katına çıkar.'),
                _Benefit(icon: Icons.record_voice_over_outlined, title: 'Sınırsıza yakın konuşma pratiği', body: 'Telaffuzunu her gün istediğin kadar dene.'),
                _Benefit(icon: Icons.library_books_outlined, title: 'Yeni paketlere erken erişim', body: 'Yeni alan ve paketler önce Premium üyelere açılır.'),
                _Benefit(icon: Icons.favorite_outline, title: 'Lingora\'yı destekle', body: 'Uygulama reklamsız kalır; gelir içerik ve sunucu giderlerine gider.'),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Ücretsiz planda kalanlar: tüm dersler ve tekrarlar, ilerleme, seri, misafir 10 / hesap 20 günlük AI sohbet hakkı.',
                style: TextStyle(color: p.muted, fontSize: 13)),
            const SizedBox(height: 24),
            if (!isPremium) ...[
              FilledButton(
                onPressed: interested
                    ? null
                    : () {
                        Telemetry.instance.event('premium_interest', {'account': backend.account.name});
                        setState(() => interested = true);
                        toast(context, 'Teşekkürler! Premium açıldığında haber vereceğiz.');
                      },
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: Text(interested ? 'İlgin kaydedildi' : 'Premium açılınca haber ver'),
              ),
              const SizedBox(height: 8),
              Text('Premium şu an test aşamasında; ödeme henüz alınmıyor. Mağaza sürümüyle birlikte App Store ve Google Play üzerinden abonelik olarak açılacak.',
                  textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
              if (backend.account != AccountKind.email) ...[
                const SizedBox(height: 12),
                Text('Premium için bir hesap gerekir; ilerlemen hesabına taşınır.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
              ],
            ],
          ]);
        },
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _Benefit({required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: context.pal.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(body),
      );
}
