// lib/redux/middleware/book_search_middleware.dart

import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

List<Middleware<AppState>> createBookSearchMiddleware() {
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");

  // Handler para a ação que inicia a busca
  void _handleSearch(Store<AppState> store,
      SearchBookRecommendationsAction action, NextDispatcher next) async {
    next(action); // Passa a ação para o reducer (que ativa o isLoading)

    try {
      final HttpsCallable callable =
          functions.httpsCallable('semanticBookSearch');
      final HttpsCallableResult result =
          await callable.call<Map<String, dynamic>>({
        'query': action.query,
      });

      // ✅ CORREÇÃO AQUI: Conversão de tipo segura
      final recommendationsData = result.data['recommendations'];
      List<Map<String, dynamic>> recommendations = [];

      if (recommendationsData != null && recommendationsData is List) {
        // Itera sobre a lista e converte cada item para o tipo correto.
        recommendations = recommendationsData
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      store.dispatch(BookRecommendationsLoadedAction(recommendations));
    } on FirebaseFunctionsException catch (e) {
      print(
          "Erro na Cloud Function 'semanticBookSearch': ${e.code} - ${e.message}");
      store.dispatch(BookRecommendationsFailedAction(
          e.message ?? 'Ocorreu um erro no servidor.'));
    } catch (e) {
      print("Erro inesperado ao buscar recomendações: $e");
      store.dispatch(BookRecommendationsFailedAction(
          'Falha na conexão. Tente novamente.'));
    }
  }

  return [
    TypedMiddleware<AppState, SearchBookRecommendationsAction>(_handleSearch),
  ];
}
