// lib/redux/middleware/bible_progress_middleware.dart
import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart'; // Para BibleBookProgressData

List<Middleware<AppState>> createBibleProgressMiddleware() {
  final firestoreService = FirestoreService();

  // Handler para LoadBibleBookProgressAction
  // Esta função carrega o progresso de um livro específico do Firestore
  // e atualiza o estado Redux. É chamado, por exemplo, quando a BiblePage é aberta
  // para um livro específico, ou após uma sincronização de escrita bem-sucedida.
  void _handleLoadBibleBookProgress(Store<AppState> store,
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

  // Handler para ToggleSectionReadStatusAction
  // Esta é a ação que a UI despacha quando o usuário clica no botão "marcar como lido".
  void _handleToggleSectionReadStatus(Store<AppState> store,
      ToggleSectionReadStatusAction action, NextDispatcher next) async {
    // 1. Passa a ação original. Isso permite que outros middlewares ou loggers a vejam,
    // mas o reducer principal para ToggleSectionReadStatusAction NÃO deve mais existir
    // ou não deve modificar o estado de `readSectionsByBook` diretamente.
    // A atualização otimista é feita pela OptimisticToggleSectionReadStatusAction.
    next(action);

    // 2. Despacha a ação otimista para atualizar a UI imediatamente
    // O reducer para OptimisticToggleSectionReadStatusAction fará a mudança no `readSectionsByBook` do UserState.
    store.dispatch(OptimisticToggleSectionReadStatusAction(
      bookAbbrev: action.bookAbbrev,
      sectionId: action.sectionId,
      markAsRead: action.markAsRead,
    ));
    // print("BibleProgressMiddleware: Despachou OptimisticToggle para ${action.sectionId}, markAsRead: ${action.markAsRead}");

    // 3. Enfileira a operação de escrita no Firestore
    // Cria um ID único para esta operação específica para que possa ser rastreada e removida da fila.
    final operationId =
        '${action.bookAbbrev}_${action.sectionId}_${DateTime.now().millisecondsSinceEpoch}_${action.markAsRead.toString()}';
    final operation = {
      'id': operationId,
      'type':
          'toggleSectionReadStatus', // Tipo da operação para o firestore_sync_middleware
      'payload': {
        'bookAbbrev': action.bookAbbrev,
        'sectionId': action.sectionId,
        'markAsRead': action.markAsRead,
        // Não precisamos passar totalSectionsInBook aqui, o firestore_sync_middleware pegará do estado Redux
      }
    };
    store.dispatch(EnqueueFirestoreWriteAction(operation));
    // print("BibleProgressMiddleware: Enfileirou operação de escrita para ${action.sectionId}. ID da op: $operationId");

    // 4. Opcional: Disparar ProcessPendingFirestoreWritesAction imediatamente para teste.
    // Em produção, isso seria acionado por outros gatilhos (sair da tela, etc.).
    // Para testes, pode ser útil:
    // store.dispatch(ProcessPendingFirestoreWritesAction());
  }

  // Handler para LoadAllBibleProgressAction
  // Carrega o progresso de TODOS os livros do usuário.
  // Usado geralmente na inicialização do app ou na UserPage.
  void _handleLoadAllBibleProgress(Store<AppState> store,
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
        _handleLoadBibleBookProgress),
    TypedMiddleware<AppState, ToggleSectionReadStatusAction>(
        _handleToggleSectionReadStatus),
    TypedMiddleware<AppState, LoadAllBibleProgressAction>(
        _handleLoadAllBibleProgress),
  ];
}
