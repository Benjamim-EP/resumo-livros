// lib/redux/middleware/bible_search_middleware.dart
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart'; // Seu AppState

// Define a função do middleware diretamente com a assinatura correta.
// Esta função será chamada quando uma SearchBibleSemanticAction for despachada.
void _handleSearchBibleSemantic(Store<AppState> store,
    SearchBibleSemanticAction action, NextDispatcher next) async {
  // 1. Despacha a ação original para o próximo middleware/reducer.
  //    Isso é importante para que o reducer possa, por exemplo,
  //    definir `isLoading = true` e `currentQuery = action.query`.
  next(action);

  try {
    print(
        'BibleSearchMiddleware: Iniciando busca para query="${action.query}" com filtros: ${store.state.bibleSearchState.activeFilters}');

    final functions =
        FirebaseFunctions.instanceFor(region: "southamerica-east1");
    final HttpsCallable callable =
        functions.httpsCallable('semantic_bible_search');

    // Prepara os dados para a Cloud Function
    final requestData = {
      'query': action.query,
      'filters': store.state.bibleSearchState
          .activeFilters, // Pega os filtros atuais do estado
      'topK': 15, // Pode ser configurável ou passado pela ação se necessário
    };

    print(
        'BibleSearchMiddleware: Chamando Cloud Function com dados: $requestData');
    final HttpsCallableResult<dynamic> response =
        await callable.call<Map<String, dynamic>>(requestData);

    // Verifica se 'results' existe e é uma lista
    final dynamic rawResults = response.data?['results'];
    List<Map<String, dynamic>> resultsList = [];

    if (rawResults is List) {
      // Converte cada item para Map<String, dynamic> se possível
      resultsList = rawResults
          .map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String,
                dynamic>{}; // Retorna mapa vazio se o item não for um mapa
          })
          .where((item) => item.isNotEmpty)
          .toList(); // Remove mapas vazios
    } else if (rawResults != null) {
      print(
          'BibleSearchMiddleware: "results" não é uma lista, recebido: ${rawResults.runtimeType}');
    }

    print(
        'BibleSearchMiddleware: Resultados recebidos da Cloud Function: ${resultsList.length} itens.');
    store.dispatch(SearchBibleSemanticSuccessAction(resultsList));
  } catch (e) {
    print(
        "BibleSearchMiddleware: Erro ao chamar a Cloud Function 'semantic_bible_search': $e");
    var errorMessage = "Ocorreu um erro desconhecido durante a busca.";
    if (e is FirebaseFunctionsException) {
      print(
          "BibleSearchMiddleware: Detalhes da FirebaseFunctionsException: code=${e.code}, message=${e.message}, details=${e.details}");
      // Tenta usar a mensagem da exceção se disponível, senão uma mensagem genérica.
      errorMessage =
          "Erro na busca (${e.code}): ${e.message ?? 'Falha ao contatar o servidor.'}";
    } else {
      // Para outros tipos de exceção, usa a mensagem da exceção.
      errorMessage = e.toString();
    }
    store.dispatch(SearchBibleSemanticFailureAction(errorMessage));
  }
}

// Função que cria e retorna a lista de middlewares para a busca bíblica.
List<Middleware<AppState>> createBibleSearchMiddleware() {
  return [
    // TypedMiddleware intercepta ações do tipo SearchBibleSemanticAction
    // e chama _handleSearchBibleSemantic com os argumentos corretos.
    TypedMiddleware<AppState, SearchBibleSemanticAction>(
        _handleSearchBibleSemantic),
    // Você pode adicionar outros TypedMiddlewares aqui para outras ações de busca bíblica se necessário.
  ];
}
