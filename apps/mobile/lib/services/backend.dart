import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../data/user_data.dart';
import '../srs/fsrs.dart';

/// Sunucu hatası (docs/api-contract.md §4). `code` uygulamanın davranışını belirler.
class ApiError implements Exception {
  final String code;
  final String message;
  final Map<String, Object?> extra;
  const ApiError(this.code, this.message, [this.extra = const {}]);
  @override
  String toString() => message;

  static const offline = ApiError('offline', 'İnternet bağlantısı yok. Hazır içeriklerle çalışmaya devam edebilirsin.');
  static const noBackend = ApiError('no_backend', 'Sunucu ayarları bu sürümde yok. Uygulama çevrimdışı çalışıyor.');
}

enum AccountKind { none, guest, email }

/// Supabase bağlantısı: oturum, eşitleme, AI uç noktaları ve hesap işlemleri.
class Backend extends ChangeNotifier {
  bool ready = false;
  String? lastSyncError;
  DateTime? lastSyncAt;
  bool syncing = false;

  SupabaseClient? get _c => AppConfig.hasBackend && ready ? Supabase.instance.client : null;
  User? get user => _c?.auth.currentUser;
  bool get signedIn => user != null;
  AccountKind get account {
    final u = user;
    if (u == null) return AccountKind.none;
    return u.isAnonymous ? AccountKind.guest : AccountKind.email;
  }

  String? get email => user?.email;

  Future<void> init() async {
    if (!AppConfig.hasBackend) return;
    try {
      await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
      ready = true;
      Supabase.instance.client.auth.onAuthStateChange.listen((s) {
        notifyListeners();
        // Mobilde Google girişi uygulama açıkken derin bağlantıyla döner
        final d = _data;
        if (s.event == AuthChangeEvent.signedIn && d != null) unawaited(finishPendingMerge(d));
      });
      await ensureSession();
    } catch (e) {
      debugPrint('backend init: $e');
    }
    notifyListeners();
  }

  /// Oturum yoksa misafir (anonim) oturum açar. Ağ yoksa sessizce geçer; sonra yeniden denenir.
  Future<void> ensureSession() async {
    final c = _c;
    if (c == null || c.auth.currentUser != null) return;
    try {
      await c.auth.signInAnonymously();
    } catch (e) {
      debugPrint('anonymous sign-in: $e');
    }
    notifyListeners();
  }

  /// Sunucudaki `show_drafts` ayarı (test projesinde true).
  Future<bool?> fetchShowDrafts() async {
    final c = _c;
    if (c == null) return null;
    try {
      final rows = await c.from('app_config').select('key,value').eq('key', 'show_drafts');
      if (rows.isEmpty) return null;
      return rows.first['value'] == 'true';
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ eşitleme
  Future<void> sync(UserData data, {bool pull = false}) async {
    final c = _c;
    final u = user;
    if (c == null || u == null || syncing) return;
    syncing = true;
    notifyListeners();
    try {
      final uid = u.id;
      if (pull) await _pull(c, uid, data);
      // 1. cevap olayları (yinelenen kimlik sunucuda yok sayılır)
      final pending = data.events.where((e) => !e.synced).toList();
      for (var i = 0; i < pending.length; i += 200) {
        final chunk = pending.sublist(i, (i + 200).clamp(0, pending.length));
        await c.from('review_events').upsert(
              chunk
                  .map((e) => {
                        'id': e.id,
                        'user_id': uid,
                        'target_id': e.targetId,
                        'exercise_id': e.exerciseId,
                        'session_id': e.sessionId,
                        'skill': e.skill,
                        'outcome': e.toJson()['outcome'],
                        'rating': e.rating.value,
                        'hints_used': e.hintsUsed,
                        'scheduled': e.scheduled,
                        'answered_at': e.answeredAt.toUtc().toIso8601String(),
                      })
                  .toList(),
              onConflict: 'id',
              ignoreDuplicates: true,
            );
        final ids = chunk.map((e) => e.id).toList();
        await data.store.markSynced(ids);
        for (final e in chunk) {
          e.synced = true;
        }
      }
      // 2. kart durumları
      final dirty = await data.store.dirtyCards();
      if (dirty.isNotEmpty) {
        final rows = <Map<String, Object?>>[];
        for (final id in dirty) {
          final card = data.cards[id];
          if (card == null) continue;
          final j = card.toJson();
          rows.add({
            'user_id': uid,
            'target_id': id,
            'stability': j['stability'],
            'difficulty': j['difficulty'],
            'due_at': j['due_at'],
            'reps': j['reps'],
            'lapses': j['lapses'],
            'state': j['state'],
            'last_review_at': j['last_review_at'],
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
        if (rows.isNotEmpty) await c.from('card_states').upsert(rows, onConflict: 'user_id,target_id');
        await data.store.clearDirtyCards(dirty);
      }
      // 3. alanlar, kişisel öğeler ve kayıtlar
      if (data.dirtyMeta) {
        if (data.domains.isNotEmpty) {
          await c.from('user_domains').upsert(
                data.domains
                    .map((d) => {
                          'user_id': uid,
                          'domain_id': d.domainId,
                          'active': d.active,
                          'level_estimate': d.level,
                          'sort': d.sort,
                          'updated_at': DateTime.now().toUtc().toIso8601String(),
                        })
                    .toList(),
                onConflict: 'user_id,domain_id',
              );
        }
        if (data.custom.isNotEmpty) {
          await c.from('custom_items').upsert(
                data.custom
                    .map((x) => {
                          'id': x.id,
                          'user_id': uid,
                          'text_en': x.textEn,
                          'meaning_tr': x.meaningTr,
                          'note': x.note,
                          'domain_id': x.domainId,
                          'source': x.source,
                          'deleted_at': x.deleted ? DateTime.now().toUtc().toIso8601String() : null,
                          'updated_at': DateTime.now().toUtc().toIso8601String(),
                        })
                    .toList(),
                onConflict: 'id',
              );
        }
        if (data.saved.isNotEmpty) {
          await c.from('saved_items').upsert(
                data.saved
                    .map((s) => {
                          'id': s.id,
                          'user_id': uid,
                          'target_id': s.targetId,
                          'custom_item_id': s.customId,
                          'deleted_at': s.deleted ? DateTime.now().toUtc().toIso8601String() : null,
                          'updated_at': DateTime.now().toUtc().toIso8601String(),
                        })
                    .toList(),
                onConflict: 'id',
              );
        }
        await data.clearMetaDirty();
      }
      lastSyncAt = DateTime.now();
      lastSyncError = null;
    } catch (e) {
      lastSyncError = e.toString();
      debugPrint('sync: $e');
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Sunucudaki olayları cihaza alır ve kartları yeniden hesaplar (yeni cihaz / giriş sonrası).
  Future<void> _pull(SupabaseClient c, String uid, UserData data) async {
    final rows = await c.from('review_events').select().eq('user_id', uid).order('answered_at').limit(10000);
    final remote = rows
        .map((r) => AnswerEvent.fromJson({
              ...r,
              'domain_id': data.domainOf?.call(r['target_id'] as String),
              'synced': true,
            }))
        .toList();
    final added = await data.mergeRemoteEvents(remote);
    if (added > 0) await data.recomputeCards(only: remote.map((e) => e.targetId).toSet());
  }

  // ------------------------------------------------------------ uç noktalar
  Future<http.Response> _post(String fn, Map<String, Object?> body) async {
    final c = _c;
    if (c == null) throw ApiError.noBackend;
    await ensureSession();
    final token = c.auth.currentSession?.accessToken;
    if (token == null) throw ApiError.offline;
    try {
      return await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/$fn'),
            headers: {'Authorization': 'Bearer $token', 'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const ApiError('provider_error', 'İstek zaman aşımına uğradı. Tekrar dene.');
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError.offline;
    }
  }

  static ApiError errorFrom(http.Response r) {
    try {
      final j = (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, Object?>();
      final e = (j['error'] as Map).cast<String, Object?>();
      return ApiError(e['code'] as String? ?? 'server_error', e['message'] as String? ?? 'Beklenmeyen bir hata oluştu.', e);
    } catch (_) {
      return ApiError('server_error', 'Beklenmeyen bir hata oluştu (${r.statusCode}).');
    }
  }

  Map<String, Object?> _json(http.Response r) {
    if (r.statusCode >= 400) throw errorFrom(r);
    return (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, Object?>();
  }

  /// Serbest cevap değerlendirmesi. Önce sunucu yerel kontrol yapar; gerekirse AI çağrılır.
  Future<Map<String, Object?>> evaluate({
    required String promptTr,
    required String expected,
    required List<String> accepted,
    required String answer,
    String skill = 'vocab',
    List<String>? rubric,
  }) async {
    final r = await _post('ai-evaluate', {
      'task': {'skill': skill, 'prompt_tr': promptTr, 'expected': expected, 'accepted': accepted, 'answer': answer, if (rubric != null) 'rubric': rubric},
    });
    return _json(r);
  }

  /// Konuşma kaydını yazıya çevirir (sunucuda Whisper). Kota: misafir 20, hesap 60 / gün.
  Future<String> transcribe(Uint8List audio, String mime) async {
    final r = await _post('ai-transcribe', {'audio': base64Encode(audio), 'mime': mime});
    return (_json(r)['text'] as String? ?? '').trim();
  }

  final Map<String, String> _ttsUrls = {};
  bool _ttsDisabled = false;

  /// İçerik cümlesinin sunucuda üretilmiş ses dosyası adresi. Sunucu seslendirmesi kapalıysa null.
  Future<String?> ttsUrl(String text) async {
    if (_ttsDisabled || _c == null) return null;
    final key = text.trim();
    final cached = _ttsUrls[key];
    if (cached != null) return cached;
    try {
      final r = await _post('ai-tts', {'text': key});
      final url = _json(r)['url'] as String?;
      if (url != null) _ttsUrls[key] = url;
      return url;
    } on ApiError catch (e) {
      // Sağlayıcı kapalı veya yapılandırılmamışsa bu oturumda tekrar denenmez; cihaz sesi kullanılır.
      if (e.code == 'provider_error' || e.code == 'ai_not_configured' || e.code == 'quota_exceeded') _ttsDisabled = true;
      return null;
    }
  }

  /// AI sohbet; SSE olaylarını sırayla döndürür (meta, delta, done, error).
  Stream<(String, Map<String, Object?>)> chat({String? threadId, required String message, String? domainId, Map<String, Object?>? context}) async* {
    final c = _c;
    if (c == null) throw ApiError.noBackend;
    await ensureSession();
    final token = c.auth.currentSession?.accessToken;
    if (token == null) throw ApiError.offline;
    final req = http.Request('POST', Uri.parse('${AppConfig.supabaseUrl}/functions/v1/ai-chat'))
      ..headers.addAll({'Authorization': 'Bearer $token', 'apikey': AppConfig.supabaseAnonKey, 'Content-Type': 'application/json'})
      ..body = jsonEncode({if (threadId != null) 'thread_id': threadId, 'message': message, if (domainId != null) 'domain_id': domainId, if (context != null) 'context': context});
    final client = http.Client();
    try {
      final http.StreamedResponse res;
      try {
        res = await client.send(req).timeout(const Duration(seconds: 60));
      } catch (_) {
        throw ApiError.offline;
      }
      if (res.statusCode >= 400) {
        throw errorFrom(await http.Response.fromStream(res));
      }
      var buf = '';
      await for (final chunk in res.stream.transform(utf8.decoder)) {
        buf += chunk;
        var idx = buf.indexOf('\n\n');
        while (idx >= 0) {
          final block = buf.substring(0, idx);
          buf = buf.substring(idx + 2);
          String? event;
          final data = StringBuffer();
          for (final line in block.split('\n')) {
            if (line.startsWith('event:')) event = line.substring(6).trim();
            if (line.startsWith('data:')) data.write(line.substring(5).trim());
          }
          if (event != null && data.isNotEmpty) {
            yield (event, (jsonDecode(data.toString()) as Map).cast<String, Object?>());
          }
          idx = buf.indexOf('\n\n');
        }
      }
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, Object?>>> chatThreads() async {
    final c = _c;
    final u = user;
    if (c == null || u == null) return const [];
    final rows = await c.from('chat_threads').select('id,title,domain_id,updated_at').eq('user_id', u.id).order('updated_at', ascending: false).limit(50);
    return rows.map((r) => r.cast<String, Object?>()).toList();
  }

  Future<List<Map<String, Object?>>> chatMessages(String threadId) async {
    final c = _c;
    if (c == null) return const [];
    final rows = await c.from('chat_messages').select('role,content,context_ref,created_at').eq('thread_id', threadId).order('created_at', ascending: true);
    return rows.map((r) => r.cast<String, Object?>()).toList();
  }

  Future<Map<String, int>> aiUsageToday() async {
    final c = _c;
    if (c == null || user == null) return const {};
    try {
      final rows = await c.rpc('my_ai_usage') as List;
      return {for (final r in rows) (r as Map)['kind'] as String: (r['requests'] as num).toInt()};
    } catch (_) {
      return const {};
    }
  }

  Future<void> saveAssessment({required String domainId, required List<Map<String, Object?>> steps, required int result, required int chosen}) async {
    final c = _c;
    final u = user;
    if (c == null || u == null) return;
    try {
      await c.from('assessments').insert({
        'id': newId(),
        'user_id': u.id,
        'domain_id': domainId,
        'steps': steps,
        'result_level': result,
        'chosen_level': chosen,
      });
    } catch (e) {
      debugPrint('assessment: $e');
    }
  }

  Future<void> report({required String entityType, required String entityId, required String reason, String? text}) async {
    final c = _c;
    final u = user;
    if (c == null || u == null) throw ApiError.offline;
    await c.from('content_reports').insert({'user_id': u.id, 'entity_type': entityType, 'entity_id': entityId, 'reason': reason, 'text': text});
  }

  // ------------------------------------------------------------ hesap
  /// Misafir hesabını e-posta hesabına çevirir; veriler aynı kullanıcıda kalır.
  Future<void> upgradeWithEmail(String email, String password) async {
    final c = _c;
    if (c == null) throw ApiError.noBackend;
    try {
      await c.auth.updateUser(UserAttributes(email: email, password: password), emailRedirectTo: _redirect());
    } on AuthException catch (e) {
      throw ApiError('auth', _authMessage(e));
    }
    notifyListeners();
  }

  /// Var olan hesaba giriş. Misafir verisi varsa birleştirme belirteci önce alınır, girişten sonra kullanılır.
  Future<Map<String, Object?>?> signInExisting(String email, String password, UserData data) async {
    final c = _c;
    if (c == null) throw ApiError.noBackend;
    String? token;
    if (account == AccountKind.guest) {
      await sync(data);
      try {
        token = _json(await _post('merge-guest', {'action': 'prepare'}))['token'] as String?;
      } catch (_) {
        token = null;
      }
    }
    try {
      await c.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw ApiError('auth', _authMessage(e));
    }
    Map<String, Object?>? merged;
    if (token != null) {
      try {
        merged = _json(await _post('merge-guest', {'action': 'complete', 'token': token}));
      } on ApiError catch (e) {
        if (e.code != 'not_found') rethrow; // kullanılmış belirteç: birleştirme zaten yapılmış
      }
    }
    // Yerel kartlar sunucuya yazılsın, sunucudaki geçmiş cihaza gelsin
    for (final id in data.cards.keys) {
      await data.store.putCard(id, data.cards[id]!.toJson());
    }
    data.dirtyMeta = true;
    await sync(data, pull: true);
    notifyListeners();
    return merged;
  }

  static const _pendingMergeKey = 'pending_merge_token';
  UserData? _data;
  bool _merging = false;

  /// Google girişinden dönüşte birleştirme yapılabilsin diye kullanıcı verisi bağlanır.
  void attach(UserData data) => _data = data;

  /// Google ile giriş. Misafir verisi varsa birleştirme belirteci yönlendirmeden önce saklanır;
  /// dönüşte [finishPendingMerge] misafir ilerlemesini Google hesabına taşır (yeni veya var olan hesap).
  Future<void> signInWithGoogle(UserData data) async {
    final c = _c;
    if (c == null) throw ApiError.noBackend;
    if (account == AccountKind.guest) {
      await sync(data);
      try {
        final token = _json(await _post('merge-guest', {'action': 'prepare'}))['token'] as String?;
        if (token != null) await data.store.putKv(_pendingMergeKey, token);
      } catch (_) {
        // Birleştirme hazırlanamazsa giriş yine yapılır; misafir verisi bu cihazda kalır
      }
    }
    try {
      await c.auth.signInWithOAuth(OAuthProvider.google, redirectTo: kIsWeb ? '${Uri.base.origin}/' : AppConfig.authRedirect);
    } on AuthException catch (e) {
      throw ApiError('auth', _authMessage(e));
    }
  }

  /// Bekleyen misafir birleştirmesini tamamlar. Belirteç yoksa hiçbir şey yapmaz.
  Future<Map<String, Object?>?> finishPendingMerge(UserData data) async {
    if (_merging || account != AccountKind.email) return null;
    final token = await data.store.getKv(_pendingMergeKey);
    if (token == null || token.isEmpty) return null;
    _merging = true;
    Map<String, Object?>? merged;
    try {
      await data.store.putKv(_pendingMergeKey, '');
      try {
        merged = _json(await _post('merge-guest', {'action': 'complete', 'token': token}));
      } on ApiError catch (e) {
        if (e.code != 'not_found') debugPrint('merge: ${e.code}');
      }
      for (final id in data.cards.keys) {
        await data.store.putCard(id, data.cards[id]!.toJson());
      }
      data.dirtyMeta = true;
      await sync(data, pull: true);
    } finally {
      _merging = false;
      notifyListeners();
    }
    return merged;
  }

  /// Giriş yöntemi: "google" veya "email".
  String? get provider => user?.appMetadata['provider'] as String?;

  Future<void> resetPassword(String email) async {
    final c = _c;
    if (c == null) throw ApiError.noBackend;
    await c.auth.resetPasswordForEmail(email, redirectTo: _redirect());
  }

  Future<void> signOut(UserData data) async {
    final c = _c;
    if (c == null) return;
    await sync(data);
    await c.auth.signOut();
    await data.wipe();
    await ensureSession();
    notifyListeners();
  }

  Future<void> deleteAccount(UserData data) async {
    _json(await _post('delete-account', {'confirm': true}));
    try {
      await _c?.auth.signOut();
    } catch (_) {}
    await data.wipe();
    await ensureSession();
    notifyListeners();
  }

  String _redirect() => kIsWeb ? Uri.base.origin : AppConfig.authRedirect;

  static String _authMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'E-posta veya şifre hatalı.';
    if (m.contains('already') && m.contains('registered')) return 'Bu e-posta ile zaten bir hesap var. “Giriş yap” sekmesini kullan.';
    if (m.contains('password')) return 'Şifre en az 6 karakter olmalı.';
    if (m.contains('email') && m.contains('confirm')) return 'E-postanı doğrulaman gerekiyor. Gelen kutunu kontrol et.';
    if (m.contains('rate')) return 'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.';
    return e.message;
  }
}
