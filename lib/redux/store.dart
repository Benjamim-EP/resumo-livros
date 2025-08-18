// lib/redux/store.dart

import 'package:flutter/foundation.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/middleware/book_club_middleware.dart';
import 'package:septima_biblia/redux/middleware/cross_reference_middleware.dart';
import 'package:septima_biblia/redux/middleware/library_reference_middleware.dart';
import 'package:septima_biblia/redux/reducers/cross_reference_reducer.dart';
import 'package:septima_biblia/redux/reducers/library_reference_reducer.dart';

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

// ... (Sua classe AppState e appReducer permanecem iguais) ...
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
  final CrossReferenceState crossReferenceState;
  final LibraryReferenceState libraryReferenceState;

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
    required this.crossReferenceState,
    required this.libraryReferenceState,
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
    CrossReferenceState? crossReferenceState,
    LibraryReferenceState? libraryReferenceState,
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
      communitySearchState: communitySearchState ?? this.communitySearchState,
      crossReferenceState: crossReferenceState ?? this.crossReferenceState,
      libraryReferenceState:
          libraryReferenceState ?? this.libraryReferenceState,
    );
  }
}

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
    crossReferenceState:
        crossReferenceReducer(state.crossReferenceState, action),
    libraryReferenceState:
        libraryReferenceReducer(state.libraryReferenceState, action),
  );
}

// ==========================================================
// FUNÇÃO createAppMiddleware CORRIGIDA
// ==========================================================
List<Middleware<AppState>> createAppMiddleware({
  required IPaymentService paymentService,
  required bool useFakePayment, // Novo parâmetro para controlar o fake
}) {
  final commonMiddleware = [
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
    ...createCrossReferenceMiddleware(),
    ...createLibraryReferenceMiddleware(),
  ];

  if (useFakePayment) {
    print("<<<<< USANDO MIDDLEWARE DE PAGAMENTO FALSO (SIMULADOR) >>>>>");
    return [
      ...commonMiddleware,
      ...createFakePaymentMiddleware(), // Usa o simulador
    ];
  } else {
    print("<<<<< USANDO MIDDLEWARE DE PAGAMENTO REAL >>>>>");
    return [
      ...commonMiddleware,
      ...createPaymentMiddleware(paymentService), // Usa o serviço real
    ];
  }
}

// ==========================================================
// FUNÇÃO createStore CORRIGIDA E MELHORADA
// ==========================================================
Store<AppState> createStore() {
  const bool isPlayStoreBuild = bool.fromEnvironment('IS_PLAY_STORE');
  late IPaymentService paymentService;
  bool useFakePayment = false;

  // Lógica de 3 vias para clareza: Debug vs. Release Play Store vs. Release Site
  if (kDebugMode && !isPlayStoreBuild) {
    print("STORE INIT: MODO DEBUG detectado. Usando simulador de pagamento.");
    useFakePayment = true;
    // Em modo debug, não importa qual serviço real instanciamos,
    // pois o `useFakePayment` vai garantir que o middleware falso seja usado.
    // Mas, por consistência, podemos instanciar um.
    paymentService = GooglePlayPaymentService();
  } else if (isPlayStoreBuild) {
    print(
        "STORE INIT: MODO RELEASE (Play Store) detectado. Usando GooglePlayPaymentService.");
    paymentService = GooglePlayPaymentService();
    useFakePayment = false;
  } else {
    print(
        "STORE INIT: MODO RELEASE (Website/Stripe) detectado. Usando StripePaymentService.");
    paymentService = StripePaymentService();
    useFakePayment = false;
  }

  return Store<AppState>(
    appReducer,
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
      crossReferenceState: CrossReferenceState(),
      libraryReferenceState: LibraryReferenceState(),
    ),
    middleware: createAppMiddleware(
      paymentService: paymentService,
      useFakePayment: useFakePayment,
    ),
  );
}

// A instância global permanece a mesma
final Store<AppState> store = createStore();
