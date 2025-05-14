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
    TypedMiddleware<AppState, EmbedAndSearchFeaturesAction>(
            _handleEmbedAndSearchFeatures(openAIService, pineconeService))
        .call, // Este pode ser obsoleto se FetchTribeTopicsAction o substitui
    TypedMiddleware<AppState, SearchByQueryAction>(_handleSearchByQuery(
            openAIService, pineconeService, firestoreService))
        .call,
  ];
}

void Function(Store<AppState>, EmbedAndSearchFeaturesAction, NextDispatcher)
    _handleEmbedAndSearchFeatures(
        OpenAIService openAIService, PineconeService pineconeService) {
  return (Store<AppState> store, EmbedAndSearchFeaturesAction action,
      NextDispatcher next) async {
    next(action);
    // Lógica similar a FetchTribeTopicsAction, mas talvez focada apenas em gerar recomendações e não salvar em 'indicacoes'
    // Esta ação pode ser redundante dependendo do fluxo exato.
    // Se for usada, extraia a lógica de embedding/query como em FetchTribeTopicsAction
    try {
      List<Map<String, dynamic>> allMatches = [];
      for (var entry in action.features.entries) {
        if ((entry.value).isNotEmpty) {
          final embedding = await openAIService.generateEmbedding(entry.value);
          final results = await pineconeService.queryPinecone(
              embedding, 100); // Ajuste topK
          allMatches.addAll(results); // Acumula resultados
        }
      }
      // Processar 'allMatches' se necessário (ex: pegar IDs, buscar no Firestore)
      // e despachar EmbedAndSearchSuccessAction
      // Exemplo simplificado:
      // final topicIds = allMatches.map((m) => m['id'] as String).toSet().toList();
      // final topics = await firestoreService.fetchTopicsByIds(topicIds);
      // store.dispatch(EmbedAndSearchSuccessAction(topics)); // Supondo que a ação espera tópicos
    } catch (e) {
      print("Erro em EmbedAndSearchFeaturesAction: $e");
      store
          .dispatch(EmbedAndSearchFailureAction('Erro durante o processo: $e'));
    }
  };
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
