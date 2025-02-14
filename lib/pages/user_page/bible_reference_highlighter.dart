import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BibleReferenceHighlighter {
  static Map<String, Map<String, dynamic>>? _booksMap;

  /// 🔹 Carrega `abbrev_map.json` apenas uma vez (cacheado)
  static Future<void> loadBooksMap() async {
    if (_booksMap == null) {
      final String data =
          await rootBundle.loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
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
    int lastIndex = 0;

    // Expressão regular para capturar referências bíblicas completas
    final regex = RegExp(
      r'\b([A-Za-zÀ-ÖØ-öø-ÿ]+|[A-Za-zÀ-ÖØ-öø-ÿ]+\s\d+)(?:\s\d+)?(?::\d+(?:-\d+)?)?\b',
      caseSensitive: false,
    );

    final matches = regex.allMatches(text);

    for (final match in matches) {
      final matchText = match.group(0)!;
      final start = match.start;
      final end = match.end;

      // Adiciona o texto antes do match sem destaque
      if (start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, start),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ));
      }

      // Verifica se o match é uma referência bíblica válida
      final formattedReference = _formatBibleReference(matchText);
      if (formattedReference != null) {
        spans.add(TextSpan(
          text: formattedReference,
          style: const TextStyle(
            color: Color(0xFF129575),
            fontWeight: FontWeight.bold,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: matchText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ));
      }

      lastIndex = end;
    }

    // Adiciona o restante do texto após o último match
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 14),
        children: spans,
      ),
    );
  }

  /// 🔹 Converte referências abreviadas para nome completo e mantém capítulo/versículo
  static String? _formatBibleReference(String reference) {
    if (_booksMap == null) return null;

    // Tenta identificar se o texto começa com uma abreviação ou nome completo
    for (var entry in _booksMap!.entries) {
      final abbrev = entry.key.toLowerCase();
      final bookName = entry.value['nome'];
      final totalChapters = entry.value['capitulos'];

      // Se a referência contém espaços, pode ter capítulo/versículo
      final parts = reference.split(RegExp(r'\s+'));

      if (parts.isNotEmpty) {
        final firstPart = parts.first.toLowerCase();

        if (firstPart == abbrev || firstPart == bookName.toLowerCase()) {
          final remaining = parts.skip(1).join(' ');

          // Verifica se tem capítulo ou versículo
          if (remaining.isNotEmpty) {
            final chapterVerse = remaining.split(':');

            if (chapterVerse.length == 2) {
              final chapter = int.tryParse(chapterVerse[0]);
              final verse = chapterVerse[1];

              if (chapter != null && chapter <= totalChapters) {
                return "$bookName $chapter:$verse";
              }
            } else {
              final chapter = int.tryParse(remaining);
              if (chapter != null && chapter <= totalChapters) {
                return "$bookName $chapter";
              }
            }
          }

          return bookName;
        }
      }
    }

    return null;
  }
}
