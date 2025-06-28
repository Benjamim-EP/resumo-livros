// lib/pages/devotional_page/devotional_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/devotional_model.dart';
import 'package:septima_biblia/utils/text_span_utils.dart'; // Importa nosso futuro utilitário

class DevotionalCard extends StatelessWidget {
  final DevotionalReading reading;
  final bool isRead;
  final VoidCallback onMarkAsRead;
  final VoidCallback onPlay;

  const DevotionalCard({
    super.key,
    required this.reading,
    required this.isRead,
    required this.onMarkAsRead,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMorning = reading.title.toLowerCase().contains('manhã');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead
              ? theme.colorScheme.primary.withOpacity(0.6)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com Título, Ícone e Botão de Play
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  isMorning ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  color: theme.colorScheme.secondary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reading.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up_outlined),
                  tooltip: "Ouvir Devocional",
                  onPressed: onPlay,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Versículo e Referência
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontStyle: FontStyle.italic, height: 1.5),
                children: [
                  TextSpan(text: '${reading.scriptureVerse} — '),
                  TextSpan(
                    text: reading.scripturePassage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    // Aqui poderíamos adicionar um recognizer para abrir a referência na Bíblia
                  ),
                ],
              ),
            ),
            const Divider(height: 24),

            // Conteúdo do Devocional
            ...reading.content.map((paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: RichText(
                    textAlign: TextAlign.justify,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      // Usaremos o TextSpanUtils para destacar referências no futuro
                      children: [TextSpan(text: paragraph)],
                    ),
                  ),
                )),

            // Ação de Marcar como Lido
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(
                  isRead ? Icons.check_circle : Icons.check_circle_outline,
                  color:
                      isRead ? theme.colorScheme.primary : theme.disabledColor,
                ),
                label: Text(isRead ? "Lido" : "Marcar como lido"),
                style: TextButton.styleFrom(
                  foregroundColor: isRead
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodySmall?.color,
                ),
                onPressed: onMarkAsRead,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
