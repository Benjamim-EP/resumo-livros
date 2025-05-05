// lib/pages/biblie_page/bible_page_helper.dart

import 'dart:convert';
import 'package:flutter/services.dart';

class BiblePageHelper {
  static Future<Map<String, dynamic>> loadBooksMap() async {
    final String data = await rootBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    return json.decode(data);
  }

  static Future<Map<String, dynamic>> loadChapterData(
      String bookAbbrev, int chapter, String translation) async {
    List<Map<String, dynamic>> sections = [];
    List<String> verses = [];

    // --- 1. Carregar Texto dos Versículos (Obrigatório) ---
    try {
      final String verseDataPath =
          'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json';
      print("Tentando carregar versos de: $verseDataPath");
      final String verseData = await rootBundle.loadString(verseDataPath);
      final decodedVerseData = json.decode(verseData);
      if (decodedVerseData is List) {
        verses =
            List<String>.from(decodedVerseData.map((item) => item.toString()));
        print("Versos carregados com sucesso (${verses.length} versos).");
      } else {
        print(
            'Formato inesperado para o conteúdo dos versículos: $decodedVerseData');
      }
    } catch (e) {
      print(
          'Erro ao carregar versículos ($translation/$bookAbbrev/$chapter): $e');
      return {'sections': [], 'verses': []};
    }

    // --- 2. Carregar Estrutura das Seções (Opcional) ---
    try {
      // <<< MODIFICAÇÃO MVP: Atualiza o caminho para a pasta 'blocos' >>>
      final String sectionStructurePath =
          'assets/Biblia/blocos/$bookAbbrev/$chapter.json';
      // <<< FIM MODIFICAÇÃO MVP >>>
      print("Tentando carregar estrutura de seções de: $sectionStructurePath");
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
                  'title': item['title']?.toString() ?? 'Seção sem título',
                  'verses': verseNumbers,
                };
              }
              return null;
            })
            .where((item) => item != null)
            .cast<Map<String, dynamic>>());
        print(
            "Estrutura de seções carregada com sucesso (${sections.length} seções).");
      } else {
        print(
            'Formato inesperado para a estrutura das seções: $decodedSectionData');
      }
    } catch (e) {
      print(
          'Info: Arquivo de estrutura de seções não encontrado ou erro ao carregar (blocos/$bookAbbrev/$chapter): $e');
      sections = [];
    }

    // --- 3. Retornar os dados combinados ---
    return {'sections': sections, 'verses': verses};
  }
}
