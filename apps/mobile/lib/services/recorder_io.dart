import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> tempPath(String ext) async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/lingora_speech_${DateTime.now().millisecondsSinceEpoch}.$ext';
}

Future<Uint8List> readBytes(String path) async {
  final f = File(path);
  final b = await f.readAsBytes();
  try {
    await f.delete();
  } catch (_) {}
  return b;
}
