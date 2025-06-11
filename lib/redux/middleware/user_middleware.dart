// lib/redux/middleware/user_middleware.dart
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
// import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart'; // Descomente se for usar para nomes de livros, etc.

List<Middleware<AppState>> createUserMiddleware() {
  final firestoreService = FirestoreService();

  return [
    // --- User Details & Stats (Operam no doc /users/{userId}) ---
    TypedMiddleware<AppState, LoadUserStatsAction>(
            _loadUserStats(firestoreService))
        .call,
    TypedMiddleware<AppState, LoadUserDetailsAction>(
            _loadUserDetails(firestoreService))
        .call,
    TypedMiddleware<AppState, UpdateUserFieldAction>(
            _updateUserField(firestoreService))
        .call,
    // Se LoadUserPremiumStatusAction ainda for relevante e operar no doc principal:
    // TypedMiddleware<AppState, LoadUserPremiumStatusAction>(_loadUserPremiumStatus(firestoreService)).call,

    // --- Coleções de Tópicos de Livros de Resumo (Operam em 'topicSaves' no doc /users/{userId}) ---
    TypedMiddleware<AppState, dynamic>(
            _loadUserCollectionsMiddleware(firestoreService))
        .call,
    TypedMiddleware<AppState, SaveTopicToCollectionAction>(
            _saveTopicToCollection(firestoreService))
        .call,
    TypedMiddleware<AppState, DeleteTopicCollectionAction>(
            _deleteTopicCollection(firestoreService))
        .call,
    TypedMiddleware<AppState, DeleteSingleTopicFromCollectionAction>(
            _deleteSingleTopicFromCollection(firestoreService))
        .call,
    TypedMiddleware<AppState, LoadTopicsContentUserSavesAction>(
            _loadTopicsContentUserSaves(firestoreService))
        .call,

    // --- Diário do Usuário (Refs em /users/{userId}/user_diaries, conteúdo em /posts) ---
    TypedMiddleware<AppState, AddDiaryEntryAction>(
            _addDiaryEntry(firestoreService))
        .call,
    TypedMiddleware<AppState, LoadUserDiariesAction>(
            _loadUserDiaries(firestoreService))
        .call,

    // --- Histórico de Leitura da Bíblia (AJUSTADO para userBibleProgress) ---
    TypedMiddleware<AppState, RecordReadingHistoryAction>(
            _handleRecordReadingHistory(firestoreService))
        .call,
    TypedMiddleware<AppState, LoadReadingHistoryAction>(
            _handleLoadReadingHistory(firestoreService))
        .call,

    // --- Destaques de Versículos Bíblicos (AJUSTADO para userVerseHighlights) ---
    TypedMiddleware<AppState, LoadUserHighlightsAction>(
            _loadUserHighlights(firestoreService))
        .call,
    TypedMiddleware<AppState, ToggleHighlightAction>(
            _toggleHighlight(firestoreService))
        .call,

    // --- Notas de Versículos Bíblicos (AJUSTADO para userVerseNotes) ---
    TypedMiddleware<AppState, LoadUserNotesAction>(
            _loadUserNotes(firestoreService))
        .call,
    TypedMiddleware<AppState, SaveNoteAction>(_saveNote(firestoreService)).call,
    TypedMiddleware<AppState, DeleteNoteAction>(_deleteNote(firestoreService))
        .call,

    // --- Destaques de Comentários Bíblicos (AJUSTADO para userCommentHighlights) ---
    TypedMiddleware<AppState, LoadUserCommentHighlightsAction>(
            _loadUserCommentHighlights(firestoreService))
        .call,
    TypedMiddleware<AppState, AddCommentHighlightAction>(
            _addCommentHighlight(firestoreService))
        .call,
    TypedMiddleware<AppState, RemoveCommentHighlightAction>(
            _removeCommentHighlight(firestoreService))
        .call,
  ];
}

// --- Handlers para User Details, Stats, Fields (operam no doc /users/{userId}) ---
void Function(Store<AppState>, LoadUserStatsAction, NextDispatcher)
    _loadUserStats(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadUserStatsAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      final stats = await firestoreService.getUserStats(userId);
      if (stats != null) {
        store.dispatch(UserStatsLoadedAction(stats));
      }
    } catch (e) {
      print('UserMiddleware: Erro ao carregar stats do usuário: $e');
    }
  };
}

void Function(Store<AppState>, LoadUserDetailsAction, NextDispatcher)
    _loadUserDetails(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadUserDetailsAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      final details = await firestoreService.getUserDetails(userId);
      if (details != null) {
        store.dispatch(UserDetailsLoadedAction(details));
      }
    } catch (e) {
      print('UserMiddleware: Erro ao carregar detalhes do usuário: $e');
    }
  };
}

void Function(Store<AppState>, UpdateUserFieldAction, NextDispatcher)
    _updateUserField(FirestoreService firestoreService) {
  return (Store<AppState> store, UpdateUserFieldAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.updateUserField(
          userId, action.field, action.value);
      final details = await firestoreService
          .getUserDetails(userId); // Recarrega após update
      if (details != null) {
        store.dispatch(UserDetailsLoadedAction(details));
      }
      print(
          'UserMiddleware: Campo "${action.field}" atualizado para usuário $userId.');
    } catch (e) {
      print(
          'UserMiddleware: Erro ao atualizar o campo "${action.field}" para $userId: $e');
    }
  };
}

// --- Handlers para Coleções de Tópicos de Livros (não bíblicos) ---
void Function(Store<AppState>, dynamic, NextDispatcher)
    _loadUserCollectionsMiddleware(FirestoreService firestoreService) {
  return (Store<AppState> store, dynamic action, NextDispatcher next) async {
    next(action);
    if (action is LoadUserTopicCollectionsAction ||
        action is LoadUserCollectionsAction) {
      final userId = store.state.userState.userId;
      if (userId == null) return;
      try {
        final collections = await firestoreService
            .getUserCollections(userId); // Lê 'topicSaves' de /users/{userId}
        if (action is LoadUserTopicCollectionsAction) {
          store.dispatch(UserTopicCollectionsLoadedAction(collections ?? {}));
        } else if (action is LoadUserCollectionsAction) {
          store.dispatch(UserCollectionsLoadedAction(collections ?? {}));
        }
      } catch (e) {
        print('UserMiddleware: Erro ao carregar coleções de tópicos: $e');
      }
    }
  };
}

void Function(Store<AppState>, SaveTopicToCollectionAction, NextDispatcher)
    _saveTopicToCollection(FirestoreService firestoreService) {
  return (Store<AppState> store, SaveTopicToCollectionAction action,
      NextDispatcher next) async {
    next(action); // O reducer já atualiza otimisticamente topicSaves
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.saveTopicToCollection(
          userId, action.collectionName, action.topicId);
      // Opcional: recarregar se a fonte da verdade for apenas o Firestore, mas o reducer já atualizou.
      // store.dispatch(LoadUserCollectionsAction());
      print(
          'UserMiddleware: Tópico ${action.topicId} salvo na coleção "${action.collectionName}".');
    } catch (e) {
      print('UserMiddleware: Erro ao salvar tópico na coleção: $e');
      // Considerar reverter a atualização otimista se a escrita falhar
    }
  };
}

void Function(Store<AppState>, DeleteTopicCollectionAction, NextDispatcher)
    _deleteTopicCollection(FirestoreService firestoreService) {
  return (Store<AppState> store, DeleteTopicCollectionAction action,
      NextDispatcher next) async {
    next(action); // Reducer remove otimisticamente
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.deleteTopicCollection(
          userId, action.collectionName);
      // Opcional: recarregar, mas o reducer já atualizou.
      // store.dispatch(LoadUserCollectionsAction());
      // store.dispatch(LoadTopicsContentUserSavesAction()); // Para recarregar o conteúdo se a UI depender disso
      print(
          'UserMiddleware: Coleção de tópicos "${action.collectionName}" deletada.');
    } catch (e) {
      print('UserMiddleware: Erro ao excluir coleção de tópicos: $e');
    }
  };
}

void Function(
        Store<AppState>, DeleteSingleTopicFromCollectionAction, NextDispatcher)
    _deleteSingleTopicFromCollection(FirestoreService firestoreService) {
  return (Store<AppState> store, DeleteSingleTopicFromCollectionAction action,
      NextDispatcher next) async {
    next(action); // Reducer remove otimisticamente
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.deleteSingleTopicFromCollection(
          userId, action.collectionName, action.topicId);
      // store.dispatch(LoadUserCollectionsAction());
      // store.dispatch(LoadTopicsContentUserSavesAction());
      print(
          'UserMiddleware: Tópico ${action.topicId} removido da coleção "${action.collectionName}".');
    } catch (e) {
      print('UserMiddleware: Erro ao excluir tópico da coleção: $e');
    }
  };
}

void Function(Store<AppState>, LoadTopicsContentUserSavesAction, NextDispatcher)
    _loadTopicsContentUserSaves(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadTopicsContentUserSavesAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(
          LoadTopicsContentUserSavesFailureAction("Usuário não autenticado"));
      return;
    }
    try {
      final topicSaves =
          await firestoreService.getUserCollections(userId) ?? {};
      final Map<String, List<Map<String, dynamic>>> topicsByCollection = {};

      for (var entry in topicSaves.entries) {
        final collectionName = entry.key;
        final ids = entry.value; // Lista de topicId ou verseId com prefixo
        final List<Map<String, dynamic>> contentList = [];
        List<String> topicIdsToFetch = [];
        List<String> verseIdsToProcess = [];

        for (var id in ids) {
          if (id.startsWith("bibleverses-")) {
            verseIdsToProcess.add(id);
          } else {
            topicIdsToFetch.add(id);
          }
        }

        if (topicIdsToFetch.isNotEmpty) {
          final topicsData =
              await firestoreService.fetchTopicsByIds(topicIdsToFetch);
          contentList.addAll(topicsData);
        }

        for (var verseIdWithPrefix in verseIdsToProcess) {
          final verseIdProper =
              verseIdWithPrefix.replaceFirst("bibleverses-", "");
          final parts = verseIdProper.split("_");
          if (parts.length == 3) {
            final bookAbbrev = parts[0];
            final chapter = parts[1];
            final verse = parts[2];
            String bookName =
                await firestoreService.getBookNameFromAbbrev(bookAbbrev) ??
                    bookAbbrev.toUpperCase();
            // String verseText = await BiblePageHelper.loadSingleVerseText(verseIdProper, 'nvi');
            contentList.add({
              'id': verseIdWithPrefix,
              'cover': 'assets/images/biblia_cover_placeholder.png',
              'bookName': bookName,
              'chapterName': chapter,
              'titulo': "$bookName $chapter:$verse",
              'conteudo': "Versículo: $bookName $chapter:$verse",
            });
          }
        }
        topicsByCollection[collectionName] = contentList;
      }
      store.dispatch(
          LoadTopicsContentUserSavesSuccessAction(topicsByCollection));
    } catch (e) {
      store.dispatch(LoadTopicsContentUserSavesFailureAction(
          'UserMiddleware: Erro ao carregar tópicos salvos: $e'));
    }
  };
}

// --- Handlers para Diário ---
void Function(Store<AppState>, AddDiaryEntryAction, NextDispatcher)
    _addDiaryEntry(FirestoreService firestoreService) {
  return (Store<AppState> store, AddDiaryEntryAction action,
      NextDispatcher next) async {
    // next(action); // O reducer para AddDiaryEntryAction não precisa fazer nada se recarregarmos
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.addDiaryEntry(
          userId, action.title, action.content);
      store.dispatch(LoadUserDiariesAction()); // Recarrega após adicionar
      print("UserMiddleware: Entrada de diário adicionada.");
    } catch (e) {
      print("UserMiddleware: Erro ao adicionar diário: $e");
    }
  };
}

void Function(Store<AppState>, LoadUserDiariesAction, NextDispatcher)
    _loadUserDiaries(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadUserDiariesAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(LoadUserDiariesFailureAction("Usuário não autenticado"));
      return;
    }
    try {
      final diaries = await firestoreService.loadUserDiaries(userId);
      store.dispatch(LoadUserDiariesSuccessAction(diaries));
    } catch (e) {
      print("UserMiddleware: Erro ao carregar os diários: $e");
      store.dispatch(LoadUserDiariesFailureAction(e.toString()));
    }
  };
}

// --- Handlers AJUSTADOS para Histórico, Destaques e Notas ---

// Histórico de Leitura da Bíblia
void Function(Store<AppState>, RecordReadingHistoryAction, NextDispatcher)
    _handleRecordReadingHistory(FirestoreService firestoreService) {
  return (Store<AppState> store, RecordReadingHistoryAction action,
      NextDispatcher next) async {
    final userId = store.state.userState.userId;
    if (userId == null) {
      print("UserMiddleware (RecordHistory): Usuário não logado.");
      return;
    }

    try {
      // Obtenha o nome do livro do estado local (booksMap) da BiblePage que foi passado via ação,
      // ou, se você decidiu que não precisa mais do nome completo no histórico do Firestore, remova-o.
      // A BiblePage agora tenta pegar o nome do seu 'booksMap' (que é o _localBooksMap).
      // Se você adicionou 'bookName' à RecordReadingHistoryAction:
      // String bookNameForHistory = action.bookName;

      // Se você quer que o nome do livro venha do UserState.booksMap (se ele existir lá globalmente)
      // ou se você decidir que o histórico só precisa da abreviação:
      String bookNameForHistoryInFirestore;
      final localBooksMapFromState = store
              .state.metadataState.bibleSectionCounts[
          'livros_mapa_local_nao_existe_aqui']; // Exemplo de onde poderia estar, ou use o da ação.
      // O ideal é que a UI (BiblePage) que tem o _localBooksMap
      // já forneça o nome correto na ação.

      // ASSUMINDO QUE A BIBLEPAGE JÁ CARREGOU O bookName CORRETO e o middleware não precisa buscá-lo.
      // A ação foi simplificada para não carregar mais o nome do livro aqui.
      // O FirestoreService.addReadingHistoryEntry agora precisa lidar com o nome do livro
      // ou a estrutura do histórico precisa ser simplificada.

      // Para o FirestoreService.addReadingHistoryEntry, ele precisará do nome.
      // Vamos assumir que o nome do livro é importante para o histórico.
      // A BiblePage DEVE carregar o nome do seu mapa local e passá-lo.
      // Se a ação RecordReadingHistoryAction não tiver bookName, você precisará adicioná-lo
      // e fazer a BiblePage preenchê-lo.

      // Cenário onde a Ação RecordReadingHistoryAction TEM o bookName:
      // await firestoreService.addReadingHistoryEntry(
      //     userId, action.bookAbbrev, action.chapter, action.bookName);

      // Cenário onde a Ação NÃO TEM bookName e você quer buscar do abbrev_map via helper.
      // Isso significa que o helper precisa estar acessível ou o mapa precisa ser carregado aqui.
      // Vamos simplificar e assumir que o nome não é mais armazenado no histórico ou que a ação o fornece.
      // Para o log do console, vamos usar a abreviação.
      final Map<String, dynamic>? booksMapFromHelper =
          await BiblePageHelper.loadBooksMap();
      String bookNameToUseForHistory = booksMapFromHelper?[action.bookAbbrev]
              ?['nome'] ??
          action.bookAbbrev.toUpperCase();

      await firestoreService.addReadingHistoryEntry(userId, action.bookAbbrev,
          action.chapter, bookNameToUseForHistory); // Passa o nome
      print(
          "UserMiddleware (RecordHistory): Entrada de histórico detalhado adicionada para $bookNameToUseForHistory ${action.chapter}.");

      await firestoreService.updateLastReadLocation(
          userId, action.bookAbbrev, action.chapter);
      print(
          "UserMiddleware (RecordHistory): Última leitura atualizada em userBibleProgress.");

      store.dispatch(
          UpdateLastReadLocationAction(action.bookAbbrev, action.chapter));
    } catch (e) {
      print(
          'UserMiddleware (RecordHistory): Erro ao salvar histórico/última leitura: $e');
    }
  };
}

void Function(Store<AppState>, LoadReadingHistoryAction, NextDispatcher)
    _handleLoadReadingHistory(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadReadingHistoryAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(ReadingHistoryLoadedAction([]));
      return;
    }
    try {
      final history = await firestoreService
          .loadReadingHistory(userId); // Lê de users/{userId}/reading_history
      store.dispatch(ReadingHistoryLoadedAction(history));
    } catch (e) {
      print(
          'UserMiddleware: Erro ao carregar histórico de leitura detalhado: $e');
      store.dispatch(ReadingHistoryLoadedAction([]));
    }
  };
}

// Destaques de Versículos Bíblicos
void Function(Store<AppState>, LoadUserHighlightsAction, NextDispatcher)
    _loadUserHighlights(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(UserHighlightsLoadedAction({}));
      return;
    }
    try {
      // FirestoreService.loadUserHighlights agora lê de /userVerseHighlights/{userId}/highlights
      final highlights = await firestoreService.loadUserHighlights(userId);
      store.dispatch(UserHighlightsLoadedAction(highlights));
    } catch (e) {
      print("UserMiddleware: Erro ao carregar destaques de versículos: $e");
      store.dispatch(UserHighlightsLoadedAction({}));
    }
  };
}

void Function(Store<AppState>, ToggleHighlightAction, NextDispatcher)
    _toggleHighlight(FirestoreService firestoreService) {
  return (store, action, next) async {
    // next(action); // O reducer desta ação pode não fazer nada se recarregarmos

    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      if (action.colorHex == null) {
        await firestoreService.removeHighlight(
            userId, action.verseId); // Chama a função atualizada do service
        print(
            "UserMiddleware: Destaque de versículo removido para ${action.verseId}");
      } else {
        await firestoreService.saveHighlight(userId, action.verseId,
            action.colorHex!); // Chama a função atualizada
        print(
            "UserMiddleware: Destaque de versículo salvo/atualizado para ${action.verseId} com cor ${action.colorHex}");
      }
      store.dispatch(
          LoadUserHighlightsAction()); // Recarrega para atualizar o estado
    } catch (e) {
      print(
          "UserMiddleware: Erro ao adicionar/remover destaque de versículo: $e");
    }
  };
}

// Notas de Versículos Bíblicos
void Function(Store<AppState>, LoadUserNotesAction, NextDispatcher)
    _loadUserNotes(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(UserNotesLoadedAction({}));
      return;
    }
    try {
      final notes = await firestoreService
          .loadUserNotes(userId); // Chama a função atualizada
      store.dispatch(UserNotesLoadedAction(notes));
    } catch (e) {
      print("UserMiddleware: Erro ao carregar notas de versículos: $e");
      store.dispatch(UserNotesLoadedAction({}));
    }
  };
}

void Function(Store<AppState>, SaveNoteAction, NextDispatcher) _saveNote(
    FirestoreService firestoreService) {
  return (store, action, next) async {
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.saveNote(
          userId, action.verseId, action.text); // Chama a função atualizada
      print("UserMiddleware: Nota salva para ${action.verseId}");
      store.dispatch(LoadUserNotesAction());
    } catch (e) {
      print("UserMiddleware: Erro ao salvar nota: $e");
    }
  };
}

void Function(Store<AppState>, DeleteNoteAction, NextDispatcher) _deleteNote(
    FirestoreService firestoreService) {
  return (store, action, next) async {
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.removeNote(
          userId, action.verseId); // Chama a função atualizada
      print("UserMiddleware: Nota removida para ${action.verseId}");
      store.dispatch(LoadUserNotesAction());
    } catch (e) {
      print("UserMiddleware: Erro ao deletar nota: $e");
    }
  };
}

// Destaques de Comentários Bíblicos
void Function(Store<AppState>, LoadUserCommentHighlightsAction, NextDispatcher)
    _loadUserCommentHighlights(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(UserCommentHighlightsLoadedAction([]));
      return;
    }
    try {
      final highlights = await firestoreService
          .loadUserCommentHighlights(userId); // Chama a função atualizada
      store.dispatch(UserCommentHighlightsLoadedAction(highlights));
    } catch (e) {
      print("UserMiddleware: Erro ao carregar destaques de comentários: $e");
      store.dispatch(UserCommentHighlightsLoadedAction([]));
    }
  };
}

void Function(Store<AppState>, AddCommentHighlightAction, NextDispatcher)
    _addCommentHighlight(FirestoreService firestoreService) {
  return (store, action, next) async {
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.addCommentHighlight(
          userId, action.commentHighlightData); // Chama a função atualizada
      print("UserMiddleware: Destaque de comentário adicionado.");
      store.dispatch(LoadUserCommentHighlightsAction());
    } catch (e) {
      print("UserMiddleware: Erro ao adicionar destaque de comentário: $e");
    }
  };
}

void Function(Store<AppState>, RemoveCommentHighlightAction, NextDispatcher)
    _removeCommentHighlight(FirestoreService firestoreService) {
  return (store, action, next) async {
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.removeCommentHighlight(
          userId, action.commentHighlightId); // Chama a função atualizada
      print(
          "UserMiddleware: Destaque de comentário removido: ${action.commentHighlightId}");
      store.dispatch(LoadUserCommentHighlightsAction());
    } catch (e) {
      print("UserMiddleware: Erro ao remover destaque de comentário: $e");
    }
  };
}
