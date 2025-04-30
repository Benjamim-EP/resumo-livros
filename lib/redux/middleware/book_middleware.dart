import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../actions.dart';
import '../store.dart';
import '../../services/book_service.dart';
import '../../services/firestore_service.dart'; // Supondo criação

List<Middleware<AppState>> createBookMiddleware() {
  final bookService = BookService();
  final firestoreService = FirestoreService();

  return [
    TypedMiddleware<AppState, LoadBookDetailsAction>(
        _loadBookDetails(bookService)),
    TypedMiddleware<AppState, StartBookProgressAction>(
        _handleStartBookProgress(firestoreService)),
    TypedMiddleware<AppState, MarkTopicAsReadAction>(
        _handleMarkTopicAsRead(firestoreService)),
    TypedMiddleware<AppState, CheckBookProgressAction>(
        _checkBookProgress(firestoreService)),
    // A ação BooksLoadedByTagAction pode ser acionada por TagMiddleware ou aqui, dependendo da lógica
    // Se for acionada após TagsLoadedAction, pertence a TagMiddleware.
    // Se for uma ação independente para carregar livros de uma tag específica, pode ficar aqui.
    // TypedMiddleware<AppState, LoadBooksByTagAction>(_loadBooksByTag(bookService)), // Exemplo
  ];
}

void Function(Store<AppState>, LoadBookDetailsAction, NextDispatcher)
    _loadBookDetails(BookService bookService) {
  return (Store<AppState> store, LoadBookDetailsAction action,
      NextDispatcher next) async {
    next(action);
    try {
      final bookDetails = await bookService.fetchBookDetails(action.bookId);
      if (bookDetails != null) {
        store.dispatch(BookDetailsLoadedAction(action.bookId, bookDetails));
        print('Livro carregado: ${action.bookId} - ${bookDetails['titulo']}');
      } else {
        print('Livro não encontrado para ID: ${action.bookId}');
        // Opcional: Despachar ação de erro
      }
    } catch (e) {
      print("Erro ao carregar detalhes do livro ${action.bookId}: $e");
      // Opcional: Despachar ação de erro
    }
  };
}

void Function(Store<AppState>, StartBookProgressAction, NextDispatcher)
    _handleStartBookProgress(FirestoreService firestoreService) {
  return (Store<AppState> store, StartBookProgressAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      print("Usuário não autenticado. Progresso não iniciado.");
      return;
    }

    try {
      await firestoreService.startBookProgressIfNeeded(userId, action.bookId);
      print("Progresso do livro ${action.bookId} iniciado/verificado.");
      // A atualização do estado Redux pode ocorrer no reducer ou com uma ação de sucesso específica
    } catch (e) {
      print('Erro ao iniciar progresso do livro: $e');
      // Opcional: despachar ação de erro
    }
  };
}

void Function(Store<AppState>, MarkTopicAsReadAction, NextDispatcher)
    _handleMarkTopicAsRead(FirestoreService firestoreService) {
  return (Store<AppState> store, MarkTopicAsReadAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      print("Usuário não autenticado. Tópico não marcado como lido.");
      return;
    }

    try {
      final bookDetails = store.state.booksState.bookDetails?[action.bookId];
      final totalTopicos =
          bookDetails?['totalTopicos'] ?? 1; // Pega do estado Redux

      final updated = await firestoreService.markTopicAsRead(
        userId,
        action.bookId,
        action.topicId,
        action.chapterId,
        totalTopicos,
      );

      if (updated) {
        print("Tópico ${action.topicId} marcado como lido.");
        // Despachar ação para atualizar o estado Redux (ou deixar o reducer cuidar disso)
        // Exemplo: store.dispatch(BookProgressUpdatedAction(...));
        store.dispatch(
            CheckBookProgressAction(action.bookId)); // Recarrega o progresso
        store
            .dispatch(LoadUserStatsAction()); // Recarrega stats (Tópicos lidos)
      }
    } catch (e) {
      print('Erro ao atualizar progresso do tópico: $e');
      // Opcional: despachar ação de erro
    }
  };
}

void Function(Store<AppState>, CheckBookProgressAction, NextDispatcher)
    _checkBookProgress(FirestoreService firestoreService) {
  return (Store<AppState> store, CheckBookProgressAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      print("Usuário não autenticado. Não é possível carregar progresso.");
      store.dispatch(LoadBookProgressFailureAction("Usuário não autenticado"));
      return;
    }

    try {
      final bookProgressData =
          await firestoreService.getBookProgress(userId, action.bookId);
      final readTopics =
          List<String>.from(bookProgressData?['readTopics'] ?? []);

      print("Progresso carregado para ${action.bookId}: $readTopics");
      store.dispatch(LoadBookProgressSuccessAction(action.bookId, readTopics));
    } catch (e) {
      print("Erro ao carregar progresso de leitura para ${action.bookId}: $e");
      store.dispatch(LoadBookProgressFailureAction(e.toString()));
    }
  };
}
