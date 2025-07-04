// redux/store.dart
import 'package:flutter/foundation.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/middleware/backend_validation_middleware.dart';
import 'package:septima_biblia/redux/middleware/bible_progress_middleware.dart';
import 'package:septima_biblia/redux/middleware/fake_payment_middleware.dart';
import 'package:septima_biblia/redux/middleware/firestore_sync_middleware.dart';
import 'package:septima_biblia/redux/middleware/metadata_middleware.dart';
import 'package:septima_biblia/redux/middleware/payment_middleware.dart';
import 'package:septima_biblia/redux/middleware/sermon_search_middleware.dart';
import 'package:septima_biblia/redux/reducers/metadata_reducer.dart';
import 'package:septima_biblia/redux/reducers/sermon_search_reducer.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'reducers.dart'; // Seu arquivo de reducers principal

import 'middleware/book_middleware.dart';
import 'middleware/author_middleware.dart';
import 'middleware/user_middleware.dart';
import 'middleware/topic_middleware.dart';
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
  final SermonSearchState sermonSearchState; // NOVO ESTADO

  final MetadataState metadataState;
  final SubscriptionState subscriptionState;

  AppState({
    required this.booksState,
    required this.userState,
    required this.authorState,
    required this.topicState,
    required this.chatState,
    required this.themeState,
    required this.bibleSearchState, // NOVO
    required this.metadataState,
    required this.subscriptionState,
    required this.sermonSearchState,
  });

  // O método copyWith é útil para testes ou cenários de atualização mais complexos,
  // mas geralmente os reducers individuais cuidam da imutabilidade.
  AppState copyWith(
      {BooksState? booksState,
      UserState? userState,
      AuthorState? authorState,
      TopicState? topicState,
      ChatState? chatState,
      ThemeState? themeState,
      BibleSearchState? bibleSearchState, // NOVO
      SubscriptionState? subscriptionState}) {
    return AppState(
      booksState: booksState ?? this.booksState,
      userState: userState ?? this.userState,
      authorState: authorState ?? this.authorState,
      topicState: topicState ?? this.topicState,
      chatState: chatState ?? this.chatState,
      themeState: themeState ?? this.themeState,
      bibleSearchState: bibleSearchState ?? this.bibleSearchState, // NOVO
      metadataState:
          metadataState ?? metadataState, // Mantém o estado de metadados atual
      subscriptionState: subscriptionState ?? this.subscriptionState,
      sermonSearchState: sermonSearchState ?? this.sermonSearchState,
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
    metadataState: metadataReducer(state.metadataState, action),
    subscriptionState: subscriptionReducer(state.subscriptionState, action),
    sermonSearchState: sermonSearchReducer(state.sermonSearchState, action),
  );
}

// Criação do store global com o estado combinado e todos os middlewares
final Store<AppState> store = Store<AppState>(
  appReducer,
  initialState: AppState(
    // Inicializa cada parte do estado com seu estado inicial padrão
    booksState: BooksState(), // Assumindo construtor padrão em BooksState
    //userState: UserState(), // Assumindo construtor padrão em UserState
    authorState: AuthorState(), // Assumindo construtor padrão em AuthorState
    topicState: TopicState(), // Assumindo construtor padrão em TopicState
    chatState: ChatState(), // Assumindo construtor padrão em ChatState
    themeState: ThemeState.initial(), // Usa o factory do ThemeState
    bibleSearchState:
        BibleSearchState(), // NOVO: Estado inicial para busca bíblica
    metadataState: MetadataState(),
    userState: UserState(pendingFirestoreWrites: []),
    subscriptionState: SubscriptionState.initial(),
    sermonSearchState:
        SermonSearchState(), // NOVO: Estado inicial para busca de sermões
  ),
  middleware: createAppMiddleware(),
);

// Função para criar a lista de middlewares dinamicamente
List<Middleware<AppState>> createAppMiddleware() {
  // Lista de middlewares que rodam em ambos os modos (debug e release)
  List<Middleware<AppState>> commonMiddleware = [
    ...createBookMiddleware(),
    ...createAuthorMiddleware(),
    ...createUserMiddleware(),
    ...createTopicMiddleware(),
    ...createMiscMiddleware(),
    ...createThemeMiddleware(),
    ...createAdMiddleware(),
    ...createBibleSearchMiddleware(),
    ...createBibleProgressMiddleware(),
    ...createMetadataMiddleware(),
    ...createFirestoreSyncMiddleware(),
    ...createSermonSearchMiddleware(),
    ...createBackendValidationMiddleware(),
  ];

  // A constante kDebugMode é verdadeira apenas quando você roda em modo debug
  if (kDebugMode) {
    print("<<<<< MODO DEBUG: Usando Middleware de Pagamento FALSO >>>>>");
    // Adiciona o middleware falso
    return [
      ...commonMiddleware,
      ...createFakePaymentMiddleware(), // <<< USA O FALSO
    ];
  } else {
    print("<<<<< MODO RELEASE: Usando Middleware de Pagamento REAL >>>>>");
    // Adiciona os middlewares reais de pagamento
    return [
      ...commonMiddleware,
      ...createPaymentMiddleware(), // <<< USA O REAL
    ];
  }
}

class MetadataState {
  final Map<String, dynamic> bibleSectionCounts;
  final bool isLoadingSectionCounts;
  final String? sectionCountsError;

  MetadataState({
    this.bibleSectionCounts = const {},
    this.isLoadingSectionCounts = false,
    this.sectionCountsError,
  });

  MetadataState copyWith({
    Map<String, dynamic>? bibleSectionCounts,
    bool? isLoadingSectionCounts,
    String? sectionCountsError,
    bool clearError = false,
  }) {
    return MetadataState(
      bibleSectionCounts: bibleSectionCounts ?? this.bibleSectionCounts,
      isLoadingSectionCounts:
          isLoadingSectionCounts ?? this.isLoadingSectionCounts,
      sectionCountsError:
          clearError ? null : sectionCountsError ?? this.sectionCountsError,
    );
  }
}
