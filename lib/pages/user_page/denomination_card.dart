// lib/pages/user_page/denomination_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';

class DenominationCard extends StatelessWidget {
  const DenominationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, String?>(
      // O converter agora foca apenas na denominação
      converter: (store) =>
          store.state.userState.userDetails?['denomination'] as String?,
      builder: (context, denomination) {
        // Se não houver denominação, o widget não ocupa espaço
        if (denomination == null || denomination.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 16.0), // Espaçamento acima
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Faz a Row se ajustar ao conteúdo
            children: [
              Icon(
                Icons.church_outlined,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                // Usa Flexible para o texto não estourar a tela
                child: Text(
                  denomination,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
