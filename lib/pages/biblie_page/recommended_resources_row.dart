// lib/pages/biblie_page/recommended_resources_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/reducers/library_reference_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
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
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            itemCount: references.length,
            itemBuilder: (context, index) {
              final reference = references[index];

              // <<< CORREÇÃO AQUI: Removemos o FutureBuilder >>>
              // Agora, passamos os dados diretamente para o card, que se tornará Stateful.
              return RecommendedResourceCard(
                contentId: reference.contentId,
                reason: reference.reason,
              );
            },
          ),
        );
      },
    );
  }
}
