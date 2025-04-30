import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../actions.dart';
import '../store.dart';
import '../../services/firestore_service.dart'; // Assumindo criação

List<Middleware<AppState>> createTopicMiddleware() {
  final firestoreService = FirestoreService();

  return [
    TypedMiddleware<AppState, LoadTopicContentAction>(
        _loadTopicContent(firestoreService)),
    TypedMiddleware<AppState, LoadSimilarTopicsAction>(
        _loadSimilarTopics(firestoreService)),
    TypedMiddleware<AppState, LoadTopicsAction>(_loadTopics(firestoreService)),
  ];
}

void Function(Store<AppState>, LoadTopicContentAction, NextDispatcher)
    _loadTopicContent(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadTopicContentAction action,
      NextDispatcher next) async {
    next(action);
    // Opcional: verificar se o conteúdo já existe no estado para evitar busca
    if (store.state.topicState.topicsContent.containsKey(action.topicId)) {
      print("Conteúdo do tópico ${action.topicId} já está no estado.");
      // Talvez recarregar metadados se necessário
      final metadata = store.state.topicState.topicsMetadata[action.topicId];
      if (metadata == null) {
        // Se metadados não existem, busca
        try {
          final topicData = await firestoreService.getTopicData(action.topicId);
          if (topicData != null) {
            store.dispatch(TopicContentLoadedAction(
              action.topicId,
              topicData['conteudo'] ?? '',
              topicData['titulo'] ?? '',
              topicData['bookId'] ?? '',
              topicData['capituloId'] ?? '',
              topicData['chapterName'] ?? '',
              firestoreService.extractChapterIndex(topicData['chapterName']),
            ));
          }
        } catch (e) {
          print('Erro ao carregar metadados do tópico ${action.topicId}: $e');
        }
      }
      return;
    }

    try {
      final topicData = await firestoreService.getTopicData(action.topicId);
      if (topicData != null) {
        store.dispatch(TopicContentLoadedAction(
          action.topicId,
          topicData['conteudo'] ?? '',
          topicData['titulo'] ?? '',
          topicData['bookId'] ?? '',
          topicData['capituloId'] ?? '',
          topicData['chapterName'] ?? '',
          firestoreService.extractChapterIndex(topicData['chapterName']),
        ));
      } else {
        print('Tópico ${action.topicId} não encontrado.');
        // Opcional: despachar erro
      }
    } catch (e) {
      print('Erro ao carregar conteúdo do tópico ${action.topicId}: $e');
      // Opcional: despachar erro
    }
  };
}

void Function(Store<AppState>, LoadSimilarTopicsAction, NextDispatcher)
    _loadSimilarTopics(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadSimilarTopicsAction action,
      NextDispatcher next) async {
    next(action);
    // Opcional: verificar se já existe no estado
    if (store.state.topicState.similarTopics.containsKey(action.topicId)) {
      print("Tópicos similares para ${action.topicId} já estão no estado.");
      return;
    }

    try {
      final similarTopicsData =
          await firestoreService.getSimilarTopics(action.topicId);
      // Como os dados já vêm processados do Firestore (assumindo), despacha diretamente
      store.dispatch(
          SimilarTopicsLoadedAction(action.topicId, similarTopicsData));
    } catch (e) {
      print(
          'Middleware: Erro ao carregar tópicos similares para ${action.topicId}: $e');
      store.dispatch(SimilarTopicsLoadedAction(
          action.topicId, [])); // Despacha lista vazia em caso de erro
    }
  };
}

void Function(Store<AppState>, LoadTopicsAction, NextDispatcher) _loadTopics(
    FirestoreService firestoreService) {
  return (Store<AppState> store, LoadTopicsAction action,
      NextDispatcher next) async {
    next(action);
    try {
      List<Map<String, dynamic>> topics =
          await firestoreService.fetchTopicsByIds(action.topicIds);
      store.dispatch(TopicsLoadedAction(topics));
    } catch (e) {
      print('Erro ao carregar tópicos: $e');
      // Opcional: Despachar erro
    }
  };
}
