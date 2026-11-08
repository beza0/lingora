import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'data/content.dart';
import 'data/user_data.dart';
import 'services/backend.dart';

final contentProvider = Provider<ContentRepo>((ref) => throw UnimplementedError('bootstrap'));
final userProvider = ChangeNotifierProvider<UserData>((ref) => throw UnimplementedError('bootstrap'));
final backendProvider = ChangeNotifierProvider<Backend>((ref) => throw UnimplementedError('bootstrap'));
final speakerProvider = Provider<Speaker>((ref) => Speaker());

/// Cihazın metin okuma motoru (en-US). Ses dosyası yoktur.
class Speaker {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> speak(String text, {double rate = 0.45}) async {
    try {
      if (!_ready) {
        await _tts.setLanguage('en-US');
        _ready = true;
      }
      await _tts.setSpeechRate(rate);
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Ses yoksa sessizce geç; metin ekranda zaten var.
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
