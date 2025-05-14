import 'package:redux/redux.dart';
import '../actions.dart';
import '../store.dart';
import '../../services/tag_service.dart';
import '../../services/firestore_service.dart'; // Assumindo criação

List<Middleware<AppState>> createMiscMiddleware() {
  final tagService = TagService();
  final firestoreService = FirestoreService();

  return [
    // Se UserLoggedInAction disparar LoadTagsAction, este middleware será chamado
    // TypedMiddleware<AppState, LoadTagsAction, NextDispatcher)(_loadTags(tagService)), // Exemplo
    TypedMiddleware<AppState, TagsLoadedAction>(
            _handleTagsLoaded(firestoreService))
        .call, // Exemplo de como lidar com tags carregadas
    TypedMiddleware<AppState, LoadUserRoutesAction>(
            _loadUserRoutes(firestoreService))
        .call,
    // Middleware para AddTopicToRouteAction e ClearRouteAction geralmente não são necessários
    // pois a lógica principal ocorre nos reducers. A menos que precise salvar no Firestore
    // TypedMiddleware<AppState, AddTopicToRouteAction, NextDispatcher)(_handleAddTopicToRoute),
    // TypedMiddleware<AppState, ClearRouteAction, NextDispatcher)(_handleClearRoute),
  ];
}

// Exemplo: Carregar livros quando as tags forem carregadas
void Function(Store<AppState>, TagsLoadedAction, NextDispatcher)
    _handleTagsLoaded(FirestoreService firestoreService) {
  return (Store<AppState> store, TagsLoadedAction action,
      NextDispatcher next) async {
    next(action);
    // A lógica original estava em bookMiddleware, movida para cá ou para RecommendationMiddleware
    // Se as tags são usadas para buscar livros específicos:
    try {
      for (final tag in action.tags) {
        final books = await firestoreService
            .fetchBooksByTag(tag); // Mover para FirestoreService
        if (books.isNotEmpty) {
          store.dispatch(BooksLoadedByTagAction(tag, books));
        } else {
          print("Nenhum livro encontrado para a tag: $tag");
        }
      }
    } catch (e) {
      print("Erro ao carregar livros por tag: $e");
    }
  };
}

void Function(Store<AppState>, LoadUserRoutesAction, NextDispatcher)
    _loadUserRoutes(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadUserRoutesAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(UserRoutesLoadFailedAction('Usuário não autenticado.'));
      return;
    }
    try {
      final routes = await firestoreService.getUserRoutes(userId);
      store.dispatch(UserRoutesLoadedAction(routes));
    } catch (e) {
      store.dispatch(UserRoutesLoadFailedAction('Erro ao carregar rotas: $e'));
    }
  };
}
