// test/reducers/metadata_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/redux/actions/metadata_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/metadata_reducer.dart';
import 'package:septima_biblia/redux/store.dart'; // Importa para ter acesso ao MetadataState

void main() {
  group('MetadataReducer', () {
    // Cenário 1: Início do Carregamento dos Metadados
    test('deve ativar o loading ao receber LoadBibleSectionCountsAction', () {
      // DADO: um estado inicial (sem loading) e com um erro antigo para garantir que ele seja limpo
      final initialState = MetadataState(
          isLoadingSectionCounts: false, sectionCountsError: 'Erro antigo');
      final action = LoadBibleSectionCountsAction();

      // QUANDO: a ação de carregar é processada
      final newState = metadataReducer(initialState, action);

      // ENTÃO: o loading deve ser true e o erro anterior deve ser limpo
      expect(newState.isLoadingSectionCounts, isTrue);
      expect(newState.sectionCountsError, isNull);
    });

    // Cenário 2: Sucesso no Carregamento dos Metadados
    test('deve preencher os dados e desativar o loading em caso de sucesso',
        () {
      // DADO: um estado de loading
      final loadingState = MetadataState(isLoadingSectionCounts: true);

      // E um mapa de dados mockado, simulando o conteúdo do JSON
      final mockData = {
        'total_secoes_biblia': 1189,
        'livros': {
          'gn': {'total_secoes_livro': 50}
        }
      };
      final action = BibleSectionCountsLoadedAction(mockData);

      // QUANDO: a ação de sucesso é processada
      final newState = metadataReducer(loadingState, action);

      // ENTÃO: o loading deve ser false e os dados devem estar no estado
      expect(newState.isLoadingSectionCounts, isFalse);
      expect(newState.bibleSectionCounts, mockData);
      expect(newState.bibleSectionCounts['total_secoes_biblia'], 1189);
    });

    // Cenário 3 (Bônus): Falha no Carregamento dos Metadados
    test('deve registrar o erro e desativar o loading em caso de falha', () {
      // DADO: um estado de loading
      final loadingState = MetadataState(isLoadingSectionCounts: true);
      final action = BibleSectionCountsFailureAction(
          'Não foi possível ler o arquivo JSON');

      // QUANDO: a ação de falha é processada
      final newState = metadataReducer(loadingState, action);

      // ENTÃO: o loading deve ser false e o erro deve ser registrado
      expect(newState.isLoadingSectionCounts, isFalse);
      expect(
          newState.sectionCountsError, 'Não foi possível ler o arquivo JSON');
      expect(newState.bibleSectionCounts,
          isEmpty); // Garante que os dados permaneçam vazios
    });
  });
}
