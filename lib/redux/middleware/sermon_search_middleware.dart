// lib/redux/middleware/sermon_search_middleware.dart
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions/sermon_search_actions.dart'; // Suas ações de busca de sermões
import 'package:septima_biblia/redux/store.dart'; // Para AppState
// Não é necessário importar FirestoreService ou OpenAIService aqui, pois a Cloud Function faz o trabalho pesado.

List<Middleware<AppState>> createSermonSearchMiddleware() {
  final FirebaseFunctions functions =
      FirebaseFunctions.instanceFor(region: "southamerica-east1");

  // Handler para a ação de buscar sermões
  void _handleSearchSermons(
    Store<AppState> store,
    SearchSermonsAction action,
    NextDispatcher next,
  ) async {
    // Passa a ação para o reducer (para atualizar isLoading, currentQuery, etc.)
    next(action);

    // Verificar se o usuário está logado (se a busca for restrita)
    // if (store.state.userState.userId == null) {
    //   store.dispatch(SearchSermonsFailureAction("Usuário não autenticado."));
    //   return;
    // }
    // Adicione lógica de custo de moedas aqui se aplicável para busca de sermões,
    // similar ao BibleSearchMiddleware. Por enquanto, vamos assumir que é gratuita.

    try {
      print(
          'SermonSearchMiddleware: Iniciando busca por sermões com query="${action.query}", topKSermons=${action.topKSermons}, topKParagraphs=${action.topKParagraphs}');

      final HttpsCallable callable =
          functions.httpsCallable('semantic_sermon_search');

      final requestData = {
        'query': action.query,
        'topKSermons': action.topKSermons,
        'topKParagraphs': action.topKParagraphs,
        // 'filters': action.filters, // Adicionar se você implementar filtros
      };

      print(
          'SermonSearchMiddleware: Chamando Cloud Function "semantic_sermon_search" com dados: $requestData');
      final HttpsCallableResult<dynamic> response =
          await callable.call<Map<String, dynamic>>(requestData);

      final dynamic rawResults = response
          .data?['sermons']; // A Cloud Function retorna {"sermons": [...]}
      List<Map<String, dynamic>> resultsList = [];

      if (rawResults is List) {
        resultsList = rawResults
            .map((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              }
              return <String, dynamic>{}; // Item inválido
            })
            .where((item) => item.isNotEmpty)
            .toList();
      } else if (rawResults != null) {
        print(
            'SermonSearchMiddleware: "sermons" não é uma lista, recebido: ${rawResults.runtimeType}');
      }

      print(
          'SermonSearchMiddleware: Resultados de sermões recebidos: ${resultsList.length} itens.');
      store.dispatch(SearchSermonsSuccessAction(resultsList));
    } on FirebaseFunctionsException catch (e) {
      print(
          "SermonSearchMiddleware: Erro FirebaseFunctionsException ao chamar 'semantic_sermon_search': ${e.code} - ${e.message} - Details: ${e.details}");
      store.dispatch(SearchSermonsFailureAction(
          "Erro na busca por sermões (${e.code}): ${e.message ?? 'Falha ao contatar o servidor.'}"));
    } catch (e) {
      print("SermonSearchMiddleware: Erro inesperado ao buscar sermões: $e");
      store.dispatch(SearchSermonsFailureAction(
          "Ocorreu um erro desconhecido durante a busca por sermões."));
    }
  }

  return [
    TypedMiddleware<AppState, SearchSermonsAction>(_handleSearchSermons).call,
  ];
}
