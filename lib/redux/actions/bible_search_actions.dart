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
