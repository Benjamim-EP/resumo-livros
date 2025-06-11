// lib/redux/actions/bible_progress_actions.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp
import 'package:septima_biblia/redux/reducers.dart'; // Para BibleBookProgressData

// Carrega o progresso de um livro específico (ex: ao abrir o livro na BiblePage)
class LoadBibleBookProgressAction {
  final String bookAbbrev;
  final int?
      knownTotalSections; // Opcional: se a UI já souber o total de seções
  LoadBibleBookProgressAction(this.bookAbbrev, {this.knownTotalSections});
}

class BibleBookProgressLoadedAction {
  final String bookAbbrev;
  final Set<String> readSections;
  final int totalSectionsInBook;
  final bool isCompleted;
  final Timestamp? lastReadTimestamp;

  BibleBookProgressLoadedAction({
    required this.bookAbbrev,
    required this.readSections,
    required this.totalSectionsInBook,
    required this.isCompleted,
    this.lastReadTimestamp,
  });
}

// Marca ou desmarca uma seção como lida
class ToggleSectionReadStatusAction {
  final String bookAbbrev;
  final String sectionId; // Ex: gn_c1_v1-5
  final bool markAsRead; // true para marcar como lida, false para desmarcar
  // O total de seções no livro é importante para o middleware/backend saber se o livro foi completado
  // Pode ser obtido do estado Redux (totalSectionsPerBook) ou passado aqui.
  // Vamos assumir que o middleware pode precisar buscar ou já ter essa info.

  ToggleSectionReadStatusAction({
    required this.bookAbbrev,
    required this.sectionId,
    required this.markAsRead,
  });
}

// Ação para indicar que o status de uma seção foi atualizado com sucesso (opcional, pode ser coberto por BibleBookProgressLoadedAction)
// class SectionReadStatusUpdatedAction {
//   final String bookAbbrev;
//   final String sectionId;
//   final bool isRead;
//   SectionReadStatusUpdatedAction(this.bookAbbrev, this.sectionId, this.isRead);
// }

// Carrega o progresso de todos os livros (para a UserPage)
class LoadAllBibleProgressAction {}

class AllBibleProgressLoadedAction {
  // Map<livroAbrev, ProgressoDetalhadoDoLivro>
  final Map<String, BibleBookProgressData> progressData;
  AllBibleProgressLoadedAction(this.progressData);
}

class BibleProgressFailureAction {
  final String error;
  BibleProgressFailureAction(this.error);
}

// Ação para atualização otimista da UI
class OptimisticToggleSectionReadStatusAction {
  final String bookAbbrev;
  final String sectionId;
  final bool markAsRead;
  OptimisticToggleSectionReadStatusAction(
      {required this.bookAbbrev,
      required this.sectionId,
      required this.markAsRead});
}

// Ação genérica para enfileirar escritas no Firestore
class EnqueueFirestoreWriteAction {
  final Map<String, dynamic>
      operation; // Ex: {'type': 'markSectionRead', 'payload': {...}}
  EnqueueFirestoreWriteAction(this.operation);
}

// Ação para iniciar o processamento da fila
class ProcessPendingFirestoreWritesAction {}

// Ação para indicar que uma escrita específica foi bem-sucedida
class FirestoreWriteSuccessfulAction {
  final String operationId; // Um ID único para a operação na fila
  FirestoreWriteSuccessfulAction(this.operationId);
}

// Ação para indicar que uma escrita específica falhou
class FirestoreWriteFailedAction {
  final String operationId;
  final Map<String, dynamic> originalOperation;
  final String error;
  FirestoreWriteFailedAction(
      this.operationId, this.originalOperation, this.error);
}

class ProcessPendingBibleProgressAction {
  // Pode ser genérica ou específica para um livro se necessário
  // final String? bookAbbrev; // Opcional
  ProcessPendingBibleProgressAction();
}

// Ação para limpar as listas pendentes de um livro após sincronização bem-sucedida
class ClearPendingBibleProgressAction {
  final String bookAbbrev;
  ClearPendingBibleProgressAction(this.bookAbbrev);
}

// Ações para persistência (se usar redux_persist ou similar)
class SavePendingBibleProgressAction {
  /* Pode ser usada pelo middleware de persistência */
}

class LoadPendingBibleProgressAction {/* Para carregar no início do app */}

class LoadedPendingBibleProgressAction {
  // Resultado do carregamento
  final Map<String, Set<String>> pendingToAdd;
  final Map<String, Set<String>> pendingToRemove;
  LoadedPendingBibleProgressAction(
      {required this.pendingToAdd, required this.pendingToRemove});
}

class UserBibleProgressDocumentLoadedAction {
  final String? lastReadBookAbbrev;
  final int? lastReadChapter;
  final Timestamp? lastReadTimestamp;
  // Não precisa incluir o mapa 'books' aqui, pois AllBibleProgressLoadedAction cuida disso.
  // Esta ação é mais para os metadados de leitura geral do documento.

  UserBibleProgressDocumentLoadedAction({
    this.lastReadBookAbbrev,
    this.lastReadChapter,
    this.lastReadTimestamp,
  });
}
