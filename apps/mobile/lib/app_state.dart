import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/content.dart';
import 'data/user_data.dart';
import 'services/backend.dart';
import 'services/sound_fx.dart';
import 'services/speech_native.dart' if (dart.library.js_interop) 'services/speech_web.dart' as speech;

final contentProvider = Provider<ContentRepo>((ref) => throw UnimplementedError('bootstrap'));
final userProvider = ChangeNotifierProvider<UserData>((ref) => throw UnimplementedError('bootstrap'));
final backendProvider = ChangeNotifierProvider<Backend>((ref) => throw UnimplementedError('bootstrap'));
final speakerProvider = Provider<Speaker>((ref) => Speaker());
final soundProvider = Provider<SoundFx>((ref) {
  final fx = SoundFx();
  fx.enabled = ref.watch(userProvider.select((u) => u.soundOn));
  return fx;
});

/// İngilizce metin okuma. Telefonun dili ne olursa olsun en-US ses kullanılır.
class Speaker {
  Speaker() {
    speech.initSpeech();
  }

  Future<void> speak(String text, {double rate = 0.45}) => speech.speakEnglish(text, rate);
  Future<void> stop() => speech.stopSpeech();
  String? get voiceName => speech.currentVoiceName();
}
