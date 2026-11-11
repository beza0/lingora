import 'reminders_stub.dart' if (dart.library.io) 'reminders_io.dart' as impl;

/// Günlük çalışma hatırlatması (telefon uygulamasında yerel bildirim; web'de yok).
class Reminders {
  static bool get supported => impl.supported;

  /// Her gün [hour]:00'da (İstanbul saati) bildirim kurar. İzin verilmezse false.
  static Future<bool> schedule(int hour) => impl.schedule(hour);

  static Future<void> cancel() => impl.cancel();
}
