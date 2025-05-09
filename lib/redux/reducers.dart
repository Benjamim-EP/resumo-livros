// redux/reducers.dart
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart';

import 'actions.dart';

class BooksState {
  final Map<String, List<Map<String, String>>> booksByTag; // Livros por tag
  final bool isLoading;
  final Map<String, dynamic>? bookDetails; // Detalhes de um único livro
  final Map<String, dynamic> booksProgress; // Progresso dos livros
  final int nTopicos;
  final List<Map<String, dynamic>> weeklyRecommendations; // Indicação semanal ✅
  final Set<String> booksReading;

  BooksState(
      {this.booksByTag = const {},
      this.isLoading = false,
      this.bookDetails,
      this.booksProgress = const {},
      this.nTopicos = 1,
      this.weeklyRecommendations = const [], // ✅ Inicializa corretamente
      this.booksReading = const {}});

  BooksState copyWith(
      {Map<String, List<Map<String, String>>>? booksByTag,
      bool? isLoading,
      Map<String, dynamic>? bookDetails,
      Map<String, dynamic>? booksProgress,
      int? nTopicos,
      List<Map<String, dynamic>>?
          weeklyRecommendations, // ✅ Adicionado no copyWith
      Set<String>? booksReading}) {
    return BooksState(
      booksByTag: booksByTag ?? this.booksByTag,
      isLoading: isLoading ?? this.isLoading,
      bookDetails: bookDetails ?? this.bookDetails,
      booksProgress: booksProgress ?? this.booksProgress,
      nTopicos: nTopicos ?? this.nTopicos,
      weeklyRecommendations: weeklyRecommendations ??
          this.weeklyRecommendations, // ✅ Agora atualizado corretamente
      booksReading: booksReading ?? this.booksReading,
    );
  }
}

BooksState booksReducer(BooksState state, dynamic action) {
  if (action is MarkBookAsReadingAction) {
    final updatedBooksReading = Set<String>.from(state.booksReading)
      ..add(action.bookId);
    return state.copyWith(booksReading: updatedBooksReading);
  } else if (action is WeeklyRecommendationsLoadedAction) {
    return state.copyWith(weeklyRecommendations: action.books);
  } else if (action is BooksLoadedByTagAction) {
    return state.copyWith(
      booksByTag: {
        ...state.booksByTag,
        action.tag: action.books,
      },
    );
  } else if (action is BookDetailsLoadedAction) {
    //print('Reducer: Atualizando estado com detalhes do livro ${action.bookId}');
    return state.copyWith(
      bookDetails: {...?state.bookDetails, action.bookId: action.bookDetails},
    );
  } else if (action is StartBookProgressAction) {
    final updatedBooksProgress = Map<String, dynamic>.from(state.booksProgress);
    updatedBooksProgress[action.bookId] ??= {'progress': 0, 'readTopics': []};
    return state.copyWith(booksProgress: updatedBooksProgress);
  } else if (action is MarkTopicAsReadAction) {
    final updatedBooksProgress = Map<String, dynamic>.from(state.booksProgress);
    final bookProgress = Map<String, dynamic>.from(
        updatedBooksProgress[action.bookId] ?? {'readTopics': <String>[]});

    final readTopics = List<String>.from(bookProgress['readTopics'] ?? []);
    if (!readTopics.contains(action.topicId)) {
      readTopics.add(action.topicId);
      bookProgress['readTopics'] = readTopics;

      // Atualiza progresso baseado no número de capítulos lidos
      final totalChapters =
          (state.bookDetails?[action.bookId]?['chapters']?.length ?? 1);
      bookProgress['progress'] =
          ((readTopics.length / totalChapters) * 100).toInt();

      updatedBooksProgress[action.bookId] = bookProgress;
    }

    return state.copyWith(booksProgress: updatedBooksProgress);
  } else if (action is LoadBookProgressSuccessAction) {
    final updatedBooksProgress = Map<String, dynamic>.from(state.booksProgress);

    updatedBooksProgress[action.bookId] = {
      ...(updatedBooksProgress[action.bookId] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          {},
      'readTopics': List<String>.from(action.readTopics ?? []),
    };

    return state.copyWith(booksProgress: updatedBooksProgress);
  }
  return state;
}

class UserState {
  final String? userId;
  final String? email;
  final String? nome;
  final bool isLoggedIn;
  final List<String> tags;
  final Map<String, dynamic>? userDetails; // informações gerais do usuário
  final Map<String, List<Map<String, String>>> userBooks;
  final Map<String, List<String>> topicSaves;
  final List<Map<String, dynamic>> booksInProgress;
  final Map<String, dynamic>? userFeatures;
  final List<Map<String, dynamic>>? userTribeRecommendations;
  final List<Map<String, dynamic>> searchResults;
  final bool? isFirstLogin;
  final List<Map<String, dynamic>> tribeTopics;
  final Map<String, List<Map<String, dynamic>>> tribeTopicsByFeature;
  final Map<String, List<Map<String, dynamic>>> savedTopicsContent;
  final List<Map<String, dynamic>> booksInProgressDetails;
  final List<Map<String, dynamic>> rotaAtual;
  final List<Map<String, dynamic>> userRoutes;
  final Map<String, List<Map<String, dynamic>>> verseSaves;
  final List<Map<String, dynamic>>
      userDiaries; // 🔹 Novo campo para armazenar os diários

  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;

  final String? initialBibleBook;
  final int? initialBibleChapter;

  final List<Map<String, dynamic>> readingHistory; // Histórico carregado
  final String? lastReadBookAbbrev; // Último livro lido na sessão/carregado
  final int? lastReadChapter; // Último capítulo lido na sessão/

  final List<Map<String, dynamic>> userCommentHighlights;

  UserState({
    this.userId,
    this.email,
    this.nome,
    this.isLoggedIn = false,
    this.isFirstLogin,
    this.tags = const [],
    this.userDetails,
    this.userBooks = const {},
    this.topicSaves = const {},
    this.booksInProgress = const [],
    this.userFeatures,
    this.userTribeRecommendations,
    this.searchResults = const [],
    this.tribeTopics = const [],
    this.tribeTopicsByFeature = const {},
    this.savedTopicsContent = const {},
    this.booksInProgressDetails = const [],
    this.rotaAtual = const [],
    this.userRoutes = const [],
    this.verseSaves = const {},
    this.userDiaries = const [],
    this.userHighlights = const {},
    this.userNotes = const {},
    this.initialBibleBook,
    this.initialBibleChapter,
    this.readingHistory = const [],
    this.lastReadBookAbbrev,
    this.lastReadChapter,
    this.userCommentHighlights = const [],
  });

  UserState copyWith({
    String? userId,
    String? email,
    String? nome,
    bool? isLoggedIn,
    bool? isFirstLogin,
    List<String>? tags,
    Map<String, dynamic>? userDetails,
    Map<String, List<Map<String, String>>>? userBooks,
    Map<String, List<String>>? topicSaves,
    List<Map<String, dynamic>>? booksInProgress,
    Map<String, dynamic>? userFeatures,
    List<Map<String, dynamic>>? userTribeRecommendations,
    List<Map<String, dynamic>>? searchResults,
    List<Map<String, dynamic>>? tribeTopics,
    Map<String, List<Map<String, dynamic>>>? tribeTopicsByFeature,
    List<Map<String, dynamic>>? booksInProgressDetails,
    Map<String, List<Map<String, dynamic>>>? savedTopicsContent,
    List<Map<String, dynamic>>? rotaAtual,
    List<Map<String, dynamic>>? userRoutes,
    Map<String, List<Map<String, dynamic>>>? verseSaves,
    List<Map<String, dynamic>>? userDiaries,
    Map<String, String>? userHighlights,
    Map<String, String>? userNotes,
    String? initialBibleBook,
    int? initialBibleChapter,
    List<Map<String, dynamic>>? readingHistory,
    String? lastReadBookAbbrev,
    int? lastReadChapter,
    List<Map<String, dynamic>>? userCommentHighlights, // NOVO
  }) {
    return UserState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      nome: nome ?? this.nome,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      tags: tags ?? this.tags,
      userDetails: userDetails ?? this.userDetails,
      userBooks: userBooks ?? this.userBooks,
      topicSaves: topicSaves ?? this.topicSaves,
      booksInProgress: booksInProgress ?? this.booksInProgress,
      userFeatures: userFeatures ?? this.userFeatures,
      userTribeRecommendations:
          userTribeRecommendations ?? this.userTribeRecommendations,
      searchResults: searchResults ?? this.searchResults,
      tribeTopics: tribeTopics ?? this.tribeTopics,
      tribeTopicsByFeature: tribeTopicsByFeature ?? this.tribeTopicsByFeature,
      savedTopicsContent: savedTopicsContent ?? this.savedTopicsContent,
      booksInProgressDetails:
          booksInProgressDetails ?? this.booksInProgressDetails,
      rotaAtual: rotaAtual ?? this.rotaAtual,
      userRoutes: userRoutes ?? this.userRoutes,
      verseSaves: verseSaves ?? this.verseSaves,
      userDiaries: userDiaries ?? this.userDiaries,
      userHighlights: userHighlights ?? this.userHighlights,
      userNotes: userNotes ?? this.userNotes,
      initialBibleBook: initialBibleBook ?? this.initialBibleBook,
      initialBibleChapter: initialBibleChapter ?? this.initialBibleChapter,
      readingHistory: readingHistory ?? this.readingHistory,
      lastReadBookAbbrev: lastReadBookAbbrev ?? this.lastReadBookAbbrev,
      lastReadChapter: lastReadChapter ?? this.lastReadChapter,
      userCommentHighlights:
          userCommentHighlights ?? this.userCommentHighlights,
    );
  }
}

UserState userReducer(UserState state, dynamic action) {
  if (action is LoadUserDiariesSuccessAction) {
    return state.copyWith(userDiaries: action.diaries);
  } else if (action is UserVerseCollectionsUpdatedAction) {
    return state.copyWith(verseSaves: action.verseSaves);
  } else if (action is UserLoggedInAction) {
    return state.copyWith(
      userId: action.userId,
      email: action.email,
      nome: action.nome,
      isLoggedIn: true,
    );
  } else if (action is TagsLoadedAction) {
    print("Tags adicionadas ao estado do usuário: ${action.tags}"); // Debug
    return state.copyWith(tags: action.tags);
  } else if (action is UserLoggedOutAction) {
    return UserState(); // Retorna o estado inicial, usuário deslogado
  } else if (action is UserDetailsLoadedAction) {
    return state.copyWith(userDetails: action.userDetails);
  } else if (action is UserLoggedInAction) {
    return state.copyWith(
      userId: action.userId,
      email: action.email,
      nome: action.nome,
      isLoggedIn: true,
    );
  } else if (action is UpdateUserUidAction) {
    return state.copyWith(userId: action.uid);
  } else if (action is UserStatsLoadedAction) {
    return state.copyWith(userDetails: action.stats);
  } else if (action is UserTopicCollectionsLoadedAction) {
    return state.copyWith(topicSaves: action.topicSaves);
  } else if (action is UserCollectionsLoadedAction) {
    return state.copyWith(topicSaves: action.topicSaves);
  } else if (action is SaveTopicToCollectionAction) {
    final updatedCollections = Map<String, List<String>>.from(state.topicSaves);

    if (!updatedCollections.containsKey(action.collectionName)) {
      updatedCollections[action.collectionName] = [];
    }

    final collection = updatedCollections[action.collectionName]!;
    if (!collection.contains(action.topicId)) {
      collection.add(action.topicId);
    }

    return state.copyWith(topicSaves: updatedCollections);
  } else if (action is BooksInProgressLoadedAction) {
    return state.copyWith(booksInProgress: action.books);
  } else if (action is UserStatsLoadedAction) {
    return state.copyWith(userDetails: action.stats);
  } else if (action is UserFeaturesLoadedAction) {
    return state.copyWith(userFeatures: action.features);
  } else if (action is EmbedAndSearchSuccessAction) {
    //print("Recomendações de tribo recebidas:");
    //print(action.recommendations); // Exibe as recomendações no console
    return state.copyWith(
      userTribeRecommendations: action.recommendations,
    );
  } else if (action is EmbedAndSearchFailureAction) {
    print('Erro no middleware de embedding: ${action.error}');
    return state;
  } else if (action is SearchSuccessAction) {
    return state.copyWith(
      searchResults: action.topics,
    );
  } else if (action is SearchFailureAction) {
    print(action.error); // Log para depuração
  } else if (action is TopicsLoadedAction) {
    return state.copyWith(
      userTribeRecommendations: action.topics,
    );
  } else if (action is FirstLoginSuccessAction) {
    return state.copyWith(isFirstLogin: action.isFirstLogin);
  } else if (action is FirstLoginFailureAction) {
    return state.copyWith(isFirstLogin: null);
  } else if (action is FetchTribeTopicsSuccessAction) {
    return state.copyWith(
      tribeTopicsByFeature: action.topicsByFeature,
    );
  } else if (action is FetchTribeTopicsFailureAction) {
    print('Erro ao buscar tópicos: ${action.error}');
    return state; // Retorna o estado anterior sem alteração
  } else if (action is TopicsByFeatureLoadedAction) {
    return state.copyWith(
      tribeTopicsByFeature: action.topicsByFeature,
    );
  } else if (action is LoadTopicsContentUserSavesSuccessAction) {
    return state.copyWith(
      savedTopicsContent: action.topicsByCollection,
    );
  } else if (action is LoadTopicsContentUserSavesFailureAction) {
    print('Erro ao carregar conteúdo dos tópicos salvos: ${action.error}');
    return state; // Retorna o estado sem alterações
  } else if (action is LoadBooksUserProgressSuccessAction) {
    return state.copyWith(booksInProgress: action.books);
  } else if (action is LoadBooksUserProgressFailureAction) {
    print(action.error); // Log para depuração
    return state; // Retorna o estado atual sem alterações
  } else if (action is LoadBooksDetailsSuccessAction) {
    return state.copyWith(booksInProgressDetails: action.bookDetails);
  } else if (action is LoadBooksDetailsFailureAction) {
    print(action.error); // Log para depuração
    return state;
  } else if (action is AddTopicToRouteAction) {
    final updatedRotaAtual = List<Map<String, dynamic>>.from(state.rotaAtual);

    // Verifique se o tópico já existe na rotaAtual antes de adicionar
    if (!updatedRotaAtual.any((topic) => topic['id'] == action.topicId)) {
      updatedRotaAtual.add({'id': action.topicId});
    }

    return state.copyWith(rotaAtual: updatedRotaAtual);
  } else if (action is ClearRouteAction) {
    return state.copyWith(rotaAtual: []);
  } else if (action is UserRoutesLoadedAction) {
    return state.copyWith(userRoutes: action.routes);
  } else if (action is UserRoutesLoadFailedAction) {
    print(action.error); // Log de erro
  } else if (action is DeleteTopicCollectionAction) {
    final updatedTopicSaves = Map<String, List<String>>.from(state.topicSaves);
    updatedTopicSaves.remove(action.collectionName);
    return state.copyWith(topicSaves: updatedTopicSaves);
  } else if (action is DeleteSingleTopicFromCollectionAction) {
    final updatedTopicSaves = Map<String, List<String>>.from(state.topicSaves);
    final updatedTopics = List<String>.from(
      updatedTopicSaves[action.collectionName] ?? [],
    );
    updatedTopics.remove(action.topicId);
    updatedTopicSaves[action.collectionName] = updatedTopics;
    return state.copyWith(topicSaves: updatedTopicSaves);
  } else if (action is UserPremiumStatusLoadedAction) {
    // MODO ANTIGO (baseado no isPremium map) - Pode ser mantido por compatibilidade ou removido
    // return state.copyWith(userDetails: {
    //   ...state.userDetails ?? {},
    //   'isPremium': action.premiumStatus,
    // });
    // MODO NOVO (atualiza campos específicos de assinatura)
    // A ação agora seria SubscriptionStatusUpdatedAction
    return state; // Não faz nada aqui, espera a nova ação
  } else if (action is SubscriptionStatusUpdatedAction) {
    // Atualiza os campos detalhados da assinatura no userDetails
    final updatedDetails = Map<String, dynamic>.from(state.userDetails ?? {});
    updatedDetails['stripeCustomerId'] = action.customerId;
    updatedDetails['subscriptionStatus'] = action.status;
    updatedDetails['subscriptionEndDate'] =
        action.endDate; // Pode ser Timestamp ou null
    updatedDetails['stripeSubscriptionId'] =
        action.subscriptionId; // Pode ser String ou null
    updatedDetails['activePriceId'] = action.priceId; // Pode ser String ou null

    // print(
    //     "Reducer: Atualizando estado com dados da assinatura: Status=${action.status}, EndDate=${action.endDate?.toDate()}");

    return state.copyWith(userDetails: updatedDetails);
  } else if (action is UserHighlightsLoadedAction) {
    return state.copyWith(userHighlights: action.highlights);
  } else if (action is ToggleHighlightAction) {
    // A lógica de adicionar/remover/atualizar no Redux pode ser feita aqui
    // após o middleware confirmar a operação no Firestore.
    // Ou o middleware pode despachar UserHighlightsLoadedAction após a operação.
    // Vamos optar pelo segundo para manter o reducer mais simples.
    return state; // O middleware irá recarregar os highlights
  } else if (action is UserNotesLoadedAction) {
    return state.copyWith(userNotes: action.notes);
  } else if (action is SaveNoteAction) {
    return state; // Middleware recarrega
  } else if (action is DeleteNoteAction) {
    return state; // Middleware recarrega
  } else if (action is SetInitialBibleLocationAction) {
    return state.copyWith(
        initialBibleBook: action.bookAbbrev,
        initialBibleChapter: action.chapter);
  } else if (action is UserDetailsLoadedAction) {
    // Ao carregar detalhes do usuário, também pega a última leitura do Firestore
    return state.copyWith(
        userDetails: action.userDetails,
        lastReadBookAbbrev: action.userDetails['lastReadBookAbbrev'] as String?,
        lastReadChapter: action.userDetails['lastReadChapter'] as int?);
  } else if (action is ReadingHistoryLoadedAction) {
    return state.copyWith(readingHistory: action.history);
  } else if (action is UpdateLastReadLocationAction) {
    // Atualiza o último lido no estado Redux
    return state.copyWith(
        lastReadBookAbbrev: action.bookAbbrev, lastReadChapter: action.chapter);
  } else if (action is UserLoggedOutAction) {
    // Limpa o histórico e último lido ao fazer logout
    return UserState(); // Reseta para o estado inicial
  } else if (action is UserCommentHighlightsLoadedAction) {
    return state.copyWith(userCommentHighlights: action.commentHighlights);
  } else if (action is UserLoggedOutAction) {
    // Garante que limpa ao sair
    return UserState(); // Reseta para o estado inicial, limpando userCommentHighlights
  }

  return state;
}

class AuthorState {
  final Map<String, dynamic>? authorDetails; // Detalhes de um autor
  final List<Map<String, dynamic>> authorBooks; // Livros do autor
  final List<Map<String, dynamic>> authorsList;

  AuthorState({
    this.authorDetails,
    this.authorsList = const [],
    this.authorBooks = const [],
  });

  AuthorState copyWith({
    Map<String, dynamic>? authorDetails,
    List<Map<String, dynamic>>? authorsList,
    List<Map<String, dynamic>>? authorBooks,
  }) {
    return AuthorState(
      authorDetails: authorDetails ?? this.authorDetails,
      authorsList: authorsList ?? this.authorsList,
      authorBooks: authorBooks ?? this.authorBooks,
    );
  }
}

AuthorState authorReducer(AuthorState state, dynamic action) {
  if (action is AuthorDetailsLoadedAction) {
    return state.copyWith(authorDetails: action.authorDetails);
  } else if (action is AuthorBooksLoadedAction) {
    return state.copyWith(authorBooks: action.books);
  } else if (action is ClearAuthorDetailsAction) {
    return state.copyWith(authorDetails: null, authorBooks: []);
  } else if (action is AuthorsLoadedAction) {
    // Armazena a lista de autores no estado
    return state.copyWith(
      authorsList: action.authors, // Atualiza a lista de autores
    );
  }
  return state;
}

class TopicState {
  final Map<String, String> topicsContent; // Conteúdo dos tópicos
  final Map<String, String> topicsTitles; // Títulos dos tópicos
  final Map<String, List<Map<String, dynamic>>>
      similarTopics; // Tópicos similares
  final Map<String, Map<String, dynamic>> topicsMetadata;

  TopicState({
    this.topicsContent = const {},
    this.topicsTitles = const {},
    this.similarTopics = const {},
    this.topicsMetadata = const {},
  });

  TopicState copyWith({
    Map<String, String>? topicsContent,
    Map<String, String>? topicsTitles,
    Map<String, List<Map<String, dynamic>>>? similarTopics,
    Map<String, Map<String, dynamic>>? topicsMetadata,
  }) {
    return TopicState(
      topicsContent: topicsContent ?? this.topicsContent,
      topicsTitles: topicsTitles ?? this.topicsTitles,
      similarTopics: similarTopics ?? this.similarTopics,
      topicsMetadata: topicsMetadata ?? this.topicsMetadata,
    );
  }
}

TopicState topicReducer(TopicState state, dynamic action) {
  if (action is TopicContentLoadedAction) {
    return state.copyWith(
      topicsContent: {
        ...state.topicsContent,
        action.topicId: action.content,
      },
      topicsTitles: {
        ...state.topicsTitles,
        action.topicId: action.titulo,
      },
      topicsMetadata: {
        ...state.topicsMetadata,
        action.topicId: {
          'bookId': action.bookId,
          'capituloId': action.capituloId,
          'chapterName': action.chapterName,
          'chapterIndex': action.chapterIndex,
        },
      },
    );
  } else if (action is SimilarTopicsLoadedAction) {
    print('Reducer: Atualizando similarTopics para ${action.topicId}');
    return state.copyWith(
      similarTopics: {
        ...state.similarTopics,
        action.topicId: action.similarTopics,
      },
    );
  } else if (action is TopicMetadatasLoadedAction) {
    return state.copyWith(
      topicsMetadata: {
        ...state.topicsMetadata,
        action.topicId: action.topicMetadata,
      },
    );
  }
  return state;
}

class ChatState {
  final String? latestResponse;

  ChatState({this.latestResponse});

  ChatState copyWith({String? latestResponse}) {
    return ChatState(
      latestResponse: latestResponse ?? this.latestResponse,
    );
  }
}

ChatState chatReducer(ChatState state, dynamic action) {
  if (action is SendMessageSuccessAction) {
    return state.copyWith(latestResponse: action.botResponse);
  } else if (action is SendMessageFailureAction) {
    return state.copyWith(latestResponse: "Erro: ${action.error}");
  }
  return state;
}
