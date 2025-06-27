// lib/redux/middleware/user_middleware.dart
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';

List<Middleware<AppState>> createUserMiddleware() {
  final firestoreService = FirestoreService();

  return [
    TypedMiddleware<AppState, LoadUserTagsAction>((store, action, next) async {
      next(action);
      final userId = store.state.userState.userId;
      if (userId == null) return;
      try {
        final tags = await firestoreService.loadUserTags(userId);
        store.dispatch(UserTagsLoadedAction(tags));
      } catch (e) {
        print("Erro ao carregar tags do usuário: $e");
      }
    }).call,

    TypedMiddleware<AppState, EnsureUserTagExistsAction>(
        (store, action, next) async {
      next(action);
      final userId = store.state.userState.userId;
      if (userId == null) return;
      try {
        await firestoreService.ensureUserTagExists(userId, action.tagName);
      } catch (e) {
        print("Erro ao garantir a existência da tag: $e");
      }
    }).call,

    TypedMiddleware<AppState, LoadUserStatsAction>(
            _loadUserStats(firestoreService))
        .call,
    TypedMiddleware<AppState, LoadUserDetailsAction>(
            _loadUserDetails(firestoreService))
        .call,
    TypedMiddleware<AppState, UpdateUserFieldAction>(
            _updateUserField(firestoreService))
        .call,

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

    TypedMiddleware<AppState, AddDiaryEntryAction>(
            _addDiaryEntry(firestoreService))
        .call,
    TypedMiddleware<AppState, LoadUserDiariesAction>(
            _loadUserDiaries(firestoreService))
        .call,

    TypedMiddleware<AppState, RecordReadingHistoryAction>(
            _handleRecordReadingHistory(firestoreService))
        .call,
    TypedMiddleware<AppState, LoadReadingHistoryAction>(
            _handleLoadReadingHistory(firestoreService))
        .call,

    // Destaques de Versículos Bíblicos
    TypedMiddleware<AppState, LoadUserHighlightsAction>(
            _loadUserHighlights(firestoreService))
        .call,
    TypedMiddleware<AppState, ToggleHighlightAction>(
            _toggleHighlight(firestoreService))
        .call,

    TypedMiddleware<AppState, LoadUserNotesAction>(
            _loadUserNotes(firestoreService))
        .call,
    TypedMiddleware<AppState, SaveNoteAction>(_saveNote(firestoreService)).call,
    TypedMiddleware<AppState, DeleteNoteAction>(_deleteNote(firestoreService))
        .call,

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

// >>> INÍCIO DA CORREÇÃO <<<
// Corrigindo o handler de LoadUserHighlightsAction
void Function(Store<AppState>, LoadUserHighlightsAction, NextDispatcher)
    _loadUserHighlights(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      // Despacha um mapa vazio do tipo CORRETO
      store.dispatch(UserHighlightsLoadedAction({}));
      return;
    }
    try {
      // O serviço agora retorna Map<String, Map<String, dynamic>>
      final highlights = await firestoreService.loadUserHighlights(userId);
      store.dispatch(UserHighlightsLoadedAction(highlights));
    } catch (e) {
      print("Erro ao carregar destaques: $e");
      // Despacha um mapa vazio do tipo CORRETO em caso de erro
      store.dispatch(UserHighlightsLoadedAction({}));
    }
  };
}

// Corrigindo o handler de ToggleHighlightAction
void Function(Store<AppState>, ToggleHighlightAction, NextDispatcher)
    _toggleHighlight(FirestoreService firestoreService) {
  return (store, action, next) async {
    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      if (action.colorHex == null) {
        await firestoreService.removeHighlight(userId, action.verseId);
      } else {
        await firestoreService.saveHighlight(
          userId,
          action.verseId,
          action.colorHex!,
          tags: action.tags,
        );

        if (action.tags != null) {
          for (var tag in action.tags!) {
            store.dispatch(EnsureUserTagExistsAction(tag));
          }
        }
      }
      store.dispatch(LoadUserHighlightsAction());
      store.dispatch(LoadUserTagsAction());
    } catch (e) {
      print("Erro no middleware ToggleHighlightAction: $e");
    }
  };
}

// Corrigindo o handler de AddCommentHighlightAction
void Function(Store<AppState>, AddCommentHighlightAction, NextDispatcher)
    _addCommentHighlight(FirestoreService firestoreService) {
  return (store, action, next) async {
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.addCommentHighlight(
          userId, action.commentHighlightData);

      final tags = action.commentHighlightData['tags'] as List<String>?;
      if (tags != null) {
        for (var tag in tags) {
          store.dispatch(EnsureUserTagExistsAction(tag));
        }
      }
      store.dispatch(LoadUserCommentHighlightsAction());
      store.dispatch(LoadUserTagsAction());
    } catch (e) {
      print("Erro no middleware AddCommentHighlightAction: $e");
    }
  };
}
// >>> FIM DA CORREÇÃO <<<

// --- O resto das funções permanece igual ---

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
      final details = await firestoreService.getUserDetails(userId);
      if (details != null) {
        store.dispatch(UserDetailsLoadedAction(details));
      }
    } catch (e) {
      print(
          'UserMiddleware: Erro ao atualizar o campo "${action.field}" para $userId: $e');
    }
  };
}

void Function(Store<AppState>, dynamic, NextDispatcher)
    _loadUserCollectionsMiddleware(FirestoreService firestoreService) {
  return (Store<AppState> store, dynamic action, NextDispatcher next) async {
    next(action);
    if (action is LoadUserTopicCollectionsAction ||
        action is LoadUserCollectionsAction) {
      final userId = store.state.userState.userId;
      if (userId == null) return;
      try {
        final collections = await firestoreService.getUserCollections(userId);
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
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.saveTopicToCollection(
          userId, action.collectionName, action.topicId);
    } catch (e) {
      print('UserMiddleware: Erro ao salvar tópico na coleção: $e');
    }
  };
}

void Function(Store<AppState>, DeleteTopicCollectionAction, NextDispatcher)
    _deleteTopicCollection(FirestoreService firestoreService) {
  return (Store<AppState> store, DeleteTopicCollectionAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.deleteTopicCollection(
          userId, action.collectionName);
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
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.deleteSingleTopicFromCollection(
          userId, action.collectionName, action.topicId);
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
        final ids = entry.value;
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

void Function(Store<AppState>, AddDiaryEntryAction, NextDispatcher)
    _addDiaryEntry(FirestoreService firestoreService) {
  return (Store<AppState> store, AddDiaryEntryAction action,
      NextDispatcher next) async {
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.addDiaryEntry(
          userId, action.title, action.content);
      store.dispatch(LoadUserDiariesAction());
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

void Function(Store<AppState>, RecordReadingHistoryAction, NextDispatcher)
    _handleRecordReadingHistory(FirestoreService firestoreService) {
  return (Store<AppState> store, RecordReadingHistoryAction action,
      NextDispatcher next) async {
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      final Map<String, dynamic>? booksMapFromHelper =
          await BiblePageHelper.loadBooksMap();
      String bookNameToUseForHistory = booksMapFromHelper?[action.bookAbbrev]
              ?['nome'] ??
          action.bookAbbrev.toUpperCase();
      await firestoreService.addReadingHistoryEntry(
          userId, action.bookAbbrev, action.chapter, bookNameToUseForHistory);
      await firestoreService.updateLastReadLocation(
          userId, action.bookAbbrev, action.chapter);
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
      final history = await firestoreService.loadReadingHistory(userId);
      store.dispatch(ReadingHistoryLoadedAction(history));
    } catch (e) {
      print(
          'UserMiddleware: Erro ao carregar histórico de leitura detalhado: $e');
      store.dispatch(ReadingHistoryLoadedAction([]));
    }
  };
}

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
      final notes = await firestoreService.loadUserNotes(userId);
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
      await firestoreService.saveNote(userId, action.verseId, action.text);
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
      await firestoreService.removeNote(userId, action.verseId);
      store.dispatch(LoadUserNotesAction());
    } catch (e) {
      print("UserMiddleware: Erro ao deletar nota: $e");
    }
  };
}

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
      final highlights =
          await firestoreService.loadUserCommentHighlights(userId);
      store.dispatch(UserCommentHighlightsLoadedAction(highlights));
    } catch (e) {
      print("UserMiddleware: Erro ao carregar destaques de comentários: $e");
      store.dispatch(UserCommentHighlightsLoadedAction([]));
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
          userId, action.commentHighlightId);
      store.dispatch(LoadUserCommentHighlightsAction());
    } catch (e) {
      print("UserMiddleware: Erro ao remover destaque de comentário: $e");
    }
  };
}
