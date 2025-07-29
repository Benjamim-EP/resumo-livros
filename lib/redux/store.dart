// lib/redux/store.dart

import 'package:flutter/foundation.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/middleware/book_club_middleware.dart';

// Importa a interface e as implementações do serviço de pagamento
import 'package:septima_biblia/services/payment_service.dart';

// Importa todos os seus reducers
import 'reducers.dart';
import 'reducers/community_search_reducer.dart';
import 'reducers/metadata_reducer.dart';
import 'reducers/sermon_search_reducer.dart';
import 'reducers/subscription_reducer.dart';

// Importa todos os seus middlewares
import 'middleware/book_middleware.dart';
import 'middleware/author_middleware.dart';
import 'middleware/user_middleware.dart';
import 'middleware/topic_middleware.dart';
import 'middleware/misc_middleware.dart';
import 'middleware/theme_middleware.dart';
import 'middleware/ad_middleware.dart';
import 'middleware/bible_search_middleware.dart';
import 'middleware/bible_progress_middleware.dart';
import 'middleware/metadata_middleware.dart';
import 'middleware/firestore_sync_middleware.dart';
import 'middleware/sermon_search_middleware.dart';
import 'middleware/backend_validation_middleware.dart';
import 'middleware/book_search_middleware.dart';
import 'middleware/sermon_data_middleware.dart';
import 'middleware/community_search_middleware.dart';
import 'middleware/payment_middleware.dart';
import 'middleware/fake_payment_middleware.dart';

// A definição do seu AppState (sem alterações)
class AppState {
  final BooksState booksState;
  final UserState userState;
  final AuthorState authorState;
  final TopicState topicState;
  final ChatState chatState;
  final ThemeState themeState;
  final BibleSearchState bibleSearchState;
  final SermonSearchState sermonSearchState;
  final BookSearchState bookSearchState;
  final MetadataState metadataState;
  final SubscriptionState subscriptionState;
  final SermonState sermonState;
  final CommunitySearchState communitySearchState;

  AppState({
    required this.booksState,
    required this.userState,
    required this.authorState,
    required this.topicState,
    required this.chatState,
    required this.themeState,
    required this.bibleSearchState,
    required this.metadataState,
    required this.subscriptionState,
    required this.sermonSearchState,
    required this.bookSearchState,
    required this.sermonState,
    required this.communitySearchState,
  });

  // copyWith (sem alterações)
  AppState copyWith({
    BooksState? booksState,
    UserState? userState,
    AuthorState? authorState,
    TopicState? topicState,
    ChatState? chatState,
    ThemeState? themeState,
    BibleSearchState? bibleSearchState,
    BookSearchState? bookSearchState,
    SermonSearchState? sermonSearchState,
    SermonState? sermonState,
    SubscriptionState? subscriptionState,
    MetadataState? metadataState,
    CommunitySearchState? communitySearchState,
  }) {
    return AppState(
        booksState: booksState ?? this.booksState,
        userState: userState ?? this.userState,
        authorState: authorState ?? this.authorState,
        topicState: topicState ?? this.topicState,
        chatState: chatState ?? this.chatState,
        themeState: themeState ?? this.themeState,
        bibleSearchState: bibleSearchState ?? this.bibleSearchState,
        metadataState: metadataState ?? this.metadataState,
        subscriptionState: subscriptionState ?? this.subscriptionState,
        sermonSearchState: sermonSearchState ?? this.sermonSearchState,
        bookSearchState: bookSearchState ?? this.bookSearchState,
        sermonState: sermonState ?? this.sermonState,
        communitySearchState:
            communitySearchState ?? this.communitySearchState);
  }
}

// O seu appReducer principal (sem alterações)
AppState appReducer(AppState state, dynamic action) {
  return AppState(
    booksState: booksReducer(state.booksState, action),
    userState: userReducer(state.userState, action),
    authorState: authorReducer(state.authorState, action),
    topicState: topicReducer(state.topicState, action),
    chatState: chatReducer(state.chatState, action),
    themeState: themeReducer(state.themeState, action),
    bibleSearchState: bibleSearchReducer(state.bibleSearchState, action),
    metadataState: metadataReducer(state.metadataState, action),
    subscriptionState: subscriptionReducer(state.subscriptionState, action),
    sermonSearchState: sermonSearchReducer(state.sermonSearchState, action),
    bookSearchState: bookSearchReducer(state.bookSearchState, action),
    sermonState: sermonReducer(state.sermonState, action),
    communitySearchState:
        communitySearchReducer(state.communitySearchState, action),
  );
}

// A sua função createAppMiddleware, agora recebendo o IPaymentService
List<Middleware<AppState>> createAppMiddleware(IPaymentService paymentService) {
  List<Middleware<AppState>> commonMiddleware = [
    ...createAuthorMiddleware(),
    ...createUserMiddleware(),
    ...createMiscMiddleware(),
    ...createThemeMiddleware(),
    ...createAdMiddleware(),
    ...createBibleSearchMiddleware(),
    ...createBibleProgressMiddleware(),
    ...createMetadataMiddleware(),
    ...createFirestoreSyncMiddleware(),
    ...createSermonSearchMiddleware(),
    ...createBackendValidationMiddleware(),
    ...createBookSearchMiddleware(),
    ...createBookMiddleware(),
    ...createSermonDataMiddleware(),
    ...createCommunitySearchMiddleware(),
    ...createBookClubMiddleware(),
  ];

  if (!kDebugMode) {
    print("<<<<< MODO DEBUG: Usando Middleware de Pagamento FALSO >>>>>");
    return [
      ...commonMiddleware,
      ...createFakePaymentMiddleware(),
    ];
  } else {
    print("<<<<< MODO RELEASE: Usando Middleware de Pagamento REAL >>>>>");
    return [
      ...commonMiddleware,
      ...createPaymentMiddleware(paymentService), // <<< USA O SERVIÇO INJETADO
    ];
  }
}

// ==========================================================
// FUNÇÃO CENTRAL PARA CRIAR E CONFIGURAR A STORE
// ==========================================================
Store<AppState> createStore() {
  // 1. Detecta qual "sabor" (flavor) do app está sendo executado.
  // Isso funciona por causa da flag "--dart-define=IS_PLAY_STORE=true/false"
  // que configuramos no seu arquivo `launch.json`.
  const bool isPlayStoreBuild = bool.fromEnvironment('IS_PLAY_STORE');

  // 2. Escolhe a implementação correta do serviço de pagamento com base no flavor.
  IPaymentService paymentService;
  if (isPlayStoreBuild) {
    print(
        "STORE INIT: Detectado build da Play Store. Usando GooglePlayPaymentService.");
    paymentService = GooglePlayPaymentService();
  } else {
    print(
        "STORE INIT: Detectado build do Website. Usando StripePaymentService.");
    paymentService = StripePaymentService();
  }

  // 3. Cria a instância da Store, passando o estado inicial e os middlewares configurados.
  return Store<AppState>(
    appReducer,
    // Este é o estado inicial do seu aplicativo. Cada "fatia" do estado
    // é inicializada com seu valor padrão.
    initialState: AppState(
      booksState: BooksState(),
      userState: UserState(pendingFirestoreWrites: []),
      authorState: AuthorState(),
      topicState: TopicState(),
      chatState: ChatState(),
      themeState: ThemeState.initial(),
      bibleSearchState: BibleSearchState(),
      metadataState: MetadataState(),
      subscriptionState: SubscriptionState.initial(),
      sermonSearchState: SermonSearchState(),
      bookSearchState: BookSearchState(),
      sermonState: SermonState(),
      communitySearchState: CommunitySearchState(),
    ),
    // Passa o serviço de pagamento escolhido para a função que cria os middlewares.
    middleware: createAppMiddleware(paymentService),
  );
}

// Cria a instância GLOBAL e ÚNICA da sua store para todo o aplicativo.
final Store<AppState> store = createStore();
