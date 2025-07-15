// test/reducers/bible_search_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';

void main() {
  group('BibleSearchReducer', () {
    // Cenário 1: Início da Busca
    test('deve ativar o estado de loading ao receber SearchBibleSemanticAction',
        () {
      // DADO: um estado inicial e uma busca anterior com erro
      final initialState = BibleSearchState(results: [
        {'id': 'resultado_antigo'}
      ], error: 'Erro antigo');
      final action = SearchBibleSemanticAction('graça de Deus');

      // QUANDO: a ação de busca é processada
      final newState = bibleSearchReducer(initialState, action);

      // ENTÃO: o estado deve ser resetado e o loading ativado
      expect(newState.isLoading, isTrue);
      expect(newState.currentQuery, 'graça de Deus');
      expect(newState.results, isEmpty); // Resultados antigos devem ser limpos
      expect(newState.error, isNull); // Erros antigos devem ser limpos
      expect(newState.isProcessingPayment,
          isTrue); // Verifica se o custo está sendo processado
    });

    // Cenário 2: Sucesso na Busca
    test(
        'deve preencher os resultados e desativar o loading em caso de sucesso',
        () {
      // DADO: um estado de loading
      final loadingState =
          BibleSearchState(isLoading: true, isProcessingPayment: true);
      final mockResults = [
        {'id': 'gn_1_1', 'score': 0.9}
      ];
      final action = SearchBibleSemanticSuccessAction(mockResults);

      // QUANDO: a ação de sucesso é processada
      final newState = bibleSearchReducer(loadingState, action);

      // ENTÃO: o estado deve refletir o sucesso da busca
      expect(newState.isLoading, isFalse);
      expect(newState.isProcessingPayment, isFalse);
      expect(newState.results, mockResults);
      expect(newState.error, isNull);
    });

    // Cenário 3: Falha na Busca
    test('deve registrar o erro e desativar o loading em caso de falha', () {
      // DADO: um estado de loading
      final loadingState =
          BibleSearchState(isLoading: true, isProcessingPayment: true);
      final action = SearchBibleSemanticFailureAction('Erro de rede');

      // QUANDO: a ação de falha é processada
      final newState = bibleSearchReducer(loadingState, action);

      // ENTÃO: o estado deve refletir a falha
      expect(newState.isLoading, isFalse);
      expect(newState.isProcessingPayment, isFalse);
      expect(newState.error, 'Erro de rede');
      expect(newState.results, isEmpty);
    });

    // Cenário 4: Aplicando e Limpando Filtros
    group('Filtros', () {
      test('deve adicionar um filtro ao estado com SetBibleSearchFilterAction',
          () {
        // DADO: um estado inicial sem filtros
        final initialState = BibleSearchState();
        final action = SetBibleSearchFilterAction('testamento', 'Novo');

        // QUANDO: a ação de definir filtro é processada
        final newState = bibleSearchReducer(initialState, action);

        // ENTÃO: o filtro deve estar no mapa activeFilters
        expect(newState.activeFilters, {'testamento': 'Novo'});
      });

      test('deve remover um filtro se o valor for nulo', () {
        // DADO: um estado com um filtro ativo
        final stateWithFilter =
            BibleSearchState(activeFilters: {'testamento': 'Novo'});
        final action = SetBibleSearchFilterAction('testamento', null);

        // QUANDO: a ação de definir filtro é processada com valor nulo
        final newState = bibleSearchReducer(stateWithFilter, action);

        // ENTÃO: o mapa de filtros deve ficar vazio
        expect(newState.activeFilters, isEmpty);
      });

      test(
          'deve limpar todos os filtros ao receber ClearBibleSearchFiltersAction',
          () {
        // DADO: um estado com múltiplos filtros
        final stateWithFilters = BibleSearchState(
          activeFilters: {'testamento': 'Novo', 'tipo': 'biblia_versiculos'},
        );
        final action = ClearBibleSearchFiltersAction();

        // QUANDO: a ação de limpar filtros é processada
        final newState = bibleSearchReducer(stateWithFilters, action);

        // ENTÃO: o mapa de filtros deve estar vazio
        expect(newState.activeFilters, isEmpty);
      });
    });

    // Cenário 5: Adicionando ao Histórico
    test('deve adicionar uma nova busca ao início do histórico', () {
      // DADO: um estado com um histórico existente
      final initialState = BibleSearchState(
        searchHistory: [
          {
            'query': 'busca antiga',
            'results': [],
            'timestamp': DateTime.now().toIso8601String()
          }
        ],
      );
      final newResults = [
        {'id': 'gn_1_1'}
      ];
      final action =
          AddSearchToHistoryAction(query: 'busca nova', results: newResults);

      // QUANDO: a ação de adicionar ao histórico é processada
      final newState = bibleSearchReducer(initialState, action);

      // ENTÃO: o histórico deve ter 2 itens, com a nova busca no início
      expect(newState.searchHistory.length, 2);
      expect(newState.searchHistory.first['query'], 'busca nova');
      expect(newState.searchHistory.first['results'], newResults);
    });

    test('deve substituir uma busca antiga com a mesma query no histórico', () {
      // DADO: um estado com uma busca pela query 'graça'
      final initialState = BibleSearchState(
        searchHistory: [
          {
            'query': 'graça',
            'results': [
              {'id': 'result1'}
            ],
            'timestamp': '2023-01-01T12:00:00.000Z'
          }
        ],
      );
      final newResultsForSameQuery = [
        {'id': 'result2'}
      ];
      final action = AddSearchToHistoryAction(
          query: 'graça', results: newResultsForSameQuery);

      // QUANDO: a mesma query é adicionada novamente
      final newState = bibleSearchReducer(initialState, action);

      // ENTÃO: o histórico ainda deve ter 1 item, mas com os novos resultados
      expect(newState.searchHistory.length, 1);
      expect(newState.searchHistory.first['results'], newResultsForSameQuery);
    });
  });
}
