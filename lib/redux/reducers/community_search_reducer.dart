// lib/redux/reducers/community_search_reducer.dart

import 'package:septima_biblia/redux/actions/community_actions.dart';

class CommunitySearchState {
  final bool isLoading;
  final List<Map<String, dynamic>> results;
  final String? error;
  final String currentQuery;

  CommunitySearchState({
    this.isLoading = false,
    this.results = const [],
    this.error,
    this.currentQuery = "",
  });

  CommunitySearchState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? results,
    String? error,
    String? currentQuery,
    bool clearError = false,
    bool clearResults = false,
  }) {
    return CommunitySearchState(
      isLoading: isLoading ?? this.isLoading,
      results: clearResults ? [] : results ?? this.results,
      error: clearError ? null : error ?? this.error,
      currentQuery: currentQuery ?? this.currentQuery,
    );
  }
}

CommunitySearchState communitySearchReducer(
    CommunitySearchState state, dynamic action) {
  if (action is SearchCommunityPostsAction) {
    return state.copyWith(
        isLoading: true,
        currentQuery: action.query,
        clearError: true,
        clearResults: true);
  }
  if (action is SearchCommunityPostsSuccessAction) {
    return state.copyWith(
        isLoading: false, results: action.results, clearError: true);
  }
  if (action is SearchCommunityPostsFailureAction) {
    return state.copyWith(isLoading: false, error: action.error, results: []);
  }
  if (action is ClearCommunitySearchResultsAction) {
    return CommunitySearchState(); // Reseta para o estado inicial
  }
  return state;
}
