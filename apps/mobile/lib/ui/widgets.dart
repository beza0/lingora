import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../services/backend.dart';
import '../theme.dart';
import 'legal.dart';

/// İncelenmemiş (taslak) içerik rozeti. Test sürümünde bütün içerik taslaktır.
class DraftBadge extends StatelessWidget {
  const DraftBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      label: 'İncelenmemiş içerik',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: p.hintSoft, borderRadius: BorderRadius.circular(999)),
        child: Text('İncelenmedi', style: TextStyle(color: p.hint, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class SpeakButton extends ConsumerWidget {
  final String text;
  final double size;
  const SpeakButton(this.text, {super.key, this.size = 22});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Dinle',
      iconSize: size,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(Icons.volume_up_outlined, color: context.pal.primary),
      onPressed: () => speakOrExplain(context, ref, text),
    );
  }
}

/// İngilizce okur; cihazda İngilizce ses yoksa nasıl ekleneceğini anlatır (bir kez).
bool _explained = false;
Future<void> speakOrExplain(BuildContext context, WidgetRef ref, String text) async {
  final ok = await ref.read(speakerProvider).speak(text, rate: ref.read(userProvider).ttsRate);
  if (ok || !context.mounted) return;
  if (_explained) {
    toast(context, 'Bu cihazda İngilizce ses yok.');
    return;
  }
  _explained = true;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('İngilizce ses bulunamadı'),
      content: const Text(
        'Bu tarayıcıda yalnız Türkçe ses var; yanlış telaffuz öğretmemek için okumadım.\n\n'
        'Windows: Ayarlar → Saat ve dil → Konuşma → Ses ekle → English (United States). Ekledikten sonra sayfayı yenile.\n\n'
        'iPhone: Ayarlar → Erişilebilirlik → Sözlü İçerik → Sesler → English.\n\n'
        'Chrome veya Edge ile açarsan İngilizce sesler genelde hazırdır.',
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam'))],
    ),
  );
}

class CopyButton extends StatelessWidget {
  final String text;
  const CopyButton(this.text, {super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Kopyala',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        icon: Icon(Icons.copy_outlined, color: context.pal.muted, size: 20),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) toast(context, 'Kopyalandı');
        },
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .3, color: context.pal.muted))),
          if (trailing != null) trailing!,
        ]),
      );
}

class DomainDot extends StatelessWidget {
  final String domainId;
  final double size;
  const DomainDot(this.domainId, {super.key, this.size = 10});
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: context.pal.domain(domainId), shape: BoxShape.circle));
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: p.muted),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? bg;
  const Pill(this.text, {super.key, this.color, this.bg});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg ?? p.surface2, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.border)),
      child: Text(text, style: TextStyle(fontSize: 13, color: color ?? p.text)),
    );
  }
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
}

String errorText(Object e) {
  if (e is ApiError) return e.message;
  return 'Beklenmeyen bir hata oluştu. Tekrar dene.';
}

/// İçerik hatası bildirme sayfası.
Future<void> showReportSheet(BuildContext context, WidgetRef ref, {required String entityType, required String entityId}) async {
  const reasons = {
    'wrong_answer': 'Doğru cevap yanlış',
    'two_correct': 'İki seçenek de doğru',
    'translation': 'Çeviri hatalı',
    'audio': 'Ses sorunu',
    'typo': 'Yazım hatası',
    'other': 'Diğer',
  };
  String? selected;
  final note = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Hata bildir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in reasons.entries)
              ChoiceChip(label: Text(e.value), selected: selected == e.key, onSelected: (_) => setState(() => selected = e.key)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: note, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: 'İstersen kısa bir not ekle')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: selected == null
                ? null
                : () async {
                    try {
                      await ref.read(backendProvider).report(entityType: entityType, entityId: entityId, reason: selected!, text: note.text.trim().isEmpty ? null : note.text.trim());
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) toast(context, 'Teşekkürler, bildirimin alındı.');
                    } catch (e) {
                      if (ctx.mounted) toast(ctx, errorText(e));
                    }
                  },
            child: const Text('Gönder'),
          ),
        ]),
      ),
    ),
  );
}


/// AI özellikleri kapalıyken gösterilir: neden kapalı olduğunu söyler ve açık rızayla açmayı sağlar.
class AiConsentCard extends ConsumerWidget {
  final String feature;
  const AiConsentCard({super.key, this.feature = 'Bu özellik'});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome_outlined, color: p.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('AI özellikleri kapalı', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          ]),
          const SizedBox(height: 8),
          Text('$feature AI ile çalışıyor. Açarsan yazdıkların ve ses kayıtların işlenmek üzere yurt dışındaki '
              'hizmet sağlayıcıya (Groq, ABD) gönderilir; ses kayıtları saklanmaz.'),
          const LegalLink(LegalPage.kvkk, label: 'Ayrıntılar: KVKK aydınlatma metni'),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: () => ref.read(userProvider).setAiConsent(true),
            child: const Text('Açık rıza veriyorum, AI\'ı aç'),
          ),
        ]),
      ),
    );
  }
}
