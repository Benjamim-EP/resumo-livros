// redux/store.dart
import 'package:redux/redux.dart';
import 'reducers.dart';
import 'middleware.dart'; // Middlewares existentes

class AppState {
  final BooksState booksState;
  final UserState userState;
  final AuthorState authorState;
  final TopicState topicState;

  AppState({
    required this.booksState,
    required this.userState,
    required this.authorState,
    required this.topicState,
  });

  AppState copyWith({
    BooksState? booksState,
    UserState? userState,
    AuthorState? authorState,
    TopicState? topicState,
  }) {
    return AppState(
      booksState: booksState ?? this.booksState,
      userState: userState ?? this.userState,
      authorState: authorState ?? this.authorState,
      topicState: topicState ?? this.topicState,
    );
  }
}

AppState appReducer(AppState state, dynamic action) {
  return AppState(
    booksState: booksReducer(state.booksState, action),
    userState: userReducer(state.userState, action),
    authorState: authorReducer(state.authorState, action),
    topicState: topicReducer(state.topicState, action),
  );
}

// Criação do store global com o estado combinado e middleware
final Store<AppState> store = Store<AppState>(
  appReducer,
  initialState: AppState(
    booksState: BooksState(booksByTag: {}),
    userState: UserState(),
    authorState: AuthorState(),
    topicState: TopicState(),
  ),
  middleware: [
    userRoutesMiddleware,
    tagMiddleware,
    bookMiddleware,
    authorMiddleware,
    userMiddleware,
    topicMiddleware,
    embeddingMiddleware, // Adicione o middleware aqui
  ],
);
