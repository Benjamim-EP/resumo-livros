// lib/redux/actions/sermon_search_actions.dart

class SearchSermonsAction {
  final String query;
  // Você pode adicionar filtros aqui no futuro se precisar, ex:
  // final Map<String, dynamic>? filters;
  final int topKSermons;
  final int topKParagraphs;

  SearchSermonsAction({
    required this.query,
    this.topKSermons = 100, // Valor padrão
    this.topKParagraphs = 30, // Valor padrão
    // this.filters,
  });
}

class SearchSermonsSuccessAction {
  final List<Map<String, dynamic>> results; // Lista de sermões agrupados
  SearchSermonsSuccessAction(this.results);
}

class SearchSermonsFailureAction {
  final String error;
  SearchSermonsFailureAction(this.error);
}

// Opcional: Ação para limpar os resultados da busca de sermões
class ClearSermonSearchResultsAction {}
