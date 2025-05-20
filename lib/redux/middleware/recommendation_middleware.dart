import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../actions.dart';
import '../store.dart';
// Importar serviços necessários (Pinecone, OpenAI, LocalStorage, Firestore)
import '../../services/openai_service.dart';
import '../../services/pinecone_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/firestore_service.dart'; // Supondo que você crie este

List<Middleware<AppState>> createRecommendationMiddleware() {
  final firestoreService = FirestoreService(); // Instanciar serviços
  final openAIService = OpenAIService();
  final pineconeService = PineconeService();
  final localStorageService = LocalStorageService();

  return [
    TypedMiddleware<AppState, LoadWeeklyRecommendationsAction>(
            _loadWeeklyRecommendations(firestoreService))
        .call,
    TypedMiddleware<AppState, LoadTopicsByFeatureAction>(
            _handleLoadTopicsByFeature(firestoreService, openAIService,
                pineconeService, localStorageService))
        .call,
  ];
}

// --- Handlers (Funções que retornam MiddlewareFunc) ---

void Function(Store<AppState>, LoadWeeklyRecommendationsAction, NextDispatcher)
    _loadWeeklyRecommendations(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadWeeklyRecommendationsAction action,
      NextDispatcher next) async {
    next(action);
    try {
      final topBooks = await firestoreService.fetchWeeklyRecommendations();
      store.dispatch(WeeklyRecommendationsLoadedAction(topBooks));
    } catch (e) {
      print("Erro ao carregar recomendações semanais: $e");
    }
  };
}

void Function(Store<AppState>, LoadTopicsByFeatureAction, NextDispatcher)
    _handleLoadTopicsByFeature(
  FirestoreService firestoreService,
  OpenAIService openAIService,
  PineconeService pineconeService,
  LocalStorageService localStorageService,
) {
  return (Store<AppState> store, LoadTopicsByFeatureAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      print('Usuário não autenticado.');
      // Opcional: despachar ação de erro
      return;
    }

    try {
      // 1. Tenta carregar do cache local
      final cachedTopics =
          await localStorageService.loadTopicsByFeature(userId);
      if (cachedTopics != null && cachedTopics.isNotEmpty) {
        print("Carregando tópicos do cache local...");
        store.dispatch(TopicsByFeatureLoadedAction(cachedTopics));
        return;
      }

      // 2. Se não houver cache, busca do Firestore (campo indicacoes)
      final indicacoes = await firestoreService.getUserIndicacoes(userId);

      if (indicacoes != null &&
          indicacoes.values.any((list) => list.isNotEmpty)) {
        print("Carregando tópicos de 'indicacoes' do Firestore...");
        Map<String, List<Map<String, dynamic>>> topicsByFeature = {};

        for (var key in indicacoes.keys) {
          final topicIds = indicacoes[key] ?? [];
          List<Map<String, dynamic>> topics =
              await firestoreService.fetchTopicsByIds(topicIds);
          topicsByFeature[key] = topics;
        }

        await localStorageService.saveTopicsByFeature(userId, topicsByFeature);
        store.dispatch(TopicsByFeatureLoadedAction(topicsByFeature));
        print(
            "Busca de tópicos (via indicacoes) finalizada e salva localmente.");
        return;
      }

      // 3. Se 'indicacoes' estiver vazio/nulo, busca por features (fallback)
      print('Nenhuma indicação encontrada. Carregando por features...');
      final userFeatures = await firestoreService.getUserFeatures(userId);

      if (userFeatures == null || userFeatures.isEmpty) {
        print('Nenhuma feature encontrada para o usuário.');
        // Opcional: despachar ação de erro ou estado vazio
        store.dispatch(TopicsByFeatureLoadedAction({})); // Envia mapa vazio
        return;
      }

      Map<String, List<Map<String, dynamic>>> topicsByFeature = {};
      Map<String, List<String>> updatedIndicacoes = {}; // Usar List<String>

      for (var feature in userFeatures.entries) {
        final key = feature.key;
        final value = feature.value?.toString() ?? ''; // Garante que é string

        if (value.isEmpty) continue; // Pula features vazias

        final embedding = await openAIService.generateEmbedding(value);
        final results =
            await pineconeService.queryPinecone(embedding, 100); // Ajustar topK

        final topicIds = results.map((match) => match['id'] as String).toList();

        List<Map<String, dynamic>> topics =
            await firestoreService.fetchTopicsByIds(topicIds);
        topicsByFeature[key] = topics;
        updatedIndicacoes[key] = topicIds;
      }

      await firestoreService.updateUserIndicacoes(userId, updatedIndicacoes);
      await localStorageService.saveTopicsByFeature(userId, topicsByFeature);
      store.dispatch(TopicsByFeatureLoadedAction(topicsByFeature));
      print("Busca de tópicos (via features) finalizada e salva localmente.");
    } catch (e) {
      print('Erro ao carregar topicsByFeature: $e');
      // Opcional: despachar ação de erro
    }
  };
}
