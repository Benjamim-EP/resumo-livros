import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BibleReferenceHighlighter {
  static Map<String, Map<String, dynamic>>? _booksMap;

  /// 🔹 Carrega `abbrev_map.json` apenas uma vez (cacheado)
  static Future<void> loadBooksMap() async {
  if (_booksMap == null) {
    final String data = await rootBundle.loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
    final Map<String, dynamic> decodedData = json.decode(data);

    // 🔹 Converte para Map<String, Map<String, dynamic>>
    _booksMap = decodedData.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
  }
}


  /// 🔹 Destaca referências bíblicas no texto
  static Future<RichText> highlightBibleReferences(String text) async {
    await loadBooksMap();
    if (_booksMap == null) return RichText(text: TextSpan(text: text));

    List<TextSpan> spans = [];
    final regExp = RegExp(r'(\s+|\n+|[^\s]+)');
    final matches = regExp.allMatches(text).toList();

    for (int i = 0; i < matches.length; i++) {
      final word = matches[i].group(0)!;
      final nextWord = (i + 1 < matches.length) ? matches[i + 1].group(0) : null;

      if (word.trim().isEmpty) {
        spans.add(TextSpan(text: word));
        continue;
      }

      final reference = _detectBibleReference(word, nextWord);
      if (reference != null) {
        spans.add(TextSpan(
          text: reference,
          style: const TextStyle(
            color: Color(0xFF129575),
            fontWeight: FontWeight.bold,
          ),
        ));
      } else {
        spans.add(TextSpan(text: word));
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 14),
        children: spans,
      ),
    );
  }


  /// 🔹 Detecta referências como `Gênesis 1:2` ou `Gn 1:2`
  static String? _detectBibleReference(String word, String? nextWord) {
    if (_booksMap == null) return null;

    for (var entry in _booksMap!.entries) {
      final abbrev = entry.key;
      final bookName = entry.value['nome'];
      final totalChapters = entry.value['capitulos'];

      // 🔸 Verifica se a palavra corresponde a um nome de livro ou abreviação
      if (word == bookName || word.toLowerCase() == abbrev) {
        if (nextWord != null) {
          final parts = nextWord.split(':');

          if (parts.length == 2) {
            final chapter = int.tryParse(parts[0]);
            final verse = int.tryParse(parts[1]);

            if (chapter != null && verse != null && chapter <= totalChapters) {
              return "$bookName $chapter:$verse";
            }
          } else {
            final chapter = int.tryParse(nextWord);
            if (chapter != null && chapter <= totalChapters) {
              return "$bookName $chapter";
            }
          }
        }
        return bookName;
      }
    }

    return null;
  }
}
