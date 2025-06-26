// lib/pages/biblie_page/bible_page_helper.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

class BiblePageHelper {
  static Map<String, dynamic>? _hebrewStrongsLexicon;
  static Map<String, dynamic>? _greekStrongsLexicon;

  // >>> INÍCIO DA CORREÇÃO <<<
  static Future<Map<String, String>> loadBookVariationsMapForGoTo() async {
    try {
      final String jsonString = await rootBundle
          .loadString('assets/Biblia/book_variations_map_search.json');
      final Map<String, dynamic> decodedJson = json.decode(jsonString);
      final Map<String, String> normalizedMap = {};

      String normalizeText(String text) {
        return unorm
            .nfd(text.toLowerCase().trim())
            .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
      }

      decodedJson.forEach((key, value) {
        normalizedMap[normalizeText(key)] = value.toString();
      });
      return normalizedMap;
    } catch (e) {
      print("Erro ao carregar book_variations_map_search.json: $e");
      return {};
    }
  }
  // >>> FIM DA CORREÇÃO <<<

  static Future<Map<String, dynamic>> loadBooksMap() async {
    final String data = await rootBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    return json.decode(data);
  }

  static final Map<String, String> _bookNameToAbbrevMap = {
    'gênesis': 'gn', 'genesis': 'gn',
    'êxodo': 'ex', 'exodo': 'ex',
    'levítico': 'lv', 'levitico': 'lv',
    'números': 'nm', 'numeros': 'nm',
    'deuteronômio': 'dt', 'deuteronomio': 'dt',
    'josué': 'js', 'josue': 'js',
    'juízes': 'jz', 'juizes': 'jz',
    'rute': 'rt',
    '1 samuel': '1sm', '1º samuel': '1sm',
    '2 samuel': '2sm', '2º samuel': '2sm',
    '1 reis': '1rs', '1º reis': '1rs',
    '2 reis': '2rs', '2º reis': '2rs',
    '1 crônicas': '1cr', '1 cronicas': '1cr', '1º crônicas': '1cr',
    '2 crônicas': '2cr', '2 cronicas': '2cr', '2º crônicas': '2cr',
    'esdras': 'ed',
    'neemias': 'ne',
    'ester': 'et',
    'jó': 'job', 'jo': 'jo', // Cuidado com "jo" para João
    'salmos': 'sl',
    'provérbios': 'pv', 'proverbios': 'pv',
    'eclesiastes': 'ec',
    'cantares': 'ct', 'cânticos': 'ct',
    'isaías': 'is', 'isaias': 'is',
    'jeremias': 'jr',
    'lamentações': 'lm', 'lamentacoes': 'lm',
    'ezequiel': 'ez',
    'daniel': 'dn',
    'oseias': 'os', 'oséias': 'os',
    'joel': 'jl',
    'amós': 'am', 'amos': 'am',
    'obadias': 'ob',
    'jonas': 'jn',
    'miqueias': 'mq', 'miquéias': 'mq',
    'naum': 'na',
    'habacuque': 'hc',
    'sofonias': 'sf',
    'ageu': 'ag',
    'zacarias': 'zc',
    'malaquias': 'ml',
    'mateus': 'mt',
    'marcos': 'mc',
    'lucas': 'lc',
    'joão': 'jo', // Distinto de Jó
    'atos': 'at',
    'romanos': 'rm',
    '1 coríntios': '1co', '1 corintios': '1co', '1º coríntios': '1co',
    '2 coríntios': '2co', '2 corintios': '2co', '2º coríntios': '2co',
    'gálatas': 'gl', 'galatas': 'gl',
    'efésios': 'ef', 'efesios': 'ef',
    'filipenses': 'fp',
    'colossenses': 'cl',
    '1 tessalonicenses': '1ts', '1º tessalonicenses': '1ts',
    '2 tessalonicenses': '2ts', '2º tessalonicenses': '2ts',
    '1 timóteo': '1tm', '1 timoteo': '1tm', '1º timóteo': '1tm',
    '2 timóteo': '2tm', '2 timoteo': '2tm', '2º timóteo': '2tm',
    'tito': 'tt',
    'filemom': 'fm',
    'hebreus': 'hb',
    'tiago': 'tg',
    '1 pedro': '1pe', '1º pedro': '1pe',
    '2 pedro': '2pe', '2º pedro': '2pe',
    '1 joão': '1jo', '1º joão': '1jo',
    '2 joão': '2jo', '2º joão': '2jo',
    '3 joão': '3jo', '3º joão': '3jo',
    'judas': 'jd',
    'apocalipse': 'ap'
  };

  static String formatReferenceForTts(String reference) {
    return reference.replaceAllMapped(RegExp(r'(\d):(\d)'),
        (match) => '${match.group(1)} versiculo ${match.group(2)}');
  }

  static Future<String> getFullReferenceName(
      String abbreviatedReference) async {
    try {
      final booksMap = await loadBooksMap();
      final regex = RegExp(r'^(\S+)\s*(.*)$');
      final match = regex.firstMatch(abbreviatedReference.trim());
      if (match != null) {
        final abbrev = match.group(1)?.toLowerCase() ?? '';
        final restOfReference = match.group(2) ?? '';
        if (booksMap.containsKey(abbrev)) {
          final bookName = booksMap[abbrev]?['nome'] ?? abbrev.toUpperCase();
          return '$bookName $restOfReference';
        }
      }
      return abbreviatedReference;
    } catch (e) {
      return abbreviatedReference;
    }
  }

  static Future<Map<String, dynamic>?>
      loadAndCacheHebrewStrongsLexicon() async {
    if (_hebrewStrongsLexicon == null) {
      try {
        final String data = await rootBundle.loadString(
            'assets/Biblia/completa_traducoes/hebrew_strong_lexicon_traduzido.json');
        _hebrewStrongsLexicon = json.decode(data);
      } catch (e) {
        return null;
      }
    }
    return _hebrewStrongsLexicon;
  }

  static Map<String, dynamic>? get cachedHebrewStrongsLexicon =>
      _hebrewStrongsLexicon;

  static Future<Map<String, dynamic>?> loadAndCacheGreekStrongsLexicon() async {
    if (_greekStrongsLexicon == null) {
      try {
        final String data = await rootBundle.loadString(
            'assets/Biblia/completa_traducoes/greek_strong_lexicon_traduzido.json');
        _greekStrongsLexicon = json.decode(data);
      } catch (e) {
        return null;
      }
    }
    return _greekStrongsLexicon;
  }

  static String? _getAbbrevFromPortugueseName(String bookName) {
    String normalizedName = unorm
        .nfd(bookName.toLowerCase().trim())
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
    return _bookNameToAbbrevMap[normalizedName];
  }

  static Future<List<String>> loadVersesFromReference(
      String reference, String translation) async {
    if (reference.isEmpty) return ["Referência inválida."];
    final RegExp regex = RegExp(
        r"^\s*([1-3]?\s*[A-Za-zÀ-ÖØ-öø-ÿ]+)\s*(\d+)\s*[:\.]\s*(\d+)(?:\s*-\s*(\d+))?\s*$",
        caseSensitive: false);
    final Match? match = regex.firstMatch(reference.trim());
    if (match == null) return ["Formato de referência inválido: $reference"];
    String bookNamePart = match.group(1)!.trim();
    String chapterStr = match.group(2)!;
    String startVerseStr = match.group(3)!;
    String? endVerseStr = match.group(4);
    String? bookAbbrev = _getAbbrevFromPortugueseName(bookNamePart);
    if (bookAbbrev == null) {
      final Map<String, dynamic> booksMap = await loadBooksMap();
      for (var entry in booksMap.entries) {
        final data = entry.value;
        if (data is Map && data['nome'] != null) {
          String nameFromMap = unorm
              .nfd((data['nome'] as String).toLowerCase().trim())
              .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
          if (nameFromMap ==
              unorm
                  .nfd(bookNamePart.toLowerCase().trim())
                  .replaceAll(RegExp(r'[\u0300-\u036f]'), '')) {
            bookAbbrev = entry.key;
            break;
          }
        }
        if (entry.key.toLowerCase() == bookNamePart.toLowerCase()) {
          bookAbbrev = entry.key;
          break;
        }
      }
      if (bookAbbrev == null) return ["Livro não reconhecido: $bookNamePart"];
    }
    final int? chapter = int.tryParse(chapterStr);
    final int? startVerse = int.tryParse(startVerseStr);
    final int? endVerse =
        endVerseStr != null ? int.tryParse(endVerseStr) : startVerse;
    if (chapter == null ||
        startVerse == null ||
        endVerse == null ||
        endVerse < startVerse)
      return ["Capítulo/versículo(s) inválido(s) na referência: $reference"];
    try {
      final String verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
      final String verseDataString = await rootBundle.loadString(verseDataPath);
      final List<dynamic> allVersesInChapter = json.decode(verseDataString);
      List<String> resultVerses = [];
      for (int i = startVerse; i <= endVerse; i++) {
        if (i > 0 && i <= allVersesInChapter.length) {
          resultVerses.add("${i} ${allVersesInChapter[i - 1].toString()}");
        } else {
          resultVerses.add("$i [Texto do verso não encontrado]");
        }
      }
      return resultVerses.isNotEmpty
          ? resultVerses
          : ["Versículos não encontrados para: $reference"];
    } catch (e) {
      return ["Erro ao carregar versículos para: $reference"];
    }
  }

  static Map<String, dynamic>? get cachedGreekStrongsLexicon =>
      _greekStrongsLexicon;

  static Future<Map<String, dynamic>> loadChapterDataComparison(
      String bookAbbrev,
      int chapter,
      String translation1,
      String? translation2) async {
    List<Map<String, dynamic>> sections = [];
    Map<String, dynamic> verseData = {};
    try {
      final String sectionStructurePath =
          'assets/Biblia/blocos/$bookAbbrev/$chapter.json';
      final String sectionData =
          await rootBundle.loadString(sectionStructurePath);
      final decodedSectionData = json.decode(sectionData);
      if (decodedSectionData is List) {
        sections = List<Map<String, dynamic>>.from(decodedSectionData
            .map((item) {
              if (item is Map)
                return {
                  'title': item['title']?.toString() ?? 'Seção',
                  'verses':
                      (item['verses'] as List<dynamic>?)?.cast<int>() ?? []
                };
              return null;
            })
            .where((item) => item != null)
            .cast<Map<String, dynamic>>());
      }
    } catch (e) {
      sections = [];
    }

    try {
      verseData[translation1] =
          await _loadVerseDataForTranslation(bookAbbrev, chapter, translation1);
    } catch (e) {
      return {'sectionStructure': [], 'verseData': {}};
    }

    if (translation2 != null) {
      try {
        verseData[translation2] = await _loadVerseDataForTranslation(
            bookAbbrev, chapter, translation2);
      } catch (e) {
        verseData[translation2] = [];
      }
    }
    return {'sectionStructure': sections, 'verseData': verseData};
  }

  static Future<dynamic> _loadVerseDataForTranslation(
      String bookAbbrev, int chapter, String translation) async {
    String verseDataPath;
    if (translation == 'hebrew_original') {
      verseDataPath =
          'assets/Biblia/completa_traducoes/hebrew_original/$bookAbbrev/$chapter.json';
    } else if (translation == 'greek_interlinear') {
      verseDataPath =
          'assets/Biblia/completa_traducoes/greek_original/$bookAbbrev/$chapter.json';
    } else {
      verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
    }
    final String verseDataString = await rootBundle.loadString(verseDataPath);
    final decodedVerseData = json.decode(verseDataString);
    if (translation == 'hebrew_original' ||
        translation == 'greek_interlinear') {
      if (decodedVerseData is List) {
        return List<List<Map<String, String>>>.from(decodedVerseData.map(
            (verse) => (verse is List)
                ? List<Map<String, String>>.from(verse
                    .map((wordData) => (wordData is Map)
                        ? Map<String, String>.from(wordData.map((key, value) =>
                            MapEntry(key.toString(), value.toString())))
                        : <String, String>{})
                    .where((map) => map.isNotEmpty))
                : <List<Map<String, String>>>[]));
      }
    } else {
      if (decodedVerseData is List)
        return List<String>.from(
            decodedVerseData.map((item) => item.toString()));
    }
    return [];
  }

  static Future<String> loadSingleVerseText(
      String verseId, String translation) async {
    if (translation == 'hebrew_original' ||
        translation == 'greek_interlinear') {
      return "[Visualização interlinear]";
    }
    final parts = verseId.split('_');
    if (parts.length != 3) return "Referência inválida";
    final bookAbbrev = parts[0];
    final chapterForPath = parts[1];
    final verseIndex = int.tryParse(parts[2]);
    if (verseIndex == null) return "Verso inválido";
    try {
      final String verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapterForPath.json';
      final String verseDataString = await rootBundle.loadString(verseDataPath);
      final decodedVerseData = json.decode(verseDataString);
      if (decodedVerseData is List &&
          verseIndex > 0 &&
          verseIndex <= decodedVerseData.length) {
        return decodedVerseData[verseIndex - 1].toString();
      } else {
        return "[Texto não encontrado]";
      }
    } catch (e) {
      return "[Erro ao carregar]";
    }
  }
}
