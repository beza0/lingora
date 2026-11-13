import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> shareText(String text, {String? url}) async {
  try {
    final data = url == null ? web.ShareData(text: text) : web.ShareData(text: text, url: url);
    if (!web.window.navigator.canShare(data)) return false;
    await web.window.navigator.share(data).toDart;
    return true;
  } catch (_) {
    return false; // kullanıcı iptal etti veya desteklenmiyor
  }
}
