// redux/reducers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';
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

  final int? targetBottomNavIndex;

  // CAMPOS NOVOS PARA MOEDAS E ANÚNCIOS
  final int userCoins;
  final DateTime? lastRewardedAdWatchTime;
  final int rewardedAdsWatchedToday;

  // NOVOS CAMPOS PARA PROGRESSO DE LEITURA BÍBLICA
  // Map<livroAbrev, Set<idDaSecaoLida>>
  final Map<String, Set<String>> readSectionsByBook;
  // Map<livroAbrev, totalDeSecoesNoLivro>
  final Map<String, int> totalSectionsPerBook;
  // Map<livroAbrev, boolean>
  final Map<String, bool> bookCompletionStatus; // Opcional, pode ser derivado

  // Para progresso geral (UserPage)
  // Map<livroAbrev, ProgressoDetalhadoDoLivro>
  final Map<String, BibleBookProgressData> allBooksProgress;

  final List<Map<String, dynamic>>
      pendingFirestoreWrites; // NOVO CAMPO PARA A FILA

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
    this.targetBottomNavIndex,
    this.userCoins = 0, // Começa com 0, será carregado ou definido como 100
    this.lastRewardedAdWatchTime,
    this.rewardedAdsWatchedToday = 0,
    this.readSectionsByBook = const {},
    this.totalSectionsPerBook = const {},
    this.bookCompletionStatus = const {},
    this.allBooksProgress = const {},
    this.pendingFirestoreWrites = const [], // NOVO: Inicializa a fila
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
    int? targetBottomNavIndex, // NOVO
    bool clearTargetBottomNavIndex = false,
    int? userCoins,
    DateTime? lastRewardedAdWatchTime,
    bool clearLastRewardedAdWatchTime = false,
    int? rewardedAdsWatchedToday,
    Map<String, Set<String>>? readSectionsByBook,
    Map<String, int>? totalSectionsPerBook,
    Map<String, bool>? bookCompletionStatus,
    Map<String, BibleBookProgressData>? allBooksProgress,
    List<Map<String, dynamic>>? pendingFirestoreWrites, // NOVO
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
      pendingFirestoreWrites:
          pendingFirestoreWrites ?? this.pendingFirestoreWrites,
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
    // Similar a UserDetailsLoadedAction, se 'stats' contiver os campos de moedas.
    return state.copyWith(
      userDetails: action.stats, // Assumindo que 'stats' é o novo 'userDetails'
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
      // Carrega as moedas do Firestore, ou mantém o valor atual se não existir, ou 100 como fallback
      userCoins: action.userDetails['userCoins'] as int? ?? state.userCoins,
      // Carregar lastRewardedAdWatchTime e rewardedAdsWatchedToday do Firestore
      lastRewardedAdWatchTime:
          (action.userDetails['lastRewardedAdWatchTime'] as Timestamp?)
              ?.toDate(),
      rewardedAdsWatchedToday:
          action.userDetails['rewardedAdsWatchedToday'] as int? ?? 0,
    );
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
  } else if (action is UserLoggedOutAction) {
    // Limpa todos os dados do usuário, mas mantém o estado de não logado.
    // Preserva o userId e email se precisar deles para a tela de login (opcional).
    // Para uma limpeza completa e redirecionamento para o login,
    // retornar UserState() é o mais comum e seguro.
    print("Reducer: UserLoggedOutAction recebida. Resetando UserState.");
    return UserState(); // Retorna o estado inicial, usuário deslogado
  } else if (action is RequestBottomNavChangeAction) {
    // NOVA AÇÃO
    return state.copyWith(targetBottomNavIndex: action.index);
  } else if (action is ClearTargetBottomNavAction) {
    // NOVA AÇÃO
    return state.copyWith(clearTargetBottomNavIndex: true);
  } // --- NOVA LÓGICA PARA REWARDED AD ---
  else if (action is RewardedAdWatchedAction) {
    int currentCoins = state.userCoins;
    int coinsToAdd = action.coinsAwarded;
    int newTotalCoins = currentCoins + coinsToAdd;

    if (newTotalCoins > 100) {
      newTotalCoins = 100; // Aplica o limite máximo
    }

    // Lógica para resetar rewardedAdsWatchedToday se for um novo dia
    DateTime now = DateTime.now();
    int updatedAdsWatchedToday = state.rewardedAdsWatchedToday + 1;

    if (state.lastRewardedAdWatchTime != null) {
      final lastWatchDate = state.lastRewardedAdWatchTime!;
      if (now.year > lastWatchDate.year ||
          now.month > lastWatchDate.month ||
          now.day > lastWatchDate.day) {
        updatedAdsWatchedToday = 1; // Primeiro anúncio de um novo dia
      }
    }

    return state.copyWith(
      userCoins: newTotalCoins,
      lastRewardedAdWatchTime: action.adWatchTime,
      rewardedAdsWatchedToday: updatedAdsWatchedToday,
    );
  } else if (action is BibleBookProgressLoadedAction) {
    final newReadSectionsByBook =
        Map<String, Set<String>>.from(state.readSectionsByBook);
    newReadSectionsByBook[action.bookAbbrev] = action.readSections;

    final newTotalSectionsPerBook =
        Map<String, int>.from(state.totalSectionsPerBook);
    newTotalSectionsPerBook[action.bookAbbrev] = action.totalSectionsInBook;

    final newBookCompletionStatus =
        Map<String, bool>.from(state.bookCompletionStatus);
    newBookCompletionStatus[action.bookAbbrev] = action.isCompleted;

    // Atualiza também o allBooksProgress se este livro específico foi carregado
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
      allBooksProgress:
          newAllBooksProgress, // Atualiza o progresso geral também
    );
  }
  // A ação ToggleSectionReadStatusAction é principalmente tratada pelo middleware.
  // O middleware, após atualizar o Firestore, pode despachar BibleBookProgressLoadedAction
  // para atualizar o estado, ou você pode ter uma atualização otimista aqui.
  // Para manter simples, vamos deixar o middleware recarregar via BibleBookProgressLoadedAction.

  else if (action is AllBibleProgressLoadedAction) {
    // Preenche os mapas individuais a partir do mapa consolidado
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
      readSectionsByBook: newReadSectionsByBook, // Preenche para acesso rápido
      totalSectionsPerBook:
          newTotalSectionsPerBook, // Preenche para acesso rápido
      bookCompletionStatus:
          newBookCompletionStatus, // Preenche para acesso rápido
    );
  } else if (action is BibleProgressFailureAction) {
    // Você pode querer armazenar o erro em algum lugar no estado se precisar mostrá-lo na UI
    print("BibleProgressFailureAction: ${action.error}");
    return state; // Ou state.copyWith(bibleProgressError: action.error)
  } else if (action is OptimisticToggleSectionReadStatusAction) {
    final newReadSectionsByBook =
        Map<String, Set<String>>.from(state.readSectionsByBook);
    final sectionsForBook =
        Set<String>.from(newReadSectionsByBook[action.bookAbbrev] ?? {});

    if (action.markAsRead) {
      sectionsForBook.add(action.sectionId);
    } else {
      sectionsForBook.remove(action.sectionId);
    }
    newReadSectionsByBook[action.bookAbbrev] = sectionsForBook;
    // print("Reducer (Optimistic): readSectionsByBook atualizado para ${action.bookAbbrev}: $sectionsForBook");
    return state.copyWith(readSectionsByBook: newReadSectionsByBook);
  }

  if (action is EnqueueFirestoreWriteAction) {
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites);
    // Adiciona um ID único à operação para rastreamento, se não existir
    final operationWithId = Map<String, dynamic>.from(action.operation);
    if (operationWithId['id'] == null) {
      operationWithId['id'] = DateTime.now().millisecondsSinceEpoch.toString() +
          '_' +
          (newPendingWrites.length).toString();
    }
    newPendingWrites.add(operationWithId);
    // print("Reducer: Operação enfileirada: ${operationWithId['id']}");
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  }

  if (action is FirestoreWriteSuccessfulAction) {
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites);
    newPendingWrites.removeWhere((op) => op['id'] == action.operationId);
    // print("Reducer: Operação ${action.operationId} removida da fila (sucesso).");
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  }

  if (action is FirestoreWriteFailedAction) {
    // Aqui você pode decidir o que fazer.
    // Opção 1: Manter na fila e adicionar uma contagem de retentativas ou marcar como falha.
    // Opção 2: Remover da fila e talvez despachar uma ação para reverter a UI (mais complexo).
    // Por simplicidade, vamos apenas logar e remover por enquanto.
    final newPendingWrites =
        List<Map<String, dynamic>>.from(state.pendingFirestoreWrites);
    newPendingWrites.removeWhere((op) => op['id'] == action.operationId);
    print(
        "Reducer: Operação ${action.operationId} removida da fila (FALHA): ${action.error}");
    // TODO: Considerar uma estratégia de retentativa ou notificação ao usuário.
    return state.copyWith(pendingFirestoreWrites: newPendingWrites);
  }

  // A ação original ToggleSectionReadStatusAction agora não modifica diretamente o estado aqui.
  // Ela será capturada pelo middleware que então despachará Optimistic... e Enqueue...
  // Se você quiser que o reducer original também trate ToggleSectionReadStatusAction para
  // iniciar o processo, você pode fazer isso, mas o middleware é um lugar comum para orquestrar.
  // Por ora, vamos assumir que o middleware de bible_progress lida com a ToggleSectionReadStatusAction
  // e despacha as ações Optimistic e Enqueue.

  // O BibleBookProgressLoadedAction e AllBibleProgressLoadedAction continuam como antes,
  // eles são o resultado do carregamento do Firestore, não da atualização otimista.
  if (action is BibleBookProgressLoadedAction) {
    final newReadSectionsByBook =
        Map<String, Set<String>>.from(state.readSectionsByBook);
    newReadSectionsByBook[action.bookAbbrev] = action.readSections;

    final newTotalSectionsPerBook =
        Map<String, int>.from(state.totalSectionsPerBook);
    newTotalSectionsPerBook[action.bookAbbrev] = action.totalSectionsInBook;

    final newBookCompletionStatus =
        Map<String, bool>.from(state.bookCompletionStatus);
    newBookCompletionStatus[action.bookAbbrev] = action.isCompleted;

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
      allBooksProgress: newAllBooksProgress,
    );
  }

  if (action is AllBibleProgressLoadedAction) {
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
    );
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

class BibleSearchState {
  final bool isLoading;
  final List<Map<String, dynamic>> results;
  final String? error;
  final Map<String, dynamic>
      activeFilters; // e.g., {"livro_curto": "gn", "testamento": "Novo"}
  final String
      currentQuery; // Para manter a query atual, útil se filtros mudarem

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
      clearResults: true, // Limpa resultados antigos ao iniciar nova busca
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

// Classe auxiliar para AllBibleProgressLoadedAction
class BibleBookProgressData {
  final Set<String> readSections;
  final int totalSections;
  final bool completed;
  final Timestamp? lastReadTimestamp; // Opcional, mas útil

  BibleBookProgressData({
    required this.readSections,
    required this.totalSections,
    this.completed = false,
    this.lastReadTimestamp,
  });

  // Necessário para comparação no StoreConnector se você usar distinct: true
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleBookProgressData &&
          runtimeType == other.runtimeType &&
          setEquals(readSections,
              other.readSections) && // Use setEquals para comparar Sets
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
