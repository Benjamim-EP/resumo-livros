// lib/utils/text_span_utils.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart'; // Para BiblePageHelper.loadVersesFromReference

class TextSpanUtils {
  static Map<String, dynamic>? booksMap;

  // Função para garantir que o mapa de livros esteja carregado.
  static Future<void> _ensureBooksMapLoaded() async {
    if (booksMap == null) {
      booksMap = await BiblePageHelper.loadBooksMap();
    }
  }

  static Future<void> loadBooksMap() async {
    if (booksMap == null) {
      booksMap = await BiblePageHelper.loadBooksMap();
    }
  }

  static void showVersePopup(BuildContext context, String reference) {
    _handleReferenceTap(context, reference, Theme.of(context));
  }

  // --- NOVA FUNÇÃO HELPER ---
  /// Converte um ID customizado (ex: sl_c31_v1-8) para uma string de exibição (ex: Salmos 31:1-8).
  static String _formatCustomReferenceForDisplay(String customId) {
    if (booksMap == null) return customId; // Fallback

    final parts = customId.split('_');
    if (parts.length != 3) return customId;

    final bookAbbrev = parts[0];
    final chapter = parts[1].replaceAll('c', '');
    final verses = parts[2].replaceAll('v', '').replaceAll('-', '-');

    final bookName = booksMap![bookAbbrev]?['nome'] ?? bookAbbrev.toUpperCase();
    return "$bookName $chapter:$verses";
  }

  // --- NOVA FUNÇÃO PRINCIPAL PARA GUIAS DE ESTUDO ---
  static Future<List<TextSpan>> buildTextSpansFromCustomFormat({
    required String textSegment,
    required ThemeData theme,
    required BuildContext pageContext,
    required double fontSize,
  }) async {
    await _ensureBooksMapLoaded(); // Garante que temos os nomes dos livros

    final List<TextSpan> spans = [];
    // Nova Regex para encontrar o formato: 'sl_c31_v1-8'
    final RegExp customRefRegex = RegExp(
      r'\b([a-z1-3]+)_c(\d+)_v(\d+(?:-\d+)?)\b',
      caseSensitive: false,
    );

    int currentPosition = 0;
    for (final Match match in customRefRegex.allMatches(textSegment)) {
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: textSegment.substring(currentPosition, match.start),
          style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurface.withOpacity(0.9)),
        ));
      }

      final String matchedId = match.group(0)!; // ex: 'sl_c31_v1-8'
      final String displayReference =
          _formatCustomReferenceForDisplay(matchedId);

      spans.add(
        TextSpan(
          text: displayReference, // Mostra "Salmos 31:1-8"
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: theme.colorScheme.primary.withOpacity(0.5),
            fontSize: fontSize,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // A ação de clique usa a string de exibição que o `loadVersesFromReference` já entende
              _handleReferenceTap(pageContext, displayReference, theme);
            },
        ),
      );
      currentPosition = match.end;
    }

    if (currentPosition < textSegment.length) {
      spans.add(TextSpan(
        text: textSegment.substring(currentPosition),
        style: TextStyle(
            fontSize: fontSize,
            color: theme.colorScheme.onSurface.withOpacity(0.9)),
      ));
    }

    return spans.isEmpty ? [TextSpan(text: textSegment)] : spans;
  }

  static void _handleReferenceTap(
      BuildContext pageContext, String reference, ThemeData theme) async {
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          content: Row(
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(width: 20),
              Text("Carregando...",
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            ],
          ),
        );
      },
    );

    try {
      final List<String> verseTexts =
          await BiblePageHelper.loadVersesFromReference(reference, 'nvi');
      if (pageContext.mounted)
        Navigator.of(pageContext, rootNavigator: true).pop();
      if (verseTexts.isNotEmpty &&
          !verseTexts.first.contains("Erro") &&
          !verseTexts.first.contains("inválid")) {
        if (pageContext.mounted)
          showVerseTextDialog(pageContext, reference, verseTexts.join("\n\n"));
      } else {
        if (pageContext.mounted)
          showVerseTextDialog(pageContext, reference,
              "Não foi possível carregar o texto para esta referência.");
      }
    } catch (e) {
      if (pageContext.mounted)
        Navigator.of(pageContext, rootNavigator: true).pop();
      if (pageContext.mounted)
        showVerseTextDialog(
            pageContext, reference, "Erro ao carregar referência: $e");
    }
  }

  // Função para exibir o texto do versículo em um diálogo
  static void showVerseTextDialog(
      BuildContext context, String reference, String verseText) {
    final theme = Theme.of(context); // Pega o tema do contexto do diálogo
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text("Referência: $reference",
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Text(
              verseText,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.85),
                  height: 1.5),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Fechar",
                  style: TextStyle(color: theme.colorScheme.primary)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Função para construir TextSpans com referências bíblicas clicáveis
  static List<TextSpan> buildTextSpansForSegment(
    String textSegment,
    ThemeData theme,
    BuildContext
        pageContext, // Contexto da página/widget que está chamando, para mostrar diálogos
    double fontSize, // Tamanho da fonte base para o texto normal e referências
  ) {
    final List<TextSpan> spans = [];
    // Regex aprimorada para capturar abreviações comuns, capítulos e versículos
    final RegExp bibleRefRegex = RegExp(
      r'\b([1-3]?[a-zA-Z]{1,5})\s*(\d+)\s*[:.]\s*(\d+(?:\s*-\s*\d+)?)\b',
      caseSensitive: false,
    );

    int currentPosition = 0;
    for (final Match match in bibleRefRegex.allMatches(textSegment)) {
      // Adiciona o texto ANTES da referência encontrada
      if (match.start > currentPosition) {
        spans.add(TextSpan(
          text: textSegment.substring(currentPosition, match.start),
          // Estilo para texto normal (não-link)
          style: TextStyle(
              fontSize: fontSize,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9)),
        ));
      }

      // A referência bíblica completa que foi encontrada pela regex
      final String matchedReference = match.group(0)!;

      spans.add(
        TextSpan(
          text: matchedReference,
          style: TextStyle(
            color:
                theme.colorScheme.primary, // Cor de destaque para a referência
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor:
                theme.colorScheme.primary.withOpacity(0.5), // Cor do sublinhado
            fontSize: fontSize, // Mantém o mesmo tamanho de fonte base
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              print("TextSpanUtils: Referência clicada: $matchedReference");
              // Mostrar um indicador de loading
              showDialog(
                context: pageContext, // Usa o contexto da PÁGINA que chamou
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    backgroundColor: theme.dialogBackgroundColor,
                    content: Row(
                      children: [
                        CircularProgressIndicator(
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 20),
                        Text("Carregando...",
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                      ],
                    ),
                  );
                },
              );

              try {
                // Assume tradução 'nvi' por padrão.
                final List<String> verseTexts =
                    await BiblePageHelper.loadVersesFromReference(
                        matchedReference, 'nvi');

                // Fecha o diálogo de loading ANTES de mostrar o resultado
                if (pageContext.mounted)
                  Navigator.of(pageContext, rootNavigator: true).pop();

                if (verseTexts.isNotEmpty &&
                    !verseTexts.first.contains("Erro") &&
                    !verseTexts.first.contains("inválid")) {
                  if (pageContext.mounted)
                    showVerseTextDialog(
                        pageContext, matchedReference, verseTexts.join("\n\n"));
                } else {
                  if (pageContext.mounted)
                    showVerseTextDialog(pageContext, matchedReference,
                        "Não foi possível carregar o texto para esta referência ou a referência é inválida.\nDetalhe: ${verseTexts.join("\n")}");
                }
              } catch (e) {
                if (pageContext.mounted)
                  Navigator.of(pageContext, rootNavigator: true)
                      .pop(); // Fecha o diálogo de loading
                if (pageContext.mounted)
                  showVerseTextDialog(pageContext, matchedReference,
                      "Erro ao carregar referência: $e");
              }
            },
        ),
      );
      currentPosition = match.end;
    }

    // Adiciona o restante do texto após a última referência (se houver)
    if (currentPosition < textSegment.length) {
      spans.add(TextSpan(
        text: textSegment.substring(currentPosition),
        style: TextStyle(
            fontSize: fontSize,
            color: theme.colorScheme.onSurfaceVariant
                .withOpacity(0.9)), // Estilo para texto normal
      ));
    }

    // Se o texto original era vazio e nenhum span foi adicionado, retorna um span vazio
    // Se o texto original não era vazio mas nenhum span foi adicionado (ex: sem referências), retorna o texto original com estilo base
    if (spans.isEmpty && textSegment.isNotEmpty) {
      return [
        TextSpan(
            text: textSegment,
            style: TextStyle(
                fontSize: fontSize,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9)))
      ];
    }
    return spans;
  }
}
