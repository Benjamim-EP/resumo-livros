// lib/pages/user_page/components/saga_progress_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/consts/bible_constants.dart'; // Para o mapa de nomes de livros
import 'package:septima_biblia/consts/saga_covers.dart'; // ✅ Importa nosso novo mapa de capas
import 'package:septima_biblia/models/bible_saga_model.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

class SagaProgressCard extends StatelessWidget {
  final BibleSaga saga;

  const SagaProgressCard({super.key, required this.saga});

  // Função auxiliar para gerar a string de referência (ex: "Juízes 13-16")
  String _getSagaReferenceString(BibleSaga saga) {
    if (saga.sections.isEmpty) return "N/A";

    final String firstSectionId = saga.sections.first;
    final String lastSectionId = saga.sections.last;

    final startParts = firstSectionId.split('_'); // ex: ['jz', 'c13', 'v1-7']
    final endParts = lastSectionId.split('_'); // ex: ['jz', 'c16', 'v28-31']

    if (startParts.length < 2 || endParts.length < 2) return "N/A";

    final String startBookAbbrev = startParts[0];
    final String endBookAbbrev = endParts[0];
    final String startChapter = startParts[1].replaceAll('c', '');
    final String endChapter = endParts[1].replaceAll('c', '');

    final String startBookName = ABBREV_TO_FULL_NAME_MAP[startBookAbbrev] ??
        startBookAbbrev.toUpperCase();

    // Se a saga se passa em um único livro
    if (startBookAbbrev == endBookAbbrev) {
      // Se for no mesmo capítulo
      if (startChapter == endChapter) {
        return "$startBookName $startChapter";
      }
      // Se for em capítulos diferentes
      return "$startBookName $startChapter-$endChapter";
    }

    // Se a saga abrange múltiplos livros
    final String endBookName =
        ABBREV_TO_FULL_NAME_MAP[endBookAbbrev] ?? endBookAbbrev.toUpperCase();
    return "$startBookName $startChapter - $endBookName $endChapter";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String coverFileName = sagaCoversMap[saga.id] ?? '';
    final String coverPath =
        coverFileName.isNotEmpty ? 'assets/covers/sagas/$coverFileName' : '';
    final String referenceString = _getSagaReferenceString(saga);

    return StoreConnector<AppState, Set<String>>(
      converter: (store) {
        final allReadSections = <String>{};
        store.state.userState.readSectionsByBook.values.forEach((sections) {
          allReadSections.addAll(sections);
        });
        return allReadSections;
      },
      builder: (context, allReadSections) {
        final sagaSectionsSet = Set<String>.from(saga.sections);
        final readSectionsInSaga =
            allReadSections.intersection(sagaSectionsSet);
        final double progress = (saga.sections.isNotEmpty)
            ? (readSectionsInSaga.length / saga.sections.length).clamp(0.0, 1.0)
            : 0.0;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              final String bookAbbrev = saga.startReference['bookAbbrev'];
              final int chapter = saga.startReference['chapter'];

              StoreProvider.of<AppState>(context, listen: false)
                  .dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
              StoreProvider.of<AppState>(context, listen: false)
                  .dispatch(RequestBottomNavChangeAction(2));
            },
            child: SizedBox(
              height: 120, // Altura fixa para o card
              child: Row(
                children: [
                  // Imagem da Capa
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: coverPath.isNotEmpty
                          ? Image.asset(coverPath, fit: BoxFit.cover)
                          : const Icon(Icons.book_outlined),
                    ),
                  ),

                  // Conteúdo (Título, Descrição, Progresso)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(saga.title,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            referenceString, // ✅ Exibe a referência (Ex: Juízes 13-16)
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.primary),
                          ),
                          const Spacer(), // Empurra a barra de progresso para baixo
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                  backgroundColor: theme
                                      .colorScheme.surfaceVariant
                                      .withOpacity(0.5),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
