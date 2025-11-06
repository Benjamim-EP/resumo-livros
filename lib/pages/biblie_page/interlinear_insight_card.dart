// lib/pages/biblie_page/interlinear_insight_card.dart

import 'package:flutter/material.dart';

class InterlinearInsightCard extends StatelessWidget {
  final String markdownContent;

  const InterlinearInsightCard({super.key, required this.markdownContent});

  /// Converte uma string em Markdown simples para uma lista de widgets Flutter.
  List<Widget> _parseMarkdown(BuildContext context) {
    final theme = Theme.of(context);
    final List<Widget> widgets = [];
    final lines = markdownContent.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('### ')) {
        // Título de Nível 3
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              line.substring(4), // Remove '### '
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        // Item de lista (bullet point)
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                    child: _buildRichTextFromLine(line.substring(2), theme)),
              ],
            ),
          ),
        );
      } else {
        // Parágrafo normal
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _buildRichTextFromLine(line, theme),
          ),
        );
      }
    }
    return widgets;
  }

  /// Converte uma única linha de texto em um RichText, tratando negrito (**).
  RichText _buildRichTextFromLine(String line, ThemeData theme) {
    List<TextSpan> spans = [];
    // Regex para encontrar texto entre **...**
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int currentPosition = 0;

    for (final Match match in boldRegex.allMatches(line)) {
      // Adiciona o texto normal antes do negrito
      if (match.start > currentPosition) {
        spans.add(TextSpan(text: line.substring(currentPosition, match.start)));
      }
      // Adiciona o texto em negrito
      spans.add(
        TextSpan(
          text: match.group(1), // Conteúdo dentro dos asteriscos
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      currentPosition = match.end;
    }

    // Adiciona o restante do texto
    if (currentPosition < line.length) {
      spans.add(TextSpan(text: line.substring(currentPosition)));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, fontSize: 15),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 20.0),
      elevation: 0,
      color: theme.colorScheme.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text("Insights do Original",
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(height: 16),
            ..._parseMarkdown(context),
          ],
        ),
      ),
    );
  }
}
