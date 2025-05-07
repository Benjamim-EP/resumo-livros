// lib/pages/biblie_page/bible_page_helper.dart
import 'dart:convert';
import 'package:flutter/services.dart';

class BiblePageHelper {
  static Future<Map<String, dynamic>> loadBooksMap() async {
    final String data = await rootBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    return json.decode(data);
  }

  // <<< FUNÇÃO OBSOLETA (será substituída por loadChapterDataComparison) >>>
  // static Future<Map<String, dynamic>> loadChapterData(...) async { ... }

  // <<< NOVA FUNÇÃO PARA CARREGAR DADOS PARA COMPARAÇÃO >>>
  static Future<Map<String, dynamic>> loadChapterDataComparison(
    String bookAbbrev,
    int chapter,
    String translation1,
    String? translation2, // Segunda tradução é opcional
  ) async {
    List<Map<String, dynamic>> sections = [];
    Map<String, List<String>> verseTexts =
        {}; // Mapa para armazenar textos das traduções

    // --- 1. Carregar Estrutura das Seções (Opcional, apenas uma vez) ---
    try {
      final String sectionStructurePath =
          'assets/Biblia/blocos/$bookAbbrev/$chapter.json';
      print("Tentando carregar estrutura de seções de: $sectionStructurePath");
      final String sectionData =
          await rootBundle.loadString(sectionStructurePath);
      final decodedSectionData = json.decode(sectionData);
      if (decodedSectionData is List) {
        sections = List<Map<String, dynamic>>.from(
            /* ... (lógica de parse das seções como antes) ... */
            decodedSectionData
                .map((item) {
                  if (item is Map) {
                    final verseNumbers =
                        (item['verses'] as List<dynamic>?)?.cast<int>() ?? [];
                    return {
                      'title': item['title']?.toString() ?? 'Seção sem título',
                      'verses': verseNumbers,
                    };
                  }
                  return null;
                })
                .where((item) => item != null)
                .cast<Map<String, dynamic>>());
        print("Estrutura de seções carregada (${sections.length} seções).");
      } else {
        print(
            'Formato inesperado para a estrutura das seções: $decodedSectionData');
      }
    } catch (e) {
      print(
          'Info: Arquivo de estrutura de seções não encontrado ou erro (blocos/$bookAbbrev/$chapter): $e');
      sections = [];
    }

    // --- 2. Carregar Texto dos Versículos (Tradução 1 - Obrigatório) ---
    try {
      verseTexts[translation1] = await _loadVerseTextsForTranslation(
          bookAbbrev, chapter, translation1);
      print(
          "Versos carregados para $translation1 (${verseTexts[translation1]?.length ?? 0} versos).");
    } catch (e) {
      print('Erro CRÍTICO ao carregar versículos para $translation1: $e');
      // Se a tradução principal falhar, retorna vazio
      return {'sectionStructure': [], 'verseTexts': {}};
    }

    // --- 3. Carregar Texto dos Versículos (Tradução 2 - Se necessário) ---
    if (translation2 != null) {
      try {
        verseTexts[translation2] = await _loadVerseTextsForTranslation(
            bookAbbrev, chapter, translation2);
        print(
            "Versos carregados para $translation2 (${verseTexts[translation2]?.length ?? 0} versos).");
      } catch (e) {
        print('Erro ao carregar versículos para $translation2: $e');
        // Não é fatal, mas a segunda coluna ficará vazia ou com erro
        verseTexts[translation2] = []; // Define como vazio para indicar falha
      }
    }

    // --- 4. Retornar os dados combinados ---
    return {'sectionStructure': sections, 'verseTexts': verseTexts};
  }

  // <<< NOVO: Helper interno para carregar versos de uma tradução específica >>>
  static Future<List<String>> _loadVerseTextsForTranslation(
      String bookAbbrev, int chapter, String translation) async {
    final String verseDataPath =
        'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
    final String verseData = await rootBundle.loadString(verseDataPath);
    final decodedVerseData = json.decode(verseData);
    if (decodedVerseData is List) {
      return List<String>.from(decodedVerseData.map((item) => item.toString()));
    } else {
      print(
          'Formato inesperado para versículos ($translation/$bookAbbrev/$chapter): $decodedVerseData');
      return []; // Retorna vazio se o formato for inválido
    }
  }
  // <<< FIM NOVO >>>

  // <<< loadSingleVerseText permanece o mesmo >>>
  static Future<String> loadSingleVerseText(
      String verseId, String translation) async {
    // ... (código de loadSingleVerseText como antes) ...
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
        return "[Texto não encontrado]"; // Mensagem mais clara
      }
    } catch (e) {
      print('Erro ao carregar verso ($verseId, $translation): $e');
      return "[Erro ao carregar]";
    }
  }
}
