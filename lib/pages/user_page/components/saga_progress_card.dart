// lib/pages/user_page/components/saga_progress_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/models/bible_saga_model.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

class SagaProgressCard extends StatelessWidget {
  final BibleSaga saga;

  const SagaProgressCard({super.key, required this.saga});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, Set<String>>(
      // Conecta-se a todas as seções lidas de todos os livros
      converter: (store) {
        final allReadSections = <String>{};
        store.state.userState.readSectionsByBook.values.forEach((sections) {
          allReadSections.addAll(sections);
        });
        return allReadSections;
      },
      builder: (context, allReadSections) {
        // Lógica para calcular o progresso
        final sagaSectionsSet = Set<String>.from(saga.sections);
        final readSectionsInSaga =
            allReadSections.intersection(sagaSectionsSet);
        final double progress = (saga.sections.isNotEmpty)
            ? (readSectionsInSaga.length / saga.sections.length).clamp(0.0, 1.0)
            : 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          child: InkWell(
            onTap: () {
              final String bookAbbrev = saga.startReference['bookAbbrev'];
              final int chapter = saga.startReference['chapter'];

              // Despacha a ação para navegar para o início da saga
              StoreProvider.of<AppState>(context, listen: false)
                  .dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
              StoreProvider.of<AppState>(context, listen: false).dispatch(
                  RequestBottomNavChangeAction(2)); // Vai para a aba Bíblia
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(saga.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    saga.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "${(progress * 100).toStringAsFixed(0)}%",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
