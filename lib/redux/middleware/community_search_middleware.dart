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
      final resultsList =
          List<Map<String, dynamic>>.from(result.data['results'] ?? []);
      store.dispatch(SearchCommunityPostsSuccessAction(resultsList));
    } on FirebaseFunctionsException catch (e) {
      store.dispatch(
          SearchCommunityPostsFailureAction(e.message ?? 'Erro na busca.'));
    } catch (e) {
      store.dispatch(SearchCommunityPostsFailureAction('Erro inesperado.'));
    }
  }

  return [
    TypedMiddleware<AppState, SearchCommunityPostsAction>(_handleSearch),
  ];
}
