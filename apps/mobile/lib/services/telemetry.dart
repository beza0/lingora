import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../data/local_store.dart';

/// Anonim kullanım ölçümü ve hata kaydı.
/// Hesapla ilişkilendirilmez: cihaza özgü rastgele bir kimlik kullanılır. İçerik metni, e-posta veya
/// kullanıcının yazdığı hiçbir şey gönderilmez. Kullanıcı Profil'den kullanım istatistiklerini kapatabilir;
/// hata kayıtları uygulamanın düzeltilmesi için her durumda gönderilir (yine anonim).
class Telemetry {
  Telemetry._();
  static final Telemetry instance = Telemetry._();

  LocalStore? _store;
  String? _installId;
  bool usageEnabled = true;
  final List<Map<String, Object?>> _queue = [];
  Timer? _timer;
  String _screen = '';
  final Set<String> _sentErrors = {};

  String get platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  Future<void> init(LocalStore store, {required bool usage}) async {
    _store = store;
    usageEnabled = usage;
    _installId = await store.getKv('install_id');
    if (_installId == null || _installId!.isEmpty) {
      _installId = const Uuid().v4();
      await store.putKv('install_id', _installId!);
    }
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  SupabaseClient? get _client {
    if (!AppConfig.hasBackend) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null; // henüz başlatılmadı
    }
  }

  /// Ekran değişimi: kimlikler yol şablonuna indirgenir (/target/abc → /target/:id).
  void screen(String location) {
    final path = location.split('?').first.replaceAllMapped(RegExp(r'/([^/]+)'), (m) {
      final seg = m.group(1)!;
      final isId = seg.length > 20 || RegExp(r'^[0-9a-f-]{8,}$').hasMatch(seg) || seg == 'new';
      return isId ? '/:id' : '/$seg';
    });
    if (path == _screen) return;
    _screen = path;
    event('screen', {'path': path});
  }

  void event(String name, [Map<String, Object?> props = const {}]) {
    if (!usageEnabled || _installId == null) return;
    _queue.add({'event': name, 'props': props});
    if (_queue.length >= 20) flush();
  }

  Future<void> flush() async {
    final c = _client;
    if (c == null || _queue.isEmpty || _installId == null) return;
    final batch = List<Map<String, Object?>>.from(_queue);
    _queue.clear();
    try {
      await c.rpc('log_usage', params: {'p_install_id': _installId, 'p_platform': platform, 'p_app_version': AppConfig.appVersion, 'p_events': batch});
    } catch (_) {
      if (_queue.length < 200) _queue.insertAll(0, batch); // sonra tekrar denenir
    }
  }

  Future<void> error(Object error, StackTrace? stack, {String? type}) async {
    final t = type ?? error.runtimeType.toString();
    final msg = _scrub(error.toString());
    final key = '$t|$msg';
    if (!_sentErrors.add(key)) return; // aynı hata bu oturumda bir kez
    if (kDebugMode) debugPrint('telemetry error: $t $msg');
    final c = _client;
    if (c == null) return;
    try {
      await c.rpc('log_client_error', params: {
        'p_install_id': _installId,
        'p_platform': platform,
        'p_app_version': AppConfig.appVersion,
        'p_screen': _screen,
        'p_error_type': t.length > 120 ? t.substring(0, 120) : t,
        'p_message': msg,
        'p_stack': stack == null ? null : _scrub(stack.toString().split('\n').take(25).join('\n')),
      });
    } catch (_) {}
  }

  /// Hata metninde olabilecek e-posta ve uzun sayı/simge dizilerini maskeler.
  static String _scrub(String s) => s
      .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '<e-posta>')
      .replaceAll(RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), '<token>')
      .replaceAll(RegExp(r'\b\d{6,}\b'), '<sayı>');

  @visibleForTesting
  static String scrub(String s) => _scrub(s);

  String debugJson() => jsonEncode(_queue);
}
