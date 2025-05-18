// lib/redux/middleware/firestore_sync_middleware.dart
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart'; // Ações gerais
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart'; // Nossas novas ações
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';

List<Middleware<AppState>> createFirestoreSyncMiddleware() {
  final firestoreService = FirestoreService();

  void _handleProcessPendingWrites(Store<AppState> store,
      ProcessPendingFirestoreWritesAction action, NextDispatcher next) async {
    next(action); // Passa a ação, embora ela seja principalmente um gatilho

    final userId = store.state.userState.userId;
    if (userId == null) {
      print(
          "FirestoreSyncMiddleware: Usuário não logado, não pode processar fila.");
      return;
    }

    final List<Map<String, dynamic>> pendingWrites =
        List.from(store.state.userState.pendingFirestoreWrites);
    if (pendingWrites.isEmpty) {
      // print("FirestoreSyncMiddleware: Nenhuma operação pendente para processar.");
      return;
    }

    print(
        "FirestoreSyncMiddleware: Processando ${pendingWrites.length} operações pendentes...");

    for (var operation in pendingWrites) {
      final operationId =
          operation['id'] as String; // Assumindo que temos um ID
      final type = operation['type'] as String?;
      final payload = operation['payload'] as Map<String, dynamic>?;

      if (type == null || payload == null) {
        print(
            "FirestoreSyncMiddleware: Operação inválida na fila (sem tipo ou payload): $operationId");
        store.dispatch(FirestoreWriteFailedAction(
            operationId, operation, "Operação inválida"));
        continue;
      }

      try {
        if (type == 'toggleSectionReadStatus') {
          final bookAbbrev = payload['bookAbbrev'] as String;
          final sectionId = payload['sectionId'] as String;
          final markAsRead = payload['markAsRead'] as bool;

          // Pegar o total de seções do livro do estado atual do Redux (que deve ter sido carregado)
          int totalSectionsInBook =
              store.state.metadataState.bibleSectionCounts['livros']
                      ?[bookAbbrev]?['total_secoes_livro'] as int? ??
                  store.state.userState.totalSectionsPerBook[bookAbbrev] ??
                  0;

          if (totalSectionsInBook == 0) {
            // Se ainda for 0, pode ser um problema. Tentar buscar do progresso salvo se existir.
            final bookProgressData =
                store.state.userState.allBooksProgress[bookAbbrev];
            if (bookProgressData != null &&
                bookProgressData.totalSections > 0) {
              totalSectionsInBook = bookProgressData.totalSections;
            } else {
              print(
                  "AVISO: totalSectionsInBook é 0 para $bookAbbrev ao tentar sincronizar seção. O status 'completed' pode não ser atualizado corretamente no Firestore.");
            }
          }

          await firestoreService.toggleBibleSectionReadStatus(
            userId,
            bookAbbrev,
            sectionId,
            markAsRead,
            totalSectionsInBook,
          );
          store.dispatch(FirestoreWriteSuccessfulAction(operationId));
          print(
              "FirestoreSyncMiddleware: Operação '$type' para $sectionId bem-sucedida.");
          // Despachar para recarregar o progresso do livro específico após a escrita bem-sucedida
          store.dispatch(LoadBibleBookProgressAction(bookAbbrev,
              knownTotalSections:
                  totalSectionsInBook > 0 ? totalSectionsInBook : null));
        }
        // Adicionar 'else if' para outros tipos de operação (destaques, notas) aqui no futuro
        else {
          print(
              "FirestoreSyncMiddleware: Tipo de operação desconhecido: $type");
          store.dispatch(FirestoreWriteFailedAction(
              operationId, operation, "Tipo desconhecido"));
        }
      } catch (e) {
        print(
            "FirestoreSyncMiddleware: Erro ao processar operação $operationId ($type): $e");
        store.dispatch(
            FirestoreWriteFailedAction(operationId, operation, e.toString()));
        // TODO: Adicionar lógica de retentativa ou notificação ao usuário
      }
    }
  }

  return [
    TypedMiddleware<AppState, ProcessPendingFirestoreWritesAction>(
        _handleProcessPendingWrites),
  ];
}
