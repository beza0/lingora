import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/share.dart';
import '../services/telemetry.dart';

/// Seri başarısını paylaşma: ekran görüntüsü alınabilecek bir kart ve paylaşım metni.
Future<void> shareStreak(BuildContext context, int streak, int words) async {
  final text = '🔥 Lingora\'da $streak günlük seri! Şimdiye kadar $words kelime ve kalıp çalıştım. '
      'İngilizce, senin alanında.';
  await showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF7356F0), Color(0xFF4527C4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(children: [
            const Text('🔥', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 4),
            Text('$streak günlük seri', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('$words kelime ve kalıp çalışıldı', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/brand/icon-128.png', width: 28, height: 28)),
              const SizedBox(width: 8),
              const Text('Lingora · İngilizce, senin alanında.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Kapat'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.ios_share),
                label: const Text('Paylaş'),
                onPressed: () async {
                  Telemetry.instance.event('share_streak', {'streak': streak});
                  final shared = await shareText(text, url: AppConfig.webBaseUrl);
                  if (!shared) {
                    await Clipboard.setData(ClipboardData(text: '$text ${AppConfig.webBaseUrl}'));
                    if (c.mounted) {
                      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Metin kopyalandı. Kartın ekran görüntüsünü de paylaşabilirsin.')));
                    }
                  }
                },
              ),
            ),
          ]),
        ),
      ]),
    ),
  );
}
