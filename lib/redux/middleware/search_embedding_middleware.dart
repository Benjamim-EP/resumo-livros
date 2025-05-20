import 'package:redux/redux.dart';
import '../actions.dart';
import '../store.dart';
import '../../services/openai_service.dart';
import '../../services/pinecone_service.dart';
import '../../services/firestore_service.dart'; // Supondo criação

List<Middleware<AppState>> createSearchEmbeddingMiddleware() {
  final openAIService = OpenAIService();
  final pineconeService = PineconeService();
  final firestoreService = FirestoreService();

  return [
    TypedMiddleware<AppState, SearchByQueryAction>(_handleSearchByQuery(
            openAIService, pineconeService, firestoreService))
        .call,
  ];
}

void Function(Store<AppState>, SearchByQueryAction, NextDispatcher)
    _handleSearchByQuery(OpenAIService openAIService,
        PineconeService pineconeService, FirestoreService firestoreService) {
  return (Store<AppState> store, SearchByQueryAction action,
      NextDispatcher next) async {
    next(action);
    try {
      final embedding = await openAIService.generateEmbedding(action.query);
      final results =
          await pineconeService.queryPinecone(embedding, 100); // Ajustar topK

      final topicIds = results
          .map((match) =>
              match['id'] as String) // Assumindo que 'results' é List<Map>
          .toList();

      List<Map<String, dynamic>> topics =
          await firestoreService.fetchTopicsByIds(topicIds);

      store.dispatch(SearchSuccessAction(topics));
    } catch (e) {
      print('Erro durante a busca: $e');
      store.dispatch(SearchFailureAction('Erro durante a busca: $e'));
    }
  };
}
