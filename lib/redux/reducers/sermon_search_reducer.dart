// lib/redux/reducers/sermon_search_reducer.dart
import 'package:septima_biblia/redux/actions/sermon_search_actions.dart';

class SermonSearchState {
  final bool isLoading;
  final List<Map<String, dynamic>> sermonResults;
  final String? error;
  final String currentSermonQuery;
  // >>> INÍCIO DA NOVA ADIÇÃO <<<
  final List<Map<String, dynamic>>
      searchHistory; // Lista de mapas: {'query': String, 'results': List, 'timestamp': String}
  final bool isLoadingHistory;
  // Não precisamos de 'isProcessingPayment' aqui se a busca de sermões não tiver custo de moedas.
  // Se tiver custo, adicione 'isProcessingPayment' como no BibleSearchState.
  // Pela sua última mensagem, a busca de sermões tem custo, então vamos adicionar.
  final bool isProcessingPayment;
  // >>> FIM DA NOVA ADIÇÃO <<<

  SermonSearchState({
    this.isLoading = false,
    this.sermonResults = const [],
    this.error,
    this.currentSermonQuery = "",
    // >>> INÍCIO DA NOVA ADIÇÃO <<<
    this.searchHistory = const [],
    this.isLoadingHistory = false,
    this.isProcessingPayment = false, // Adicionado
    // >>> FIM DA NOVA ADIÇÃO <<<
  });

  SermonSearchState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? sermonResults,
    String? error,
    String? currentSermonQuery,
    // >>> INÍCIO DA NOVA ADIÇÃO <<<
    List<Map<String, dynamic>>? searchHistory,
    bool? isLoadingHistory,
    bool? isProcessingPayment, // Adicionado
    // >>> FIM DA NOVA ADIÇÃO <<<
    bool clearError = false,
    bool clearResults = false,
  }) {
    return SermonSearchState(
      isLoading: isLoading ?? this.isLoading,
      sermonResults: clearResults ? [] : sermonResults ?? this.sermonResults,
      error: clearError ? null : error ?? this.error,
      currentSermonQuery: currentSermonQuery ?? this.currentSermonQuery,
      // >>> INÍCIO DA NOVA ADIÇÃO <<<
      searchHistory: searchHistory ?? this.searchHistory,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isProcessingPayment:
          isProcessingPayment ?? this.isProcessingPayment, // Adicionado
      // >>> FIM DA NOVA ADIÇÃO <<<
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
      clearResults: true,
      isProcessingPayment: true, // <<< Define ao iniciar busca com custo
    );
  }
  if (action is SearchSermonsSuccessAction) {
    return state.copyWith(
      isLoading: false,
      sermonResults: action.results,
      isProcessingPayment: false, // <<< Limpa ao sucesso
      clearError: true,
    );
  }
  if (action is SearchSermonsFailureAction) {
    return state.copyWith(
      isLoading: false,
      error: action.error,
      isProcessingPayment: false, // <<< Limpa em falha
    );
  }
  if (action is ClearSermonSearchResultsAction) {
    return state.copyWith(
      sermonResults: [],
      currentSermonQuery: "",
      clearError: true,
      // Não limpa isProcessingPayment aqui, pois a busca pode ter sido cancelada antes do pagamento
    );
  }

  // >>> INÍCIO DAS NOVAS LÓGICAS PARA HISTÓRICO DE SERMÕES <<<
  if (action is AddSermonSearchToHistoryAction) {
    // Nova ação específica
    List<Map<String, dynamic>> updatedHistory = List.from(state.searchHistory);
    updatedHistory.removeWhere((item) => item['query'] == action.query);
    updatedHistory.insert(0, {
      'query': action.query,
      'results': action.results,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Limita o histórico a 30 itens
    if (updatedHistory.length > 30) {
      updatedHistory = updatedHistory.sublist(0, 30);
    }
    return state.copyWith(searchHistory: updatedHistory);
  }

  if (action is LoadSermonSearchHistoryAction) {
    // Nova ação específica
    return state.copyWith(isLoadingHistory: true);
  }

  if (action is SermonSearchHistoryLoadedAction) {
    // Nova ação específica
    return state.copyWith(
        searchHistory: action.history, isLoadingHistory: false);
  }

  if (action is ViewSermonSearchFromHistoryAction) {
    // Nova ação específica
    return state.copyWith(
      currentSermonQuery: action.searchEntry['query'] as String,
      sermonResults: List<Map<String, dynamic>>.from(
          action.searchEntry['results'] as List<dynamic>),
      isLoading: false,
      clearError: true,
    );
  }
  // >>> FIM DAS NOVAS LÓGICAS PARA HISTÓRICO DE SERMÕES <<<

  return state;
}
