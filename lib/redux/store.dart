// redux/store.dart
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/middleware/payment_middleware.dart';
import 'reducers.dart'; // Seu arquivo de reducers principal

import 'middleware/book_middleware.dart';
import 'middleware/author_middleware.dart';
import 'middleware/user_middleware.dart';
import 'middleware/topic_middleware.dart';
import 'middleware/search_embedding_middleware.dart'; // Middleware de busca por query de TÓPICOS GERAIS
import 'middleware/chat_middleware.dart';
import 'middleware/recommendation_middleware.dart';
import 'middleware/misc_middleware.dart';
import 'middleware/theme_middleware.dart';
import 'middleware/ad_middleware.dart';
import 'middleware/bible_search_middleware.dart'; // NOVO: Middleware para busca semântica BÍBLICA

class AppState {
  final BooksState booksState;
  final UserState userState;
  final AuthorState authorState;
  final TopicState topicState;
  final ChatState chatState;
  final ThemeState themeState;
  final BibleSearchState
      bibleSearchState; // NOVO: Estado para a busca semântica bíblica

  AppState({
    required this.booksState,
    required this.userState,
    required this.authorState,
    required this.topicState,
    required this.chatState,
    required this.themeState,
    required this.bibleSearchState, // NOVO
  });

  // O método copyWith é útil para testes ou cenários de atualização mais complexos,
  // mas geralmente os reducers individuais cuidam da imutabilidade.
  AppState copyWith({
    BooksState? booksState,
    UserState? userState,
    AuthorState? authorState,
    TopicState? topicState,
    ChatState? chatState,
    ThemeState? themeState,
    BibleSearchState? bibleSearchState, // NOVO
  }) {
    return AppState(
      booksState: booksState ?? this.booksState,
      userState: userState ?? this.userState,
      authorState: authorState ?? this.authorState,
      topicState: topicState ?? this.topicState,
      chatState: chatState ?? this.chatState,
      themeState: themeState ?? this.themeState,
      bibleSearchState: bibleSearchState ?? this.bibleSearchState, // NOVO
    );
  }
}

// Reducer principal que combina todos os outros reducers
AppState appReducer(AppState state, dynamic action) {
  return AppState(
    booksState: booksReducer(state.booksState, action),
    userState: userReducer(state.userState, action),
    authorState: authorReducer(state.authorState, action),
    topicState: topicReducer(state.topicState, action),
    chatState: chatReducer(state.chatState, action),
    themeState: themeReducer(state.themeState, action),
    bibleSearchState:
        bibleSearchReducer(state.bibleSearchState, action), // NOVO
  );
}

// Criação do store global com o estado combinado e todos os middlewares
final Store<AppState> store = Store<AppState>(
  appReducer,
  initialState: AppState(
    // Inicializa cada parte do estado com seu estado inicial padrão
    booksState: BooksState(), // Assumindo construtor padrão em BooksState
    userState: UserState(), // Assumindo construtor padrão em UserState
    authorState: AuthorState(), // Assumindo construtor padrão em AuthorState
    topicState: TopicState(), // Assumindo construtor padrão em TopicState
    chatState: ChatState(), // Assumindo construtor padrão em ChatState
    themeState: ThemeState.initial(), // Usa o factory do ThemeState
    bibleSearchState:
        BibleSearchState(), // NOVO: Estado inicial para busca bíblica
  ),
  middleware: [
    // Combina todos os middlewares dos arquivos separados
    ...createBookMiddleware(),
    ...createAuthorMiddleware(),
    ...createUserMiddleware(),
    ...createTopicMiddleware(),
    ...createSearchEmbeddingMiddleware(), // Para busca de tópicos gerais
    ...createChatMiddleware(),
    ...createRecommendationMiddleware(),
    ...createMiscMiddleware(),
    ...createPaymentMiddleware(),
    ...createThemeMiddleware(),
    ...createAdMiddleware(),
    ...createBibleSearchMiddleware(), // NOVO: Middleware para busca semântica bíblica
  ],
);
