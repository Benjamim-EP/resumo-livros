// lib/redux/reducers/sermon_search_reducer.dart
import 'package:resumo_dos_deuses_flutter/redux/actions/sermon_search_actions.dart';

class SermonSearchState {
  final bool isLoading;
  final List<Map<String, dynamic>>
      sermonResults; // Resultados da busca por sermões
  final String? error;
  final String currentSermonQuery;

  SermonSearchState({
    this.isLoading = false,
    this.sermonResults = const [],
    this.error,
    this.currentSermonQuery = "",
  });

  SermonSearchState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? sermonResults,
    String? error,
    String? currentSermonQuery,
    bool clearError = false,
    bool clearResults = false,
  }) {
    return SermonSearchState(
      isLoading: isLoading ?? this.isLoading,
      sermonResults: clearResults ? [] : sermonResults ?? this.sermonResults,
      error: clearError ? null : error ?? this.error,
      currentSermonQuery: currentSermonQuery ?? this.currentSermonQuery,
    );
  }
}

// Reducer para SermonSearchState
SermonSearchState sermonSearchReducer(SermonSearchState state, dynamic action) {
  if (action is SearchSermonsAction) {
    return state.copyWith(
      isLoading: true,
      currentSermonQuery: action.query,
      clearError: true,
      clearResults: true, // Limpa resultados anteriores ao iniciar nova busca
    );
  }
  if (action is SearchSermonsSuccessAction) {
    return state.copyWith(
      isLoading: false,
      sermonResults: action.results,
    );
  }
  if (action is SearchSermonsFailureAction) {
    return state.copyWith(
      isLoading: false,
      error: action.error,
    );
  }
  if (action is ClearSermonSearchResultsAction) {
    return state.copyWith(
      sermonResults: [],
      currentSermonQuery: "",
      clearError: true,
    );
  }
  return state;
}
