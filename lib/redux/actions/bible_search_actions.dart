class SearchBibleSemanticAction {
  final String query;
  SearchBibleSemanticAction(this.query);
}

class SetBibleSearchFilterAction {
  final String filterKey;
  final dynamic filterValue; // Pode ser null para limpar
  SetBibleSearchFilterAction(this.filterKey, this.filterValue);
}

class ClearBibleSearchFiltersAction {}

class SearchBibleSemanticSuccessAction {
  final List<Map<String, dynamic>> results;
  SearchBibleSemanticSuccessAction(this.results);
}

class SearchBibleSemanticFailureAction {
  final String error;
  SearchBibleSemanticFailureAction(this.error);
}

class AddSearchToHistoryAction {
  final String query;
  final List<Map<String, dynamic>> results;
  // Não precisa do timestamp aqui, o reducer o adicionará.

  AddSearchToHistoryAction({required this.query, required this.results});
}

class LoadSearchHistoryAction {
  // Esta ação será despachada pela UI (ex: no initState da página de busca)
}

class SearchHistoryLoadedAction {
  final List<Map<String, dynamic>> history;
  SearchHistoryLoadedAction(this.history);
}

// Ação para quando o usuário clica em um item do histórico para visualizar seus resultados
class ViewSearchFromHistoryAction {
  final Map<String, dynamic>
      searchEntry; // Contém 'query' e 'results' do histórico
  ViewSearchFromHistoryAction(this.searchEntry);
}
