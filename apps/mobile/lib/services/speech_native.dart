// iOS/Android için İngilizce metin okuma (cihazın kendi sesleri).
import 'package:flutter_tts/flutter_tts.dart';

final FlutterTts _tts = FlutterTts();
bool _ready = false;

void initSpeech() {}

Future<void> speakEnglish(String text, double rate) async {
  try {
    if (!_ready) {
      await _tts.setSharedInstance(true);
      _ready = true;
    }
    // Dil her seferinde ayarlanır; telefonun dili Türkçe olsa bile İngilizce ses kullanılır.
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    await _tts.stop();
    await _tts.speak(text);
  } catch (_) {
    // Ses yoksa sessizce geç; metin ekranda zaten var.
  }
}

Future<void> stopSpeech() async {
  try {
    await _tts.stop();
  } catch (_) {}
}

String? currentVoiceName() => null;
