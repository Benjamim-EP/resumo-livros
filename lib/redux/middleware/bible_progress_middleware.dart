// lib/redux/middleware/bible_progress_middleware.dart
import 'dart:convert';

import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para BibleBookProgressData

const String _pendingBibleToAddKey = 'pendingBibleSectionsToAdd';
const String _pendingBibleToRemoveKey = 'pendingBibleSectionsToRemove';

List<Middleware<AppState>> createBibleProgressMiddleware() {
  final firestoreService = FirestoreService();

  // Handler para LoadBibleBookProgressAction
  // Esta função carrega o progresso de um livro específico do Firestore
  // e atualiza o estado Redux. É chamado, por exemplo, quando a BiblePage é aberta
  // para um livro específico, ou após uma sincronização de escrita bem-sucedida.
  void handleLoadBibleBookProgress(Store<AppState> store,
      LoadBibleBookProgressAction action, NextDispatcher next) async {
    next(action); // Passa a ação para o próximo middleware ou reducer.
    // O reducer para esta ação NÃO deve fazer chamadas de API.

    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(BibleProgressFailureAction(
          "Usuário não autenticado para carregar progresso do livro."));
      return;
    }

    try {
      // print("BibleProgressMiddleware: Carregando progresso do Firestore para o livro ${action.bookAbbrev}");
      DocumentSnapshot? progressDoc = await firestoreService
          .getBibleBookProgress(userId, action.bookAbbrev);

      Set<String> readSections = {};
      // Usa o total de seções conhecido se passado, senão tenta pegar do Firestore, ou fallback para 0.
      // O FirestoreService.toggleBibleSectionReadStatus tentará buscar o total de seções dos metadados se não existir no doc de progresso.
      int totalSectionsInBook = action.knownTotalSections ?? 0;
      bool isCompleted = false;
      Timestamp? lastReadTimestamp;

      if (progressDoc != null && progressDoc.exists) {
        final data = progressDoc.data() as Map<String, dynamic>;
        readSections =
            Set<String>.from(data['readSections'] as List<dynamic>? ?? []);
        // Prioriza o total de seções do Firestore se ele existir e for maior que 0,
        // caso contrário, mantém o valor passado ou o fallback.
        int totalFromFirestore = data['totalSectionsInBook'] as int? ?? 0;
        if (totalFromFirestore > 0) {
          totalSectionsInBook = totalFromFirestore;
        }
        isCompleted = data['completed'] as bool? ?? false;
        lastReadTimestamp = data['lastReadTimestamp'] as Timestamp?;
        // print("BibleProgressMiddleware: Progresso encontrado para ${action.bookAbbrev}: ${readSections.length}/$totalSectionsInBook seções lidas.");
      } else {
        // print("BibleProgressMiddleware: Nenhum progresso no Firestore para ${action.bookAbbrev}. Pode ser a primeira vez ou precisa carregar metadados.");
        // Se não há documento de progresso e knownTotalSections não foi passado,
        // `totalSectionsInBook` permanecerá o que foi passado (provavelmente 0 ou null).
        // A lógica no FirestoreService tentará obter o total de seções dos metadados gerais da Bíblia.
        if (totalSectionsInBook == 0) {
          // print("AVISO (LoadBibleBookProgress): totalSectionsInBook não conhecido para ${action.bookAbbrev}. O cálculo de 'completed' pode ser impreciso até a primeira sincronização.");
        }
      }

      store.dispatch(BibleBookProgressLoadedAction(
        bookAbbrev: action.bookAbbrev,
        readSections: readSections,
        totalSectionsInBook:
            totalSectionsInBook, // Passa o total de seções determinado
        isCompleted: isCompleted,
        lastReadTimestamp: lastReadTimestamp,
      ));
    } catch (e) {
      print(
          "Erro em _handleLoadBibleBookProgress para ${action.bookAbbrev}: $e");
      store.dispatch(BibleProgressFailureAction(
          "Erro ao carregar progresso do livro ${action.bookAbbrev}: $e"));
    }
  }

  // Persistência com SharedPreferences
  Future<void> savePendingProgressToPrefs(Map<String, Set<String>> pendingToAdd,
      Map<String, Set<String>> pendingToRemove) async {
    final prefs = await SharedPreferences.getInstance();
    // Converter Set<String> para List<String> para jsonEncode
    final encodableToAdd =
        pendingToAdd.map((key, value) => MapEntry(key, value.toList()));
    final encodableToRemove =
        pendingToRemove.map((key, value) => MapEntry(key, value.toList()));

    await prefs.setString(_pendingBibleToAddKey, jsonEncode(encodableToAdd));
    await prefs.setString(
        _pendingBibleToRemoveKey, jsonEncode(encodableToRemove));
    print("Progresso pendente da Bíblia salvo no SharedPreferences.");
  }

  // Handler para ToggleSectionReadStatusAction
  // Esta é a ação que a UI despacha quando o usuário clica no botão "marcar como lido".
  void handleToggleSectionReadStatus(Store<AppState> store,
      ToggleSectionReadStatusAction action, NextDispatcher next) async {
    // 1. NÃO FAÇA next(action) para a ToggleSectionReadStatusAction original se o reducer não a trata otimisticamente.
    //    Em vez disso, o middleware orquestra as ações otimistas e de persistência/sincronização.

    // 2. Despache a ação otimista IMEDIATAMENTE.
    //    O reducer para OptimisticToggleSectionReadStatusAction atualizará a UI
    //    e também as listas pendingSectionsToAdd/ToRemove.
    store.dispatch(OptimisticToggleSectionReadStatusAction(
      bookAbbrev: action.bookAbbrev,
      sectionId: action.sectionId,
      markAsRead: action.markAsRead,
    ));
    print(
        "BibleProgressMiddleware: Despachou OptimisticToggle para ${action.sectionId}, markAsRead: ${action.markAsRead}");

    // 3. Após o estado ser atualizado pelo reducer (de forma síncrona após o dispatch acima),
    //    salve as pendências no SharedPreferences.
    //    Usar um pequeno Future.delayed para garantir que o reducer teve chance de processar
    //    antes de ler o estado para salvar pode ser uma boa prática, embora o dispatch seja síncrono.
    //    Ou, melhor ainda, o middleware que salva no SharedPreferences poderia ouvir
    //    a OptimisticToggleSectionReadStatusAction. Mas, por simplicidade, vamos manter aqui por enquanto.
    //    A chamada direta a _savePendingProgressToPrefs após o dispatch da ação otimista deve funcionar
    //    porque o dispatch da ação otimista é síncrono e o estado é atualizado antes da próxima linha.

    // É CRUCIAL que o estado seja lido DEPOIS que o reducer da ação otimista rodou.
    // O dispatch acima é síncrono, então o estado DEVE estar atualizado aqui.
    savePendingProgressToPrefs(store.state.userState.pendingSectionsToAdd,
        store.state.userState.pendingSectionsToRemove);

    // A ação original ToggleSectionReadStatusAction agora serve apenas como um gatilho para este middleware.
    // Não precisamos chamar next(action) se ela não tiver mais um reducer.
    // Se você quiser que ela seja logada ou passada para outros middlewares, você pode chamar next(action)
    // no início, mas certifique-se que nenhum reducer está tentando fazer a atualização otimista
    // para ela também.
    // Por clareza, se ToggleSectionReadStatusAction SÓ existe para ser pega por este middleware,
    // o next(action) pode ser omitido ou chamado no início ANTES de despachar a ação otimista.
    // Vamos chamar no início por consistência com outros middlewares, mas o reducer para ela não deve existir.
    // next(action); // Opcional, se outros middlewares precisarem ver.
  }

  void handleProcessPendingBibleProgress(Store<AppState> store,
      ProcessPendingBibleProgressAction action, NextDispatcher next) async {
    next(action);

    final userId = store.state.userState.userId;
    if (userId == null) {
      print("Middleware Sync: Usuário não logado, abortando sincronização.");
      return;
    }

    final pendingToAdd = Map<String, Set<String>>.from(
        store.state.userState.pendingSectionsToAdd);
    final pendingToRemove = Map<String, Set<String>>.from(
        store.state.userState.pendingSectionsToRemove);

    if (pendingToAdd.isEmpty && pendingToRemove.isEmpty) {
      print("Middleware Sync: Nenhuma pendência para sincronizar.");
      return;
    }

    print(
        "Middleware Sync: Iniciando. Pendentes Adicionar: $pendingToAdd, Pendentes Remover: $pendingToRemove");

    final booksToProcess =
        {...pendingToAdd.keys, ...pendingToRemove.keys}.toList();
    print("Middleware Sync: Livros para processar: $booksToProcess");

    for (String bookAbbrev in booksToProcess) {
      final sectionsToAdd = pendingToAdd[bookAbbrev] ?? {};
      final sectionsToRemove = pendingToRemove[bookAbbrev] ?? {};

      if (sectionsToAdd.isEmpty && sectionsToRemove.isEmpty) {
        print(
            "Middleware Sync: Nenhuma mudança para o livro $bookAbbrev, pulando.");
        continue;
      }
      print(
          "Middleware Sync: Processando livro $bookAbbrev. Adicionar: $sectionsToAdd, Remover: $sectionsToRemove");

      try {
        int totalSectionsInBook =
            store.state.metadataState.bibleSectionCounts['livros']?[bookAbbrev]
                    ?['total_secoes_livro'] as int? ??
                store.state.userState.totalSectionsPerBook[bookAbbrev] ??
                0;

        if (totalSectionsInBook == 0) {
          final existingProgress =
              await firestoreService.getBibleBookProgress(userId, bookAbbrev);
          if (existingProgress != null && existingProgress.exists) {
            totalSectionsInBook = (existingProgress.data()
                    as Map<String, dynamic>)['totalSectionsInBook'] as int? ??
                0;
          }
        }
        print(
            "Middleware Sync: Total de seções para $bookAbbrev: $totalSectionsInBook");

        await firestoreService.batchUpdateBibleProgress(
          userId,
          bookAbbrev,
          sectionsToAdd.toList(),
          sectionsToRemove.toList(),
          totalSectionsInBook,
        );
        print(
            "Middleware Sync: Sincronização Firestore para $bookAbbrev BEM-SUCEDIDA.");
        store.dispatch(ClearPendingBibleProgressAction(bookAbbrev));
        savePendingProgressToPrefs(
            // Salva o estado de pendências atualizado (agora vazio para este livro)
            store.state.userState.pendingSectionsToAdd,
            store.state.userState.pendingSectionsToRemove);
        store.dispatch(LoadBibleBookProgressAction(bookAbbrev,
            knownTotalSections:
                totalSectionsInBook > 0 ? totalSectionsInBook : null));
      } catch (e) {
        print(
            "Middleware Sync: ERRO ao sincronizar progresso para $bookAbbrev: $e");
        // As pendências permanecem no estado para a próxima tentativa.
      }
    }
    print("Middleware Sync: Processamento de pendências finalizado.");
  }

  void handleLoadPendingProgress(Store<AppState> store,
      LoadPendingBibleProgressAction action, NextDispatcher next) async {
    next(action);
    final prefs = await SharedPreferences.getInstance();
    final String? addJson = prefs.getString(_pendingBibleToAddKey);
    final String? removeJson = prefs.getString(_pendingBibleToRemoveKey);

    Map<String, Set<String>> pendingToAdd = {};
    Map<String, Set<String>> pendingToRemove = {};

    if (addJson != null) {
      final Map<String, dynamic> decodedAdd = jsonDecode(addJson);
      pendingToAdd = decodedAdd
          .map((key, value) => MapEntry(key, Set<String>.from(value as List)));
    }
    if (removeJson != null) {
      final Map<String, dynamic> decodedRemove = jsonDecode(removeJson);
      pendingToRemove = decodedRemove
          .map((key, value) => MapEntry(key, Set<String>.from(value as List)));
    }
    print(
        "Middleware LoadPending: Pendentes Adicionar Carregados: $pendingToAdd");
    print(
        "Middleware LoadPending: Pendentes Remover Carregados: $pendingToRemove");
    store.dispatch(LoadedPendingBibleProgressAction(
        pendingToAdd: pendingToAdd, pendingToRemove: pendingToRemove));
    print("Progresso pendente da Bíblia carregado do SharedPreferences.");

    if (pendingToAdd.isNotEmpty || pendingToRemove.isNotEmpty) {
      print(
          "Middleware LoadPending: Despachando ProcessPendingBibleProgressAction após carregar pendências.");
      store.dispatch(ProcessPendingBibleProgressAction());
    } else {
      print(
          "Middleware LoadPending: Nenhuma pendência carregada para sincronizar.");
    }
  }

  // Handler para LoadAllBibleProgressAction
  // Carrega o progresso de TODOS os livros do usuário.
  // Usado geralmente na inicialização do app ou na UserPage.
  void handleLoadAllBibleProgress(Store<AppState> store,
      LoadAllBibleProgressAction action, NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(BibleProgressFailureAction(
          "Usuário não autenticado para carregar todo o progresso bíblico."));
      return;
    }
    try {
      // print("BibleProgressMiddleware: Carregando todo o progresso bíblico do usuário do Firestore.");
      final allProgressData =
          await firestoreService.getAllBibleProgress(userId);
      store.dispatch(AllBibleProgressLoadedAction(allProgressData));
      // print("BibleProgressMiddleware: Progresso de todos os livros carregado: ${allProgressData.length} livros com progresso.");
    } catch (e) {
      print("Erro em _handleLoadAllBibleProgress: $e");
      store.dispatch(BibleProgressFailureAction(
          "Erro ao carregar todo o progresso bíblico: $e"));
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
  ];
}
