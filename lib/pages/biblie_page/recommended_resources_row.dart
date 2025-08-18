// lib/pages/biblie_page/recommended_resources_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/reducers/library_reference_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/library_content_service.dart';
import 'package:septima_biblia/pages/biblie_page/recommended_resource_card.dart';

class RecommendedResourcesRow extends StatelessWidget {
  final String sectionId;
  const RecommendedResourcesRow({super.key, required this.sectionId});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, List<LibraryReference>>(
      converter: (store) =>
          store.state.libraryReferenceState.referencesBySection[sectionId] ??
          [],
      builder: (context, references) {
        if (references.isEmpty) {
          // Se não houver referências, não mostra nada
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 140, // Altura fixa para a linha horizontal
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0, top: 8.0),
            itemCount: references.length,
            itemBuilder: (context, index) {
              final reference = references[index];
              final contentUnit = LibraryContentService.instance
                  .getContentUnit(reference.contentId);

              if (contentUnit == null) {
                // Caso o conteúdo não seja encontrado no mapa local
                return const SizedBox.shrink();
              }

              return RecommendedResourceCard(
                contentUnit: contentUnit,
                reason: reference.reason,
              );
            },
          ),
        );
      },
    );
  }
}
