// Web (iPhone Safari dahil) için İngilizce metin okuma.
// Safari ses listesini geç yükler; bu yüzden her okumada dil açıkça en-US yapılır ve
// ses listesi değiştiğinde en iyi İngilizce ses yeniden seçilir.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.SpeechSynthesisVoice? _voice;
bool _listening = false;

int _score(web.SpeechSynthesisVoice v) {
  final lang = v.lang.toLowerCase().replaceAll('_', '-');
  if (!lang.startsWith('en')) return -1;
  var s = lang == 'en-us' ? 20 : (lang == 'en-gb' ? 14 : 8);
  final n = v.name.toLowerCase();
  const preferred = ['samantha', 'ava', 'allison', 'susan', 'alex', 'google us english', 'aria', 'jenny', 'zira', 'karen', 'daniel'];
  for (final p in preferred) {
    if (n.contains(p)) {
      s += 5;
      break;
    }
  }
  if (n.contains('enhanced') || n.contains('premium') || n.contains('natural') || n.contains('neural')) s += 4;
  // iOS'ta eğlence amaçlı sesler (Bells, Bubbles, Whisper…) telaffuz için uygun değil
  const novelty = ['bells', 'bubbles', 'whisper', 'bad news', 'good news', 'jester', 'organ', 'cellos', 'trinoids', 'zarvox', 'boing', 'superstar', 'wobble', 'albert', 'bahh', 'hysterical', 'junior', 'ralph', 'fred', 'kathy', 'grandma', 'grandpa', 'eddy', 'flo', 'reed', 'rocko', 'sandy', 'shelley'];
  for (final x in novelty) {
    if (n.contains(x)) s -= 15;
  }
  if (v.localService) s += 1;
  return s;
}

web.SpeechSynthesisVoice? _pick() {
  final voices = web.window.speechSynthesis.getVoices().toDart;
  web.SpeechSynthesisVoice? best;
  var bestScore = -1;
  for (final v in voices) {
    final s = _score(v);
    if (s > bestScore) {
      best = v;
      bestScore = s;
    }
  }
  return bestScore >= 0 ? best : null;
}

void initSpeech() {
  if (_listening) return;
  _listening = true;
  _voice = _pick();
  web.window.speechSynthesis.onvoiceschanged = ((web.Event _) {
    _voice = _pick();
  }).toJS;
}

/// [rate]: uygulama ayarı 0.2–0.8 (varsayılan 0.45). Web'de normal hız 1.0'dır.
/// Cihazda İngilizce ses yoksa okumaz ve false döner: Türkçe sesle yanlış telaffuz öğretmekten iyidir.
Future<bool> speakEnglish(String text, double rate) async {
  initSpeech();
  final synth = web.window.speechSynthesis;
  synth.cancel();
  _voice ??= _pick();
  // Bazı tarayıcılar ses listesini ilk istekten sonra yükler
  for (var i = 0; _voice == null && i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _voice = _pick();
  }
  final v = _voice;
  if (v == null) return false;
  final u = web.SpeechSynthesisUtterance(text);
  u.lang = v.lang;
  u.voice = v;
  u.rate = (0.5 + rate).clamp(0.5, 1.4);
  synth.speak(u);
  return true;
}

Future<void> stopSpeech() async {
  web.window.speechSynthesis.cancel();
}

String? currentVoiceName() => _voice?.name;
