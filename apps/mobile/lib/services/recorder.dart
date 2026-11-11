import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'recorder_io.dart' if (dart.library.js_interop) 'recorder_web.dart' as impl;

class Recording {
  final Uint8List bytes;
  final String mime;
  const Recording(this.bytes, this.mime);
}

/// Mikrofon kaydı. Web'de (Chrome) webm/opus, Safari ve iPhone'da m4a/AAC kullanılır.
class VoiceRecorder {
  final AudioRecorder _r = AudioRecorder();
  String _mime = 'audio/mp4';
  bool recording = false;

  /// İzin verilmezse false döner.
  Future<bool> start() async {
    if (!await _r.hasPermission()) return false;
    var encoder = AudioEncoder.aacLc;
    _mime = 'audio/mp4';
    if (kIsWeb && await _r.isEncoderSupported(AudioEncoder.opus)) {
      encoder = AudioEncoder.opus;
      _mime = 'audio/webm';
    }
    final path = await impl.tempPath(encoder == AudioEncoder.opus ? 'webm' : 'm4a');
    await _r.start(RecordConfig(encoder: encoder, numChannels: 1), path: path);
    recording = true;
    return true;
  }

  Future<Recording?> stop() async {
    recording = false;
    final path = await _r.stop();
    if (path == null || path.isEmpty) return null;
    final bytes = await impl.readBytes(path);
    return Recording(bytes, _mime);
  }

  Future<void> cancel() async {
    recording = false;
    try {
      await _r.cancel();
    } catch (_) {}
  }

  void dispose() {
    _r.dispose();
  }
}
