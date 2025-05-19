// lib/pages/biblie_page/bible_page_helper.dart
import 'dart:convert';
import 'package:flutter/services.dart';

class BiblePageHelper {
  static Map<String, dynamic>? _strongsLexicon; // Cache para o léxico

  static Future<Map<String, dynamic>> loadBooksMap() async {
    final String data = await rootBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    return json.decode(data);
  }

  // Método assíncrono para carregar e cachear
  static Future<Map<String, dynamic>?> loadAndCacheStrongsLexicon() async {
    // Renomeado para clareza
    if (_strongsLexicon == null) {
      try {
        final String data = await rootBundle.loadString(
            'assets/Biblia/completa_traducoes/hebrew_strong_lexicon_traduzido.json');
        _strongsLexicon = json.decode(data);
        print("Léxico de Strong Hebraico carregado e cacheado.");
      } catch (e) {
        print("Erro ao carregar o léxico de Strong Hebraico: $e");
        return null;
      }
    }
    return _strongsLexicon;
  }

  // NOVO: Getter síncrono para o léxico cacheado
  static Map<String, dynamic>? get cachedStrongsLexicon {
    return _strongsLexicon;
  }

  // ... (loadChapterDataComparison e loadSingleVerseText como antes)
  static Future<Map<String, dynamic>> loadChapterDataComparison(
    String bookAbbrev,
    int chapter,
    String translation1,
    String? translation2,
  ) async {
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
          'Info: Estrutura de seções não encontrada para $bookAbbrev/$chapter: $e');
      sections = [];
    }

    try {
      verseData[translation1] =
          await _loadVerseDataForTranslation(bookAbbrev, chapter, translation1);
    } catch (e) {
      print('Erro CRÍTICO ao carregar dados para $translation1: $e');
      return {'sectionStructure': [], 'verseData': {}};
    }

    if (translation2 != null) {
      try {
        verseData[translation2] = await _loadVerseDataForTranslation(
            bookAbbrev, chapter, translation2);
      } catch (e) {
        print('Erro ao carregar dados para $translation2: $e');
        verseData[translation2] = [];
      }
    }
    return {'sectionStructure': sections, 'verseData': verseData};
  }

  static Future<dynamic> _loadVerseDataForTranslation(
      String bookAbbrev, int chapter, String translation) async {
    final String verseDataPath =
        'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
    final String verseDataString = await rootBundle.loadString(verseDataPath);
    final decodedVerseData = json.decode(verseDataString);

    if (translation == 'hebrew_original') {
      if (decodedVerseData is List) {
        return List<List<Map<String, String>>>.from(
            decodedVerseData.map((verse) {
          if (verse is List) {
            return List<Map<String, String>>.from(verse.map((wordData) {
              if (wordData is Map) {
                return Map<String, String>.from(wordData.map((key, value) =>
                    MapEntry(key.toString(), value.toString())));
              }
              return <String, String>{};
            }).where((wordMap) => wordMap.isNotEmpty));
          }
          return <List<Map<String, String>>>[];
        }).where((verseList) => verseList.isNotEmpty));
      } else {
        print(
            'Formato inesperado para dados hebraicos ($translation/$bookAbbrev/$chapter): $decodedVerseData');
        return [];
      }
    } else {
      if (decodedVerseData is List) {
        return List<String>.from(
            decodedVerseData.map((item) => item.toString()));
      } else {
        print(
            'Formato inesperado para versículos ($translation/$bookAbbrev/$chapter): $decodedVerseData');
        return [];
      }
    }
  }

  static Future<String> loadSingleVerseText(
      String verseId, String translation) async {
    if (translation == 'hebrew_original') {
      return "[Visualização de verso único em hebraico não implementada]";
    }

    final parts = verseId.split('_');
    if (parts.length != 3) return "Referência inválida";
    final bookAbbrev = parts[0];
    final chapterStr = parts[1];
    final verseStr = parts[2];
    final chapter = int.tryParse(chapterStr);
    final verse = int.tryParse(verseStr);
    if (chapter == null || verse == null) return "Referência inválida";

    try {
      final String verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
      final String verseData = await rootBundle.loadString(verseDataPath);
      final decodedVerseData = json.decode(verseData);
      if (decodedVerseData is List &&
          verse > 0 &&
          verse <= decodedVerseData.length) {
        return decodedVerseData[verse - 1].toString();
      } else {
        return "[Texto não encontrado]";
      }
    } catch (e) {
      print('Erro ao carregar verso ($verseId, $translation): $e');
      return "[Erro ao carregar]";
    }
  }
}
