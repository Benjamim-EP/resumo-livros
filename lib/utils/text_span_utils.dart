// lib/utils/text_span_utils.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart'; // Para BiblePageHelper.loadVersesFromReference

class TextSpanUtils {
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
