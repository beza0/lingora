import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/content.dart';
import 'data/user_data.dart';
import 'services/backend.dart';
import 'services/sound_fx.dart';
import 'services/speech_native.dart' if (dart.library.js_interop) 'services/speech_web.dart' as speech;

final contentProvider = Provider<ContentRepo>((ref) => throw UnimplementedError('bootstrap'));
final userProvider = ChangeNotifierProvider<UserData>((ref) => throw UnimplementedError('bootstrap'));
final backendProvider = ChangeNotifierProvider<Backend>((ref) => throw UnimplementedError('bootstrap'));
final speakerProvider = Provider<Speaker>((ref) => Speaker(ref.read(backendProvider)));
final soundProvider = Provider<SoundFx>((ref) {
  final fx = SoundFx();
  fx.enabled = ref.watch(userProvider.select((u) => u.soundOn));
  return fx;
});

/// İngilizce metin okuma. Önce sunucuda üretilmiş doğal ses (her cihazda aynı), olmazsa cihazın İngilizce sesi.
class Speaker {
  final Backend? backend;
  final AudioPlayer _player = AudioPlayer();
  Speaker([this.backend]) {
    speech.initSpeech();
  }

  /// Ses çalınamazsa (sunucu sesi yok ve cihazda İngilizce ses yok) false döner.
  Future<bool> speak(String text, {double rate = 0.45}) async {
    final url = await backend?.ttsUrl(text);
    if (url != null) {
      try {
        await speech.stopSpeech();
        await _player.stop();
        await _player.setPlaybackRate((0.55 + rate).clamp(0.6, 1.3));
        await _player.play(UrlSource(url));
        return true;
      } catch (_) {
        // Çalınamazsa cihaz sesine düş
      }
    }
    return speech.speakEnglish(text, rate);
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    await speech.stopSpeech();
  }

  String? get voiceName => speech.currentVoiceName();
}
