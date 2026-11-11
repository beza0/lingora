import 'dart:typed_data';

import 'package:http/http.dart' as http;

// Web'de kayıt bir blob adresine yazılır; baytlar oradan okunur.
Future<String> tempPath(String ext) async => '';

Future<Uint8List> readBytes(String path) async => (await http.get(Uri.parse(path))).bodyBytes;
