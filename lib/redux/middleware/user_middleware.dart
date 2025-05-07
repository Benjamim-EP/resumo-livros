// lib/redux/middleware/user_middleware.dart

import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../actions.dart';
import '../store.dart';
import '../../services/firestore_service.dart'; // Assumindo a criação deste serviço
import '../../services/local_storage_service.dart'; // Assumindo a criação

List<Middleware<AppState>> createUserMiddleware() {
  final firestoreService = FirestoreService();
  final localStorageService = LocalStorageService();

  return [
    TypedMiddleware<AppState, LoadUserStatsAction>(
        _loadUserStats(firestoreService)),
    TypedMiddleware<AppState, LoadUserDetailsAction>(
        _loadUserDetails(firestoreService)),
    TypedMiddleware<AppState, LoadUserPremiumStatusAction>(
        _loadUserPremiumStatus(firestoreService)),
    // Ação dinâmica para _loadUserCollections
    TypedMiddleware<AppState, dynamic>(
        _loadUserCollectionsMiddleware(firestoreService)),
    TypedMiddleware<AppState, SaveTopicToCollectionAction>(
        _saveTopicToCollection(firestoreService)),
    TypedMiddleware<AppState, SaveVerseToCollectionAction>(
        _saveVerseToCollection(firestoreService)),
    // TypedMiddleware<AppState, LoadBooksInProgressAction>(_loadBooksInProgress(firestoreService)), // Desativado
    // TypedMiddleware<AppState, LoadBooksDetailsAction>(_loadBooksDetails(firestoreService)), // Desativado
    TypedMiddleware<AppState, UpdateUserFieldAction>(
        _updateUserField(firestoreService)),
    TypedMiddleware<AppState, SaveUserFeaturesAction>(
        _saveUserFeatures(firestoreService)),
    TypedMiddleware<AppState, CheckFirstLoginAction>(
        _checkFirstLogin(firestoreService)),
    TypedMiddleware<AppState, LoadTopicsContentUserSavesAction>(
        _loadTopicsContentUserSaves(firestoreService)),
    TypedMiddleware<AppState, DeleteTopicCollectionAction>(
        _deleteTopicCollection(firestoreService)),
    TypedMiddleware<AppState, DeleteSingleTopicFromCollectionAction>(
        _deleteSingleTopicFromCollection(firestoreService)),
    TypedMiddleware<AppState, AddDiaryEntryAction>(
        _addDiaryEntry(firestoreService)),
    TypedMiddleware<AppState, LoadUserDiariesAction>(
        _loadUserDiaries(firestoreService)),
    TypedMiddleware<AppState, LoadUserHighlightsAction>(
        _loadUserHighlights(firestoreService)),
    TypedMiddleware<AppState, ToggleHighlightAction>(
        _toggleHighlight(firestoreService)),
    TypedMiddleware<AppState, LoadUserNotesAction>(
        _loadUserNotes(firestoreService)),
    TypedMiddleware<AppState, SaveNoteAction>(_saveNote(firestoreService)),
    TypedMiddleware<AppState, DeleteNoteAction>(_deleteNote(firestoreService)),
    // Histórico de Leitura
    TypedMiddleware<AppState, RecordReadingHistoryAction>(
        _handleRecordReadingHistory(firestoreService)),
    TypedMiddleware<AppState, LoadReadingHistoryAction>(
        _handleLoadReadingHistory(firestoreService)),
  ];
}

// --- Handlers ---

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
      } else {
        print('Usuário não encontrado no Firestore para stats.');
      }
    } catch (e) {
      print('Erro ao carregar stats do usuário: $e');
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
        store.dispatch(UserDetailsLoadedAction(
            details)); // O reducer agora pega lastRead daqui
      } else {
        print('Usuário não encontrado no Firestore para details.');
      }
    } catch (e) {
      print('Erro ao carregar detalhes do usuário: $e');
    }
  };
}

void Function(Store<AppState>, LoadUserPremiumStatusAction, NextDispatcher)
    _loadUserPremiumStatus(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadUserPremiumStatusAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      final premiumStatus = await firestoreService.getUserPremiumStatus(userId);
      store.dispatch(UserPremiumStatusLoadedAction(premiumStatus ?? {}));
    } catch (e) {
      print('Erro ao carregar status premium do usuário: $e');
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
        print('Erro ao carregar coleções do usuário: $e');
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
      final collections = await firestoreService.getUserCollections(userId);
      store.dispatch(UserCollectionsLoadedAction(collections ?? {}));
      print(
          'Tópico ${action.topicId} salvo na coleção "${action.collectionName}".');
    } catch (e) {
      print('Erro ao salvar tópico na coleção: $e');
    }
  };
}

void Function(Store<AppState>, SaveVerseToCollectionAction, NextDispatcher)
    _saveVerseToCollection(FirestoreService firestoreService) {
  return (Store<AppState> store, SaveVerseToCollectionAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.saveVerseToCollection(
          userId, action.collectionName, action.verseId);
      final collections = await firestoreService.getUserCollections(userId);
      store.dispatch(UserCollectionsLoadedAction(collections ?? {}));
      print(
          'Versículo ${action.verseId} salvo na coleção "${action.collectionName}".');
    } catch (e) {
      print('Erro ao salvar versículo na coleção: $e');
    }
  };
}

// --- Middlewares de Progresso de Livro (Comentados) ---
/*
void Function(Store<AppState>, LoadBooksInProgressAction, NextDispatcher) _loadBooksInProgress(FirestoreService firestoreService) {
  // ... (lógica original)
}

void Function(Store<AppState>, LoadBooksDetailsAction, NextDispatcher) _loadBooksDetails(FirestoreService firestoreService) {
  // ... (lógica original)
}
*/

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
      final stats = await firestoreService.getUserStats(userId);
      if (stats != null) {
        store.dispatch(UserStatsLoadedAction(stats));
      }
      print('Campo "${action.field}" atualizado com sucesso.');
    } catch (e) {
      print('Erro ao atualizar o campo "${action.field}": $e');
    }
  };
}

void Function(Store<AppState>, SaveUserFeaturesAction, NextDispatcher)
    _saveUserFeatures(FirestoreService firestoreService) {
  return (Store<AppState> store, SaveUserFeaturesAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      print('UID do usuário ausente. Não é possível salvar features.');
      return;
    }
    try {
      await firestoreService.updateUserFeatures(userId, action.features);
      store.dispatch(UserFeaturesLoadedAction(action.features));
      print('Features do usuário salvas com sucesso.');
    } catch (e) {
      print('Erro ao salvar features do usuário: $e');
    }
  };
}

void Function(Store<AppState>, CheckFirstLoginAction, NextDispatcher)
    _checkFirstLogin(FirestoreService firestoreService) {
  return (Store<AppState> store, CheckFirstLoginAction action,
      NextDispatcher next) async {
    next(action);
    try {
      final isFirstLogin =
          await firestoreService.checkAndSetFirstLogin(action.userId);
      store.dispatch(FirstLoginSuccessAction(isFirstLogin));
    } catch (e) {
      store.dispatch(FirstLoginFailureAction('Erro ao verificar login: $e'));
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

        for (var verseId in verseIdsToProcess) {
          final parts = verseId.split("-");
          if (parts.length == 4) {
            final bookAbbrev = parts[1];
            final chapter = parts[2];
            final verse = parts[3];
            String bookName =
                await firestoreService.getBookNameFromAbbrev(bookAbbrev) ??
                    bookAbbrev;
            // Considerar buscar o texto real do versículo aqui se necessário para a UI 'Salvos'
            // String verseText = await BiblePageHelper.loadSingleVerseText(verseId.replaceFirst("bibleverses-", "").replaceAll("-", "_"), 'nvi');
            contentList.add({
              'id': verseId,
              'cover': 'assets/images/biblia_cover_placeholder.png',
              'bookName': bookName, 'chapterName': chapter,
              'titulo': "$bookName $chapter:$verse",
              'conteudo': "Versículo salvo", // Placeholder
            });
          }
        }
        topicsByCollection[collectionName] = contentList;
      }
      store.dispatch(
          LoadTopicsContentUserSavesSuccessAction(topicsByCollection));
    } catch (e) {
      store.dispatch(LoadTopicsContentUserSavesFailureAction(
          'Erro ao carregar tópicos salvos: $e'));
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
      final collections = await firestoreService.getUserCollections(userId);
      store.dispatch(UserCollectionsLoadedAction(collections ?? {}));
      store.dispatch(
          LoadTopicsContentUserSavesAction()); // Recarrega conteúdo após deletar
    } catch (e) {
      print('Erro ao excluir coleção de tópicos: $e');
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
      final collections = await firestoreService.getUserCollections(userId);
      store.dispatch(UserCollectionsLoadedAction(collections ?? {}));
      store.dispatch(
          LoadTopicsContentUserSavesAction()); // Recarrega conteúdo após deletar item
    } catch (e) {
      print('Erro ao excluir tópico da coleção: $e');
    }
  };
}

void Function(Store<AppState>, AddDiaryEntryAction, NextDispatcher)
    _addDiaryEntry(FirestoreService firestoreService) {
  return (Store<AppState> store, AddDiaryEntryAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.addDiaryEntry(
          userId, action.title, action.content);
      store.dispatch(LoadUserDiariesAction()); // Recarrega após adicionar
    } catch (e) {
      print("Erro ao adicionar diário: $e");
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
      print("Erro ao carregar os diários: $e");
      store.dispatch(LoadUserDiariesFailureAction(e.toString()));
    }
  };
}

// --- Highlight Middlewares ---
void Function(Store<AppState>, LoadUserHighlightsAction, NextDispatcher)
    _loadUserHighlights(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      final highlights = await firestoreService.loadUserHighlights(userId);
      store.dispatch(UserHighlightsLoadedAction(highlights));
    } catch (e) {
      print("Erro ao carregar destaques do usuário: $e");
    }
  };
}

void Function(Store<AppState>, ToggleHighlightAction, NextDispatcher)
    _toggleHighlight(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      if (action.colorHex == null) {
        await firestoreService.removeHighlight(userId, action.verseId);
      } else {
        await firestoreService.saveHighlight(
            userId, action.verseId, action.colorHex!);
      }
      store.dispatch(LoadUserHighlightsAction()); // Recarrega após alteração
    } catch (e) {
      print("Erro ao adicionar/remover destaque: $e");
    }
  };
}

// --- Note Middlewares ---
void Function(Store<AppState>, LoadUserNotesAction, NextDispatcher)
    _loadUserNotes(FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      final notes = await firestoreService.loadUserNotes(userId);
      store.dispatch(UserNotesLoadedAction(notes));
    } catch (e) {
      print("Erro ao carregar notas do usuário: $e");
    }
  };
}

void Function(Store<AppState>, SaveNoteAction, NextDispatcher) _saveNote(
    FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.saveNote(userId, action.verseId, action.text);
      store.dispatch(LoadUserNotesAction()); // Recarrega notas
    } catch (e) {
      print("Erro ao salvar nota: $e");
    }
  };
}

void Function(Store<AppState>, DeleteNoteAction, NextDispatcher) _deleteNote(
    FirestoreService firestoreService) {
  return (store, action, next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      await firestoreService.removeNote(userId, action.verseId);
      store.dispatch(LoadUserNotesAction()); // Recarrega notas
    } catch (e) {
      print("Erro ao deletar nota: $e");
    }
  };
}

// --- Reading History Middlewares ---
void Function(Store<AppState>, RecordReadingHistoryAction, NextDispatcher)
    _handleRecordReadingHistory(FirestoreService firestoreService) {
  return (Store<AppState> store, RecordReadingHistoryAction action,
      NextDispatcher next) async {
    // Atualiza o estado Redux imediatamente (otimista) para lastRead
    store.dispatch(
        UpdateLastReadLocationAction(action.bookAbbrev, action.chapter));
    next(action);

    final userId = store.state.userState.userId;
    if (userId == null) {
      print("Histórico: Usuário não logado.");
      return;
    }

    // Busca o nome do livro para salvar no histórico
    String bookName = action.bookAbbrev.toUpperCase();
    try {
      // Tentativa de pegar do booksMap local da BiblePage (idealmente via estado Redux se disponível)
      // Se não disponível, busca no Firestore
      final bookData =
          await firestoreService.getBookDataByAbbrev(action.bookAbbrev);
      if (bookData != null) {
        bookName = bookData['titulo'] ?? bookName;
      }
    } catch (e) {
      print("Erro ao buscar nome do livro para histórico: $e");
    }

    try {
      // Salva no Firestore
      await firestoreService.addReadingHistoryEntry(
          userId, action.bookAbbrev, action.chapter, bookName);
      await firestoreService.updateLastReadLocation(
          userId, action.bookAbbrev, action.chapter);
    } catch (e) {
      print('Erro ao salvar histórico/última leitura: $e');
    }
  };
}

void Function(Store<AppState>, LoadReadingHistoryAction, NextDispatcher)
    _handleLoadReadingHistory(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadReadingHistoryAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;

    try {
      final history = await firestoreService.loadReadingHistory(userId);
      store.dispatch(ReadingHistoryLoadedAction(history));
    } catch (e) {
      print('Erro ao carregar histórico de leitura: $e');
      store.dispatch(ReadingHistoryLoadedAction([]));
    }
  };
}
