// Falora — Kişiye özel, seed tabanlı mock AI fal yorumu üretici servisi.

import 'package:falora/ai_service.dart';
import 'package:falora/picked_image.dart';

enum FalCategory { tarot, bakla, kahve, su, iskambil }

class FalInput {
  const FalInput({
    required this.category,
    required this.name,
    required this.age,
    required this.burc,
    required this.niyet,
    required this.createdAt,
    this.photoNames = const [],
  });

  final FalCategory category;
  final String name;
  final int age;
  final String burc;
  final String niyet;
  final DateTime createdAt;
  final List<String> photoNames;
}

class CiftInput {
  const CiftInput({
    required this.kadinIsim,
    required this.kadinYas,
    required this.kadinBurc,
    required this.erkekIsim,
    required this.erkekYas,
    required this.erkekBurc,
    required this.createdAt,
    this.kadinFotoAdi,
    this.erkekFotoAdi,
  });

  final String kadinIsim;
  final int kadinYas;
  final String kadinBurc;
  final String erkekIsim;
  final int erkekYas;
  final String erkekBurc;
  final DateTime createdAt;
  final String? kadinFotoAdi;
  final String? erkekFotoAdi;
}

// ─── RNG & yardımcılar ──────────────────────────────────────────────────────

class _SeededRandom {
  _SeededRandom(int seed) : _state = seed & 0x7fffffff;
  int _state;

  int nextInt(int max) {
    if (max <= 0) return 0;
    _state = (_state * 1664525 + 1013904223) & 0x7fffffff;
    return _state % max;
  }

  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  T pick<T>(List<T> list) => list[nextInt(list.length)];
}

int _seedFrom(Iterable<String> parts) =>
    parts.fold(1, (h, s) => (h * 31 + s.hashCode) & 0x7fffffff);

int _wordCount(String t) =>
    t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

List<String> _sents(String t) =>
    t.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().isNotEmpty).toList();

// ─── Burç & niyet analizi ───────────────────────────────────────────────────

class _BurcInfo {
  const _BurcInfo(this.element, this.ozellik, this.guclu, this.zorluk, this.ask);
  final String element;
  final String ozellik;
  final String guclu;
  final String zorluk;
  final String ask;
}

const _burcMap = <String, _BurcInfo>{
  'Koç': _BurcInfo('ateş', 'cesur ve atılgan', 'liderlik gücü', 'sabırsızlık', 'tutkulu'),
  'Boğa': _BurcInfo('toprak', 'kararlı ve sadık', 'dayanıklılık', 'inatçılık', 'güvenilir'),
  'İkizler': _BurcInfo('hava', 'meraklı ve çevik', 'iletişim', 'dağınıklık', 'zihinsel'),
  'Yengeç': _BurcInfo('su', 'duygusal ve koruyucu', 'sezgi', 'hassasiyet', 'şefkatli'),
  'Aslan': _BurcInfo('ateş', 'cömert ve görkemli', 'yaratıcılık', 'gurur', 'tutkulu'),
  'Başak': _BurcInfo('toprak', 'titiz ve analitik', 'detaycılık', 'eleştiri', 'pratik'),
  'Terazi': _BurcInfo('hava', 'dengeli ve zarif', 'diplomasi', 'kararsızlık', 'romantik'),
  'Akrep': _BurcInfo('su', 'derin ve yoğun', 'dönüşüm', 'kontrol', 'manyetik'),
  'Yay': _BurcInfo('ateş', 'özgür ve iyimser', 'vizyon', 'huzursuzluk', 'maceracı'),
  'Oğlak': _BurcInfo('toprak', 'disiplinli', 'strateji', 'mesafe', 'ciddi'),
  'Kova': _BurcInfo('hava', 'özgün', 'yenilik', 'uzaklık', 'zihinsel'),
  'Balık': _BurcInfo('su', 'hassas', 'empati', 'belirsizlik', 'ruhsal'),
};

_BurcInfo _burc(String b) =>
    _burcMap[b] ?? const _BurcInfo('kozmik', 'özel', 'iç güç', 'belirsizlik', 'derin');

enum _NiyetTema { para, ask, eskiSevgili, aile, gelecek, saglik, genel }

class _NiyetProfil {
  _NiyetProfil(this.tema, this.anahtarlar);
  final _NiyetTema tema;
  final List<String> anahtarlar;

  static _NiyetProfil analiz(String niyet) {
    final n = niyet.toLowerCase();
    final keys = <String>[];
    _NiyetTema tema = _NiyetTema.genel;

    if (_esles(n, ['para', 'zengin', 'iş', 'kariyer', 'maaş', 'bereket', 'kazan'])) {
      tema = _NiyetTema.para;
      keys.addAll(['maddi akış', 'disiplin', 'fırsat']);
    } else if (_esles(n, ['aşk', 'sevgi', 'ilişki', 'evlilik', 'flört', 'partner'])) {
      tema = _NiyetTema.ask;
      keys.addAll(['kalp', 'bağ', 'çekim']);
    } else if (_esles(n, ['eski', 'geri dön', 'ayrılık', 'barış'])) {
      tema = _NiyetTema.eskiSevgili;
      keys.addAll(['kapanış', 'yeni sayfa', 'geçmiş']);
    } else if (_esles(n, ['aile', 'anne', 'baba', 'kardeş', 'ev'])) {
      tema = _NiyetTema.aile;
      keys.addAll(['kök', 'bağ', 'huzur']);
    } else if (_esles(n, ['gelecek', 'yol', 'kader', 'hedef', 'başarı'])) {
      tema = _NiyetTema.gelecek;
      keys.addAll(['vizyon', 'adım', 'potansiyel']);
    } else if (_esles(n, ['sağlık', 'enerji', 'huzur', 'ruh', 'stres'])) {
      tema = _NiyetTema.saglik;
      keys.addAll(['denge', 'dinlenme', 'iç huzur']);
    } else {
      keys.addAll(['dönüşüm', 'netlik', 'yön']);
    }
    return _NiyetProfil(tema, keys);
  }

  static bool _esles(String n, List<String> kelimeler) =>
      kelimeler.any(n.contains);
}

String _yasTonu(int yas) {
  if (yas < 22) return 'keşif ve deneme döneminde';
  if (yas < 30) return 'inşa ve yön bulma döneminde';
  if (yas < 40) return 'olgunlaşma ve derinleşme döneminde';
  if (yas < 55) return 'hasat ve sorumluluk döneminde';
  return 'bilgelik ve aktarım döneminde';
}

String _harfEnerji(String isim) {
  if (isim.isEmpty) return 'özel bir frekans';
  final h = isim.trim()[0].toUpperCase();
  const map = {
    'A': 'başlangıç ve öncülük enerjisi',
    'B': 'istikrar ve sabır enerjisi',
    'C': 'iletişim ve hareket enerjisi',
    'D': 'temel ve güven enerjisi',
    'E': 'ifade ve özgürlük enerjisi',
    'F': 'şefkat ve uyum enerjisi',
    'G': 'büyüme ve öğrenme enerjisi',
    'H': 'koruma ve sınır enerjisi',
    'I': 'sezgi ve içgörü enerjisi',
    'J': 'adalet ve denge enerjisi',
    'K': 'dönüşüm ve derinlik enerjisi',
    'L': 'yaratıcılık ve ışık enerjisi',
    'M': 'pratiklik ve emek enerjisi',
    'N': 'yenilik ve değişim enerjisi',
    'O': 'tamamlanma ve bütünlük enerjisi',
    'P': 'vizyon ve genişleme enerjisi',
    'R': 'liderlik ve karar enerjisi',
    'S': 'duygu ve akış enerjisi',
    'T': 'disiplin ve yapı enerjisi',
    'U': 'uyum ve bağlantı enerjisi',
    'V': 'zafer ve irade enerjisi',
    'Y': 'özgürlük ve keşif enerjisi',
    'Z': 'kapanış ve yeni döngü enerjisi',
  };
  return map[h] ?? 'kendine özgü bir titreşim';
}

// ─── Metin motoru ───────────────────────────────────────────────────────────

class _Engine {
  _Engine(this.rng, this.v);

  final _SeededRandom rng;
  final Map<String, String> v;

  String f(String t) {
    var r = t;
    v.forEach((k, val) => r = r.replaceAll('{$k}', val));
    return r;
  }

  String pick(List<String> pool, Set<int> used) {
    final avail = pool.where((s) => !used.contains(s.hashCode)).toList();
    final src = avail.isEmpty ? List<String>.from(pool) : avail;
    final raw = src[rng.nextInt(src.length)];
    used.add(raw.hashCode);
    return f(raw);
  }

  String para(List<String> pool, int n) {
    final used = <int>{};
    return List.generate(n, (_) => pick(pool, used)).join(' ');
  }

  List<String> pickMany(List<String> pool, int n) {
    final copy = List<String>.from(pool);
    rng.shuffle(copy);
    return copy.take(n).map(f).toList();
  }
}

// ─── MockAiService ──────────────────────────────────────────────────────────

class MockAiService implements AiService {
  @override
  Future<String> generateFortune({
    required String category,
    required String name,
    required int age,
    required String zodiac,
    required String intention,
    required String tellerId,
    List<String> imageNames = const [],
  }) async {
    return MockAiService.generateFal(
      FalInput(
        category: _categoryFromLabel(category),
        name: name,
        age: age,
        burc: zodiac,
        niyet: intention,
        createdAt: DateTime.now(),
        photoNames: imageNames,
      ),
    );
  }

  @override
  Future<String> generateCoupleCompatibility({
    required String womanName,
    required int womanAge,
    required String womanZodiac,
    required String manName,
    required int manAge,
    required String manZodiac,
    PickedImage? womanImage,
    PickedImage? manImage,
  }) async {
    return MockAiService.generateCiftUyumu(
      CiftInput(
        kadinIsim: womanName,
        kadinYas: womanAge,
        kadinBurc: womanZodiac,
        erkekIsim: manName,
        erkekYas: manAge,
        erkekBurc: manZodiac,
        createdAt: DateTime.now(),
        kadinFotoAdi: womanImage?.name,
        erkekFotoAdi: manImage?.name,
      ),
    );
  }

  static FalCategory _categoryFromLabel(String label) => switch (label) {
        'Tarot Falı' => FalCategory.tarot,
        'Bakla Falı' => FalCategory.bakla,
        'Kahve Falı' => FalCategory.kahve,
        'Su Falı' => FalCategory.su,
        'İskambil Falı' => FalCategory.iskambil,
        _ => FalCategory.tarot,
      };

  static String generateFal(FalInput input) {
    final profil = _NiyetProfil.analiz(input.niyet);
    final b = _burc(input.burc);
    final seed = _seedFrom([
      input.category.name,
      input.name,
      input.age.toString(),
      input.burc,
      input.niyet,
      input.createdAt.toIso8601String(),
      ...input.photoNames,
      profil.tema.name,
    ]);
    final rng = _SeededRandom(seed);
    final voice = _voice(input.category);

    final v = <String, String>{
      'isim': input.name,
      'yas': input.age.toString(),
      'burc': input.burc,
      'niyet': input.niyet,
      'ozellik': b.ozellik,
      'guclu': b.guclu,
      'zorluk': b.zorluk,
      'element': b.element,
      'yasTon': _yasTonu(input.age),
      'harfEnerji': _harfEnerji(input.name),
      'tema': profil.tema.name,
      'fotoNot': input.photoNames.isEmpty
          ? ''
          : 'Yüklediğin ${input.photoNames.length} görsel enerjiyi somutlaştırdı.',
      ...voice,
    };

    final e = _Engine(rng, v);
    final bloklar = <String>[
      e.para(_havuzGenel(input.category, b.element), 4 + rng.nextInt(2)),
      e.para(_havuzNiyet(input.category, profil.tema), 4 + rng.nextInt(2)),
      e.para(_havuzTema(profil.tema, input.category), 4 + rng.nextInt(2)),
      e.para(_havuzAsk(profil.tema), 3 + rng.nextInt(2)),
      e.para(_havuzPara(profil.tema), 3 + rng.nextInt(2)),
      e.para(_havuzSembol(input.category), 4 + rng.nextInt(2)),
      e.para(_havuzUyari(input.category, b.zorluk), 3 + rng.nextInt(2)),
      e.para(_havuzKapanis(profil.tema), 4 + rng.nextInt(2)),
    ];

    final sira = List.generate(bloklar.length, (i) => i);
    rng.shuffle(sira);
    var text = sira.map((i) => bloklar[i]).join('\n\n');

    text = _fit(text, 350, 500, _ekFal(input.category, profil.tema, v));
    return text;
  }

  static String generateCiftUyumu(CiftInput input) {
    final bk = _burc(input.kadinBurc);
    final be = _burc(input.erkekBurc);
    final yasFark = (input.kadinYas - input.erkekYas).abs();
    final uyum = _uyumSkoru(input.kadinBurc, input.erkekBurc);
    final elementNot = _elementAnaliz(bk.element, be.element);

    final seed = _seedFrom([
      input.kadinIsim,
      input.kadinYas.toString(),
      input.kadinBurc,
      input.erkekIsim,
      input.erkekYas.toString(),
      input.erkekBurc,
      input.createdAt.toIso8601String(),
      yasFark.toString(),
      elementNot,
    ]);
    final rng = _SeededRandom(seed);

    final v = <String, String>{
      'kadin': input.kadinIsim,
      'kadinYas': input.kadinYas.toString(),
      'kadinBurc': input.kadinBurc,
      'kadinOz': bk.ozellik,
      'kadinEl': bk.element,
      'kadinHarf': _harfEnerji(input.kadinIsim),
      'erkek': input.erkekIsim,
      'erkekYas': input.erkekYas.toString(),
      'erkekBurc': input.erkekBurc,
      'erkekOz': be.ozellik,
      'erkekEl': be.element,
      'erkekHarf': _harfEnerji(input.erkekIsim),
      'uyum': uyum.toString(),
      'yasFark': yasFark.toString(),
      'elementNot': elementNot,
    };

    final e = _Engine(rng, v);
    final yapilar = [
      [
        e.para(_ciftGiris(), 4 + rng.nextInt(2)),
        e.para(_ciftKadinOzel(), 5 + rng.nextInt(2)),
        e.para(_ciftErkekOzel(), 5 + rng.nextInt(2)),
        e.para(_ciftElement(), 4 + rng.nextInt(2)),
        e.para(_ciftCekim(), 4 + rng.nextInt(2)),
        e.para(_ciftIletisim(yasFark), 4 + rng.nextInt(2)),
        e.para(_ciftGuven(), 4 + rng.nextInt(2)),
        e.para(_ciftGelecek(yasFark), 4 + rng.nextInt(2)),
        e.para(_ciftDenge(), 3 + rng.nextInt(2)),
        e.para(_ciftKapanis(), 4 + rng.nextInt(2)),
      ],
      [
        e.para(_ciftGiris(), 3 + rng.nextInt(2)),
        e.para(_ciftElement(), 4 + rng.nextInt(2)),
        e.para(_ciftKadinOzel(), 5 + rng.nextInt(2)),
        e.para(_ciftCekim(), 4 + rng.nextInt(2)),
        e.para(_ciftErkekOzel(), 5 + rng.nextInt(2)),
        e.para(_ciftDenge(), 3 + rng.nextInt(2)),
        e.para(_ciftGuven(), 4 + rng.nextInt(2)),
        e.para(_ciftIletisim(yasFark), 4 + rng.nextInt(2)),
        e.para(_ciftGelecek(yasFark), 3 + rng.nextInt(2)),
        e.para(_ciftKapanis(), 4 + rng.nextInt(2)),
      ],
      [
        e.para(_ciftGiris(), 3 + rng.nextInt(2)),
        e.para(_ciftCekim(), 4 + rng.nextInt(2)),
        e.para(_ciftKadinOzel(), 4 + rng.nextInt(2)),
        e.para(_ciftElement(), 4 + rng.nextInt(2)),
        e.para(_ciftErkekOzel(), 4 + rng.nextInt(2)),
        e.para(_ciftGelecek(yasFark), 4 + rng.nextInt(2)),
        e.para(_ciftIletisim(yasFark), 4 + rng.nextInt(2)),
        e.para(_ciftDenge(), 4 + rng.nextInt(2)),
        e.para(_ciftGuven(), 3 + rng.nextInt(2)),
        e.para(_ciftKapanis(), 4 + rng.nextInt(2)),
      ],
    ];

    final bloklar = yapilar[rng.nextInt(yapilar.length)];
    final sira = List.generate(bloklar.length, (i) => i);
    rng.shuffle(sira);
    var text = sira.map((i) => bloklar[i]).join('\n\n');

    text = _fit(text, 450, 650, _ekCift(v));
    return text;
  }

  static int _uyumSkoru(String b1, String b2) {
    final e1 = _burcMap[b1]?.element;
    final e2 = _burcMap[b2]?.element;
    var base = 70;
    if (e1 == e2) base = 82;
    if ((e1 == 'ateş' && e2 == 'hava') || (e1 == 'hava' && e2 == 'ateş')) base = 80;
    if ((e1 == 'toprak' && e2 == 'su') || (e1 == 'su' && e2 == 'toprak')) base = 79;
    return (base + (b1.hashCode ^ b2.hashCode).abs() % 14).clamp(64, 94);
  }

  static String _elementAnaliz(String e1, String e2) {
    if (e1 == e2) return '$e1-$e2 aynı element: derin anlayış, benzer ritim';
    if ((e1 == 'ateş' && e2 == 'su') || (e1 == 'su' && e2 == 'ateş')) {
      return 'ateş-su karşıtlığı: tutku ile derinlik bir arada';
    }
    if ((e1 == 'hava' && e2 == 'toprak') || (e1 == 'toprak' && e2 == 'hava')) {
      return 'hava-toprak: fikir ile istikrar dengelenmeli';
    }
    return '$e1 ve $e2 elementleri birbirini tamamlayıcı öğretmenler gibi';
  }

  static String _fit(String text, int min, int max, List<String> ek) {
    var r = _dedupe(text);
    var ekIdx = 0;
    var guard = 0;
    while (_wordCount(r) < min && guard < 80 && ek.isNotEmpty) {
      r = '$r\n\n${ek[ekIdx % ek.length]}';
      ekIdx++;
      guard++;
    }
    while (_wordCount(r) > max) {
      final p = r.split('\n\n');
      if (p.length > 1) {
        final last = _sents(p.removeLast());
        if (last.length > 1) {
          last.removeLast();
          p.add(last.join(' '));
          r = p.join('\n\n');
        } else {
          r = p.join('\n\n');
        }
      } else {
        final s = _sents(r);
        if (s.length <= 1) break;
        s.removeLast();
        r = s.join(' ');
      }
    }
    r = _dedupe(r.trim());
    guard = 0;
    while (_wordCount(r) < min && guard < 40 && ek.isNotEmpty) {
      final e = ek[(ekIdx + guard) % ek.length];
      final seen = _sents(r).map((s) => s.toLowerCase().hashCode).toSet();
      if (!seen.contains(e.toLowerCase().hashCode)) {
        r = '$r\n\n$e';
      }
      guard++;
    }
    return r.trim();
  }

  static String _dedupe(String text) {
    final seen = <int>{};
    final out = <String>[];
    for (final p in text.split('\n\n')) {
      final u = <String>[];
      for (final s in _sents(p)) {
        final k = s.toLowerCase().hashCode;
        if (seen.add(k)) u.add(s);
      }
      if (u.isNotEmpty) out.add(u.join(' '));
    }
    return out.join('\n\n');
  }

  static Map<String, String> _voice(FalCategory c) => switch (c) {
        FalCategory.tarot => {
            'arac': 'tarot kartları',
            'rituel': 'Kartlar açılırken',
            'falci': 'Tarot okuyucusu olarak',
          },
        FalCategory.bakla => {
            'arac': 'bakla taneleri',
            'rituel': 'Baklalar saçılırken',
            'falci': 'Bakla falcısı olarak',
          },
        FalCategory.kahve => {
            'arac': 'telve desenleri',
            'rituel': 'Fincan çevrilirken',
            'falci': 'Kahve falcısı olarak',
          },
        FalCategory.su => {
            'arac': 'su yüzeyi',
            'rituel': 'Su mührü okunurken',
            'falci': 'Su falcısı olarak',
          },
        FalCategory.iskambil => {
            'arac': 'iskambil kartları',
            'rituel': 'Kartlar dizilirken',
            'falci': 'İskambil falcısı olarak',
          },
      };

  // ─── Fal havuzları (kategori + tema bazlı) ──────────────────────────────

  static List<String> _havuzGenel(FalCategory c, String el) => [
        '{isim}, {yas} yaşında {burc} burcunun {ozellik} doğasıyla {yasTon} bir enerji taşıyorsun.',
        '{rituel} {arac} önce adını, sonra {harfEnerji} getirdiğini gösterdi.',
        '{burc} burcunun {element} elementi bu dönemde {guclu} yanını öne çıkarıyor.',
        '{falci} hissediyorum: {isim} için tablo durgun değil, bilinçli bir hareket dönemi.',
        switch (c) {
          FalCategory.tarot => 'Desteden çıkan enerji arketipsel bir dönüşümü işaret ediyor.',
          FalCategory.bakla => 'Yere düşen baklalar toprağın kadim dilini konuşuyor.',
          FalCategory.kahve => 'Fincanın kenarındaki izler yolculuk ve haber taşıyor.',
          FalCategory.su => 'Suyun yüzeyindeki titreşim iç dünyanı aynalıyor.',
          FalCategory.iskambil => 'Masadaki kartlar net ve doğrudan konuşuyor.',
        },
        '{fotoNot}',
      ].where((s) => s.isNotEmpty).toList();

  static List<String> _havuzNiyet(FalCategory c, _NiyetTema tema) => [
        'Kalbine yazdığın "{niyet}" cümlesi bu okumanın omurgası; her sembol bunun etrafında dönüyor.',
        '{isim}, "{niyet}" dediğin an {arac} frekansı değişti — bu rezonans tesadüf değil.',
        switch (tema) {
          _NiyetTema.para =>
            '"{niyet}" sorusu maddi alanın kapısını aralıyor; disiplin ve fırsat bilinci burada kesişiyor.',
          _NiyetTema.ask =>
            '"{niyet}" kalp merkezinden yükseliyor; duygusal netlik bu dönemin anahtarı.',
          _NiyetTema.eskiSevgili =>
            '"{niyet}" geçmişle yüzleşme ve kapanış ihtiyacını taşıyor; yeni döngü için alan açılmalı.',
          _NiyetTema.aile =>
            '"{niyet}" köklerin ve bağların alanında; aile enerjisi şu an belirgin.',
          _NiyetTema.gelecek =>
            '"{niyet}" vizyon ve yön arayışını gösteriyor; önün açık ama adım senin.',
          _NiyetTema.saglik =>
            '"{niyet}" beden ve ruh dengesine işaret ediyor; bu bir tıbbi teşhis değil, enerji dengesi çağrısı.',
          _ => '"{niyet}" içsel pusulan; {burc} burcunun ritmi bunu destekliyor.',
        },
        switch (c) {
          FalCategory.kahve => 'Telveler "{niyet}" etrafında sıkı bir halka oluşturdu.',
          FalCategory.tarot => 'Öne çıkan kart doğrudan bu niyetin dış yansımasını taşıyor.',
          _ => '{arac} niyetinin somut karşılığını hazırlıyor.',
        },
      ];

  static List<String> _havuzTema(_NiyetTema tema, FalCategory c) => switch (tema) {
        _NiyetTema.para => [
            '{isim}, maddi konularda ani sıçrama değil sürdürülebilir büyüme görünüyor.',
            'Risk almadan önce plan yap; {burc} burcunun {guclu} yanı stratejik hamleleri destekler.',
            'Bolluk bilinci "{niyet}" niyetinle uyumlu; küçük tutarlı adımlar büyük fark yaratır.',
            'Gelir ya da fırsat kapısı {yas} yaşının deneyimiyle birleşince daha görünür olacak.',
          ],
        _NiyetTema.ask => [
            'Kalp alanında hareket var; {isim} duygularını daha net ifade edecek.',
            'Yüzeysel çekimden çok anlam arayışı öne çıkıyor; bu senin için olgun bir seçim.',
            'İlişki enerjisi "{niyet}" niyetinle rezonansa girdi; sabırlı ol ama kapalı kalma.',
          ],
        _NiyetTema.eskiSevgili => [
            'Geçmişten bir iz kapanmaya hazır; bu kapanış yeni bir sayfa için alan açar.',
            '{isim}, geri dönüş mü yeni yön mü sorusunda iç sesin öncelikli.',
            'Eski bağların enerjisi hafifliyor; "{niyet}" bunu fark etmeni istiyor.',
          ],
        _ => [
            '{isim}, "{niyet}" yolculuğunda içsel hazırlık dış dünyada sinyallere dönüşecek.',
            '{burc} burcunun {element} doğası bu niyeti besliyor.',
          ],
      };

  static List<String> _havuzAsk(_NiyetTema tema) => [
        if (tema != _NiyetTema.para)
          'Aşk tarafında {burc} burcunun kalp dili daha seçici ve bilinçli.',
        'Duygusal açıklık ilişkilerde güven inşa eder; bunu küçümseme.',
        'Kalbin korunmak istiyor ama aynı zamanda açılmaya hazır; dengeyi sen kuracaksın.',
        'Yeni tanışma ya da mevcut bağda derinleşme — ikisi de mümkün.',
      ];

  static List<String> _havuzPara(_NiyetTema tema) => [
        if (tema != _NiyetTema.ask)
          'İş ve para ekseninde görünürlük artıyor; emeğinin karşılığı yaklaşıyor.',
        'Harcama alışkanlıklarını gözden geçirmek bereketi artırır.',
        'Kariyerde küçük ama kesin bir adım büyük kapıların habercisi olabilir.',
      ];

  static List<String> _havuzSembol(FalCategory c) => switch (c) {
        FalCategory.tarot => [
            'Yol kartı {isim} için yeni bir başlangıç kapısını işaret ediyor.',
            'Güç arketipi iradeni destekliyor; kader seni değil sen yönünü seçiyorsun.',
            'Ters bir kart {zorluk} eğilimine dikkat çekiyor; farkındalık kalkanın.',
          ],
        FalCategory.bakla => [
            'Spiral dağılım büyüme sembolü; tohum atıldı, sabır isteniyor.',
            'Sağa yığılan taneler eylem, sola yığılanlar dinlenme öneriyor.',
            'Merkezdeki boşluk nefes alanı; "{niyet}" burada tazelenmeli.',
          ],
        FalCategory.kahve => [
            'Kuş figürü haber ve yolculuk; yakın günlerde gelişme.',
            'Tabak deseni bağlılık ve süreklilik vurguluyor.',
            'Dibdeki halka tamamlanacak döngünün işareti.',
          ],
        FalCategory.su => [
            'Halkalar merkezden dışa yayılan etki alanını simgeliyor.',
            'Yansımada iki yol görünüyor; sezgin doğru olanı gösterecek.',
          ],
        FalCategory.iskambil => [
            'Kupa AS duygusal temiz sayfa açıyor.',
            'Karo dizisi maddi konularda somut adımlar öneriyor.',
            'Maça Kralı stratejik düşün ve sınır koy.',
          ],
      };

  static List<String> _havuzUyari(FalCategory c, String zorluk) => [
        '{burc} burcunun {zorluk} eğilimi tetiklenebilir; farkında ol.',
        'Aceleci kararlar "{niyet}" hedefini yavaşlatır; 24 saat kuralı işe yarar.',
        'Enerjini dağıtan küçük meselelere değil, niyetine yatır.',
        'Başkalarının endişesi senin pusulan değil; iç sesine dön.',
      ];

  static List<String> _havuzKapanis(_NiyetTema tema) => [
        '{isim}, önümüzdeki haftalarda "{niyet}" konusunda somut bir gelişme mümkün.',
        'Umut gerçekçi olduğunda en güçlü halini bulur; sen tam oradasın.',
        switch (tema) {
          _NiyetTema.para => 'Maddi konularda sabırlı disiplin seni hedefine yaklaştıracak.',
          _NiyetTema.ask => 'Kalbini açarken sınırlarını da koru; ikisi bir arada.',
          _ => 'Bu yorum sana özel; enerjini kendi "{niyet}" pusulana yönlendir.',
        },
        'Evren seni cezalandırmıyor; her ders seni güçlendiriyor.',
      ];

  static List<String> _ekFal(FalCategory c, _NiyetTema t, Map<String, String> v) {
    final ek = <String>[
      '{isim}, {burc} ve "{niyet}" birleşimi bu dönemde içsel netlik getiriyor.',
      '{rituel} gördüğüm işaretler tesadüf değil; {isim} bunları hissettiğinde yol aydınlanır.',
      '{harfEnerji} {isim} için bu falda belirleyici bir ton taşıyor.',
      '{yasTon} bir {yas} yaşındaki {isim} için doğru zamanlama kritik.',
      '{burc} burcunun {guclu} yanı en büyük müttefikin; bunu kullan.',
      'Önümüzdeki günlerde küçük bir işaret büyük bir kapının habercisi olabilir.',
      '"{niyet}" konusunda iç sesinle dış dünyanın işaretleri aynı yönü gösteriyor.',
      switch (t) {
        _NiyetTema.para =>
          '{isim}, maddi hedeflerinde disiplinli ritim ve bolluk bilinci en güçlü kombinasyon.',
        _NiyetTema.ask =>
          'Kalp konularında {isim} için açıklık ve seçicilik bir arada olmalı.',
        _NiyetTema.eskiSevgili =>
          'Geçmiş kapanmadan yeni kapı tam açılmaz; bu süreç doğal.',
        _NiyetTema.saglik =>
          'Beden ve ruh dengesi için dinlenme stratejik bir adımdır; tıbbi iddia değil enerji dengesi.',
        _ => '{isim}, bu dönemde sabırlı olduğunda sonuçlar sağlam temellere oturur.',
      },
      switch (c) {
        FalCategory.kahve => 'Telveler acele etmez; {isim} hazır olduğunda netleşir.',
        FalCategory.tarot => 'Kartların dili dürüsttür; duymak istemediğini de gösterir.',
        FalCategory.bakla => 'Baklalar yalan söylemez; toprağın bilgeliği kadimdir.',
        _ => '{arac} senin frekansında konuşmaya devam ediyor.',
      },
    ];
    return ek.map((s) {
      var r = s;
      v.forEach((k, val) => r = r.replaceAll('{$k}', val));
      return r;
    }).toList();
  }

  // ─── Çift uyumu havuzları ───────────────────────────────────────────────

  static List<String> _ciftGiris() => [
        '{kadin} ve {erkek} bir araya geldiğinde ortamda belirgin bir çekim oluşuyor.',
        'Astrolojik uyum skorunuz %{uyum} — bu sağlam bir başlangıç, tavan değil.',
        '{elementNot} Bu kombinasyon ilişkinize özgü bir ritim veriyor.',
        'İkinizin hikâyesi aceleci değil, derinleşmeye yönelik bir tempo çiziyor.',
        '{kadinBurc} ve {erkekBurc} birleşimi ilişkide hem tutku hem istikrar potansiyeli taşıyor.',
      ];

  static List<String> _ciftKadinOzel() => [
        '{kadin}, {kadinYas} yaşında {kadinBurc} burcunun {kadinOz} doğasıyla duygusal derinlik katıyor.',
        'Adının taşıdığı {kadinHarf} {kadin} için ilişkide belirleyici bir ton.',
        '{kadinBurc} kadını güven bulduğunda ilişkinin en şefkatli yüzünü gösterir.',
        '{kadin} partnerinin ince değişimlerini erkenden algılar; bu sezgi gücü.',
        '{kadinYas} yaşındaki {kadin} için ilişkide anlam ve güven birincil öncelik.',
        '{kadinBurc} kadının duygusal dili söyleneni değil yaşananı ölçer.',
        'İç dünyasında güçlü bir sezgi var; {kadin} tutarsızlıkları erken fark eder.',
        '{kadin} kendini güvende hissettiğinde ilişkinin en yaratıcı tarafı açığa çıkar.',
      ];

  static List<String> _ciftErkekOzel() => [
        '{erkek}, {erkekYas} yaşında {erkekBurc} burcunun {erkekOz} enerjisiyle yapı ve kararlılık getiriyor.',
        '{erkekHarf} {erkek} için ilişkide eylem ve tutarlılık dili anlamına geliyor.',
        '{erkekBurc} erkeği sevgisini sözden çok davranışla gösterir.',
        'Güven inşa edildiğinde {erkek} sadık ve koruyucu bir partner olur.',
        '{erkekYas} yaşındaki {erkek} uzun vadeli plan yapma eğiliminde.',
        '{erkek} duygularını hemen ifade etmeyebilir; bu ilgisizlik değil sindirme sürecidir.',
        '{erkekBurc} erkeğinin aşk dili sorumluluk ve zaman ayırmaktır.',
        'İlişkide netlik isteyen {erkek}, tutarlılıkla güven inşa eder.',
      ];

  static List<String> _ciftElement() => [
        '{kadinBurc} ({kadinEl}) ile {erkekBurc} ({erkekEl}) elementleri: {elementNot}',
        'Ateş suyu kaynatır ya da buharlaştırır; sizin dinamiğinizde denge şart.',
        'Toprak havanın fikirlerini somutlaştırır; pratik adımlar ilişkiyi güçlendirir.',
        'Element farkı çatışma değil, öğrenme alanıdır.',
        'Aynı element ilişkide derin anlayış getirir; farklı element tamamlayıcılık.',
        '{elementNot} Bu astrolojik dinamik günlük iletişimle şekillenir.',
        'Element uyumu skorunuzu belirlemez; sizin emeğiniz belirler.',
      ];

  static List<String> _ciftCekim() => [
        'Fiziksel ve duygusal çekim ilişkinizin parlak alanlarından biri.',
        '{kadin} ve {erkek} arasındaki manyetizma ilk günden beri canlı tutulabilir.',
        'Tutku günlük şefkatle dengelendiğinde ilişki hem canlı hem güvenli kalır.',
        '{kadinBurc} kadının enerjisi ile {erkekBurc} erkeğinin karizması doğal uyum oluşturuyor.',
        'Çekim sadece fiziksel değil; zihinsel uyumunuz da güçlü bir bağlayıcı.',
        'Uzun ilişkilerde tutkuyu canlı tutmak için yenilik ve ortak deneyimler şart.',
      ];

  static List<String> _ciftIletisim(int yasFark) => [
        if (yasFark >= 5)
          '{yasFark} yaş farkı olgunluk ve tempo farkı getiriyor; karşılıklı anlayış şart.',
        '{kadin}ın dolaylı ifadesi ile {erkek}in doğrudan dili zaman zaman çatışır.',
        '"Ne demek istedin?" sorusu bu ilişkide altın değerinde.',
        'Yazılı mesajlarda ton kaybı yaşanabilir; önemli konuları yüz yüze konuşun.',
        'Dinleme becerisi ilişkinizin en güçlü yatırımı; konuşmadan önce anlamayı seçin.',
        'Tartışma anlarında {erkek} mesafe koyarken {kadin} yakınlık arayabilir.',
        'Haftalık otuz dakikalık kalp sohbeti iletişim uyumunu belirgin artırır.',
      ];

  static List<String> _ciftGuven() => [
        'Güven {erkek} için tutarlılık, {kadin} için şeffaflık demek.',
        'Küçük tutarlı adımlar büyük vaatlerden daha etkilidir.',
        'Geçmiş kırgınlıklar kapanmadan yeni tartışma açmayın.',
        '{kadin} ve {erkek} birbirlerinin sınırlarına saygı gösterdiğinde bağlılık derinleşir.',
        'Bağlılık sözle değil davranışla ölçülür.',
        'Güven krizi yaşanırsa profesyonel destek zayıflık değil yatırımdır.',
      ];

  static List<String> _ciftGelecek(int yasFark) => [
        'Uzun vadede ortak değerler etrafında kalıcı yapı kurma potansiyeli yüksek.',
        if (yasFark <= 3)
          'Yaş yakınlığı ortak ritim ve benzer hayat evreleri getiriyor.'
        else
          'Yaş farkı farklı perspektifler sunuyor; öğrenme alanı geniş.',
        'İlişkinizin geleceği günlük küçük seçimlere bağlı.',
        'Ortak hedefler — ev, seyahat, proje — ilişkinizi somutlaştırır.',
        'Beş yıllık perspektifte büyüme eğrisi çiziyorsunuz; ilk yıllar öğrenme, sonrakiler derinleşme.',
        'Evlilik veya birliktelik planları astrolojik açıdan destekleniyor; zamanlama bilinçli olmalı.',
        '{kadin} ve {erkek} birlikte yeni alışkanlıklar inşa ettikçe bağ güçlenir.',
        'Gelecek planlarında finansal şeffaflık ve duygusal açıklık aynı önemde.',
      ];

  static List<String> _ciftDenge() => [
        '{kadin} ve {erkek} arasında verme-alma dengesi zaman zaman test edilir.',
        'Biri çok verirken diğeri alıyorsa ilişki yorulur; denge bilinçli kurulmalı.',
        '{kadinBurc} kadının ihtiyaç duyduğu duygusal alan ile {erkekBurc} erkeğinin yapı ihtiyacı uzlaşmayı gerektirir.',
        'Rutin içinde küçük yenilikler ilişkinin canlılığını korur.',
        'Birbirinizin hobilerine saygı göstermek kişisel alanı güçlendirir.',
        'Çift olarak sosyal çevreyle sınır koymak iç dünyanızı korur.',
        '{yasFark} yaş farkı bazen tempo farkı yaratır; haftalık planlama bu farkı yumuşatır.',
        'Özür dilemek ve telafi etmek bu ilişkide güven inşasının sessiz kahramanlarıdır.',
      ];

  static List<String> _ciftKapanis() => [
        '{kadin} ve {erkek}, birbirinizin en iyi halini ortaya çıkarabilecek bir eşleşmesiniz.',
        'En büyük gücünüz öğrenme isteğiniz; en büyük risk konuşulmayan beklentiler.',
        'Bu bağı bilinçli emekle büyütün; astroloji potansiyel gösterir, siz belirlersiniz.',
        'Haftalık kaliteli zaman ve açık iletişim bu ilişkinin temel taşları olmalı.',
        'Son sözüm: {kadin} ve {erkek}, birbirinizin yanında huzur bulduğunuzda ilişki derinleşir.',
      ];

  static List<String> _ekCift(Map<String, String> v) => [
        '{kadin} ve {erkek} arasındaki %{uyum} uyum günlük emekle artabilir.',
        '{elementNot} Element uyumunu iletişimle besleyin.',
        '{kadinHarf} ve {erkekHarf} bir araya gelince ilişkiye özgü bir ritim doğuyor.',
        '{yasFark} yaş farkı ilişkinize özel bir dinamizm katıyor; bunu yönetin.',
        'Haftalık kaliteli zaman ve açık iletişim bu bağın temel taşları.',
        '{kadin} duygusal derinlik, {erkek} yapı ve kararlılık getiriyor; ikisi de değerli.',
        'Tutkuyu rutinle öldürmeyin; küçük sürprizler bağı canlı tutar.',
        'Uzun vadede ortak hedefler ilişkinizi somutlaştıracak.',
        '{kadinBurc} kadının sezgisi ile {erkekBurc} erkeğinin kararlılığı birbirini tamamlar.',
        'İlişkinizde konuşulmayan beklentiler en büyük risk; açık diyalog şifadır.',
        '{kadin} ve {erkek} birlikte büyüdükçe uyum skoru da derinleşir.',
        'Çekim ve güven aynı anda inşa edilebilir; biri diğerini dışlamaz.',
        '{erkek} için duygusal açıklık, {kadin} için alan tanıma değerli yatırımlardır.',
        'Astroloji potansiyeli gösterir; {kadin} ve {erkek} günlük seçimlerle belirler.',
        'Kriz anlarında kişisel saldırı yerine ihtiyaç dilini tercih edin.',
        '{kadin} ve {erkek} birlikte güldükçe iletişim köprüleri güçlenir.',
        'İlişkinizde sabır ve merak aynı anda var olabilir; ikisi de şifadır.',
        '{kadinBurc}-{erkekBurc} kombinasyonu öğrenmeye açık çiftler için verimli bir zemin sunuyor.',
        'Günlük minnettarlık pratiği ilişkinizin görünmez ama güçlü temelidir.',
        'Birbirinizin başarılarını kutlamak kıskançlığı erken söndürür.',
        'Ortak bir gelecek vizyonu yazmak soyut umutları somut adımlara dönüştürür.',
        '{erkek} ve {kadin} arasındaki enerji dalgalanması doğal; önemli olan birlikte dengeyi bulmak.',
      ].map((s) {
        var r = s;
        v.forEach((k, val) => r = r.replaceAll('{$k}', val));
        return r;
      }).toList();
}
