// test/reducers/sermon_search_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/redux/actions/sermon_search_actions.dart';
import 'package:septima_biblia/redux/reducers/sermon_search_reducer.dart';

void main() {
  group('SermonSearchReducer', () {
    // Cenário 1: Início da Busca
    test('deve ativar o loading ao receber SearchSermonsAction', () {
      final initialState =
          SermonSearchState(error: 'Erro antigo', sermonResults: [
        {'id': '1'}
      ]);
      final action = SearchSermonsAction(query: 'pregação sobre fé');

      final newState = sermonSearchReducer(initialState, action);

      expect(newState.isLoading, isTrue);
      expect(newState.isProcessingPayment, isTrue);
      expect(newState.currentSermonQuery, 'pregação sobre fé');
      expect(newState.sermonResults, isEmpty);
      expect(newState.error, isNull);
    });

    // Cenário 2: Sucesso na Busca
    test(
        'deve preencher os resultados e desativar o loading em caso de sucesso',
        () {
      final loadingState =
          SermonSearchState(isLoading: true, isProcessingPayment: true);
      final mockResults = [
        {'sermon_id': 'spurgeon_123'}
      ];
      final action = SearchSermonsSuccessAction(mockResults);

      final newState = sermonSearchReducer(loadingState, action);

      expect(newState.isLoading, isFalse);
      expect(newState.isProcessingPayment, isFalse);
      expect(newState.sermonResults, mockResults);
    });

    // Cenário 3: Falha na Busca
    test('deve registrar o erro e desativar o loading em caso de falha', () {
      final loadingState =
          SermonSearchState(isLoading: true, isProcessingPayment: true);
      final action = SearchSermonsFailureAction('Erro de servidor');

      final newState = sermonSearchReducer(loadingState, action);

      expect(newState.isLoading, isFalse);
      expect(newState.isProcessingPayment, isFalse);
      expect(newState.error, 'Erro de servidor');
      expect(newState.sermonResults, isEmpty);
    });

    // Cenário 4: Limpeza dos Resultados
    test(
        'deve limpar os resultados e a query ao receber ClearSermonSearchResultsAction',
        () {
      final stateWithResults = SermonSearchState(sermonResults: [
        {'id': '1'}
      ], currentSermonQuery: 'fé', error: 'um erro');
      final action = ClearSermonSearchResultsAction();

      final newState = sermonSearchReducer(stateWithResults, action);

      expect(newState.sermonResults, isEmpty);
      expect(newState.currentSermonQuery, isEmpty);
      expect(newState.error, isNull); // Garante que erros também sejam limpos
    });

    // Cenário 5: Histórico (semelhante ao bibleSearchReducer)
    test('deve adicionar uma nova busca ao início do histórico', () {
      final initialState = SermonSearchState(searchHistory: [
        {'query': 'busca antiga'}
      ]);
      final newResults = [
        {'sermon_id': 'spurgeon_123'}
      ];
      final action = AddSermonSearchToHistoryAction(
          query: 'busca nova', results: newResults);

      final newState = sermonSearchReducer(initialState, action);

      expect(newState.searchHistory.length, 2);
      expect(newState.searchHistory.first['query'], 'busca nova');
    });
  });
}
