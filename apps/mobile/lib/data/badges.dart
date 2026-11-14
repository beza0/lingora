import 'content.dart';
import 'user_data.dart';

/// Kazanılan rozet. [progress] 0–1 arası; kazanıldıysa 1.
class Achievement {
  final String id, icon, title, description;
  final int current, goal;
  const Achievement(this.id, this.icon, this.title, this.description, this.current, this.goal);
  bool get earned => current >= goal;
  double get progress => goal == 0 ? 1 : (current / goal).clamp(0, 1).toDouble();
}

/// Rozetler yalnız cihazdaki çalışma verisinden hesaplanır; sunucuya ek veri gönderilmez.
List<Achievement> computeBadges(UserData user, ContentRepo content) {
  final answers = user.events.length;
  final spoken = user.speakLog.values.fold<int>(0, (a, b) => a + b);
  final best = user.bestStreak();
  final started = user.cards.length;
  final saved = user.saved.where((s) => !s.deleted).length;
  var packsDone = 0;
  for (final p in content.packs) {
    final ids = content.packTargets[p['id']] ?? const <String>[];
    if (ids.isNotEmpty && ids.every(user.cards.containsKey)) packsDone++;
  }
  final levelDomains = user.activeDomains.where((d) => ContentRepo.isLevelDomain(d.domainId)).length;
  return [
    Achievement('first', '🌱', 'İlk adım', 'İlk alıştırmanı cevapla', answers, 1),
    Achievement('streak3', '🔥', 'Isınma turu', '3 gün üst üste çalış', best, 3),
    Achievement('streak7', '📅', 'Bir hafta', '7 gün üst üste çalış', best, 7),
    Achievement('streak30', '🏅', 'Alışkanlık', '30 gün üst üste çalış', best, 30),
    Achievement('answers100', '✏️', 'Yüz cevap', '100 alıştırma cevapla', answers, 100),
    Achievement('answers1000', '🚀', 'Bin cevap', '1000 alıştırma cevapla', answers, 1000),
    Achievement('words50', '📚', 'Kelime avcısı', '50 kelime veya kalıba başla', started, 50),
    Achievement('words300', '🧠', 'Geniş dağarcık', '300 kelime veya kalıba başla', started, 300),
    Achievement('speak10', '🎙️', 'Sesini duyur', '10 cümleyi sesli söyle', spoken, 10),
    Achievement('speak100', '🗣️', 'Akıcı konuşmacı', '100 cümleyi sesli söyle', spoken, 100),
    Achievement('pack1', '🎓', 'Ünite tamam', 'Bir ünitenin bütün hedeflerine başla', packsDone, 1),
    Achievement('saved10', '⭐', 'Koleksiyoncu', 'Koleksiyonuna 10 ifade kaydet', saved, 10),
    Achievement('level', '🪜', 'Seviye yolcusu', 'Bir A1–C2 seviye alanı ekle', levelDomains, 1),
  ];
}
