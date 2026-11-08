import 'package:audioplayers/audioplayers.dart';

/// Kısa ses efektleri: düğme dokunuşu, doğru, yanlış, bölüm sonu.
enum Fx { tap, correct, wrong, complete }

class SoundFx {
  final Map<Fx, AudioPlayer> _players = {};
  bool enabled = true;

  String _file(Fx f) => switch (f) {
        Fx.tap => 'sounds/tap.wav',
        Fx.correct => 'sounds/correct.wav',
        Fx.wrong => 'sounds/wrong.wav',
        Fx.complete => 'sounds/complete.wav',
      };

  double _volume(Fx f) => switch (f) {
        Fx.tap => 0.35,
        Fx.correct => 0.6,
        Fx.wrong => 0.5,
        Fx.complete => 0.6,
      };

  Future<void> play(Fx f) async {
    if (!enabled) return;
    try {
      final p = _players.putIfAbsent(f, () => AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      await p.stop();
      await p.play(AssetSource(_file(f)), volume: _volume(f));
    } catch (_) {
      // Ses çalınamazsa (ör. tarayıcı izni) sessizce geç.
    }
  }
}
