import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../services/backend.dart';
import '../../services/recorder.dart';
import '../../services/sound_fx.dart';
import '../../srs/answer_check.dart';
import '../../srs/session.dart';
import '../../theme.dart';
import '../widgets.dart';

/// Konuşma pratiği: cümleyi dinle, sesli söyle, uygulama duyduğunu yazar ve kelime kelime karşılaştırır.
class SpeakScreen extends ConsumerStatefulWidget {
  final String domainId;
  final String? targetId; // tek bir hedef için açıldıysa
  const SpeakScreen({super.key, required this.domainId, this.targetId});
  @override
  ConsumerState<SpeakScreen> createState() => _SpeakScreenState();
}

enum _Phase { ready, recording, checking, result }

class _SpeakScreenState extends ConsumerState<SpeakScreen> {
  final rec = VoiceRecorder();
  late final List<String> items;
  int index = 0;
  _Phase phase = _Phase.ready;
  SpeechMatch? match;
  String? error;
  bool hideEnglish = false;
  final scores = <int>[];

  @override
  void initState() {
    super.initState();
    final content = ref.read(contentProvider);
    final user = ref.read(userProvider);
    items = widget.targetId != null ? [widget.targetId!] : pickSpeakingTargets(content, widget.domainId, user.cards);
  }

  @override
  void dispose() {
    rec.cancel();
    rec.dispose();
    super.dispose();
  }

  String get _sentence => cleanSentence(ref.read(contentProvider).view(items[index])!.exampleEn);

  Future<void> _toggleRecord() async {
    if (phase == _Phase.recording) return _stop();
    setState(() => error = null);
    try {
      await ref.read(speakerProvider).stop();
      final ok = await rec.start();
      if (!ok) {
        setState(() => error = 'Mikrofon izni verilmedi. Tarayıcının veya telefonun ayarlarından Lingora için mikrofonu aç.');
        return;
      }
      ref.read(soundProvider).play(Fx.tap);
      setState(() => phase = _Phase.recording);
    } catch (_) {
      setState(() => error = 'Kayıt başlatılamadı. Bu cihazda mikrofon kullanılamıyor olabilir.');
    }
  }

  Future<void> _stop() async {
    setState(() => phase = _Phase.checking);
    try {
      final r = await rec.stop();
      if (r == null || r.bytes.length < 1000) {
        setState(() {
          phase = _Phase.ready;
          error = 'Ses kaydedilemedi. Düğmeye bas, cümleyi söyle, sonra tekrar bas.';
        });
        return;
      }
      final heard = await ref.read(backendProvider).transcribe(r.bytes, r.mime);
      final m = matchSpeech(_sentence, heard);
      final pct = (m.score * 100).round();
      scores.add(pct);
      await ref.read(userProvider).logSpeech(pct);
      ref.read(soundProvider).play(m.good ? Fx.correct : Fx.wrong);
      setState(() {
        match = m;
        phase = _Phase.result;
      });
    } on ApiError catch (e) {
      setState(() {
        phase = _Phase.ready;
        error = e.message;
      });
    } catch (_) {
      setState(() {
        phase = _Phase.ready;
        error = 'Beklenmeyen bir hata oluştu. Tekrar dene.';
      });
    }
  }

  void _next() {
    setState(() {
      index++;
      match = null;
      error = null;
      phase = _Phase.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final content = ref.watch(contentProvider);
    if (items.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Konuşma pratiği')), body: const EmptyState(icon: Icons.mic_none, title: 'Söylenecek cümle yok', body: 'Bu alanda konuşma pratiğine uygun cümle bulunamadı.'));
    }
    if (index >= items.length) return _summary(context);
    if (!ref.watch(userProvider).aiConsent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Konuşma pratiği')),
        body: ListView(padding: const EdgeInsets.all(16), children: const [AiConsentCard(feature: 'Konuşma pratiği')]),
      );
    }
    final v = content.view(items[index])!;
    final sentence = cleanSentence(v.exampleEn);
    final showEn = !hideEnglish || phase == _Phase.result;
    return Scaffold(
      appBar: AppBar(
        title: Text('Konuşma pratiği · ${index + 1}/${items.length}'),
        actions: [
          if (items.length > 1)
            IconButton(
              tooltip: hideEnglish ? 'İngilizceyi göster' : 'Ezberden söyle (İngilizceyi gizle)',
              icon: Icon(hideEnglish ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => hideEnglish = !hideEnglish),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          Text(hideEnglish ? 'Türkçesini okuyup İngilizcesini ezberden söyle.' : 'Önce dinle, sonra mikrofona basıp cümleyi sesli söyle.', style: TextStyle(color: p.muted)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(v.headline, style: TextStyle(color: p.primary, fontWeight: FontWeight.w700))),
                  SpeakButton(sentence),
                ]),
                const SizedBox(height: 8),
                if (match != null)
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final w in match!.words)
                      Text(w.word,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: w.heard ? p.success : p.danger,
                            decoration: w.heard ? null : TextDecoration.underline,
                          )),
                  ])
                else if (showEn)
                  Text(sentence, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))
                else
                  Text('• • •', style: TextStyle(fontSize: 22, color: p.muted)),
                const SizedBox(height: 10),
                Text(v.exampleTr, style: TextStyle(color: p.muted, fontSize: 15)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          if (match != null) _resultBox(context, match!),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: TextStyle(color: p.danger))),
          if (phase != _Phase.result) Center(child: _micButton(context)),
          if (phase == _Phase.result) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    match = null;
                    phase = _Phase.ready;
                  }),
                  icon: const Icon(Icons.replay),
                  label: const Text('Tekrar dene'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _next, child: Text(index + 1 < items.length ? 'Sonraki' : 'Bitir'))),
            ]),
          ],
          const SizedBox(height: 16),
          Text('Kaydın yalnız yazıya çevrilmek için sunucuya gönderilir, saklanmaz.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _micButton(BuildContext context) {
    final p = context.pal;
    final recording = phase == _Phase.recording;
    final checking = phase == _Phase.checking;
    return Column(children: [
      Semantics(
        button: true,
        label: checking ? 'Dinleniyor' : (recording ? 'Kaydı bitir' : 'Cümleyi söylemek için kaydı başlat'),
        excludeSemantics: true,
        child: SizedBox(
        width: 88,
        height: 88,
        child: FilledButton(
          style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: recording ? p.danger : p.primary, padding: EdgeInsets.zero),
          onPressed: checking ? null : _toggleRecord,
          child: checking
              ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
              : Icon(recording ? Icons.stop : Icons.mic, size: 40, color: Colors.white),
        ),
        ),
      ),
      const SizedBox(height: 10),
      Text(checking ? 'Dinleniyor…' : (recording ? 'Söyle, bitince dokun' : 'Söylemek için dokun'), style: TextStyle(color: p.muted)),
    ]);
  }

  Widget _resultBox(BuildContext context, SpeechMatch m) {
    final p = context.pal;
    final pct = (m.score * 100).round();
    final title = m.perfect ? 'Harika, eksiksiz!' : (m.good ? 'Çok iyi, neredeyse tamam.' : (pct >= 50 ? 'İyi deneme.' : 'Biraz daha deneyelim.'));
    final missed = m.words.where((w) => !w.heard).map((w) => w.word).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: m.good ? p.successSoft : p.surface2, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$title  %$pct', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 6),
        Text('Duyulan: “${m.heard.isEmpty ? '—' : m.heard}”', style: TextStyle(color: p.muted)),
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Duyulmayan veya farklı duyulan kelimeler — dokunup tek tek dinle:'),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final w in missed)
              ActionChip(
                avatar: const Icon(Icons.volume_up_outlined, size: 18),
                label: Text(w),
                tooltip: '$w kelimesini dinle',
                onPressed: () => speakOrExplain(context, ref, w.replaceAll(RegExp(r"[^A-Za-z0-9'’-]"), '')),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _summary(BuildContext context) {
    final p = context.pal;
    final avg = scores.isEmpty ? 0 : (scores.reduce((a, b) => a + b) / scores.length).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Konuşma pratiği')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Icons.record_voice_over_outlined, size: 56, color: p.primary),
            const SizedBox(height: 12),
            Text('${scores.length} cümle söyledin', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Ortalama anlaşılırlık: %$avg', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => context.pop(), child: const Text('Tamam')),
          ]),
        ),
      ),
    );
  }
}
