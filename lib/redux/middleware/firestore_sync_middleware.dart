// lib/redux/middleware/firestore_sync_middleware.dart
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';

List<Middleware<AppState>> createFirestoreSyncMiddleware() {
  final firestoreService = FirestoreService();

  void _handleProcessPendingWrites(Store<AppState> store,
      ProcessPendingFirestoreWritesAction action, NextDispatcher next) async {
    next(action);

    final userId = store.state.userState.userId;
    if (userId == null) {
      print(
          "FirestoreSyncMiddleware: Usuário não logado, não pode processar fila.");
      return;
    }

    final List<Map<String, dynamic>> pendingWrites =
        List.from(store.state.userState.pendingFirestoreWrites);

    if (pendingWrites.isEmpty) {
      return;
    }

    print(
        "FirestoreSyncMiddleware: Processando ${pendingWrites.length} operações pendentes...");

    for (var operation in pendingWrites) {
      final operationId = operation['id'] as String?;
      final type = operation['type'] as String?;
      final payload = operation['payload'] as Map<String, dynamic>?;

      if (operationId == null || type == null || payload == null) {
        print("FirestoreSyncMiddleware: Operação inválida na fila: $operation");
        if (operationId != null) {
          store.dispatch(FirestoreWriteFailedAction(
              operationId, operation, "Operação inválida na fila"));
        }
        continue;
      }

      // --- TRATAMENTO PARA 'toggleSectionReadStatus' ---
      if (type == 'toggleSectionReadStatus') {
        final bookAbbrev = payload['bookAbbrev'] as String?;
        final sectionId = payload['sectionId'] as String?;
        final markAsRead = payload['markAsRead'] as bool?;

        if (bookAbbrev == null || sectionId == null || markAsRead == null) {
          print(
              "FirestoreSyncMiddleware: Payload inválido para 'toggleSectionReadStatus' (ID: $operationId).");
          store.dispatch(FirestoreWriteFailedAction(operationId, operation,
              "Payload inválido para toggleSectionReadStatus"));
          continue;
        }

        try {
          // Obter o total de seções do livro a partir do estado Redux (metadataState ou userState)
          // Esta é a melhor fonte, pois deve estar atualizada com os metadados carregados.
          int totalSectionsInBookFromState =
              store.state.metadataState.bibleSectionCounts['livros']
                      ?[bookAbbrev]?['total_secoes_livro'] as int? ??
                  store.state.userState.totalSectionsPerBook[bookAbbrev] ??
                  0;

          if (totalSectionsInBookFromState == 0) {
            print(
                "AVISO (FirestoreSync - toggle): totalSectionsInBookFromState é 0 para $bookAbbrev ao tentar sincronizar. O status 'completed' pode ser impreciso no Firestore.");
          }

          // Chama a função do FirestoreService que opera na coleção userBibleProgress
          await firestoreService.toggleBibleSectionReadStatus(
            userId,
            bookAbbrev,
            sectionId,
            markAsRead,
            totalSectionsInBookFromState, // Passa o total de seções
          );
          print(
              "FirestoreSyncMiddleware: Operação '$type' para $sectionId (ID Fila: $operationId) BEM-SUCEDIDA.");
          store.dispatch(
              FirestoreWriteSuccessfulAction(operationId)); // Remove da fila

          // Despacha para recarregar o progresso do livro específico após a escrita bem-sucedida
          // Isso garante que o UserState reflita o estado persistido, incluindo 'completed' e 'lastReadTimestampBook'.
          store.dispatch(LoadBibleBookProgressAction(bookAbbrev,
              knownTotalSections: totalSectionsInBookFromState));

          // Adicionalmente, se esta ação de toggle também deve atualizar o lastRead geral,
          // o firestoreService.toggleBibleSectionReadStatus já faz isso no documento userBibleProgress.
          // Para atualizar o UserState.lastReadBookAbbrev/Chapter, despachamos UpdateLastReadLocationAction.
          final chapterMatch = RegExp(r'_c(\d+)_').firstMatch(sectionId);
          if (chapterMatch != null) {
            final chapterNum = int.tryParse(chapterMatch.group(1) ?? "");
            if (chapterNum != null) {
              store.dispatch(
                  UpdateLastReadLocationAction(bookAbbrev, chapterNum));
            }
          }
        } catch (e) {
          print(
              "FirestoreSyncMiddleware: ERRO ao processar 'toggleSectionReadStatus' (ID Fila: $operationId) para $sectionId: $e");
          store.dispatch(
              FirestoreWriteFailedAction(operationId, operation, e.toString()));
          // A operação permanece na fila para uma próxima tentativa se desejado, ou pode ser removida aqui.
          // A lógica atual do reducer remove em caso de falha.
        }
      }
      // --- FIM DO TRATAMENTO PARA 'toggleSectionReadStatus' ---

      // Adicione aqui 'else if' para outros tipos de operações futuras
      /*
      else if (type == 'outroTipoDeOperacaoBackground') {
        // ... lógica para outro tipo ...
      }
      */
      else {
        print(
            "FirestoreSyncMiddleware: Tipo de operação desconhecido na fila: '$type' (ID: $operationId).");
        store.dispatch(FirestoreWriteFailedAction(
            operationId, operation, "Tipo de operação desconhecido"));
      }
    } // Fim do loop for

    if (pendingWrites.isNotEmpty) {
      print(
          "FirestoreSyncMiddleware: Processamento da fila de escritas gerais concluído.");
    }
  }

  return [
    TypedMiddleware<AppState, ProcessPendingFirestoreWritesAction>(
        _handleProcessPendingWrites),
  ];
}
