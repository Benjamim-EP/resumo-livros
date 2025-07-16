// lib/pages/library_page/sermon_card.dart
import 'package:flutter/material.dart';

class SermonCard extends StatelessWidget {
  final String title;
  final String reference;
  final double progress; // 0.0 a 1.0
  final VoidCallback onTap;

  const SermonCard({
    super.key,
    required this.title,
    required this.reference,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.cardColor.withOpacity(0.9),
      clipBehavior: Clip.antiAlias, // Importante para o Stack
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Conteúdo principal do Card
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(
                16, 12, 16, 16), // Padding inferior maior
            title: Text(
              title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "Referência: $reference",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: theme.iconTheme.color?.withOpacity(0.7)),
            onTap: onTap,
          ),
          // Barra de progresso
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 4.0,
            child: Container(
              color: theme.colorScheme.surfaceVariant
                  .withOpacity(0.3), // Fundo da barra
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: MediaQuery.of(context).size.width *
                      progress, // Largura baseada no progresso
                  height: 4.0,
                  color: theme.colorScheme.primary, // Cor do progresso
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
