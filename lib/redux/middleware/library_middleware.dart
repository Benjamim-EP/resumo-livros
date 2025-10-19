import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/library_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

List<Middleware<AppState>> createLibraryMiddleware() {
  final firestoreService = FirestoreService();
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");

  void _loadShelves(Store<AppState> store, LoadLibraryShelvesAction action,
      NextDispatcher next) async {
    next(action);
    try {
      final curatedShelvesFuture = firestoreService.fetchLibraryShelves();
      final recommendedShelfFuture = _fetchRecommendedShelf(functions);
      final results =
          await Future.wait([curatedShelvesFuture, recommendedShelfFuture]);
      final List<Map<String, dynamic>> curatedShelves =
          results[0] as List<Map<String, dynamic>>;
      final Map<String, dynamic>? recommendedShelf =
          results[1] as Map<String, dynamic>?;
      List<Map<String, dynamic>> allShelves = [];
      if (recommendedShelf != null &&
          (recommendedShelf['items'] as List).isNotEmpty) {
        allShelves.add(recommendedShelf);
      }
      allShelves.addAll(curatedShelves);
      allShelves.sort((a, b) =>
          (a['order'] as int? ?? 99).compareTo(b['order'] as int? ?? 99));
      store.dispatch(LibraryShelvesLoadedAction(allShelves));
    } catch (e) {
      print("LibraryMiddleware: Erro ao carregar prateleiras: $e");
      store.dispatch(LibraryShelvesFailedAction(e.toString()));
    }
  }

  void _fetchSermons(Store<AppState> store,
      FetchRecommendedSermonsAction action, NextDispatcher next) async {
    next(action);
    // if (store.state.userState.recommendedSermons.isNotEmpty) {
    //   return;
    // }
    final userId = store.state.userState.userId;
    if (userId == null || (store.state.userState.learningGoal ?? '').isEmpty) {
      return;
    }
    try {
      final callable =
          functions.httpsCallable('getSermonRecommendationsForUser');
      final result = await callable.call<Map<String, dynamic>>({});
      // 1. Recebe a lista como 'dynamic' para evitar erros de tipo iniciais.
      final dynamic rawRecommendations = result.data['recommendations'];
      final List<Map<String, dynamic>> recommendations =
          []; // Inicializa uma lista vazia do tipo correto.

      // 2. Verifica se a resposta é de fato uma lista antes de iterar.
      if (rawRecommendations != null && rawRecommendations is List) {
        // 3. Itera sobre a lista dinâmica e converte cada item para o tipo desejado.
        recommendations.addAll(rawRecommendations
            .map((item) => Map<String, dynamic>.from(item as Map)));
      }
      store.dispatch(RecommendedSermonsLoadedAction(recommendations));
    } catch (e) {
      print("ERRO no LibraryMiddleware ao buscar sermões: $e");
      store.dispatch(RecommendedSermonsLoadedAction([]));
    }
  }

  return [
    TypedMiddleware<AppState, LoadLibraryShelvesAction>(_loadShelves).call,
    TypedMiddleware<AppState, FetchRecommendedSermonsAction>(_fetchSermons)
        .call,
  ];
}

Future<Map<String, dynamic>?> _fetchRecommendedShelf(
    FirebaseFunctions functions) async {
  try {
    final callable = functions.httpsCallable('recommendLibraryBooks');
    final result = await callable.call<Map<String, dynamic>>({});
    final recommendations =
        result.data['recommendations'] as List<dynamic>? ?? [];

    if (recommendations.isNotEmpty) {
      // <<< INÍCIO DA CORREÇÃO DE ROBUSTEZ >>>
      final List<String> sanitizedBookIds = recommendations.map((item) {
        final aiBookId = item['bookId'] as String? ?? '';

        // 1. Tenta uma correspondência exata primeiro (o caso ideal)
        if (allLibraryItems.any((libItem) => libItem['id'] == aiBookId)) {
          return aiBookId;
        }

        // 2. Se falhar, tenta uma correspondência parcial (fuzzy match)
        // Isso corrige erros como 'a-ultima-noite-do-mundo' vs 'c-s-lewis-a-ultima-noite-do-mundo'
        final correctedItem = allLibraryItems.firstWhere(
          (libItem) => (libItem['id'] as String).endsWith(aiBookId),
          orElse: () => {},
        );

        if (correctedItem.isNotEmpty) {
          print(
              "LibraryMiddleware: Corrigido ID da IA de '$aiBookId' para '${correctedItem['id']}'");
          return correctedItem['id'] as String;
        }

        // 3. Se tudo falhar, retorna o ID quebrado para que o log de erro na UI o capture
        print(
            "LibraryMiddleware: AVISO - Não foi possível corrigir ou encontrar o ID da IA: '$aiBookId'");
        return aiBookId;
      }).toList();
      // <<< FIM DA CORREÇÃO DE ROBUSTEZ >>>

      return {
        'title': 'Recomendado para Você',
        'items': sanitizedBookIds, // Usa a lista de IDs corrigida
        'order': 1,
      };
    }
    return null;
  } catch (e) {
    print("LibraryMiddleware: Erro ao buscar prateleira recomendada: $e");
    return null;
  }
}
