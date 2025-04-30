import 'dart:convert';
import 'package:flutter/services.dart';
// REMOVIDO: import 'package:cloud_firestore/cloud_firestore.dart';

class BiblePageHelper {
  static Future<Map<String, dynamic>> loadBooksMap() async {
    final String data = await rootBundle
        .loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    return json.decode(data);
  }

  static Future<List<String>> loadChapterContent(
      String bookAbbrev, int chapter, String translation) async {
    try {
      final String data = await rootBundle.loadString(
        'assets/Biblia/completa_traducoes/$translation/$bookAbbrev/$chapter.json',
      );
      // Garante que o resultado seja sempre List<String>
      final decodedData = json.decode(data);
      if (decodedData is List) {
        return List<String>.from(decodedData.map((item) => item.toString()));
      }
      print('Formato inesperado para o conteúdo do capítulo: $decodedData');
      return []; // Retorna lista vazia se o formato não for esperado
    } catch (e) {
      print(
          'Erro ao carregar o capítulo $bookAbbrev $chapter ($translation): $e');
      return []; // Retorna lista vazia em caso de erro
    }
  }

  // REMOVIDO: Função loadChapterComments inteira
}
