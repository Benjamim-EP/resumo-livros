// redux/store.dart
import 'package:redux/redux.dart';
import 'reducers.dart';

import 'middleware/book_middleware.dart';
import 'middleware/author_middleware.dart';
import 'middleware/user_middleware.dart';
import 'middleware/topic_middleware.dart';
import 'middleware/search_embedding_middleware.dart';
import 'middleware/chat_middleware.dart';
import 'middleware/recommendation_middleware.dart';
import 'middleware/misc_middleware.dart';

class AppState {
  final BooksState booksState;
  final UserState userState;
  final AuthorState authorState;
  final TopicState topicState;
  final ChatState chatState; // 🔹 Adicionando ChatState

  AppState({
    required this.booksState,
    required this.userState,
    required this.authorState,
    required this.topicState,
    required this.chatState,
  });

  AppState copyWith({
    BooksState? booksState,
    UserState? userState,
    AuthorState? authorState,
    TopicState? topicState,
    ChatState? chatState,
  }) {
    return AppState(
      booksState: booksState ?? this.booksState,
      userState: userState ?? this.userState,
      authorState: authorState ?? this.authorState,
      topicState: topicState ?? this.topicState,
      chatState: chatState ?? this.chatState,
    );
  }
}

AppState appReducer(AppState state, dynamic action) {
  return AppState(
    booksState: booksReducer(state.booksState, action),
    userState: userReducer(state.userState, action),
    authorState: authorReducer(state.authorState, action),
    topicState: topicReducer(state.topicState, action),
    chatState: chatReducer(state.chatState, action), // 🔹 Adicionado aqui
  );
}

// Criação do store global com o estado combinado e middleware
final Store<AppState> store = Store<AppState>(
  appReducer,
  initialState: AppState(
    booksState: BooksState(booksByTag: {}, weeklyRecommendations: []),
    userState: UserState(),
    authorState: AuthorState(),
    topicState: TopicState(),
    chatState: ChatState(),
  ),
  middleware: [
    // Combina todos os middlewares dos arquivos separados
    ...createBookMiddleware(),
    ...createAuthorMiddleware(),
    ...createUserMiddleware(),
    ...createTopicMiddleware(),
    ...createSearchEmbeddingMiddleware(),
    ...createChatMiddleware(),
    ...createRecommendationMiddleware(),
    ...createMiscMiddleware(),
  ],
);
