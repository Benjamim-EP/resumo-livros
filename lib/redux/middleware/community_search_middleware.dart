// lib/redux/middleware/community_search_middleware.dart

import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions/community_actions.dart';
import 'package:septima_biblia/redux/store.dart';

List<Middleware<AppState>> createCommunitySearchMiddleware() {
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");

  void _handleSearch(Store<AppState> store, SearchCommunityPostsAction action,
      NextDispatcher next) async {
    next(action);
    try {
      final callable = functions.httpsCallable('semanticCommunitySearch');
      final result =
          await callable.call<Map<String, dynamic>>({'query': action.query});

      final dynamic rawResults = result.data['results'];
      final List<Map<String, dynamic>> resultsList = [];

      if (rawResults != null && rawResults is List) {
        for (var item in rawResults) {
          if (item is Map) {
            resultsList.add(Map<String, dynamic>.from(item));
          }
        }
      }

      store.dispatch(SearchCommunityPostsSuccessAction(resultsList));
    } on FirebaseFunctionsException catch (e) {
      store.dispatch(
          SearchCommunityPostsFailureAction(e.message ?? 'Erro na busca.'));
    } catch (e) {
      print(
          "Erro de casting ou inesperado no middleware de busca da comunidade: $e");
      store.dispatch(SearchCommunityPostsFailureAction(
          'Erro inesperado ao processar a resposta.'));
    }
  }

  return [
    TypedMiddleware<AppState, SearchCommunityPostsAction>(_handleSearch),
  ];
}
