import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../services/backend.dart';
import '../../theme.dart';
import '../widgets.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  late Future<List<Map<String, Object?>>> threads = ref.read(backendProvider).chatThreads();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(() => threads = ref.read(backendProvider).chatThreads()),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          const Text('AI\'a sor', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('“Bunu İngilizce nasıl derim?”, “Bu cümle doğru mu?” gibi sorular sorabilirsin.', style: TextStyle(color: p.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await context.push('/chat/new');
              if (mounted) setState(() => threads = ref.read(backendProvider).chatThreads());
            },
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Yeni soru'),
          ),
          const SectionTitle('GEÇMİŞ'),
          FutureBuilder<List<Map<String, Object?>>>(
            future: threads,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              final list = snap.data ?? const [];
              if (list.isEmpty) return Text('Henüz sohbet yok.', style: TextStyle(color: p.muted));
              return Card(
                child: Column(children: [
                  for (final t in list)
                    ListTile(
                      leading: t['domain_id'] == null ? const Icon(Icons.chat_bubble_outline) : DomainDot(t['domain_id'] as String),
                      title: Text(t['title'] as String? ?? 'Sohbet', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/chat/${t['id']}'),
                    ),
                ]),
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _Msg {
  final String role;
  String text;
  bool error;
  _Msg(this.role, this.text, {this.error = false});
}

class ChatScreen extends ConsumerStatefulWidget {
  final String? threadId;
  final Map<String, Object?>? initialContext;
  const ChatScreen({super.key, this.threadId, this.initialContext});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final msgs = <_Msg>[];
  final input = TextEditingController();
  final scroll = ScrollController();
  String? threadId;
  bool sending = false;
  ApiError? blocking; // ai_not_configured / quota_exceeded
  StreamSubscription<(String, Map<String, Object?>)>? sub;
  int? used, limit;
  Map<String, Object?>? ctx;

  @override
  void initState() {
    super.initState();
    threadId = widget.threadId;
    ctx = widget.initialContext;
    if (threadId != null) _load();
    if (ctx != null && ctx!['text'] != null) {
      input.text = '“${ctx!['text']}” ne zaman ve nasıl kullanılır?';
    }
  }

  Future<void> _load() async {
    final rows = await ref.read(backendProvider).chatMessages(threadId!);
    if (!mounted) return;
    setState(() => msgs.addAll(rows.map((r) => _Msg(r['role'] as String, r['content'] as String))));
    _toBottom();
  }

  @override
  void dispose() {
    sub?.cancel();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  void _send() {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;
    final reply = _Msg('assistant', '');
    setState(() {
      msgs.add(_Msg('user', text));
      msgs.add(reply);
      input.clear();
      sending = true;
    });
    _toBottom();
    final context = ctx == null
        ? null
        : {'kind': ctx!['kind'], 'text': ctx!['text'], 'meaning_tr': ctx!['meaning_tr'], 'pack_title': ctx!['pack_title']};
    final stream = ref.read(backendProvider).chat(threadId: threadId, message: text, domainId: ctx?['domain_id'] as String?, context: context);
    sub = stream.listen(
      (ev) {
        final (name, data) = ev;
        setState(() {
          switch (name) {
            case 'meta':
              threadId = data['thread_id'] as String? ?? threadId;
              used = (data['used'] as num?)?.toInt();
              limit = (data['limit'] as num?)?.toInt();
            case 'delta':
              reply.text += data['text'] as String? ?? '';
            case 'error':
              reply.error = true;
              reply.text = reply.text.isEmpty ? (data['message'] as String? ?? 'Yanıt yarıda kesildi.') : '${reply.text}\n\n(${data['message']})';
          }
        });
        _toBottom();
      },
      onError: (Object e) {
        setState(() {
          msgs.remove(reply);
          final err = e is ApiError ? e : ApiError.offline;
          if (err.code == 'ai_not_configured' || err.code == 'quota_exceeded') {
            blocking = err;
          } else {
            msgs.add(_Msg('assistant', err.message, error: true));
          }
          sending = false;
        });
      },
      onDone: () {
        ctx = null; // bağlam yalnız ilk mesajda gönderilir
        setState(() => sending = false);
      },
      cancelOnError: true,
    );
  }

  void _stop() {
    sub?.cancel();
    setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final backend = ref.watch(backendProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI\'a sor'), actions: [
        if (used != null && limit != null)
          Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: Text('Bugün $used/$limit', style: TextStyle(color: p.muted)))),
      ]),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: blocking != null
                ? _Blocking(error: blocking!, guest: backend.account == AccountKind.guest)
                : msgs.isEmpty
                    ? ListView(padding: const EdgeInsets.all(20), children: [
                        Text('Örnek sorular', style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        for (final q in const [
                          'Toplantıya geç kalacağımı ekibe nasıl yazarım?',
                          '“Could you take a look at my PR?” kibar mı?',
                          '“I am agree with you” doğru mu?',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                              onPressed: () => setState(() => input.text = q),
                              child: Text(q),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text('AI yanıtları hata içerebilir. Önemli bir metni göndermeden önce kontrol et.', style: TextStyle(color: p.muted, fontSize: 13)),
                      ])
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: msgs.length,
                        itemBuilder: (_, i) => _MessageView(msg: msgs[i], typing: sending && i == msgs.length - 1),
                      ),
          ),
          if (blocking == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 1000,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Sorunu yaz', counterText: ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: sending ? 'Durdur' : 'Gönder',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: sending ? _stop : _send,
                  icon: Icon(sending ? Icons.stop : Icons.send),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Blocking extends StatelessWidget {
  final ApiError error;
  final bool guest;
  const _Blocking({required this.error, required this.guest});
  @override
  Widget build(BuildContext context) {
    if (error.code == 'quota_exceeded') {
      final resets = DateTime.tryParse(error.extra['resets_at'] as String? ?? '')?.toLocal();
      return EmptyState(
        icon: Icons.hourglass_bottom,
        title: 'Bugünkü AI hakkın doldu',
        body: '${resets == null ? 'Yarın' : 'Saat ${resets.hour.toString().padLeft(2, '0')}:${resets.minute.toString().padLeft(2, '0')}\'da'} yenilenir. '
            '${guest ? 'Hesap oluşturursan günlük hakkın artar.' : 'Bu arada hazır içeriklerle çalışmaya devam edebilirsin.'}',
        action: guest ? FilledButton(onPressed: () => context.push('/auth'), child: const Text('Hesap oluştur')) : null,
      );
    }
    return const EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'AI henüz yapılandırılmadı',
      body: 'Hazır içeriklerle çalışmaya devam edebilirsin. AI açıldığında sohbet burada çalışacak.',
    );
  }
}

/// Mesaj: `<en>…</en>` blokları dinle/kopyala/kaydet düğmeli kartlar olarak gösterilir.
class _MessageView extends ConsumerWidget {
  final _Msg msg;
  final bool typing;
  const _MessageView({required this.msg, required this.typing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final mine = msg.role == 'user';
    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.primarySoft, borderRadius: BorderRadius.circular(14)),
          child: Text(msg.text, style: const TextStyle(fontSize: 16)),
        ),
      );
    }
    if (msg.text.isEmpty && typing) {
      return const Padding(padding: EdgeInsets.all(12), child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    final parts = <Widget>[];
    final re = RegExp(r'<en>([\s\S]*?)</en>');
    var last = 0;
    for (final m in re.allMatches(msg.text)) {
      final before = msg.text.substring(last, m.start).trim();
      if (before.isNotEmpty) parts.add(Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(before, style: const TextStyle(fontSize: 15, height: 1.4))));
      parts.add(_EnCard(text: m.group(1)!.trim()));
      last = m.end;
    }
    final rest = msg.text.substring(last).replaceAll(RegExp(r'</?en>?'), '').trim();
    if (rest.isNotEmpty) parts.add(Text(rest, style: TextStyle(fontSize: 15, height: 1.4, color: msg.error ? p.danger : p.text)));
    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: msg.error ? p.danger : p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: parts),
    );
  }
}

class _EnCard extends ConsumerWidget {
  final String text;
  const _EnCard({required this.text});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
      child: Row(children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        SpeakButton(text, size: 20),
        CopyButton(text),
        IconButton(
          tooltip: 'Koleksiyona ekle',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Icon(Icons.bookmark_add_outlined, color: p.muted, size: 20),
          onPressed: () async {
            await ref.read(userProvider).addCustom(textEn: text, source: 'ai');
            ref.read(backendProvider).sync(ref.read(userProvider));
            if (context.mounted) toast(context, 'Koleksiyona eklendi');
          },
        ),
      ]),
    );
  }
}
