import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';

// Classe FakeAssetBundle (sem alterações)
class FakeAssetBundle extends CachingAssetBundle {
  final Map<String, String> stringAssets;
  FakeAssetBundle(this.stringAssets);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (stringAssets.containsKey(key)) {
      return stringAssets[key]!;
    }
    throw FlutterError('FakeAssetBundle: Unable to load asset: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    if (stringAssets.containsKey(key)) {
      final bytes = utf8.encode(stringAssets[key]!);
      return ByteData.view(bytes.buffer);
    }
    throw FlutterError('FakeAssetBundle: Unable to load asset: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BiblePageHelper.clearCache();
  });

  group('BiblePageHelper', () {
    test('formatReferenceForTts deve converter corretamente a referência', () {
      const reference = "João 3:16";
      final formatted = BiblePageHelper.formatReferenceForTts(reference);
      expect(formatted, "João 3 versiculo 16");
    });

    test('loadVersesFromReference deve buscar o versículo correto', () async {
      // DADO
      const mockAbbrevMap = '''
      {
        "jo": { "nome": "João", "capitulos": 21 }
      }
      ''';

      const verseText =
          "Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito, para que todo aquele que nele crê não pereça, mas tenha a vida eterna.";

      // ✅ CORREÇÃO AQUI: Cria uma lista com 16 elementos para simular João 3.
      // O 16º elemento (índice 15) é o nosso versículo alvo.
      final List<String> mockChapterList =
          List.generate(15, (i) => "Versículo de teste ${i + 1}");
      mockChapterList.add(verseText);

      final String mockChapterJson = jsonEncode(mockChapterList);

      final fakeBundle = FakeAssetBundle({
        'assets/Biblia/completa_traducoes/abbrev_map.json': mockAbbrevMap,
        'assets/Biblia/completa_traducoes/nvi/jo/3.json': mockChapterJson,
      });

      // QUANDO
      final verses = await BiblePageHelper.loadVersesFromReference(
        "João 3:16",
        "nvi",
        bundle: fakeBundle,
      );

      // ENTÃO
      expect(verses.length, 1);
      expect(verses.first, contains("Porque Deus amou o mundo"));
    });
  });
}
