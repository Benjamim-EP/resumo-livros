// lib/redux/actions/bible_progress_actions.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart'; // Para BibleBookProgressData

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
