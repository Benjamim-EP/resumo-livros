// redux/reducers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/actions/metadata_actions.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/design/theme.dart'; // Importar seus temas
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

// --- UserState e userReducer (COM AS PRINCIPAIS ALTERAÇÕES) ---
class UserState {
  final String? userId;
  final String? email;
  final String? nome;
  final bool isLoggedIn;
  // final List<String> tags; // Se tags forem globais, podem sair do UserState
  final Map<String, dynamic>?
      userDetails; // Para dados gerais do /users/{userId}
  // final Map<String, List<Map<String, String>>> userBooks; // Se userBooks for específico, senão global
  final Map<String, List<String>>
      topicSaves; // Coleções de tópicos de resumos de livros
  // final List<Map<String, dynamic>> booksInProgress; // Pode ser derivado ou obsoleto se progresso for mais detalhado
  final List<Map<String, dynamic>> searchResults; // Para busca geral de tópicos
  final Map<String, List<Map<String, dynamic>>>
      savedTopicsContent; // Conteúdo de tópicos salvos
  // final List<Map<String, dynamic>> booksInProgressDetails; // Detalhes de livros em progresso
  final List<Map<String, dynamic>> rotaAtual;
  final List<Map<String, dynamic>> userRoutes;
  // final Map<String, List<Map<String, dynamic>>> verseSaves; // Se for para versículos BÍBLICOS, isto será gerenciado de forma diferente
  final List<Map<String, dynamic>> userDiaries;

  // Campos para dados que agora vêm de coleções separadas, mas mantidos no UserState para a UI
  final Map<String, Map<String, dynamic>> userHighlights;
  final Map<String, String>
      userNotes; // Notas de versículos bíblicos <verseId, noteText>
  final List<Map<String, dynamic>>
      userCommentHighlights; // Destaques de comentários bíblicos

  final String? initialBibleBook;
  final int? initialBibleChapter;
  final String? initialBibleSectionIdToScrollTo; // NOVO

  final List<Map<String, dynamic>>
      readingHistory; // Histórico geral de leitura da Bíblia
  final String? lastReadBookAbbrev; // Último livro bíblico lido (geral)
  final int? lastReadChapter; // Último capítulo bíblico lido (geral)

  final int? targetBottomNavIndex;

  final int userCoins;
  final DateTime? lastRewardedAdWatchTime;
  final int rewardedAdsWatchedToday;

  // Progresso Bíblico Detalhado (agora populado a partir de userBibleProgress/{userId})
  final Map<String, BibleBookProgressData>
      allBooksProgress; // <bookAbbrev, BibleBookProgressData>
  final Map<String, Set<String>>
      readSectionsByBook; // <bookAbbrev, Set<sectionId>> (derivado de allBooksProgress para UI)
  final Map<String, int>
      totalSectionsPerBook; // <bookAbbrev, total> (derivado de allBooksProgress)
  final Map<String, bool>
      bookCompletionStatus; // <bookAbbrev, isCompleted> (derivado de allBooksProgress)

  final bool isLoadingAllBibleProgress;
  final String? bibleProgressError;

  final List<Map<String, dynamic>> pendingFirestoreWrites;
  final Map<String, Set<String>> pendingSectionsToAdd;
  final Map<String, Set<String>> pendingSectionsToRemove;

  final DateTime? firstAdIn6HourWindowTimestamp;
  final int adsWatchedIn6HourWindow;

  final bool isGuestUser; // NOVO

  final List<String> allUserTags;

  UserState({
    this.userId,
    this.email,
    this.nome,
    this.isLoggedIn = false,
    // this.tags = const [],
    this.userDetails, // Continuará sendo o doc /users/{userId} sem os campos movidos
    // this.userBooks = const {},
    this.topicSaves = const {},
    // this.booksInProgress = const [],
    this.searchResults = const [],
    this.savedTopicsContent = const {},
    // this.booksInProgressDetails = const [],
    this.rotaAtual = const [],
    this.userRoutes = const [],
    // this.verseSaves = const {},
    this.userDiaries = const [],
    this.userHighlights = const {}, // Inicializa vazio
    this.userNotes = const {}, // Inicializa vazio
    this.userCommentHighlights = const [], // Inicializa vazio

    this.initialBibleBook,
    this.initialBibleChapter,
    this.readingHistory = const [],
    this.lastReadBookAbbrev, // Será populado por UserBibleProgressDocumentLoadedAction
    this.lastReadChapter, // Será populado por UserBibleProgressDocumentLoadedAction

    this.targetBottomNavIndex,
    this.userCoins = 0,
    this.lastRewardedAdWatchTime,
    this.rewardedAdsWatchedToday = 0,
    this.allBooksProgress = const {}, // Inicializa vazio
    this.readSectionsByBook = const {}, // Inicializa vazio
    this.totalSectionsPerBook = const {}, // Inicializa vazio
    this.bookCompletionStatus = const {}, // Inicializa vazio
    this.isLoadingAllBibleProgress = false,
    this.bibleProgressError,
    this.pendingFirestoreWrites = const [],
    this.pendingSectionsToAdd = const {},
    this.pendingSectionsToRemove = const {},
    this.firstAdIn6HourWindowTimestamp,
    this.adsWatchedIn6HourWindow = 0,
    this.isGuestUser = false,
    this.initialBibleSectionIdToScrollTo, // NOVO
    this.allUserTags = const [],
  });

  UserState copyWith({
    String? userId,
    String? email,
    String? nome,
    bool? isLoggedIn,
    // List<String>? tags,
    Map<String, dynamic>? userDetails, // Sem os campos movidos
    // Map<String, List<Map<String, String>>>? userBooks,
    Map<String, List<String>>? topicSaves,
    // List<Map<String, dynamic>>? booksInProgress,
    List<Map<String, dynamic>>? searchResults,
    Map<String, List<Map<String, dynamic>>>? savedTopicsContent,
    // List<Map<String, dynamic>>? booksInProgressDetails,
    List<Map<String, dynamic>>? rotaAtual,
    List<Map<String, dynamic>>? userRoutes,
    // Map<String, List<Map<String, dynamic>>>? verseSaves,
    List<Map<String, dynamic>>? userDiaries,
    Map<String, Map<String, dynamic>>? userHighlights,
    Map<String, String>? userNotes,
    List<Map<String, dynamic>>? userCommentHighlights,
    String? initialBibleBook,
    int? initialBibleChapter,
    bool clearInitialBibleLocation = false, // Para limpar a intent

    List<Map<String, dynamic>>? readingHistory,
    String?
        lastReadBookAbbrev, // Agora virá de UserBibleProgressDocumentLoadedAction
    int? lastReadChapter, // Agora virá de UserBibleProgressDocumentLoadedAction
    bool clearLastReadLocation = false, // Para resetar ao deslogar

    int? targetBottomNavIndex,
    bool clearTargetBottomNavIndex = false,
    int? userCoins,
    DateTime? lastRewardedAdWatchTime,
    bool clearLastRewardedAdWatchTime = false,
    int? rewardedAdsWatchedToday,
    Map<String, BibleBookProgressData>? allBooksProgress,
    Map<String, Set<String>>? readSectionsByBook, // Derivado
    Map<String, int>? totalSectionsPerBook, // Derivado
    Map<String, bool>? bookCompletionStatus, // Derivado
    bool? isLoadingAllBibleProgress,
    String? bibleProgressError,
    bool clearBibleProgressError = false,
    List<Map<String, dynamic>>? pendingFirestoreWrites,
    Map<String, Set<String>>? pendingSectionsToAdd,
    Map<String, Set<String>>? pendingSectionsToRemove,
    DateTime? firstAdIn6HourWindowTimestamp,
    bool clearFirstAdIn6HourWindowTimestamp = false,
    int? adsWatchedIn6HourWindow,
    bool? isGuestUser, // NOVO
    String? initialBibleSectionIdToScrollTo, // NOVO
    List<String>? allUserTags, // <<< NOVO PARÂMETRO
  }) {
    return UserState(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      nome: nome ?? this.nome,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      // tags: tags ?? this.tags,
      userDetails: userDetails ?? this.userDetails,
      // userBooks: userBooks ?? this.userBooks,
      topicSaves: topicSaves ?? this.topicSaves,
      // booksInProgress: booksInProgress ?? this.booksInProgress,
      searchResults: searchResults ?? this.searchResults,
      savedTopicsContent: savedTopicsContent ?? this.savedTopicsContent,
      // booksInProgressDetails: booksInProgressDetails ?? this.booksInProgressDetails,
      rotaAtual: rotaAtual ?? this.rotaAtual,
      userRoutes: userRoutes ?? this.userRoutes,
      // verseSaves: verseSaves ?? this.verseSaves,
      userDiaries: userDiaries ?? this.userDiaries,

      userHighlights: userHighlights ?? this.userHighlights,
      userNotes: userNotes ?? this.userNotes,
      userCommentHighlights:
          userCommentHighlights ?? this.userCommentHighlights,

      initialBibleBook: clearInitialBibleLocation
          ? null
          : (initialBibleBook ?? this.initialBibleBook),
      initialBibleChapter: clearInitialBibleLocation
          ? null
          : (initialBibleChapter ?? this.initialBibleChapter),

      readingHistory: readingHistory ?? this.readingHistory,
      lastReadBookAbbrev: clearLastReadLocation
          ? null
          : (lastReadBookAbbrev ?? this.lastReadBookAbbrev),
      lastReadChapter: clearLastReadLocation
          ? null
          : (lastReadChapter ?? this.lastReadChapter),

      targetBottomNavIndex: clearTargetBottomNavIndex
          ? null
          : (targetBottomNavIndex ?? this.targetBottomNavIndex),

      userCoins: userCoins ?? this.userCoins,
      lastRewardedAdWatchTime: clearLastRewardedAdWatchTime
          ? null
          : (lastRewardedAdWatchTime ?? this.lastRewardedAdWatchTime),
      rewardedAdsWatchedToday:
          rewardedAdsWatchedToday ?? this.rewardedAdsWatchedToday,

      allBooksProgress: allBooksProgress ?? this.allBooksProgress,
      readSectionsByBook: readSectionsByBook ??
          this.readSectionsByBook, // Será recalculado por AllBibleProgressLoadedAction
      totalSectionsPerBook:
          totalSectionsPerBook ?? this.totalSectionsPerBook, // Recalculado
      bookCompletionStatus:
          bookCompletionStatus ?? this.bookCompletionStatus, // Recalculado
      isLoadingAllBibleProgress:
          isLoadingAllBibleProgress ?? this.isLoadingAllBibleProgress,
      bibleProgressError: clearBibleProgressError
          ? null
          : bibleProgressError ?? this.bibleProgressError,

      pendingFirestoreWrites:
          pendingFirestoreWrites ?? this.pendingFirestoreWrites,
      pendingSectionsToAdd: pendingSectionsToAdd ?? this.pendingSectionsToAdd,
      pendingSectionsToRemove:
          pendingSectionsToRemove ?? this.pendingSectionsToRemove,

      firstAdIn6HourWindowTimestamp: clearFirstAdIn6HourWindowTimestamp
          ? null
          : (firstAdIn6HourWindowTimestamp ??
              this.firstAdIn6HourWindowTimestamp),
      adsWatchedIn6HourWindow:
          adsWatchedIn6HourWindow ?? this.adsWatchedIn6HourWindow,
      isGuestUser: isGuestUser ?? this.isGuestUser,
      initialBibleSectionIdToScrollTo: clearInitialBibleLocation
          ? null
          : (initialBibleSectionIdToScrollTo ??
              this.initialBibleSectionIdToScrollTo), // NOVO
      allUserTags: allUserTags ?? this.allUserTags,
    );
  }
}

UserState userReducer(UserState state, dynamic action) {
  if (action is UserLoggedInAction) {
    return state.copyWith(
      userId: action.userId,
      email: action.email,
      nome: action
          .nome, // Nome inicial, pode ser atualizado por UserDetailsLoadedAction
      isLoggedIn: true,
      isGuestUser: false,
      // Não reseta moedas ou outros dados aqui, UserDetailsLoadedAction ou
      // uma ação de carregamento de dados do userBibleProgress cuidará disso.
    );
  } else if (action is UserLoggedOutAction) {
    // Retorna ao estado inicial completo, limpando todos os dados do usuário.
    return UserState();
  } else if (action is UserExitedGuestModeAction) {
    // Similar a UserLoggedOutAction, mas pode ter lógica específica
    return state.copyWith(isGuestUser: false);
  } else if (action is UserEnteredGuestModeAction) {
    // <<< INÍCIO DA MUDANÇA: Usa os dados da ação se disponíveis >>>
    return state.copyWith(
      isLoggedIn: false,
      userId: null,
      email: null,
      nome: "Convidado",
      isGuestUser: true,
      userCoins: action.initialCoins ?? 10, // Usa moedas salvas ou o padrão 10
      rewardedAdsWatchedToday: action.initialAdsToday ?? 0,
      lastRewardedAdWatchTime: action.initialLastAdTime, // Pode ser nulo
      // Resetar a janela de 6h ao entrar como convidado
      adsWatchedIn6HourWindow: 0,
      clearFirstAdIn6HourWindowTimestamp: true,
    );
    // <<< FIM DA MUDANÇA >>>
  } else if (action is UpdateUserUidAction) {
    // Usado pelo AuthCheck se o UID inicial for nulo
    return state.copyWith(userId: action.uid);
  } else if (action is UserDetailsLoadedAction) {
    // Esta ação carrega os dados do documento /users/{userId}
    // Não deve mais conter bibleProgress, userHighlights, userNotes, userCommentHighlights, lastRead...
    // Esses virão de ações específicas que leem as novas coleções.
    return state.copyWith(
      userDetails: action.userDetails,
      // lastReadBookAbbrev e lastReadChapter NÃO são mais definidos aqui.
      // Eles serão definidos quando os dados de userBibleProgress forem carregados (ex: AllBibleProgressLoadedAction).
      userCoins: action.userDetails['userCoins'] as int? ??
          state.userCoins, // Pega do doc ou mantém o do estado
      lastRewardedAdWatchTime:
          (action.userDetails['lastRewardedAdWatchTime'] as Timestamp?)
              ?.toDate(),
      rewardedAdsWatchedToday:
          action.userDetails['rewardedAdsWatchedToday'] as int? ?? 0,
      // Outros campos do documento /users/{userId} podem ser atualizados aqui se necessário
      // como nome, email (se puderem mudar e forem refletidos no doc principal), etc.
      nome: action.userDetails['nome'] as String? ?? state.nome,
      email: action.userDetails['email'] as String? ?? state.email,
    );
  }
  // Ações de Coleções de Tópicos de Livros (não bíblicos)
  else if (action is UserTopicCollectionsLoadedAction ||
      action is UserCollectionsLoadedAction) {
    Map<String, List<String>> collections =
        (action is UserTopicCollectionsLoadedAction)
            ? action.topicSaves
            : (action as UserCollectionsLoadedAction).topicSaves;
    return state.copyWith(topicSaves: collections);
  } else if (action is SaveTopicToCollectionAction) {
    final updatedCollections = Map<String, List<String>>.from(state.topicSaves);
    updatedCollections.putIfAbsent(action.collectionName, () => []);
    if (!updatedCollections[action.collectionName]!.contains(action.topicId)) {
      updatedCollections[action.collectionName]!.add(action.topicId);
    }
    return state.copyWith(topicSaves: updatedCollections);
  } else if (action is DeleteTopicCollectionAction) {
    final updatedTopicSaves = Map<String, List<String>>.from(state.topicSaves);
    updatedTopicSaves.remove(action.collectionName);
    return state.copyWith(topicSaves: updatedTopicSaves);
  } else if (action is DeleteSingleTopicFromCollectionAction) {
    final updatedTopicSaves = Map<String, List<String>>.from(state.topicSaves);
    if (updatedTopicSaves.containsKey(action.collectionName)) {
      final List<String> updatedList =
          List.from(updatedTopicSaves[action.collectionName]!);
      updatedList.remove(action.topicId);
      if (updatedList.isEmpty) {
        updatedTopicSaves.remove(action.collectionName);
      } else {
        updatedTopicSaves[action.collectionName] = updatedList;
      }
    }
    return state.copyWith(topicSaves: updatedTopicSaves);
  }

  // Diário do Usuário
  else if (action is LoadUserDiariesSuccessAction) {
    return state.copyWith(userDiaries: action.diaries);
  }
  // AddDiaryEntryAction é tratada pelo middleware, que depois despacha LoadUserDiariesAction.

  // Destaques de Versículos Bíblicos
  else if (action is UserHighlightsLoadedAction) {
    return state.copyWith(userHighlights: action.highlights);
  } else if (action is UserTagsLoadedAction) {
    return state.copyWith(allUserTags: action.tags);
  }
  // Notas de Versículos Bíblicos
  else if (action is UserNotesLoadedAction) {
    return state.copyWith(userNotes: action.notes);
  }
  // SaveNoteAction e DeleteNoteAction são tratadas pelo middleware, que depois despacha LoadUserNotesAction.

  // Destaques de Comentários Bíblicos
  else if (action is UserCommentHighlightsLoadedAction) {
    return state.copyWith(userCommentHighlights: action.commentHighlights);
  }
  // AddCommentHighlightAction e RemoveCommentHighlightAction são tratadas pelo middleware.

  // Progresso Bíblico (agora de userBibleProgress/{userId})
  else if (action is LoadAllBibleProgressAction) {
    return state.copyWith(
      isLoadingAllBibleProgress: true,
      clearBibleProgressError: true, // Limpa erro anterior ao tentar carregar
    );
  } else if (action is AllBibleProgressLoadedAction) {
    final newReadSectionsByBook = <String, Set<String>>{};
    final newTotalSectionsPerBook = <String, int>{};
    final newBookCompletionStatus = <String, bool>{};
    String? overallLastReadBook;
    int? overallLastReadChapter;
    Timestamp? overallLastReadTimestamp;

    // Tenta buscar o lastRead geral do payload da ação se o middleware o incluir.
    // Se não, tentaremos derivar ou manter o existente.
    // Idealmente, o middleware que carrega de /userBibleProgress/{userId} também obteria
    // os campos lastReadBookAbbrev, lastReadChapter, lastReadTimestamp do nível raiz
    // desse documento e os passaria na ação.
    // Por ora, vamos assumir que AllBibleProgressLoadedAction foca no mapa 'books'.

    action.progressData.forEach((bookAbbrev, data) {
      newReadSectionsByBook[bookAbbrev] = data.readSections;
      newTotalSectionsPerBook[bookAbbrev] = data.totalSections;
      newBookCompletionStatus[bookAbbrev] = data.completed;
      // Lógica para determinar o lastRead geral (o mais recente entre todos os livros)
      if (data.lastReadTimestamp != null) {
        if (overallLastReadTimestamp == null ||
            data.lastReadTimestamp!.compareTo(overallLastReadTimestamp!) > 0) {
          overallLastReadTimestamp = data.lastReadTimestamp;
          // Se temos um lastReadTimestampBook, precisamos do livro e capítulo associado.
          // Isto é uma simplificação. A fonte da verdade para lastReadBookAbbrev/Chapter GERAL
          // deve ser o documento userBibleProgress/{userId} no nível raiz.
          // Aqui, estamos apenas pegando o último livro que teve um 'lastReadTimestampBook'.
          // overallLastReadBook = bookAbbrev;
          // overallLastReadChapter = ???; // Precisaríamos do capítulo da última seção lida.
        }
      }
    });

    // Para lastReadBookAbbrev e lastReadChapter GERAIS:
    // Estes deveriam vir idealmente de uma ação que carrega o documento userBibleProgress/{userId}
    // ou serem passados como parte do payload de AllBibleProgressLoadedAction se o middleware
    // os extraiu do documento pai de userBibleProgress.
    // Se não, a UI que depende deles pode precisar de um selector mais complexo
    // ou eles permanecerão como estavam no estado.

    return state.copyWith(
      allBooksProgress: action.progressData,
      readSectionsByBook: newReadSectionsByBook,
      totalSectionsPerBook: newTotalSectionsPerBook,
      bookCompletionStatus: newBookCompletionStatus,
      isLoadingAllBibleProgress: false,
      clearBibleProgressError:
          true, // Limpa erro após carregamento bem-sucedido
      // lastReadBookAbbrev: overallLastReadBook ?? state.lastReadBookAbbrev, // Atualização experimental
      // lastReadChapter: overallLastReadChapter ?? state.lastReadChapter,  // Atualização experimental
    );
  } else if (action is BibleBookProgressLoadedAction) {
    final newAllBooksProgress =
        Map<String, BibleBookProgressData>.from(state.allBooksProgress);
    newAllBooksProgress[action.bookAbbrev] = BibleBookProgressData(
        readSections: action.readSections,
        totalSections: action.totalSectionsInBook,
        completed: action.isCompleted,
        lastReadTimestamp: action.lastReadTimestamp);

    final newReadSectionsByBook =
        Map<String, Set<String>>.from(state.readSectionsByBook);
    final newTotalSectionsPerBook =
        Map<String, int>.from(state.totalSectionsPerBook);
    final newBookCompletionStatus =
        Map<String, bool>.from(state.bookCompletionStatus);

    newReadSectionsByBook[action.bookAbbrev] = action.readSections;
    newTotalSectionsPerBook[action.bookAbbrev] = action.totalSectionsInBook;
    newBookCompletionStatus[action.bookAbbrev] = action.isCompleted;

    return state.copyWith(
      allBooksProgress: newAllBooksProgress,
      readSectionsByBook: newReadSectionsByBook,
      totalSectionsPerBook: newTotalSectionsPerBook,
      bookCompletionStatus: newBookCompletionStatus,
      clearBibleProgressError: true,
    );
  } else if (action is BibleProgressFailureAction) {
    return state.copyWith(
      isLoadingAllBibleProgress: false,
      bibleProgressError: action.error,
    );
  } else if (action is OptimisticToggleSectionReadStatusAction) {
    final newReadSectionsByBook =
        Map<String, Set<String>>.from(state.readSectionsByBook);
    final sectionsForBookUI =
        Set<String>.from(newReadSectionsByBook[action.bookAbbrev] ?? {});

    if (action.markAsRead) {
      sectionsForBookUI.add(action.sectionId);
    } else {
      sectionsForBookUI.remove(action.sectionId);
    }
    newReadSectionsByBook[action.bookAbbrev] = sectionsForBookUI;

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
      bookToRemoveSet.remove(action.sectionId);
    } else {
      bookToRemoveSet.add(action.sectionId);
      bookToAddSet.remove(action.sectionId);
    }
    newPendingToAdd[action.bookAbbrev] = bookToAddSet;
    newPendingToRemove[action.bookAbbrev] = bookToRemoveSet;

    // Opcional: Atualizar otimisticamente allBooksProgress e bookCompletionStatus
    // Isso envolveria recalcular 'completed' aqui.
    // Por simplicidade, pode-se esperar o recarregamento após sincronização.
    // Se for feito aqui, a lógica de 'completed' deve ser replicada.

    return state.copyWith(
        readSectionsByBook: newReadSectionsByBook,
        pendingSectionsToAdd: newPendingToAdd,
        pendingSectionsToRemove: newPendingToRemove);
  }
  // --- Ações de Pendências de Sincronização ---
  else if (action is EnqueueFirestoreWriteAction) {
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites);
    final operationWithId = Map<String, dynamic>.from(action.operation);
    operationWithId['id'] ??=
        '${DateTime.now().millisecondsSinceEpoch}_${newPendingWrites.length}';
    newPendingWrites.add(operationWithId);
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  } else if (action is FirestoreWriteSuccessfulAction) {
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites)
          ..removeWhere((op) => op['id'] == action.operationId);
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  } else if (action is FirestoreWriteFailedAction) {
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites)
          ..removeWhere((op) => op['id'] == action.operationId);
    print(
        "Reducer: Operação ${action.operationId} removida da fila (FALHA): ${action.error}");
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  } else if (action is ClearPendingBibleProgressAction) {
    final newPendingToAdd =
        Map<String, Set<String>>.from(state.pendingSectionsToAdd)
          ..remove(action.bookAbbrev);
    final newPendingToRemove =
        Map<String, Set<String>>.from(state.pendingSectionsToRemove)
          ..remove(action.bookAbbrev);
    return state.copyWith(
        pendingSectionsToAdd: newPendingToAdd,
        pendingSectionsToRemove: newPendingToRemove);
  } else if (action is LoadedPendingBibleProgressAction) {
    return state.copyWith(
      pendingSectionsToAdd: action.pendingToAdd,
      pendingSectionsToRemove: action.pendingToRemove,
    );
  }

  // --- Ações de Leitura Geral e Navegação ---
  else if (action is UpdateLastReadLocationAction) {
    // Esta ação é para atualizar o estado Redux sobre a última leitura geral.
    // O middleware que chama firestoreService.updateLastReadLocation (na coleção userBibleProgress)
    // deve despachar esta ação se a atualização no Firestore for bem-sucedida.
    return state.copyWith(
      lastReadBookAbbrev: action.bookAbbrev,
      lastReadChapter: action.chapter,
    );
  } else if (action is ReadingHistoryLoadedAction) {
    return state.copyWith(readingHistory: action.history);
  } else if (action is SetInitialBibleLocationAction) {
    print(
        "userReducer: Recebendo SetInitialBibleLocationAction - book: ${action.bookAbbrev}, chapter: ${action.chapter}");
    return state.copyWith(
        initialBibleBook: action.bookAbbrev,
        initialBibleChapter: action.chapter,
        // REMOVIDO: initialBibleSectionIdToScrollTo: action.sectionIdToScrollTo,
        clearInitialBibleLocation:
            action.bookAbbrev == null && action.chapter == null);
  } else if (action is RequestBottomNavChangeAction) {
    return state.copyWith(targetBottomNavIndex: action.index);
  } else if (action is ClearTargetBottomNavAction) {
    return state.copyWith(clearTargetBottomNavIndex: true);
  }

  // --- Ações de Anúncios e Moedas ---
  else if (action is RewardedAdWatchedAction) {
    int currentCoins = state.userCoins;
    int coinsToAdd = action.coinsAwarded; // Pode ser negativo se for dedução
    int newTotalCoins = currentCoins + coinsToAdd;

    // Aplica limite máximo apenas se estiver adicionando moedas
    if (coinsToAdd > 0 && newTotalCoins > 100) {
      // 100 é o MAX_COINS_LIMIT do ad_middleware
      newTotalCoins = 100;
    }
    // Garante que não fique negativo se estiver deduzindo
    if (newTotalCoins < 0) {
      newTotalCoins = 0;
    }

    DateTime now = DateTime.now();
    int updatedAdsWatchedToday = state.rewardedAdsWatchedToday;
    // Só incrementa adsWatchedToday se for uma recompensa positiva
    if (coinsToAdd > 0) {
      updatedAdsWatchedToday += 1;
      if (state.lastRewardedAdWatchTime != null) {
        final lastWatchDate = state.lastRewardedAdWatchTime!;
        if (now.year > lastWatchDate.year ||
            now.month > lastWatchDate.month ||
            now.day > lastWatchDate.day) {
          updatedAdsWatchedToday = 1; // Reseta para o novo dia
        }
      }
    }
    return state.copyWith(
      userCoins: newTotalCoins,
      // Só atualiza lastRewardedAdWatchTime e rewardedAdsWatchedToday se for uma recompensa positiva
      lastRewardedAdWatchTime:
          coinsToAdd > 0 ? action.adWatchTime : state.lastRewardedAdWatchTime,
      rewardedAdsWatchedToday: coinsToAdd > 0
          ? updatedAdsWatchedToday
          : state.rewardedAdsWatchedToday,
    );
  } else if (action is UpdateUserCoinsAction) {
    // Ação mais direta para atualizar moedas
    return state.copyWith(
        userCoins: action.newCoinAmount
            .clamp(0, 100)); // Garante que não ultrapasse limites
  } else if (action is AdLimitDataLoadedAction) {
    return state.copyWith(
        firstAdIn6HourWindowTimestamp: action.firstAdTimestamp,
        adsWatchedIn6HourWindow: action.adsInWindowCount);
  } else if (action is UpdateAdWindowStatsAction) {
    return state.copyWith(
        firstAdIn6HourWindowTimestamp: action.firstAdTimestamp,
        adsWatchedIn6HourWindow: action.adsInWindowCount,
        clearFirstAdIn6HourWindowTimestamp:
            action.firstAdTimestamp == null // Limpa se for nulo
        );
  }

  // Ações de Busca Geral de Tópicos
  else if (action is SearchSuccessAction) {
    return state.copyWith(searchResults: action.topics);
  } else if (action is LoadTopicsContentUserSavesSuccessAction) {
    return state.copyWith(savedTopicsContent: action.topicsByCollection);
  }
  // Ações de Rotas do Usuário
  else if (action is AddTopicToRouteAction) {
    final updatedRotaAtual = List<Map<String, dynamic>>.from(state.rotaAtual);
    if (!updatedRotaAtual.any((topic) => topic['id'] == action.topicId)) {
      updatedRotaAtual.add({
        'id': action.topicId
      }); // Adiciona apenas o ID ou o objeto do tópico se disponível
    }
    return state.copyWith(rotaAtual: updatedRotaAtual);
  } else if (action is ClearRouteAction) {
    return state.copyWith(rotaAtual: []);
  } else if (action is UserRoutesLoadedAction) {
    return state.copyWith(userRoutes: action.routes);
  } else if (action is SetInitialBibleLocationAction) {
    return state.copyWith(
        initialBibleBook: action.bookAbbrev,
        initialBibleChapter: action.chapter,
        clearInitialBibleLocation:
            action.bookAbbrev == null && action.chapter == null);
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
  final bool isProcessingPayment; // <<< ADICIONAR ESTE CAMPO
  final List<Map<String, dynamic>> searchHistory;
  final bool isLoadingHistory;

  BibleSearchState({
    this.isLoading = false,
    this.results = const [],
    this.error,
    this.activeFilters = const {},
    this.currentQuery = "",
    this.isProcessingPayment = false, // <<< ADICIONAR VALOR PADRÃO
    this.searchHistory = const [],
    this.isLoadingHistory = false,
  });

  BibleSearchState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? results,
    String? error,
    Map<String, dynamic>? activeFilters,
    String? currentQuery,
    bool? isProcessingPayment, // <<< ADICIONAR ESTE PARÂMETRO
    bool clearError = false,
    bool clearResults = false,
    List<Map<String, dynamic>>? searchHistory,
    bool? isLoadingHistory,
  }) {
    return BibleSearchState(
      isLoading: isLoading ?? this.isLoading,
      results: clearResults ? [] : results ?? this.results,
      error: clearError ? null : error ?? this.error,
      activeFilters: activeFilters ?? this.activeFilters,
      currentQuery: currentQuery ?? this.currentQuery,
      isProcessingPayment: isProcessingPayment ??
          this.isProcessingPayment, // <<< USAR O PARÂMETRO
      searchHistory: searchHistory ?? this.searchHistory,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
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
      isProcessingPayment: true, // Define ao iniciar
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
    return state.copyWith(
      isLoading: false,
      results: action.results,
      isProcessingPayment: false, // Limpa ao sucesso
      clearError: true,
    );
  }
  if (action is SearchBibleSemanticFailureAction) {
    return state.copyWith(
      isLoading: false,
      error: action.error,
      isProcessingPayment: false, // Limpa em falha
    );
  } else if (action is AddSearchToHistoryAction) {
    List<Map<String, dynamic>> updatedHistory = List.from(state.searchHistory);

    // Remove buscas antigas com a mesma query para evitar duplicatas exatas, mantendo a mais recente
    updatedHistory.removeWhere((item) => item['query'] == action.query);

    updatedHistory.insert(0, {
      // Adiciona no início (mais recente primeiro)
      'query': action.query,
      'results': action.results,
      'timestamp': DateTime.now()
          .toIso8601String(), // Salva como string para facilitar serialização
    });

    // Limita o histórico a 50 itens
    if (updatedHistory.length > 50) {
      updatedHistory = updatedHistory.sublist(0, 50);
    }
    return state.copyWith(searchHistory: updatedHistory);
  }

  if (action is LoadSearchHistoryAction) {
    return state.copyWith(isLoadingHistory: true);
  }

  if (action is SearchHistoryLoadedAction) {
    return state.copyWith(
        searchHistory: action.history, isLoadingHistory: false);
  }

  if (action is ViewSearchFromHistoryAction) {
    // Quando o usuário clica em um item do histórico,
    // preenchemos os resultados atuais e a query atual com os dados do histórico.
    return state.copyWith(
      currentQuery: action.searchEntry['query'] as String,
      results: List<Map<String, dynamic>>.from(
          action.searchEntry['results'] as List<dynamic>),
      isLoading: false, // A busca já foi feita
      clearError: true,
    );
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
