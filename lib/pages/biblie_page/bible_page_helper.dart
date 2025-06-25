// lib/pages/biblie_page/bible_page_helper.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

class BiblePageHelper {
  static Map<String, dynamic>?
      _hebrewStrongsLexicon; // Cache para o léxico Hebraico
  static Map<String, dynamic>?
      _greekStrongsLexicon; // Cache para o léxico Grego

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
    // Substitui os dois pontos por " e " para guiar o motor TTS.
    // Usamos uma expressão regular para garantir que só substituímos os dois pontos
    // que estão entre números.
    return reference.replaceAllMapped(
      RegExp(r'(\d):(\d)'),
      (match) => '${match.group(1)} versiculo ${match.group(2)}',
    );
  }

  static Future<String> getFullReferenceName(
      String abbreviatedReference) async {
    try {
      // Carrega o mapa de livros (usa o cache se já carregado)
      final booksMap = await loadBooksMap();

      // Regex para separar a abreviação do resto da referência (capítulo e versículos)
      final regex = RegExp(r'^(\S+)\s*(.*)$');
      final match = regex.firstMatch(abbreviatedReference.trim());

      if (match != null) {
        final abbrev = match.group(1)?.toLowerCase() ?? '';
        final restOfReference = match.group(2) ?? '';

        // Procura a abreviação no nosso mapa de livros
        if (booksMap.containsKey(abbrev)) {
          final bookName = booksMap[abbrev]?['nome'] ?? abbrev.toUpperCase();
          return '$bookName $restOfReference';
        }
      }
      // Se não encontrar ou o formato for inesperado, retorna a original
      return abbreviatedReference;
    } catch (e) {
      print("Erro ao obter nome completo da referência: $e");
      return abbreviatedReference; // Retorna a original em caso de erro
    }
  }

  // Método assíncrono para carregar e cachear o léxico Hebraico
  static Future<Map<String, dynamic>?>
      loadAndCacheHebrewStrongsLexicon() async {
    if (_hebrewStrongsLexicon == null) {
      try {
        final String data = await rootBundle.loadString(
            'assets/Biblia/completa_traducoes/hebrew_strong_lexicon_traduzido.json');
        _hebrewStrongsLexicon = json.decode(data);
        print("Léxico de Strong Hebraico carregado e cacheado.");
      } catch (e) {
        print("Erro ao carregar o léxico de Strong Hebraico: $e");
        return null;
      }
    }
    return _hebrewStrongsLexicon;
  }

  // Getter síncrono para o léxico hebraico cacheado
  static Map<String, dynamic>? get cachedHebrewStrongsLexicon {
    return _hebrewStrongsLexicon;
  }

  // Método assíncrono para carregar e cachear o léxico Grego
  static Future<Map<String, dynamic>?> loadAndCacheGreekStrongsLexicon() async {
    if (_greekStrongsLexicon == null) {
      try {
        // Ajuste o caminho para o seu arquivo de léxico grego
        final String data = await rootBundle.loadString(
            'assets/Biblia/completa_traducoes/greek_strong_lexicon_traduzido.json');
        _greekStrongsLexicon = json.decode(data);
        print("Léxico de Strong Grego carregado e cacheado.");
      } catch (e) {
        print("Erro ao carregar o léxico de Strong Grego: $e");
        return null;
      }
    }
    return _greekStrongsLexicon;
  }

  static String? _getAbbrevFromPortugueseName(String bookName) {
    String normalizedName = unorm
        .nfd(bookName.toLowerCase().trim())
        .replaceAll(RegExp(r'[\u0300-\u036f]'), ''); // Remove acentos
    return _bookNameToAbbrevMap[normalizedName];
  }

  static Future<List<String>> loadVersesFromReference(
    String reference, // Ex: "Lc 9:42" ou "Gn 1:1-3"
    String translation, // Ex: "nvi"
  ) async {
    if (reference.isEmpty) return ["Referência inválida."];

    // Regex para capturar: Nome do Livro, Capítulo, Versículo Inicial, (Opcional) Versículo Final
    // Exemplo: "Lucas 9:42" ou "Gênesis 1:1-3" ou "1 Coríntios 13:4"
    final RegExp regex = RegExp(
      r"^\s*([1-3]?\s*[A-Za-zÀ-ÖØ-öø-ÿ]+)\s*(\d+)\s*[:\.]\s*(\d+)(?:\s*-\s*(\d+))?\s*$",
      caseSensitive: false,
    );

    final Match? match = regex.firstMatch(reference.trim());

    if (match == null) {
      print(
          "BiblePageHelper: Formato de referência não reconhecido: '$reference'");
      return ["Formato de referência inválido: $reference"];
    }

    String bookNamePart = match.group(1)!.trim();
    String chapterStr = match.group(2)!;
    String startVerseStr = match.group(3)!;
    String? endVerseStr = match.group(4); // Pode ser nulo

    String? bookAbbrev = _getAbbrevFromPortugueseName(bookNamePart);

    if (bookAbbrev == null) {
      // Tentar encontrar abreviação diretamente se já for uma (caso comum)
      // Isso pode ser mais robusto se o _bookNameToAbbrevMap for carregado do seu abbrev_map.json
      final Map<String, dynamic> booksMap =
          await loadBooksMap(); // Carrega o mapa de abreviações
      booksMap.forEach((abbrev, data) {
        if (data is Map && data['nome'] != null) {
          String nameFromMap = unorm
              .nfd((data['nome'] as String).toLowerCase().trim())
              .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
          if (nameFromMap ==
              unorm
                  .nfd(bookNamePart.toLowerCase().trim())
                  .replaceAll(RegExp(r'[\u0300-\u036f]'), '')) {
            bookAbbrev = abbrev;
          }
        }
        // Se a parte do livro já for uma abreviação conhecida
        if (bookAbbrev == null &&
            abbrev.toLowerCase() == bookNamePart.toLowerCase()) {
          bookAbbrev = abbrev;
        }
      });

      if (bookAbbrev == null) {
        print(
            "BiblePageHelper: Abreviação não encontrada para o livro: '$bookNamePart' na referência '$reference'");
        return ["Livro não reconhecido: $bookNamePart"];
      }
    }

    final int? chapter = int.tryParse(chapterStr);
    final int? startVerse = int.tryParse(startVerseStr);
    final int? endVerse =
        endVerseStr != null ? int.tryParse(endVerseStr) : startVerse;

    if (chapter == null || startVerse == null || endVerse == null) {
      print(
          "BiblePageHelper: Capítulo ou versículo(s) inválido(s) na referência: '$reference'");
      return ["Capítulo/versículo(s) inválido(s) na referência: $reference"];
    }

    if (endVerse < startVerse) {
      print(
          "BiblePageHelper: Versículo final menor que o inicial na referência: '$reference'");
      return ["Intervalo de versículos inválido: $reference"];
    }

    try {
      final String verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
      print("BiblePageHelper: Carregando versículos de: $verseDataPath");
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
      if (resultVerses.isEmpty)
        return ["Versículos não encontrados para: $reference"];
      return resultVerses;
    } catch (e) {
      print(
          'BiblePageHelper: Erro ao carregar versículos para "$reference" ($translation): $e');
      return ["Erro ao carregar versículos para: $reference"];
    }
  }

  // Getter síncrono para o léxico grego cacheado
  static Map<String, dynamic>? get cachedGreekStrongsLexicon {
    return _greekStrongsLexicon;
  }

  static Future<Map<String, dynamic>> loadChapterDataComparison(
    String bookAbbrev,
    int chapter,
    String translation1,
    String? translation2, // Pode ser nulo se não estiver em modo de comparação
  ) async {
    List<Map<String, dynamic>> sections = [];
    Map<String, dynamic> verseData = {};

    // 1. Carregar estrutura de seções (independente da tradução)
    try {
      final String sectionStructurePath =
          'assets/Biblia/blocos/$bookAbbrev/$chapter.json';
      final String sectionData =
          await rootBundle.loadString(sectionStructurePath);
      final decodedSectionData = json.decode(sectionData);
      if (decodedSectionData is List) {
        sections = List<Map<String, dynamic>>.from(decodedSectionData
            .map((item) {
              if (item is Map) {
                final verseNumbers =
                    (item['verses'] as List<dynamic>?)?.cast<int>() ?? [];
                return {
                  'title': item['title']?.toString() ?? 'Seção',
                  'verses': verseNumbers
                };
              }
              return null;
            })
            .where((item) => item != null)
            .cast<Map<String, dynamic>>());
      }
    } catch (e) {
      print(
          'Info: Estrutura de seções não encontrada para $bookAbbrev/$chapter: $e. Continuando sem seções.');
      sections = []; // Define como lista vazia se não encontrar ou erro
    }

    // 2. Carregar dados da primeira tradução
    try {
      verseData[translation1] =
          await _loadVerseDataForTranslation(bookAbbrev, chapter, translation1);
    } catch (e) {
      print(
          'Erro CRÍTICO ao carregar dados para $translation1 ($bookAbbrev $chapter): $e');
      // Retorna estrutura vazia para evitar crash na UI, mas loga o erro.
      return {'sectionStructure': [], 'verseData': {}};
    }

    // 3. Carregar dados da segunda tradução (se houver)
    if (translation2 != null) {
      try {
        verseData[translation2] = await _loadVerseDataForTranslation(
            bookAbbrev, chapter, translation2);
      } catch (e) {
        print(
            'Erro ao carregar dados para $translation2 ($bookAbbrev $chapter): $e. Esta tradução não será exibida.');
        verseData[translation2] =
            []; // Define como lista vazia em caso de erro para esta tradução
      }
    }
    return {'sectionStructure': sections, 'verseData': verseData};
  }

  static Future<dynamic> _loadVerseDataForTranslation(
      String bookAbbrev, int chapter, String translation) async {
    String verseDataPath; // Caminho do arquivo de dados do verso

    if (translation == 'hebrew_original') {
      verseDataPath =
          'assets/Biblia/completa_traducoes/hebrew_original/$bookAbbrev/$chapter.json';
    } else if (translation == 'greek_interlinear') {
      // <<< NOVO CASO PARA GREGO INTERLINEAR
      verseDataPath =
          'assets/Biblia/completa_traducoes/greek_original/$bookAbbrev/$chapter.json';
    } else {
      // Traduções normais (NVI, ACF, AA, etc.)
      verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
    }

    final String verseDataString = await rootBundle.loadString(verseDataPath);
    final decodedVerseData = json.decode(verseDataString);

    // Tratamento específico para hebraico original e grego interlinear
    if (translation == 'hebrew_original' ||
        translation == 'greek_interlinear') {
      if (decodedVerseData is List) {
        // Ambas as estruturas (hebraico e grego interlinear) são List<List<Map<String, String>>>
        return List<List<Map<String, String>>>.from(
            decodedVerseData.map((verse) {
          // Itera sobre cada versículo (que é uma lista de palavras)
          if (verse is List) {
            return List<Map<String, String>>.from(verse.map((wordData) {
              // Itera sobre cada palavra (que é um mapa)
              if (wordData is Map) {
                // Garante que todas as chaves e valores no mapa da palavra são strings
                return Map<String, String>.from(wordData.map((key, value) =>
                    MapEntry(key.toString(), value.toString())));
              }
              return <String,
                  String>{}; // Retorna mapa vazio se wordData não for um mapa
            }).where((wordMap) =>
                wordMap.isNotEmpty)); // Remove mapas de palavras vazios
          }
          return <List<
              Map<String,
                  String>>>[]; // Retorna lista de versos vazia se o verso não for uma lista
        })
            // Opcional: filtrar listas de versos que ficaram vazias após o processamento interno
            // .where((verseList) => verseList.isNotEmpty)
            );
      } else {
        print(
            'Formato inesperado para dados interlineares ($translation/$bookAbbrev/$chapter): $decodedVerseData. Esperado List<List<Map<String, String>>>.');
        return []; // Retorna lista vazia em caso de erro de formato
      }
    } else {
      // Traduções normais (lista de strings)
      if (decodedVerseData is List) {
        return List<String>.from(
            decodedVerseData.map((item) => item.toString()));
      } else {
        print(
            'Formato inesperado para versículos ($translation/$bookAbbrev/$chapter): $decodedVerseData. Esperado List<String>.');
        return []; // Retorna lista vazia em caso de erro de formato
      }
    }
  }

  static Future<String> loadSingleVerseText(
      String verseId, String translation) async {
    // Se for uma tradução interlinear, não faz sentido carregar um "single verse text" simples.
    // Retorna uma mensagem indicando que a visualização é diferente.
    if (translation == 'hebrew_original' ||
        translation == 'greek_interlinear') {
      return "[Visualização interlinear. Detalhes mostrados palavra por palavra.]";
    }

    final parts = verseId.split('_'); // Ex: "gn_1_1"
    if (parts.length != 3)
      return "Referência inválida para carregar texto único";

    final bookAbbrev = parts[0];
    final chapterStr = parts[1]; // Mantém como string
    final verseStr = parts[2]; // Mantém como string

    // Não precisamos converter capítulo e verso para int aqui, pois o caminho do arquivo usa strings.
    // Apenas verificamos se são numéricos se necessário para lógica interna, mas para o path não.
    final chapterForPath = chapterStr;
    final verseIndex = int.tryParse(verseStr);

    if (verseIndex == null) return "Número do verso inválido na referência";

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
        return "[Texto do verso não encontrado]";
      }
    } catch (e) {
      print('Erro ao carregar verso único ($verseId, $translation): $e');
      return "[Erro ao carregar texto do verso]";
    }
  }
}
