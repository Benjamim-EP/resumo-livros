// lib/pages/biblie_page/bible_page_helper.dart
import 'dart:convert';
import 'package:flutter/services.dart';

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
