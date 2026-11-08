import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../services/backend.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Hesap oluşturma (misafir hesabını kalıcı hâle getirir) ve var olan hesaba giriş (misafir verisi birleştirilir).
class AuthScreen extends ConsumerStatefulWidget {
  final bool startWithLogin;
  const AuthScreen({super.key, this.startWithLogin = false});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool login = widget.startWithLogin;
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  String? info;

  Future<void> _submit() async {
    final e = email.text.trim();
    final pw = password.text;
    if (!e.contains('@') || e.length < 5) {
      setState(() => error = 'Geçerli bir e-posta yaz.');
      return;
    }
    if (pw.length < 6) {
      setState(() => error = 'Şifre en az 6 karakter olmalı.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    final backend = ref.read(backendProvider);
    final user = ref.read(userProvider);
    try {
      if (login) {
        final merged = await backend.signInExisting(e, pw, user);
        if (!user.onboarded) {
          if (user.domains.isEmpty) {
            // Sunucudaki alanlar henüz gelmediyse kullanıcı seçer
            if (mounted) context.go('/welcome');
          } else {
            await user.completeOnboarding();
          }
        }
        if (!mounted) return;
        final n = (merged?['counts'] as Map?)?['events'];
        toast(context, n != null && n != 0 ? 'Giriş yapıldı; misafir ilerlemen hesabına eklendi.' : 'Giriş yapıldı.');
        if (user.onboarded) context.go('/profile');
      } else {
        await backend.upgradeWithEmail(e, pw);
        setState(() => info = 'Doğrulama bağlantısı $e adresine gönderildi. Bağlantıya tıkladıktan sonra hesabın etkinleşir; bu arada çalışmaya devam edebilirsin.');
      }
    } on ApiError catch (x) {
      setState(() => error = x.message);
    } catch (_) {
      setState(() => error = 'Beklenmeyen bir hata oluştu. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final backend = ref.watch(backendProvider);
    return Scaffold(
      appBar: AppBar(title: Text(login ? 'Giriş yap' : 'Hesap oluştur')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Hesap oluştur')), ButtonSegment(value: true, label: Text('Giriş yap'))],
          selected: {login},
          onSelectionChanged: (s) => setState(() {
            login = s.first;
            error = null;
            info = null;
          }),
        ),
        const SizedBox(height: 16),
        Text(
          login
              ? 'Var olan hesabına gir. Bu cihazda misafir olarak yaptığın çalışmalar hesabına eklenir.'
              : 'Misafir ilerlemen kaybolmaz; aynı hesap kalıcı hâle gelir.',
          style: TextStyle(color: p.muted),
        ),
        const SizedBox(height: 16),
        if (!AppConfig.hasBackend || !backend.ready)
          Text('Sunucuya bağlanılamadı. İnternet bağlantını kontrol et.', style: TextStyle(color: p.danger))
        else if (!login && backend.account == AccountKind.email)
          Text('Zaten ${backend.email} hesabıyla giriş yaptın.', style: TextStyle(color: p.muted))
        else ...[
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            autofillHints: [login ? AutofillHints.password : AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Şifre (en az 6 karakter)'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: TextStyle(color: p.danger))),
          if (info != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.successSoft, borderRadius: BorderRadius.circular(12)),
              child: Text(info!),
            ),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(login ? 'Giriş yap' : 'Hesap oluştur'),
          ),
          if (login)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!email.text.contains('@')) {
                        setState(() => error = 'Önce e-postanı yaz.');
                        return;
                      }
                      try {
                        await backend.resetPassword(email.text.trim());
                        setState(() => info = 'Şifre sıfırlama bağlantısı gönderildi.');
                      } catch (e) {
                        setState(() => error = errorText(e));
                      }
                    },
              child: const Text('Şifremi unuttum'),
            ),
          const SizedBox(height: 16),
          Text('Google ile giriş yakında eklenecek.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13)),
        ],
      ]),
    );
  }
}
