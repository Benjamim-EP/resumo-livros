// lib/pages/biblie_page/bible_semantic_search_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/redux/actions.dart';

class BibleSemanticSearchView extends StatefulWidget {
  // Callbacks para interagir com o estado da BiblePage
  final Function(Map<String, dynamic> metadata, String itemId)
      onToggleItemExpansion;
  final Function(String bookAbbrev, int chapter) onNavigateToVerse;

  // Estado atual da UI da BiblePage
  final String? expandedItemId;
  final bool isLoadingExpandedContent;
  final String? loadedExpandedContent;
  final double fontSizeMultiplier;

  const BibleSemanticSearchView({
    super.key,
    required this.onToggleItemExpansion,
    required this.onNavigateToVerse,
    this.expandedItemId,
    required this.isLoadingExpandedContent,
    this.loadedExpandedContent,
    required this.fontSizeMultiplier,
  });

  @override
  State<BibleSemanticSearchView> createState() =>
      _BibleSemanticSearchViewState();
}

class _BibleSemanticSearchViewState extends State<BibleSemanticSearchView> {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, BibleSearchState>(
      converter: (store) => store.state.bibleSearchState,
      distinct: true,
      onInit: (store) {
        if (store.state.bibleSearchState.searchHistory.isEmpty &&
            !store.state.bibleSearchState.isLoadingHistory) {
          store.dispatch(LoadSearchHistoryAction());
        }
      },
      builder: (context, searchState) {
        final theme = Theme.of(context);

        // 1. Loading de uma nova busca
        if (searchState.isLoading && searchState.currentQuery.isNotEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Erro na busca
        if (!searchState.isLoading && searchState.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Erro na busca: ${searchState.error}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          );
        }

        // 3. Exibir resultados da busca
        if (searchState.results.isNotEmpty) {
          return _buildResultsList(theme, searchState.results);
        }

        // 4. Exibir histórico se não houver busca ativa
        if (searchState.currentQuery.isEmpty &&
            searchState.searchHistory.isNotEmpty) {
          return _buildHistoryList(theme, searchState.searchHistory);
        }

        // 5. Nenhum resultado para a busca ativa
        if (!searchState.isLoading &&
            searchState.results.isEmpty &&
            searchState.currentQuery.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Nenhum resultado encontrado para '${searchState.currentQuery}' com os filtros aplicados.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          );
        }

        // 6. Mensagem padrão (inicial ou sem histórico)
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              searchState.isLoadingHistory
                  ? "Carregando histórico..."
                  : "Digite sua busca acima e pressione o ícone de lupa para pesquisar. Seu histórico aparecerá aqui.",
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsList(
      ThemeData theme, List<Map<String, dynamic>> results) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        final itemId = item['id'] as String? ?? 'unknown_id_$index';
        Map<String, dynamic> metadata = {};
        final rawMetadata = item['metadata'];
        if (rawMetadata is Map) {
          metadata = Map<String, dynamic>.from(
              rawMetadata.map((key, value) => MapEntry(key.toString(), value)));
        }

        final tipoResultado = metadata['tipo'] as String?;
        String? commentaryTitle = metadata['titulo_comentario'] as String?;
        final reference =
            "${metadata['livro_completo'] ?? metadata['livro_curto'] ?? '?'} ${metadata['capitulo'] ?? '?'}:${metadata['versiculos'] ?? '?'}";
        final score = item['score'] as double?;
        final bool isExpanded = widget.expandedItemId == itemId;

        String previewContent = "Toque para ver detalhes";
        if (tipoResultado == 'biblia_comentario_secao') {
          previewContent = commentaryTitle ?? "Ver comentário...";
        } else if (tipoResultado == 'biblia_versiculos') {
          previewContent = "Ver versículos...";
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          color: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(reference,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color)),
                subtitle: Text(previewContent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.7))),
                trailing: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.iconTheme.color),
                onTap: () => widget.onToggleItemExpansion(metadata, itemId),
              ),
              if (isExpanded)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Container(
                    width: double.infinity,
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: widget.isLoadingExpandedContent
                        ? const Center(
                            child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5))))
                        : (widget.loadedExpandedContent != null &&
                                widget.loadedExpandedContent!.isNotEmpty
                            ? MarkdownBody(
                                data: widget.loadedExpandedContent!,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                    .copyWith(
                                  p: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: 14 * widget.fontSizeMultiplier,
                                      height: 1.5,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                  strong: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                  blockSpacing: 8.0,
                                ),
                              )
                            : Text(
                                "Conteúdo não disponível ou não pôde ser carregado.",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.7)))),
                  ),
                ),
              if (isExpanded && !widget.isLoadingExpandedContent)
                Padding(
                  padding:
                      const EdgeInsets.only(right: 8.0, top: 4.0, bottom: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(Icons.menu_book,
                          size: 18, color: theme.colorScheme.primary),
                      label: Text("Abrir na Bíblia",
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final bookAbbrevNav =
                            metadata['livro_curto'] as String?;
                        final chapterStrNav = metadata['capitulo']?.toString();
                        int? chapterIntNav;
                        if (chapterStrNav != null)
                          chapterIntNav = int.tryParse(chapterStrNav);

                        if (bookAbbrevNav != null && chapterIntNav != null) {
                          widget.onNavigateToVerse(
                              bookAbbrevNav, chapterIntNav);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Não foi possível abrir na Bíblia. Dados incompletos.')));
                        }
                      },
                    ),
                  ),
                ),
              if (score != null && !isExpanded)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16.0, bottom: 8.0, top: 0),
                  child: Text("Similaridade: ${score.toStringAsFixed(3)}",
                      style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(
      ThemeData theme, List<Map<String, dynamic>> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text("Histórico de Buscas Recentes:",
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.9))),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final historyEntry = history[index];
              final String query =
                  historyEntry['query'] as String? ?? 'Busca inválida';
              final String? timestampStr = historyEntry['timestamp'] as String?;
              final DateTime? timestamp =
                  timestampStr != null ? DateTime.tryParse(timestampStr) : null;

              return ListTile(
                leading: Icon(Icons.history,
                    color: theme.iconTheme.color?.withOpacity(0.6)),
                title: Text(query, style: theme.textTheme.bodyLarge),
                subtitle: timestamp != null
                    ? Text(
                        DateFormat('dd/MM/yy HH:mm')
                            .format(timestamp.toLocal()),
                        style: theme.textTheme.bodySmall)
                    : null,
                trailing: Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: theme.iconTheme.color?.withOpacity(0.5)),
                onTap: () {
                  // Preenche o campo de busca e despacha a ação para visualizar o histórico
                  StoreProvider.of<AppState>(context, listen: false)
                      .dispatch(ViewSearchFromHistoryAction(historyEntry));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
