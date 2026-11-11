import 'package:flutter_test/flutter_test.dart';
import 'package:lingora/data/local_store.dart';
import 'package:lingora/data/user_data.dart';
import 'package:lingora/srs/answer_check.dart';
import 'package:lingora/srs/session.dart';

void main() {
  group('konuşma karşılaştırması', () {
    test('aynı cümle: hepsi duyuldu, noktalama ve büyük harf önemsiz', () {
      final m = matchSpeech('My only blocker is the missing API key.', 'my only blocker is the missing api key');
      expect(m.perfect, isTrue);
      expect(m.words.length, 8);
    });

    test('eksik kelime işaretlenir, sıra korunur', () {
      final m = matchSpeech('I fixed the login bug yesterday.', 'I fix the login bug yesterday');
      expect(m.words.map((w) => w.heard).toList(), [true, false, true, true, true, true]);
      expect(m.good, isTrue); // 5/6
    });

    test('kısaltmalar ve sayılar eşleşir', () {
      expect(matchSpeech("I'm based in Ankara.", 'I am based in Ankara').perfect, isTrue);
      expect(matchSpeech('It takes about 40 minutes.', "it takes about 40 minutes").perfect, isTrue);
      expect(matchSpeech('We took 10 samples.', 'we took ten samples').perfect, isTrue);
    });

    test('alakasız konuşma düşük puan alır', () {
      final m = matchSpeech('The tank has a capacity of 500 liters.', 'hello how are you');
      expect(m.score, lessThan(0.3));
      expect(matchSpeech('Sounds good.', '').score, 0);
    });

    test('tek harflik ses farkı (uzun kelimede) kabul edilir', () {
      expect(matchSpeech('Please check the dimensions.', 'please check the dimension').perfect, isTrue);
    });

    test('vurgu işaretleri temizlenir', () {
      expect(cleanSentence('My only [[blocker]] is here.'), 'My only blocker is here.');
    });
  });

  group('seri ve günlük hedef', () {
    test('konuşma ve cevaplar günlere göre sayılır; seri bugün yoksa dünden sayılır', () async {
      final u = UserData(MemoryStore());
      await u.load();
      final today = DateTime(2026, 11, 12, 10);
      await u.logSpeech(80, DateTime(2026, 11, 9, 9));
      await u.logSpeech(90, DateTime(2026, 11, 10, 9));
      await u.logSpeech(70, DateTime(2026, 11, 11, 21));
      expect(u.streak(today), 3);
      expect(u.todayCount(today), 0);
      await u.logSpeech(60, today);
      expect(u.streak(today), 4);
      expect(u.todayCount(today), 1);
      expect(u.bestStreak(), 4);
      final days = u.lastDays(7, today);
      expect(days.length, 7);
      expect(days.last.$2, 1);
      expect(u.speakScores[UserData.dayKey(today)], [60]);
    });

    test('ara verilince seri sıfırdan başlar', () async {
      final u = UserData(MemoryStore());
      await u.load();
      await u.logSpeech(80, DateTime(2026, 11, 1, 9));
      await u.logSpeech(80, DateTime(2026, 11, 2, 9));
      expect(u.streak(DateTime(2026, 11, 12)), 0);
      expect(u.bestStreak(), 2);
    });

    test('günlük hedef 5–100 arasında tutulur', () async {
      final u = UserData(MemoryStore());
      await u.load();
      await u.setDailyGoal(1);
      expect(u.dailyGoal, 5);
      await u.setDailyGoal(25);
      expect(u.dailyGoal, 25);
    });
  });
}
