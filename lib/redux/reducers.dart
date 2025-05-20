// redux/reducers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/metadata_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart';
import 'package:resumo_dos_deuses_flutter/design/theme.dart'; // Importar seus temas
import 'package:cloud_firestore/cloud_firestore.dart';

import 'actions.dart';

// Enum para identificar os temas
enum AppThemeOption {
  green, // Tema verde original
  septimaDark,
  septimaLight,
}

class ThemeState {
  final AppThemeOption activeThemeOption; // Armazena a opção do tema
  final ThemeData activeThemeData; // Armazena o ThemeData correspondente

  ThemeState({
    required this.activeThemeOption,
    required this.activeThemeData,
  });

  factory ThemeState.initial() {
    // Define o tema verde como padrão inicial
    return ThemeState(
      activeThemeOption: AppThemeOption.green,
      activeThemeData: AppTheme.greenTheme,
    );
  }

  ThemeState copyWith({
    AppThemeOption? activeThemeOption,
    ThemeData? activeThemeData,
  }) {
    return ThemeState(
      activeThemeOption: activeThemeOption ?? this.activeThemeOption,
      activeThemeData: activeThemeData ?? this.activeThemeData,
    );
  }
}

// Helper para obter ThemeData a partir da opção
ThemeData _getThemeDataFromOption(AppThemeOption option) {
  switch (option) {
    case AppThemeOption.green:
      return AppTheme.greenTheme;
    case AppThemeOption.septimaDark:
      return AppTheme.septimaDarkTheme;
    case AppThemeOption.septimaLight:
      return AppTheme.septimaLightTheme;
    default:
      return AppTheme.greenTheme; // Padrão
  }
}

ThemeState themeReducer(ThemeState state, dynamic action) {
  if (action is SetThemeAction) {
    return state.copyWith(
      activeThemeOption: action.themeOption,
      activeThemeData: _getThemeDataFromOption(action.themeOption),
    );
  }
  return state;
}

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
  final Map<String, dynamic>? userDetails;
  final Map<String, List<Map<String, String>>> userBooks;
  final Map<String, List<String>> topicSaves;
  final List<Map<String, dynamic>> booksInProgress;
  final List<Map<String, dynamic>> searchResults;
  final Map<String, List<Map<String, dynamic>>> savedTopicsContent;
  final List<Map<String, dynamic>> booksInProgressDetails;
  final List<Map<String, dynamic>> rotaAtual;
  final List<Map<String, dynamic>> userRoutes;
  final Map<String, List<Map<String, dynamic>>> verseSaves;
  final List<Map<String, dynamic>> userDiaries;

  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;

  final String? initialBibleBook;
  final int? initialBibleChapter;

  final List<Map<String, dynamic>> readingHistory;
  final String? lastReadBookAbbrev;
  final int? lastReadChapter;

  final List<Map<String, dynamic>> userCommentHighlights;
  final int? targetBottomNavIndex;

  final int userCoins;
  final DateTime? lastRewardedAdWatchTime;
  final int rewardedAdsWatchedToday;

  final Map<String, Set<String>> readSectionsByBook;
  final Map<String, int> totalSectionsPerBook;
  final Map<String, bool> bookCompletionStatus;

  final Map<String, BibleBookProgressData> allBooksProgress;
  final bool isLoadingAllBibleProgress; // NOVA FLAG
  final String? bibleProgressError; // NOVO CAMPO DE ERRO

  final List<Map<String, dynamic>> pendingFirestoreWrites;
  final Map<String, Set<String>> pendingSectionsToAdd;
  final Map<String, Set<String>> pendingSectionsToRemove;

  UserState({
    this.userId,
    this.email,
    this.nome,
    this.isLoggedIn = false,
    this.tags = const [],
    this.userDetails,
    this.userBooks = const {},
    this.topicSaves = const {},
    this.booksInProgress = const [],
    this.searchResults = const [],
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
    this.targetBottomNavIndex,
    this.userCoins = 0,
    this.lastRewardedAdWatchTime,
    this.rewardedAdsWatchedToday = 0,
    this.readSectionsByBook = const {},
    this.totalSectionsPerBook = const {},
    this.bookCompletionStatus = const {},
    this.allBooksProgress = const {},
    this.isLoadingAllBibleProgress = false, // Valor inicial da nova flag
    this.bibleProgressError, // Valor inicial do novo erro
    this.pendingSectionsToAdd = const {}, // Inicializa
    this.pendingSectionsToRemove = const {}, // Inicializa
    this.pendingFirestoreWrites = const [],
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
    List<Map<String, dynamic>>? userCommentHighlights,
    int? targetBottomNavIndex,
    bool clearTargetBottomNavIndex = false,
    int? userCoins,
    DateTime? lastRewardedAdWatchTime,
    bool clearLastRewardedAdWatchTime = false,
    int? rewardedAdsWatchedToday,
    Map<String, Set<String>>? readSectionsByBook,
    Map<String, int>? totalSectionsPerBook,
    Map<String, bool>? bookCompletionStatus,
    Map<String, BibleBookProgressData>? allBooksProgress,
    bool? isLoadingAllBibleProgress, // Adicionado ao copyWith
    String? bibleProgressError, // Adicionado ao copyWith
    bool clearBibleProgressError = false, // Para limpar o erro
    Map<String, Set<String>>? pendingSectionsToAdd, // Adicionado
    Map<String, Set<String>>? pendingSectionsToRemove, // Adicionado
    List<Map<String, dynamic>>? pendingFirestoreWrites,
  }) {
    return UserState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      nome: nome ?? this.nome,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      tags: tags ?? this.tags,
      userDetails: userDetails ?? this.userDetails,
      userBooks: userBooks ?? this.userBooks,
      topicSaves: topicSaves ?? this.topicSaves,
      booksInProgress: booksInProgress ?? this.booksInProgress,
      searchResults: searchResults ?? this.searchResults,
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
      targetBottomNavIndex: clearTargetBottomNavIndex
          ? null
          : (targetBottomNavIndex ?? this.targetBottomNavIndex),
      userCoins: userCoins ?? this.userCoins,
      lastRewardedAdWatchTime: clearLastRewardedAdWatchTime
          ? null
          : (lastRewardedAdWatchTime ?? this.lastRewardedAdWatchTime),
      rewardedAdsWatchedToday:
          rewardedAdsWatchedToday ?? this.rewardedAdsWatchedToday,
      readSectionsByBook: readSectionsByBook ?? this.readSectionsByBook,
      totalSectionsPerBook: totalSectionsPerBook ?? this.totalSectionsPerBook,
      bookCompletionStatus: bookCompletionStatus ?? this.bookCompletionStatus,
      allBooksProgress: allBooksProgress ?? this.allBooksProgress,
      isLoadingAllBibleProgress:
          isLoadingAllBibleProgress ?? this.isLoadingAllBibleProgress,
      bibleProgressError: clearBibleProgressError
          ? null
          : bibleProgressError ?? this.bibleProgressError,
      pendingFirestoreWrites:
          pendingFirestoreWrites ?? this.pendingFirestoreWrites,
      pendingSectionsToAdd:
          pendingSectionsToAdd ?? this.pendingSectionsToAdd, // Adicionado
      pendingSectionsToRemove:
          pendingSectionsToRemove ?? this.pendingSectionsToRemove, // Adicionado
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
      userCoins: state.userDetails?['userCoins'] as int? ??
          100, // Define 100 como padrão
    );
  } else if (action is UserStatsLoadedAction) {
    return state.copyWith(
      userDetails: action.stats,
      userCoins: action.stats['userCoins'] as int? ?? state.userCoins,
      lastRewardedAdWatchTime:
          (action.stats['lastRewardedAdWatchTime'] as Timestamp?)?.toDate(),
      rewardedAdsWatchedToday:
          action.stats['rewardedAdsWatchedToday'] as int? ?? 0,
    );
  } else if (action is TagsLoadedAction) {
    print("Tags adicionadas ao estado do usuário: ${action.tags}"); // Debug
    return state.copyWith(tags: action.tags);
  } else if (action is UserLoggedOutAction) {
    return UserState(); // Retorna o estado inicial, usuário deslogado
  } else if (action is UserDetailsLoadedAction) {
    return state.copyWith(
      userDetails: action.userDetails,
      lastReadBookAbbrev: action.userDetails['lastReadBookAbbrev'] as String?,
      lastReadChapter: action.userDetails['lastReadChapter'] as int?,
      userCoins: action.userDetails['userCoins'] as int? ?? state.userCoins,
      lastRewardedAdWatchTime:
          (action.userDetails['lastRewardedAdWatchTime'] as Timestamp?)
              ?.toDate(),
      rewardedAdsWatchedToday:
          action.userDetails['rewardedAdsWatchedToday'] as int? ?? 0,
    );
  } else if (action is UpdateUserUidAction) {
    return state.copyWith(userId: action.uid);
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
  } else if (action is TopicsLoadedAction) {
    return state.copyWith(
      userTribeRecommendations: action.topics,
    );
  } else if (action is FirstLoginSuccessAction) {
    return state.copyWith(isFirstLogin: action.isFirstLogin);
  } else if (action is FirstLoginFailureAction) {
    return state.copyWith(isFirstLogin: null);
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
  } else if (action is SubscriptionStatusUpdatedAction) {
    final updatedDetails = Map<String, dynamic>.from(state.userDetails ?? {});
    updatedDetails['stripeCustomerId'] = action.customerId;
    updatedDetails['subscriptionStatus'] = action.status;
    updatedDetails['subscriptionEndDate'] = action.endDate;
    updatedDetails['stripeSubscriptionId'] = action.subscriptionId;
    updatedDetails['activePriceId'] = action.priceId;
    return state.copyWith(userDetails: updatedDetails);
  } else if (action is UserHighlightsLoadedAction) {
    return state.copyWith(userHighlights: action.highlights);
  } else if (action is ToggleHighlightAction) {
    return state;
  } else if (action is UserNotesLoadedAction) {
    return state.copyWith(userNotes: action.notes);
  } else if (action is SaveNoteAction) {
    return state;
  } else if (action is DeleteNoteAction) {
    return state;
  } else if (action is SetInitialBibleLocationAction) {
    return state.copyWith(
        initialBibleBook: action.bookAbbrev,
        initialBibleChapter: action.chapter);
  } else if (action is ReadingHistoryLoadedAction) {
    return state.copyWith(readingHistory: action.history);
  } else if (action is UpdateLastReadLocationAction) {
    return state.copyWith(
        lastReadBookAbbrev: action.bookAbbrev, lastReadChapter: action.chapter);
  } else if (action is UserCommentHighlightsLoadedAction) {
    return state.copyWith(userCommentHighlights: action.commentHighlights);
  } else if (action is RequestBottomNavChangeAction) {
    return state.copyWith(targetBottomNavIndex: action.index);
  } else if (action is ClearTargetBottomNavAction) {
    return state.copyWith(clearTargetBottomNavIndex: true);
  } else if (action is RewardedAdWatchedAction) {
    int currentCoins = state.userCoins;
    int coinsToAdd = action.coinsAwarded;
    int newTotalCoins = currentCoins + coinsToAdd;
    if (newTotalCoins > 100) {
      newTotalCoins = 100;
    }
    DateTime now = DateTime.now();
    int updatedAdsWatchedToday = state.rewardedAdsWatchedToday + 1;
    if (state.lastRewardedAdWatchTime != null) {
      final lastWatchDate = state.lastRewardedAdWatchTime!;
      if (now.year > lastWatchDate.year ||
          now.month > lastWatchDate.month ||
          now.day > lastWatchDate.day) {
        updatedAdsWatchedToday = 1;
      }
    }
    return state.copyWith(
      userCoins: newTotalCoins,
      lastRewardedAdWatchTime: action.adWatchTime,
      rewardedAdsWatchedToday: updatedAdsWatchedToday,
    );
  } else if (action is LoadAllBibleProgressAction) {
    // <<< NOVO
    return state.copyWith(
      isLoadingAllBibleProgress: true,
      clearBibleProgressError: true, // Limpa erro anterior ao tentar carregar
    );
  } else if (action is AllBibleProgressLoadedAction) {
    // <<< ATUALIZADO
    final newReadSectionsByBook = <String, Set<String>>{};
    final newTotalSectionsPerBook = <String, int>{};
    final newBookCompletionStatus = <String, bool>{};

    action.progressData.forEach((bookAbbrev, data) {
      newReadSectionsByBook[bookAbbrev] = data.readSections;
      newTotalSectionsPerBook[bookAbbrev] = data.totalSections;
      newBookCompletionStatus[bookAbbrev] = data.completed;
    });

    return state.copyWith(
      allBooksProgress: action.progressData,
      readSectionsByBook: newReadSectionsByBook,
      totalSectionsPerBook: newTotalSectionsPerBook,
      bookCompletionStatus: newBookCompletionStatus,
      isLoadingAllBibleProgress: false, // Finaliza o carregamento
    );
  } else if (action is BibleBookProgressLoadedAction) {
    // <<< ATUALIZADO/REVISADO
    final newReadSectionsByBook =
        Map<String, Set<String>>.from(state.readSectionsByBook);
    newReadSectionsByBook[action.bookAbbrev] = action.readSections;

    final newTotalSectionsPerBook =
        Map<String, int>.from(state.totalSectionsPerBook);
    newTotalSectionsPerBook[action.bookAbbrev] = action.totalSectionsInBook;

    final newBookCompletionStatus =
        Map<String, bool>.from(state.bookCompletionStatus);
    newBookCompletionStatus[action.bookAbbrev] = action.isCompleted;

    // Atualiza também o allBooksProgress para este livro específico
    final newAllBooksProgress =
        Map<String, BibleBookProgressData>.from(state.allBooksProgress);
    newAllBooksProgress[action.bookAbbrev] = BibleBookProgressData(
      readSections: action.readSections,
      totalSections: action.totalSectionsInBook,
      completed: action.isCompleted,
      lastReadTimestamp: action.lastReadTimestamp,
    );

    return state.copyWith(
      readSectionsByBook: newReadSectionsByBook,
      totalSectionsPerBook: newTotalSectionsPerBook,
      bookCompletionStatus: newBookCompletionStatus,
      allBooksProgress: newAllBooksProgress, // Importante atualizar este também
      isLoadingAllBibleProgress:
          false, // Pode setar para false se esta ação também indica fim de um loading geral
      clearBibleProgressError:
          true, // Limpa erro se o carregamento do livro específico foi bem sucedido
    );
  } else if (action is BibleProgressFailureAction) {
    // <<< NOVO
    return state.copyWith(
      isLoadingAllBibleProgress: false,
      bibleProgressError: action.error,
    );
  } else if (action is OptimisticToggleSectionReadStatusAction) {
    final newReadSectionsByBook = Map<String, Set<String>>.from(
        state.readSectionsByBook); // << Cria nova cópia do Map
    final sectionsForBookUI = Set<String>.from(
        newReadSectionsByBook[action.bookAbbrev] ??
            {}); // << Cria nova cópia do Set
    // OBTER OU CRIAR O SET PARA O LIVRO ATUAL, GARANTINDO QUE É UMA NOVA INSTÂNCIA
    final Set<String> sectionsForThisBook =
        Set<String>.from(newReadSectionsByBook[action.bookAbbrev] ?? {});
    print(
        "Reducer (Optimistic) ANTES - Livro: ${action.bookAbbrev}, Seção: ${action.sectionId}, Marcar: ${action.markAsRead}, Seções Atuais para este livro: $sectionsForThisBook");
    if (action.markAsRead) {
      sectionsForBookUI.add(action.sectionId);
    } else {
      sectionsForBookUI.remove(action.sectionId);
    }
    newReadSectionsByBook[action.bookAbbrev] = sectionsForBookUI;
    print(
        "Reducer (Optimistic) DEPOIS - Livro: ${action.bookAbbrev}, Seções Atualizadas para este livro: $sectionsForThisBook");
    print(
        "Reducer (Optimistic) DEPOIS - Conteúdo completo de newReadSectionsByBook: $newReadSectionsByBook");
    // 2. Atualiza as listas pendentes
    final newPendingToAdd =
        Map<String, Set<String>>.from(state.pendingSectionsToAdd);
    final newPendingToRemove =
        Map<String, Set<String>>.from(state.pendingSectionsToRemove);

    final bookToAddSet =
        Set<String>.from(newPendingToAdd[action.bookAbbrev] ?? {});
    final bookToRemoveSet =
        Set<String>.from(newPendingToRemove[action.bookAbbrev] ?? {});

    if (action.markAsRead) {
      bookToAddSet.add(action.sectionId);
      bookToRemoveSet
          .remove(action.sectionId); // Se estava para remover, cancela
    } else {
      bookToRemoveSet.add(action.sectionId);
      bookToAddSet
          .remove(action.sectionId); // Se estava para adicionar, cancela
    }

    newPendingToAdd[action.bookAbbrev] = bookToAddSet;
    newPendingToRemove[action.bookAbbrev] = bookToRemoveSet;
    print(
        "Reducer (Optimistic) - Pending Add: $newPendingToAdd, Pending Remove: $newPendingToRemove");
    return state.copyWith(
        readSectionsByBook: newReadSectionsByBook,
        pendingSectionsToAdd: newPendingToAdd,
        pendingSectionsToRemove: newPendingToRemove);
  } else if (action is EnqueueFirestoreWriteAction) {
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites);
    final operationWithId = Map<String, dynamic>.from(action.operation);
    if (operationWithId['id'] == null) {
      operationWithId['id'] = DateTime.now().millisecondsSinceEpoch.toString() +
          '_' +
          (newPendingWrites.length).toString();
    }
    newPendingWrites.add(operationWithId);
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  } else if (action is FirestoreWriteSuccessfulAction) {
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites);
    newPendingWrites.removeWhere((op) => op['id'] == action.operationId);
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  } else if (action is FirestoreWriteFailedAction) {
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites);
    newPendingWrites.removeWhere((op) => op['id'] == action.operationId);
    print(
        "Reducer: Operação ${action.operationId} removida da fila (FALHA): ${action.error}");
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  } else if (action is ClearPendingBibleProgressAction) {
    final newPendingToAdd =
        Map<String, Set<String>>.from(state.pendingSectionsToAdd);
    final newPendingToRemove =
        Map<String, Set<String>>.from(state.pendingSectionsToRemove);

    newPendingToAdd.remove(action.bookAbbrev);
    newPendingToRemove.remove(action.bookAbbrev);

    return state.copyWith(
        pendingSectionsToAdd: newPendingToAdd,
        pendingSectionsToRemove: newPendingToRemove);
  } else if (action is LoadedPendingBibleProgressAction) {
    return state.copyWith(
      pendingSectionsToAdd: action.pendingToAdd,
      pendingSectionsToRemove: action.pendingToRemove,
    );
  }
  return state;
}

class AuthorState {
  final Map<String, dynamic>? authorDetails;
  final List<Map<String, dynamic>> authorBooks;
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
    return state.copyWith(
      authorsList: action.authors,
    );
  }
  return state;
}

class TopicState {
  final Map<String, String> topicsContent;
  final Map<String, String> topicsTitles;
  final Map<String, List<Map<String, dynamic>>> similarTopics;
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

class BibleSearchState {
  final bool isLoading;
  final List<Map<String, dynamic>> results;
  final String? error;
  final Map<String, dynamic> activeFilters;
  final String currentQuery;

  BibleSearchState({
    this.isLoading = false,
    this.results = const [],
    this.error,
    this.activeFilters = const {},
    this.currentQuery = "",
  });

  BibleSearchState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? results,
    String? error,
    Map<String, dynamic>? activeFilters,
    String? currentQuery,
    bool clearError = false,
    bool clearResults = false,
  }) {
    return BibleSearchState(
      isLoading: isLoading ?? this.isLoading,
      results: clearResults ? [] : results ?? this.results,
      error: clearError ? null : error ?? this.error,
      activeFilters: activeFilters ?? this.activeFilters,
      currentQuery: currentQuery ?? this.currentQuery,
    );
  }
}

BibleSearchState bibleSearchReducer(BibleSearchState state, dynamic action) {
  if (action is SearchBibleSemanticAction) {
    return state.copyWith(
      isLoading: true,
      currentQuery: action.query,
      clearError: true,
      clearResults: true,
    );
  }
  if (action is SetBibleSearchFilterAction) {
    final newFilters = Map<String, dynamic>.from(state.activeFilters);
    if (action.filterValue == null ||
        (action.filterValue is String && action.filterValue.isEmpty)) {
      newFilters.remove(action.filterKey);
    } else {
      newFilters[action.filterKey] = action.filterValue;
    }
    return state.copyWith(activeFilters: newFilters);
  }
  if (action is ClearBibleSearchFiltersAction) {
    return state.copyWith(activeFilters: {});
  }
  if (action is SearchBibleSemanticSuccessAction) {
    return state.copyWith(isLoading: false, results: action.results);
  }
  if (action is SearchBibleSemanticFailureAction) {
    return state.copyWith(isLoading: false, error: action.error);
  }
  return state;
}

class BibleBookProgressData {
  final Set<String> readSections;
  final int totalSections;
  final bool completed;
  final Timestamp? lastReadTimestamp;

  BibleBookProgressData({
    required this.readSections,
    required this.totalSections,
    this.completed = false,
    this.lastReadTimestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleBookProgressData &&
          runtimeType == other.runtimeType &&
          setEquals(readSections, other.readSections) &&
          totalSections == other.totalSections &&
          completed == other.completed &&
          lastReadTimestamp == other.lastReadTimestamp;

  @override
  int get hashCode =>
      readSections.hashCode ^
      totalSections.hashCode ^
      completed.hashCode ^
      lastReadTimestamp.hashCode;
}

// Reducer para MetadataState (colocado aqui para manter junto com outros reducers por enquanto)
// Idealmente, poderia estar em reducers/metadata_reducer.dart e importado no store.dart
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
