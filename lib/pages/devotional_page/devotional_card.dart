// lib/pages/devotional_page/devotional_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/devotional_model.dart';
import 'package:septima_biblia/utils/text_span_utils.dart';

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
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead
              ? theme.colorScheme.primary.withOpacity(0.6)
              : theme.dividerColor
                  .withOpacity(0.2), // Borda sutil quando não lido
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias, // Necessário para o ExpansionTile
      child: ExpansionTile(
        key: PageStorageKey(
            reading.title), // Ajuda a manter o estado de expansão
        // >>> CABEÇALHO DO CARD (O QUE FICA SEMPRE VISÍVEL) <<<
        title: Row(
          children: [
            Icon(
              isMorning ? Icons.wb_sunny_outlined : Icons.nightlight_round,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reading.title,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleMedium?.color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            reading.scriptureVerse,
            style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.volume_up_outlined),
          tooltip: "Ouvir Devocional",
          onPressed: onPlay,
        ),
        backgroundColor: theme.cardColor.withOpacity(0.5),
        collapsedBackgroundColor: theme.cardColor.withOpacity(0.8),
        iconColor: theme.colorScheme.secondary,
        collapsedIconColor: theme.colorScheme.secondary.withOpacity(0.7),

        // >>> CONTEÚDO EXPANSÍVEL DO CARD <<<
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 16),

                // Referência completa
                Text(
                  "Referência: ${reading.scripturePassage}",
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),

                // Conteúdo do Devocional
                ...reading.content.map((paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: RichText(
                        textAlign: TextAlign.justify,
                        text: TextSpan(
                          style:
                              theme.textTheme.bodyMedium?.copyWith(height: 1.6),
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
                      color: isRead
                          ? theme.colorScheme.primary
                          : theme.disabledColor,
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
          )
        ],
      ),
    );
  }
}
