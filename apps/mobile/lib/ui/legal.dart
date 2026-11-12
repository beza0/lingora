import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

/// Yasal metin sayfaları (web/legal altında yayınlanır).
enum LegalPage {
  privacy('gizlilik', 'Gizlilik politikası'),
  kvkk('kvkk', 'KVKK aydınlatma metni'),
  terms('kullanim-sartlari', 'Kullanım şartları'),
  deletion('hesap-silme', 'Hesap ve veri silme');

  final String slug;
  final String title;
  const LegalPage(this.slug, this.title);

  Uri get uri => Uri.parse('${kIsWeb ? Uri.base.origin : AppConfig.webBaseUrl}/legal/$slug.html');
}

Future<void> openLegal(BuildContext context, LegalPage page) async {
  final ok = await launchUrl(page.uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${page.title} açılamadı: ${page.uri}')));
  }
}

/// Satır içi bağlantı düğmesi.
class LegalLink extends StatelessWidget {
  final LegalPage page;
  final String? label;
  const LegalLink(this.page, {super.key, this.label});

  @override
  Widget build(BuildContext context) => TextButton(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        onPressed: () => openLegal(context, page),
        child: Text(label ?? page.title),
      );
}
