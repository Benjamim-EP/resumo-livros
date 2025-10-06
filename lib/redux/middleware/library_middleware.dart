// lib/redux/middleware/library_middleware.dart

import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

List<Middleware<AppState>> createLibraryMiddleware() {
  final firestoreService = FirestoreService();
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");

  // Handler principal que orquestra o carregamento de todas as prateleiras
  void _loadShelves(Store<AppState> store, LoadLibraryShelvesAction action,
      NextDispatcher next) async {
    next(action);

    try {
      // 1. Inicia as duas buscas em paralelo para mais performance
      final curatedShelvesFuture = firestoreService.fetchLibraryShelves();
      final recommendedShelfFuture = _fetchRecommendedShelf(functions);

      // 2. Aguarda a conclusão de ambas
      final results = await Future.wait([
        curatedShelvesFuture,
        recommendedShelfFuture,
      ]);

      final List<Map<String, dynamic>> curatedShelves =
          results[0] as List<Map<String, dynamic>>;
      final Map<String, dynamic>? recommendedShelf =
          results[1] as Map<String, dynamic>?;

      // 3. Combina as listas
      List<Map<String, dynamic>> allShelves = [];
      if (recommendedShelf != null &&
          (recommendedShelf['items'] as List).isNotEmpty) {
        allShelves.add(recommendedShelf);
      }
      allShelves.addAll(curatedShelves);

      // 4. Ordena as prateleiras (se você adicionou um campo 'order' nos documentos do Firestore)
      allShelves.sort((a, b) =>
          (a['order'] as int? ?? 99).compareTo(b['order'] as int? ?? 99));

      store.dispatch(LibraryShelvesLoadedAction(allShelves));
    } catch (e) {
      print("LibraryMiddleware: Erro ao carregar prateleiras: $e");
      store.dispatch(LibraryShelvesFailedAction(e.toString()));
    }
  }

  return [
    TypedMiddleware<AppState, LoadLibraryShelvesAction>(_loadShelves),
  ];
}

// Função auxiliar para chamar a Cloud Function de recomendação
Future<Map<String, dynamic>?> _fetchRecommendedShelf(
    FirebaseFunctions functions) async {
  try {
    final callable = functions.httpsCallable('recommendLibraryBooks');
    // Chama a função SEM a 'user_query' para obter recomendações automáticas
    final result = await callable.call<Map<String, dynamic>>({});

    final recommendations =
        result.data['recommendations'] as List<dynamic>? ?? [];

    if (recommendations.isNotEmpty) {
      // Retorna a "prateleira" no formato que a UI espera
      return {
        'title': 'Recomendado para Você',
        'items':
            recommendations.map((item) => item['bookId'] as String).toList(),
        'order': 1, // Garante que esta prateleira apareça primeiro
      };
    }
    return null;
  } catch (e) {
    print("LibraryMiddleware: Erro ao buscar prateleira recomendada: $e");
    return null; // Retorna nulo em caso de erro, não quebra o fluxo principal
  }
}
