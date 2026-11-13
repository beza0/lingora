import 'share_stub.dart' if (dart.library.js_interop) 'share_web.dart' as impl;

/// Metin paylaşır: web'de (iPhone Safari dahil) sistem paylaşım menüsü açılır.
/// Desteklenmiyorsa false döner; çağıran panoya kopyalar.
Future<bool> shareText(String text, {String? url}) => impl.shareText(text, url: url);
