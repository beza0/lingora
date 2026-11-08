/// AI ile rol yapma senaryoları. `role` AI'ın oynadığı rol ve ortamdır (İngilizce, sunucu yönergesine gider);
/// `goal` kullanıcının bu konuşmada başarması gerekendir (Türkçe).
class Roleplay {
  final String id;
  final String domain;
  final String title;
  final String goal;
  final String role;
  const Roleplay(this.id, this.domain, this.title, this.goal, this.role);

  Map<String, Object?> toContext() => {
        'kind': 'roleplay',
        'roleplay_id': id,
        'domain_id': domain,
        'pack_title': title,
        'text': role,
        'meaning_tr': goal,
      };
}

const roleplays = <Roleplay>[
  // Genel
  Roleplay('rp_cafe', 'general', 'Kafede sipariş', 'Bir içecek ve atıştırmalık sipariş et, fiyatı sor ve ödemeyi yap.',
      'You are a friendly barista at a busy café in London. Greet the customer, take their order, suggest a size or a snack, and tell them the price.'),
  Roleplay('rp_hotel', 'general', 'Otelde giriş', 'Rezervasyonunla giriş yap, kahvaltı saatini ve Wi‑Fi şifresini öğren.',
      'You are a hotel receptionist. The guest has a reservation for three nights. Check them in, ask for their name and ID, and answer questions about breakfast and Wi-Fi.'),
  Roleplay('rp_neighbor', 'general', 'Yeni komşuyla tanışma', 'Kendini tanıt, nereden geldiğini anlat ve mahalle hakkında bir öneri iste.',
      'You are a friendly new neighbour who just moved in next door. Introduce yourself, ask where the user is from and chat about the neighbourhood.'),
  // Yazılım
  Roleplay('rp_standup', 'software', 'Günlük stand-up', 'Dün ne yaptığını, bugün ne yapacağını ve seni engelleyen bir şeyi anlat.',
      'You are the scrum master running a daily stand-up meeting for a software team. Ask the user what they did yesterday, what they will do today and whether anything is blocking them. Ask short follow-up questions.'),
  Roleplay('rp_codereview', 'software', 'Kod incelemesi', 'Pull request\'teki bir yorumu yanıtla, değişikliğini açıkla ve bir düzeltme öner.',
      'You are a senior developer reviewing the user\'s pull request. You are concerned that a new function has no tests and that a variable name is unclear. Discuss it politely and ask the user to explain their change.'),
  Roleplay('rp_interview', 'software', 'İş görüşmesi', 'Kendini ve son projeni tanıt, bir teknik soruyu kendi cümlelerinle yanıtla.',
      'You are a hiring manager interviewing the user for a junior backend developer role. Ask about their background, a recent project and one simple technical question. Keep a professional but friendly tone.'),
  // Mühendislik
  Roleplay('rp_site', 'engineering', 'Şantiye toplantısı', 'Gecikmenin nedenini açıkla ve yeni bir tarih öner.',
      'You are a project manager at a construction site meeting. A concrete delivery was delayed and the schedule is at risk. Ask the user, the site engineer, what happened and what the new plan is.'),
  Roleplay('rp_supplier', 'engineering', 'Tedarikçiyle görüşme', 'Bir parçanın teknik özelliklerini sor, teslim süresini ve fiyatı netleştir.',
      'You are a sales engineer at a supplier of industrial pumps. The user is an engineer who needs a pump for a project. Answer questions about specifications, lead time and price, and ask about their requirements.'),
  Roleplay('rp_safety', 'engineering', 'İş güvenliği bildirimi', 'Gördüğün bir güvenlik sorununu bildir ve alınacak önlemi öner.',
      'You are a health and safety officer at a factory. The user wants to report a safety issue they noticed. Ask what they saw, where and when, and discuss what action should be taken.'),
  // YDS / akademik
  Roleplay('rp_professor', 'yds', 'Hocayla görüşme', 'Ödev teslim tarihini uzatmak için kibarca izin iste ve nedenini açıkla.',
      'You are a university professor during office hours. The student wants to ask for an extension on an essay deadline. Ask for their reason and discuss a new date. Be polite but a little strict.'),
  Roleplay('rp_seminar', 'yds', 'Seminerde tartışma', 'Bir makale hakkında görüşünü söyle ve bir karşı görüşe yanıt ver.',
      'You are a fellow student in an academic seminar discussing an article about the effects of social media on young people. Share an opinion, ask the user for theirs and politely challenge it.'),
  Roleplay('rp_conference', 'yds', 'Konferansta tanışma', 'Araştırma konunu kısaca anlat ve iletişim bilgisi paylaş.',
      'You are a researcher at an international conference coffee break. Start a conversation with the user, ask about their research and their university, and talk about possible collaboration.'),
];

Roleplay? roleplayById(String? id) {
  for (final r in roleplays) {
    if (r.id == id) return r;
  }
  return null;
}
