// lib/redux/middleware/bible_progress_middleware.dart
import 'dart:convert'; // Para SharedPreferences
import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/actions.dart'; // Para UpdateLastReadLocationAction
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/redux/reducers.dart'; // Para BibleBookProgressData
import 'package:shared_preferences/shared_preferences.dart';

const String _pendingBibleToAddKey = 'pendingBibleSectionsToAdd';
const String _pendingBibleToRemoveKey = 'pendingBibleSectionsToRemove';

List<Middleware<AppState>> createBibleProgressMiddleware() {
  final firestoreService = FirestoreService();
  // <<< NOVA FUNÇÃO HANDLER >>>
  void handleMarkChapterAsRead(Store<AppState> store,
      MarkChapterAsReadAction action, NextDispatcher next) async {
    next(action); // Passa a ação para o próximo middleware/reducer

    final userId = store.state.userState.userId;
    if (userId == null) {
      print("MarkChapterAsReadMiddleware: Usuário não logado.");
      return;
    }

    try {
      print(
          "MarkChapterAsReadMiddleware: Marcando capítulo ${action.bookAbbrev} ${action.chapterNumber} como lido...");

      // A ação já contém a lista de IDs de seção, então não precisamos buscá-la novamente.
      final sectionsToAdd = action.sectionIdsInChapter;

      // Chama a função de batch update que já existe no seu FirestoreService.
      // O `totalSectionsInBookFromMetadata` já é pego de dentro do `batchUpdateBibleProgress`.
      await firestoreService.batchUpdateBibleProgress(
        userId,
        action.bookAbbrev,
        sectionsToAdd, // Adiciona todas as seções do capítulo
        [], // Nenhuma para remover
        store.state.metadataState.bibleSectionCounts['livros']
                ?[action.bookAbbrev]?['total_secoes_livro'] as int? ??
            sectionsToAdd.length,
      );

      print(
          "MarkChapterAsReadMiddleware: Sincronização do capítulo completo com o Firestore BEM-SUCEDIDA.");

      // Após a escrita bem-sucedida, despacha uma ação para recarregar o progresso do livro
      // para garantir que a UI reflita o estado 100% lido.
      store.dispatch(LoadBibleBookProgressAction(action.bookAbbrev));
    } catch (e) {
      print(
          "MarkChapterAsReadMiddleware: ERRO ao marcar capítulo como lido: $e");
      // Opcional: despachar uma ação de falha para a UI.
    }
  }

  // --- HANDLER PARA CARREGAR PROGRESSO DE UM LIVRO ESPECÍFICO ---
  void handleLoadBibleBookProgress(Store<AppState> store,
      LoadBibleBookProgressAction action, NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(BibleProgressFailureAction(
          "Usuário não autenticado ao carregar progresso do livro."));
      return;
    }

    try {
      BibleBookProgressData? progressData = await firestoreService
          .getBibleBookProgress(userId, action.bookAbbrev);

      if (progressData != null) {
        store.dispatch(BibleBookProgressLoadedAction(
          bookAbbrev: action.bookAbbrev,
          readSections: progressData.readSections,
          totalSectionsInBook: progressData.totalSections,
          isCompleted: progressData.completed,
          lastReadTimestamp: progressData.lastReadTimestamp,
        ));
      } else {
        int totalSectionsFromMetadata =
            store.state.metadataState.bibleSectionCounts['livros']
                    ?[action.bookAbbrev]?['total_secoes_livro'] as int? ??
                action.knownTotalSections ??
                0;

        store.dispatch(BibleBookProgressLoadedAction(
          bookAbbrev: action.bookAbbrev,
          readSections: {},
          totalSectionsInBook: totalSectionsFromMetadata,
          isCompleted: false,
          lastReadTimestamp: null,
        ));
        print(
            "BibleProgressMiddleware: Nenhum progresso no Firestore para ${action.bookAbbrev}. Iniciando com base nos metadados (Total: $totalSectionsFromMetadata).");
      }
    } catch (e) {
      print(
          "Erro em handleLoadBibleBookProgress para ${action.bookAbbrev}: $e");
      store.dispatch(BibleProgressFailureAction(
          "Erro ao carregar progresso do livro ${action.bookAbbrev}: $e"));
    }
  }

  // --- HANDLER PARA CARREGAR PROGRESSO DE TODOS OS LIVROS ---
  void handleLoadAllBibleProgress(Store<AppState> store,
      LoadAllBibleProgressAction action, NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(BibleProgressFailureAction(
          "Usuário não autenticado para carregar todo o progresso bíblico."));
      // <<< MUDANÇA ESSENCIAL AQUI >>>
      action.completer?.completeError(Exception("Usuário não autenticado."));
      return;
    }
    try {
      final Map<String, BibleBookProgressData> allProgressData =
          await firestoreService.getAllBibleProgress(userId);
      store.dispatch(AllBibleProgressLoadedAction(allProgressData));

      DocumentSnapshot? userProgressDoc =
          await firestoreService.getBibleProgressDocument(userId);

      if (userProgressDoc != null && userProgressDoc.exists) {
        // ... sua lógica para carregar a última leitura ...
        final data = userProgressDoc.data() as Map<String, dynamic>;
        final String? lastBook = data['lastReadBookAbbrev'] as String?;
        final int? lastChapter = data['lastReadChapter'] as int?;

        if (lastBook != null && lastChapter != null) {
          store.dispatch(UpdateLastReadLocationAction(lastBook, lastChapter));
        }
      }

      // <<< MUDANÇA ESSENCIAL AQUI >>>
      // Sinaliza que a operação foi concluída com sucesso.
      action.completer?.complete();
      print("Middleware: handleLoadAllBibleProgress completado com sucesso.");
    } catch (e) {
      print("Erro em handleLoadAllBibleProgress: $e");
      store.dispatch(BibleProgressFailureAction(
          "Erro ao carregar todo o progresso bíblico: $e"));

      // <<< MUDANÇA ESSENCIAL AQUI >>>
      // Sinaliza que a operação foi concluída com erro.
      action.completer?.completeError(e);
      print("Middleware: handleLoadAllBibleProgress completado com erro.");
    }
  }

  // --- PERSISTÊNCIA DE PENDÊNCIAS COM SHAREDPREFERENCES ---
  Future<void> savePendingProgressToPrefs(Map<String, Set<String>> pendingToAdd,
      Map<String, Set<String>> pendingToRemove) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodableToAdd =
          pendingToAdd.map((key, value) => MapEntry(key, value.toList()));
      final encodableToRemove =
          pendingToRemove.map((key, value) => MapEntry(key, value.toList()));
      await prefs.setString(_pendingBibleToAddKey, jsonEncode(encodableToAdd));
      await prefs.setString(
          _pendingBibleToRemoveKey, jsonEncode(encodableToRemove));
      print("Progresso pendente da Bíblia salvo no SharedPreferences.");
    } catch (e) {
      print("Erro ao salvar progresso pendente no SharedPreferences: $e");
    }
  }

  // --- HANDLER PARA TOGGLESECTIONREADSTATUS ---
  void handleToggleSectionReadStatus(Store<AppState> store,
      ToggleSectionReadStatusAction action, NextDispatcher next) async {
    final userId = store.state.userState.userId;
    if (userId == null) {
      print("BibleProgressMiddleware (Toggle): Usuário não logado.");
      return;
    }

    store.dispatch(OptimisticToggleSectionReadStatusAction(
      bookAbbrev: action.bookAbbrev,
      sectionId: action.sectionId,
      markAsRead: action.markAsRead,
    ));
    print(
        "BibleProgressMiddleware (Toggle): Despachou OptimisticToggle para ${action.sectionId}, markAsRead: ${action.markAsRead}");

    await savePendingProgressToPrefs(store.state.userState.pendingSectionsToAdd,
        store.state.userState.pendingSectionsToRemove);

    final operation = {
      'type': 'toggleSectionReadStatus',
      'id':
          'toggle_${action.bookAbbrev}_${action.sectionId}_${DateTime.now().millisecondsSinceEpoch}',
      'payload': {
        'bookAbbrev': action.bookAbbrev,
        'sectionId': action.sectionId,
        'markAsRead': action.markAsRead,
      }
    };
    store.dispatch(EnqueueFirestoreWriteAction(operation));
    print(
        "BibleProgressMiddleware (Toggle): Operação toggleSectionReadStatus enfileirada para ${action.sectionId} (ID Fila: ${operation['id']}).");
  }

  // --- HANDLER PARA PROCESSAR PENDÊNCIAS DE PROGRESSO BÍBLICO ---
  void handleProcessPendingBibleProgress(Store<AppState> store,
      ProcessPendingBibleProgressAction action, NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      print(
          "BibleProgressMiddleware (ProcessPending): Usuário não logado, abortando sincronização.");
      return;
    }

    final pendingToAdd = Map<String, Set<String>>.from(
        store.state.userState.pendingSectionsToAdd);
    final pendingToRemove = Map<String, Set<String>>.from(
        store.state.userState.pendingSectionsToRemove);

    if (pendingToAdd.isEmpty && pendingToRemove.isEmpty) {
      print(
          "BibleProgressMiddleware (ProcessPending): Nenhuma pendência para sincronizar com Firestore.");
      return;
    }

    print(
        "BibleProgressMiddleware (ProcessPending): Iniciando sincronização com Firestore. Adicionar: $pendingToAdd, Remover: $pendingToRemove");
    final booksToProcess =
        {...pendingToAdd.keys, ...pendingToRemove.keys}.toList();

    for (String bookAbbrev in booksToProcess) {
      final sectionsToAddForBook = pendingToAdd[bookAbbrev] ?? {};
      final sectionsToRemoveForBook = pendingToRemove[bookAbbrev] ?? {};

      if (sectionsToAddForBook.isEmpty && sectionsToRemoveForBook.isEmpty) {
        print(
            "BibleProgressMiddleware (ProcessPending): Nenhuma alteração pendente para o livro $bookAbbrev, pulando.");
        continue;
      }

      print(
          "BibleProgressMiddleware (ProcessPending): Sincronizando livro $bookAbbrev. Adicionar: $sectionsToAddForBook, Remover: $sectionsToRemoveForBook");

      try {
        int totalSectionsInBookFromMetadata =
            store.state.metadataState.bibleSectionCounts['livros']?[bookAbbrev]
                    ?['total_secoes_livro'] as int? ??
                store.state.userState.totalSectionsPerBook[bookAbbrev] ??
                0;

        if (totalSectionsInBookFromMetadata == 0) {
          print(
              "AVISO (ProcessPending): totalSectionsInBookFromMetadata é 0 para $bookAbbrev ao tentar sincronizar. O status 'completed' pode ser impreciso no Firestore nesta sincronização.");
        }

        await firestoreService.batchUpdateBibleProgress(
          userId,
          bookAbbrev,
          sectionsToAddForBook.toList(),
          sectionsToRemoveForBook.toList(),
          totalSectionsInBookFromMetadata,
        );
        print(
            "BibleProgressMiddleware (ProcessPending): Sincronização Firestore para $bookAbbrev BEM-SUCEDIDA.");

        store.dispatch(ClearPendingBibleProgressAction(bookAbbrev));

        await savePendingProgressToPrefs(
            store.state.userState.pendingSectionsToAdd,
            store.state.userState.pendingSectionsToRemove);

        store.dispatch(LoadBibleBookProgressAction(bookAbbrev,
            knownTotalSections: totalSectionsInBookFromMetadata));
      } catch (e) {
        print(
            "BibleProgressMiddleware (ProcessPending): ERRO ao sincronizar progresso para $bookAbbrev: $e");
      }
    }
    print(
        "BibleProgressMiddleware (ProcessPending): Processamento de todas as pendências de livros finalizado.");
  }

  // --- HANDLER PARA CARREGAR PENDÊNCIAS DO SHAREDPREFERENCES ---
  void handleLoadPendingProgress(Store<AppState> store,
      LoadPendingBibleProgressAction action, NextDispatcher next) async {
    next(action);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? addJson = prefs.getString(_pendingBibleToAddKey);
      final String? removeJson = prefs.getString(_pendingBibleToRemoveKey);

      Map<String, Set<String>> pendingToAdd = {};
      Map<String, Set<String>> pendingToRemove = {};

      if (addJson != null) {
        final Map<String, dynamic> decodedAdd = jsonDecode(addJson);
        pendingToAdd = decodedAdd.map(
            (key, value) => MapEntry(key, Set<String>.from(value as List)));
      }
      if (removeJson != null) {
        final Map<String, dynamic> decodedRemove = jsonDecode(removeJson);
        pendingToRemove = decodedRemove.map(
            (key, value) => MapEntry(key, Set<String>.from(value as List)));
      }

      store.dispatch(LoadedPendingBibleProgressAction(
          pendingToAdd: pendingToAdd, pendingToRemove: pendingToRemove));
      print(
          "BibleProgressMiddleware: Progresso pendente da Bíblia carregado do SharedPreferences. Adicionar: $pendingToAdd, Remover: $pendingToRemove");

      if (pendingToAdd.isNotEmpty || pendingToRemove.isNotEmpty) {
        print(
            "BibleProgressMiddleware: Despachando ProcessPendingBibleProgressAction após carregar pendências do SharedPreferences.");
        store.dispatch(ProcessPendingBibleProgressAction());
      }
    } catch (e) {
      print(
          "BibleProgressMiddleware: Erro ao carregar progresso pendente do SharedPreferences: $e");
      store.dispatch(LoadedPendingBibleProgressAction(
          pendingToAdd: {}, pendingToRemove: {}));
    }
  }

  return [
    TypedMiddleware<AppState, LoadBibleBookProgressAction>(
            handleLoadBibleBookProgress)
        .call,
    TypedMiddleware<AppState, ToggleSectionReadStatusAction>(
            handleToggleSectionReadStatus)
        .call,
    TypedMiddleware<AppState, LoadAllBibleProgressAction>(
            handleLoadAllBibleProgress)
        .call,
    TypedMiddleware<AppState, ProcessPendingBibleProgressAction>(
            handleProcessPendingBibleProgress)
        .call,
    TypedMiddleware<AppState, LoadPendingBibleProgressAction>(
            handleLoadPendingProgress)
        .call,
    TypedMiddleware<AppState, MarkChapterAsReadAction>(handleMarkChapterAsRead)
        .call,
  ];
}
