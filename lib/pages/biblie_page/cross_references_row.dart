// lib/pages/biblie_page/cross_references_row.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/reducers/cross_reference_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/cross_reference_service.dart';

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

  String _reverseFormatReferenceForFetching(String displayRef) {
    // A verificação é case-insensitive para garantir que funcione sempre.
    if (displayRef.toLowerCase().startsWith('jó ')) {
      // Substitui a primeira ocorrência de 'JÓ' (ignorando o caso) por 'Job'.
      return displayRef.replaceFirst(
          RegExp(r'^jó', caseSensitive: false), 'Job');
    }
    // Se não for 'JÓ', retorna a referência como está.
    return displayRef;
  }

  // ==========================================================
  // <<< INÍCIO DA MODIFICAÇÃO 1/3: MAPA DE TRADUÇÃO >>>
  // ==========================================================
  // Este mapa corrige as abreviações da fonte de dados para o padrão de exibição do seu app.
  static const Map<String, String> _displayAbbreviationMap = {
    'job': 'job',
    // Adicione outras correções aqui se necessário no futuro. Ex:
    // '1sam': '1Sm',
  };
  // ==========================================================
  // <<< FIM DA MODIFICAÇÃO 1/3 >>>
  // ==========================================================

  /// Formata 'ex.20.11' para 'EX 20:11' e lida com ranges.
  String _formatReferenceForDisplay(String rawRef) {
    // Lida com ranges como "jo.1.1-jo.1.3"
    if (rawRef.contains('-')) {
      final parts = rawRef.split('-');
      if (parts.length == 2) {
        final start = _formatSingleReference(parts[0]);
        final end = _formatSingleReference(parts[1]);
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

  // ==========================================================
  // <<< INÍCIO DA MODIFICAÇÃO 2/3: FUNÇÃO DE FORMATAÇÃO ATUALIZADA >>>
  // ==========================================================
  String _formatSingleReference(String rawRef) {
    final parts = rawRef.split('.');
    if (parts.length == 3) {
      final rawBookAbbrev = parts[0]; // Ex: 'job'
      final chapter = parts[1];
      final verse = parts[2];

      // A MÁGICA ACONTECE AQUI:
      // 1. Procura 'job' no nosso mapa de tradução.
      // 2. Se encontrar, usa o valor ('jó').
      // 3. Se não encontrar, usa o valor original (rawBookAbbrev).
      // 4. Converte o resultado para maiúsculas.
      final displayAbbrev =
          (_displayAbbreviationMap[rawBookAbbrev] ?? rawBookAbbrev)
              .toUpperCase();

      return '$displayAbbrev $chapter:$verse';
    }
    return rawRef; // Fallback
  }
  // ==========================================================
  // <<< FIM DA MODIFICAÇÃO 2/3 >>>
  // ==========================================================

  // (O resto do arquivo permanece o mesmo, incluindo o método build e o modal)

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

        final List<CrossReference> allReferences =
            (state.data[key] as List<dynamic>)
                .map((item) => CrossReference.fromJson(item))
                .toList();

        const int displayLimit = 7; // Voltado para 7 conforme o original
        final bool hasMore = allReferences.length > displayLimit;
        final topReferences = allReferences.take(displayLimit).toList();

        List<Widget> referenceWidgets = topReferences.map((ref) {
          final formattedRef = _formatReferenceForDisplay(ref.ref);
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              // ==========================================================
              // <<< A CORREÇÃO ESTÁ AQUI DENTRO >>>
              // ==========================================================
              onPressed: () {
                // 1. Pega a referência formatada para exibição (ex: "JÓ 1:1")
                final displayReference = _formatReferenceForDisplay(ref.ref);

                // 2. USA A NOVA FUNÇÃO PARA TRADUZIR DE VOLTA (ex: "Job 1:1")
                final fetchableReference =
                    _reverseFormatReferenceForFetching(displayReference);

                // 3. Chama o serviço com a referência corrigida e sem ambiguidade
                CrossReferenceService.showVerseInModal(
                    context, fetchableReference);
              },
              // ==========================================================
              // <<< FIM DA CORREÇÃO >>>
              // ==========================================================
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: theme.colorScheme.surface.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                formattedRef, // A UI continua mostrando "JÓ 1:1"
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          );
        }).toList();

        if (hasMore) {
          referenceWidgets.add(
            Padding(
              // Corrigido para adicionar Padding
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: () =>
                    _showAllReferencesModal(context, allReferences),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  "[+${allReferences.length - displayLimit}]",
                  style:
                      TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20.0),
            children: referenceWidgets,
          ),
        );
      },
    );
  }

  // O método _showAllReferencesModal permanece o mesmo
  void _showAllReferencesModal(
      BuildContext context, List<CrossReference> allReferences) {
    // ... (seu código para o modal continua aqui, sem alterações)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    "Todas as Referências",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: allReferences.length,
                      itemBuilder: (ctx, index) {
                        final ref = allReferences[index];
                        final formattedRef =
                            _formatReferenceForDisplay(ref.ref);
                        return ListTile(
                          title: Text(formattedRef),
                          trailing: Text("Votos: ${ref.votes}",
                              style: Theme.of(context).textTheme.bodySmall),
                          onTap: () {
                            Navigator.pop(modalContext);
                            CrossReferenceService.showVerseInModal(
                                context, formattedRef);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
