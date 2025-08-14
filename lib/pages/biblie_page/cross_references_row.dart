// lib/pages/biblie_page/cross_references_row.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/reducers/cross_reference_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/cross_reference_service.dart'; // Apenas para o modal

// Modelo para um resultado de referência
class CrossReference {
  final String ref;
  final int votes;
  CrossReference({required this.ref, required this.votes});
  factory CrossReference.fromJson(Map<String, dynamic> json) => CrossReference(
      ref: json['ref'] as String? ?? '', votes: json['votes'] as int? ?? 0);
}

class CrossReferencesRow extends StatelessWidget {
  final String bookAbbrev;
  final int chapter;
  final int verse;

  const CrossReferencesRow({
    super.key,
    required this.bookAbbrev,
    required this.chapter,
    required this.verse,
  });

  /// Formata 'ex.20.11' para 'Ex 20:11' e lida com ranges.
  String _formatReferenceForDisplay(String rawRef) {
    // Lida com ranges como "jo.1.1-jo.1.3"
    if (rawRef.contains('-')) {
      final parts = rawRef.split('-');
      if (parts.length == 2) {
        final start = _formatSingleReference(parts[0]);
        final end = _formatSingleReference(parts[1]);
        // Se o livro e capítulo forem os mesmos, formata como "João 1:1-3"
        final startParts = start.split(' ');
        final endParts = end.split(' ');
        if (startParts.length > 1 &&
            endParts.length > 1 &&
            startParts[0] == endParts[0]) {
          final startChapterVerse = startParts.sublist(1).join(' ');
          final endChapterVerse = endParts.sublist(1).join(' ');
          if (startChapterVerse.split(':')[0] ==
              endChapterVerse.split(':')[0]) {
            return '${startParts[0]} ${startChapterVerse}-${endChapterVerse.split(':')[1]}';
          }
          return '$start-${endParts.join(' ')}';
        }
        return '$start - $end';
      }
    }
    return _formatSingleReference(rawRef);
  }

  String _formatSingleReference(String rawRef) {
    final parts = rawRef.split('.');
    if (parts.length == 3) {
      final book = parts[0].toUpperCase();
      final chapter = parts[1];
      final verse = parts[2];
      return '$book $chapter:$verse';
    }
    return rawRef; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, CrossReferenceState>(
      converter: (store) => store.state.crossReferenceState,
      builder: (context, state) {
        final String key = "$bookAbbrev.$chapter.$verse";
        if (state.data.isEmpty || !state.data.containsKey(key)) {
          return const SizedBox.shrink();
        }

        final List<CrossReference> references =
            (state.data[key] as List<dynamic>)
                .map((item) => CrossReference.fromJson(item))
                .toList();

        final topReferences = references.take(21).toList();

        return SizedBox(
          height: 30, // Altura fixa para a linha
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20.0),
            itemCount: topReferences.length,
            itemBuilder: (context, index) {
              final ref = topReferences[index];
              final formattedRef = _formatReferenceForDisplay(ref.ref);

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: () {
                    // Reutiliza o serviço antigo apenas para a lógica de UI do modal
                    CrossReferenceService.showVerseInModal(
                        context, formattedRef);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: theme.colorScheme.surface.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    formattedRef,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
