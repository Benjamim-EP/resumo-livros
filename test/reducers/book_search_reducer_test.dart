// test/reducers/book_search_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/redux/actions.dart'; // Ações estão em actions.dart
import 'package:septima_biblia/redux/reducers.dart'; // Reducer está em reducers.dart

void main() {
  group('BookSearchReducer', () {
    // Cenário 1: Início da Busca
    test('deve ativar o loading ao receber SearchBookRecommendationsAction',
        () {
      final initialState =
          BookSearchState(error: 'Erro antigo', recommendations: [
        {'book_id': '1'}
      ]);
      final action = SearchBookRecommendationsAction('livros sobre sofrimento');

      final newState = bookSearchReducer(initialState, action);

      expect(newState.isLoading, isTrue);
      expect(newState.currentQuery, 'livros sobre sofrimento');
      expect(newState.recommendations, isEmpty);
      expect(newState.error, isNull);
    });

    // Cenário 2: Sucesso na Busca
    test(
        'deve preencher as recomendações e desativar o loading em caso de sucesso',
        () {
      final loadingState = BookSearchState(isLoading: true);
      final mockResults = [
        {'book_id': 'cs-lewis-dor', 'titulo': 'O Problema da Dor'}
      ];
      final action = BookRecommendationsLoadedAction(mockResults);

      final newState = bookSearchReducer(loadingState, action);

      expect(newState.isLoading, isFalse);
      expect(newState.recommendations, mockResults);
    });

    // Cenário 3: Falha na Busca
    test('deve registrar o erro e desativar o loading em caso de falha', () {
      final loadingState = BookSearchState(isLoading: true);
      final action = BookRecommendationsFailedAction('Falha na API');

      final newState = bookSearchReducer(loadingState, action);

      expect(newState.isLoading, isFalse);
      expect(newState.error, 'Falha na API');
      expect(newState.recommendations, isEmpty);
    });

    // Cenário 4: Limpeza dos Resultados
    test(
        'deve limpar as recomendações e a query ao receber ClearBookRecommendationsAction',
        () {
      final stateWithResults = BookSearchState(recommendations: [
        {'book_id': '1'}
      ], currentQuery: 'sofrimento');
      final action = ClearBookRecommendationsAction();

      final newState = bookSearchReducer(stateWithResults, action);

      // Compara com um estado totalmente novo/limpo
      expect(newState.recommendations, isEmpty);
      expect(newState.currentQuery, isEmpty);
      expect(newState.isLoading, isFalse);
      expect(newState.error, isNull);
    });
  });
}
