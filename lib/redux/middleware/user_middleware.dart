import 'package:intl/intl.dart';
import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../actions.dart';
import '../store.dart';
import '../../services/firestore_service.dart'; // Assumindo a criação deste serviço
import '../../services/local_storage_service.dart'; // Assumindo a criação

List<Middleware<AppState>> createUserMiddleware() {
  final firestoreService = FirestoreService();
  final localStorageService =
      LocalStorageService(); // Instanciação adicionada se for usar _handleUserLogin

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
    TypedMiddleware<AppState, LoadBooksInProgressAction>(
        _loadBooksInProgress(firestoreService)),
    TypedMiddleware<AppState, LoadBooksDetailsAction>(_loadBooksDetails(
        firestoreService)), // Carrega detalhes para a lista 'Lendo'
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
  ];
}

// --- Handlers ---

// CORRIGIDO: Tipo de retorno
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

// CORRIGIDO: Tipo de retorno
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
      } else {
        print('Usuário não encontrado no Firestore para details.');
      }
    } catch (e) {
      print('Erro ao carregar detalhes do usuário: $e');
    }
  };
}

// CORRIGIDO: Tipo de retorno
void Function(Store<AppState>, LoadUserPremiumStatusAction, NextDispatcher)
    _loadUserPremiumStatus(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadUserPremiumStatusAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) return;
    try {
      final premiumStatus = await firestoreService.getUserPremiumStatus(userId);
      store.dispatch(UserPremiumStatusLoadedAction(
          premiumStatus ?? {})); // Envia mapa vazio se nulo
    } catch (e) {
      print('Erro ao carregar status premium do usuário: $e');
    }
  };
}

// Middleware para lidar com ações dinâmicas (LoadUserTopicCollectionsAction e LoadUserCollectionsAction)
// CORRIGIDO: Tipo de retorno
void Function(Store<AppState>, dynamic, NextDispatcher)
    _loadUserCollectionsMiddleware(FirestoreService firestoreService) {
  return (Store<AppState> store, dynamic action, NextDispatcher next) async {
    // Primeiro, passa a ação para o próximo middleware/reducer
    next(action);

    // Verifica se a ação é uma das que queremos tratar
    if (action is LoadUserTopicCollectionsAction ||
        action is LoadUserCollectionsAction) {
      final userId = store.state.userState.userId;
      if (userId == null) return;
      try {
        final collections = await firestoreService.getUserCollections(userId);
        // Despacha a ação específica correspondente
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

// CORRIGIDO: Tipo de retorno
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
      // Recarrega as coleções para atualizar o estado
      final collections = await firestoreService.getUserCollections(userId);
      store.dispatch(UserCollectionsLoadedAction(collections ?? {}));
      print(
          'Tópico ${action.topicId} salvo na coleção "${action.collectionName}".');
    } catch (e) {
      print('Erro ao salvar tópico na coleção: $e');
    }
  };
}

// CORRIGIDO: Tipo de retorno
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
      store.dispatch(
          UserCollectionsLoadedAction(collections ?? {})); // Atualiza Redux
      print(
          'Versículo ${action.verseId} salvo na coleção "${action.collectionName}".');
    } catch (e) {
      print('Erro ao salvar versículo na coleção: $e');
    }
  };
}

// CORRIGIDO: Tipo de retorno
void Function(Store<AppState>, LoadBooksInProgressAction, NextDispatcher)
    _loadBooksInProgress(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadBooksInProgressAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      print("Usuário não autenticado.");
      return;
    }
    try {
      final booksProgressRaw =
          await firestoreService.getBooksProgressRaw(userId);
      final books = <Map<String, dynamic>>[];

      print("📚 Dados brutos do Firestore (Progresso): $booksProgressRaw");

      if (booksProgressRaw != null) {
        for (final bookId in booksProgressRaw.keys) {
          final bookProgress = booksProgressRaw[bookId];
          if (bookProgress is Map<String, dynamic>) {
            // Verifica se é um mapa
            final chaptersIniciados =
                bookProgress['chaptersIniciados'] as List<dynamic>? ?? [];
            print("📖 Livro: $bookId, Capítulos Iniciados: $chaptersIniciados");
            books.add({
              'id': bookId,
              'progress': bookProgress['progress'] ?? 0,
              'chaptersIniciados': List<String>.from(chaptersIniciados
                  .map((e) => e.toString())), // Garante lista de strings
            });
          } else {
            print(
                "⚠ Formato inesperado para o progresso do livro $bookId: $bookProgress");
          }
        }
      }
      store.dispatch(BooksInProgressLoadedAction(books));
    } catch (e) {
      print('❌ Erro ao carregar progresso dos livros: $e');
    }
  };
}

// CORRIGIDO: Tipo de retorno
void Function(Store<AppState>, LoadBooksDetailsAction, NextDispatcher)
    _loadBooksDetails(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadBooksDetailsAction action,
      NextDispatcher next) async {
    next(action);
    final booksInProgress =
        store.state.userState.booksInProgress; // Pega do estado Redux

    if (booksInProgress.isEmpty) {
      store.dispatch(LoadBooksDetailsFailureAction(
          'Nenhum livro em progresso para carregar detalhes.'));
      return;
    }

    try {
      final List<Map<String, dynamic>> booksDetails = [];
      for (final bookProgressInfo in booksInProgress) {
        final bookId = bookProgressInfo['id'];
        if (bookId == null) continue;

        final bookData =
            await firestoreService.getBookData(bookId); // Busca dados do livro

        if (bookData != null) {
          booksDetails.add({
            'id': bookId,
            'title': bookData['titulo'] ?? 'Título desconhecido',
            'author': bookData['autorId'] ??
                'Autor desconhecido', // Note que pode ser ID ou nome
            'cover': bookData['cover'],
            'progress': bookProgressInfo['progress'], // Pega do estado
            'chaptersIniciados':
                bookProgressInfo['chaptersIniciados'], // Pega do estado
          });
        }
      }
      store.dispatch(LoadBooksDetailsSuccessAction(booksDetails));
    } catch (e) {
      store.dispatch(LoadBooksDetailsFailureAction(
          'Erro ao carregar detalhes dos livros em progresso: $e'));
    }
  };
}

// CORRIGIDO: Tipo de retorno
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
      // Recarrega os stats/detalhes para refletir a mudança no estado Redux
      final stats = await firestoreService.getUserStats(userId);
      if (stats != null) {
        store.dispatch(UserStatsLoadedAction(
            stats)); // Atualiza o estado com os dados do Firestore
      }
      print('Campo "${action.field}" atualizado com sucesso.');
    } catch (e) {
      print('Erro ao atualizar o campo "${action.field}": $e');
    }
  };
}

// CORRIGIDO: Tipo de retorno
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
      store.dispatch(UserFeaturesLoadedAction(
          action.features)); // Atualiza Redux localmente
      print('Features do usuário salvas com sucesso.');
    } catch (e) {
      print('Erro ao salvar features do usuário: $e');
    }
  };
}

// CORRIGIDO: Tipo de retorno
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

// CORRIGIDO: Tipo de retorno
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
        final ids = entry.value; // Lista de IDs (tópicos ou versículos)

        final List<Map<String, dynamic>> contentList = [];
        List<String> topicIdsToFetch = [];
        List<String> verseIdsToProcess = [];

        // Separa IDs de tópicos e versículos
        for (var id in ids) {
          if (id.startsWith("bibleverses-")) {
            verseIdsToProcess.add(id);
          } else {
            topicIdsToFetch.add(id);
          }
        }

        // Busca conteúdo dos tópicos no Firestore
        if (topicIdsToFetch.isNotEmpty) {
          final topicsData =
              await firestoreService.fetchTopicsByIds(topicIdsToFetch);
          contentList.addAll(topicsData);
        }

        // Processa versículos da Bíblia (gera dados mock ou busca real se implementado)
        for (var verseId in verseIdsToProcess) {
          final parts = verseId.split("-");
          if (parts.length == 4) {
            final bookAbbrev = parts[1];
            final chapter = parts[2];
            final verse = parts[3];
            String bookName =
                await firestoreService.getBookNameFromAbbrev(bookAbbrev) ??
                    bookAbbrev;
            String verseText =
                "Texto do versículo $chapter:$verse"; // Placeholder

            contentList.add({
              'id': verseId,
              'cover':
                  'assets/images/biblia_cover_placeholder.png', // Placeholder
              'bookName': bookName,
              'chapterName': chapter,
              'titulo': "$bookName $chapter:$verse",
              'conteudo': verseText,
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

// CORRIGIDO: Tipo de retorno
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
    } catch (e) {
      print('Erro ao excluir coleção de tópicos: $e');
    }
  };
}

// CORRIGIDO: Tipo de retorno
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
    } catch (e) {
      print('Erro ao excluir tópico da coleção: $e');
    }
  };
}

// CORRIGIDO: Tipo de retorno
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
      store.dispatch(LoadUserDiariesAction());
    } catch (e) {
      print("Erro ao adicionar diário: $e");
    }
  };
}

// CORRIGIDO: Tipo de retorno
void Function(Store<AppState>, LoadUserDiariesAction, NextDispatcher)
    _loadUserDiaries(FirestoreService firestoreService) {
  return (Store<AppState> store, LoadUserDiariesAction action,
      NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      print("Usuário não autenticado. Não é possível carregar os diários.");
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
      // Opcional: despachar ação de erro
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
        // Remover destaque
        await firestoreService.removeHighlight(userId, action.verseId);
      } else {
        // Adicionar ou atualizar destaque
        await firestoreService.saveHighlight(
            userId, action.verseId, action.colorHex!);
      }
      // Recarregar os destaques para atualizar o estado
      store.dispatch(LoadUserHighlightsAction());
    } catch (e) {
      print("Erro ao adicionar/remover destaque: $e");
      // Opcional: despachar ação de erro
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
