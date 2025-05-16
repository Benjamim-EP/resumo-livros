// lib/redux/middleware/bible_progress_middleware.dart
import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart'; // Seu serviço Firestore
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart'; // Para BibleBookProgressData
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart'; // Para BibleBookProgressData

List<Middleware<AppState>> createBibleProgressMiddleware() {
  final firestoreService = FirestoreService();

  // Handler para LoadBibleBookProgressAction
  void _handleLoadBibleBookProgress(Store<AppState> store,
      LoadBibleBookProgressAction action, NextDispatcher next) async {
    next(action);
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(BibleProgressFailureAction(
          "Usuário não autenticado para carregar progresso do livro."));
      return;
    }

    try {
      print(
          "BibleProgressMiddleware: Carregando progresso para o livro ${action.bookAbbrev}");
      DocumentSnapshot? progressDoc = await firestoreService
          .getBibleBookProgress(userId, action.bookAbbrev);

      Set<String> readSections = {};
      int totalSectionsInBook =
          action.knownTotalSections ?? 0; // Usa o conhecido, ou 0 como fallback
      bool isCompleted = false;
      Timestamp? lastReadTimestamp;

      if (progressDoc != null && progressDoc.exists) {
        final data = progressDoc.data() as Map<String, dynamic>;
        readSections =
            Set<String>.from(data['readSections'] as List<dynamic>? ?? []);
        totalSectionsInBook = data['totalSectionsInBook'] as int? ??
            totalSectionsInBook; // Prioriza Firestore se existir
        isCompleted = data['completed'] as bool? ?? false;
        lastReadTimestamp = data['lastReadTimestamp'] as Timestamp?;
        print(
            "BibleProgressMiddleware: Progresso encontrado para ${action.bookAbbrev}: ${readSections.length}/$totalSectionsInBook seções lidas.");
      } else {
        print(
            "BibleProgressMiddleware: Nenhum progresso encontrado para ${action.bookAbbrev}, pode ser a primeira vez.");
        // Se knownTotalSections não foi passado e não há doc, tentamos buscar/calcular.
        // Esta lógica de obter totalSectionsInBook pode ser complexa aqui.
        // O ideal é que `totalSectionsInBook` seja definido no Firestore quando o livro é acessado
        // ou que `action.knownTotalSections` seja sempre fornecido pela UI se possível.
        if (totalSectionsInBook == 0) {
          // Placeholder: idealmente, buscar de 'books/{abbrev}/metadata' ou similar
          // ou calcular a partir da estrutura de blocos se a UI puder fornecer.
          // Esta é uma simplificação.
          print(
              "AVISO: totalSectionsInBook não conhecido para ${action.bookAbbrev}. Progresso percentual pode ser impreciso.");
        }
      }

      store.dispatch(BibleBookProgressLoadedAction(
        bookAbbrev: action.bookAbbrev,
        readSections: readSections,
        totalSectionsInBook: totalSectionsInBook,
        isCompleted: isCompleted,
        lastReadTimestamp: lastReadTimestamp,
      ));
    } catch (e) {
      print("Erro em _handleLoadBibleBookProgress: $e");
      store.dispatch(BibleProgressFailureAction(
          "Erro ao carregar progresso do livro ${action.bookAbbrev}: $e"));
    }
  }

  // Handler para ToggleSectionReadStatusAction
  void _handleToggleSectionReadStatus(Store<AppState> store,
      ToggleSectionReadStatusAction action, NextDispatcher next) async {
    next(
        action); // Ação pode ser processada no reducer para UI otimista (não implementado assim aqui)
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(BibleProgressFailureAction(
          "Usuário não autenticado para atualizar progresso da seção."));
      return;
    }

    try {
      print(
          "BibleProgressMiddleware: Atualizando status da seção ${action.sectionId} para ${action.markAsRead ? 'LIDA' : 'NÃO LIDA'} no livro ${action.bookAbbrev}");

      // Precisamos do total de seções no livro para determinar se ele foi completado.
      // Tenta pegar do estado, se não, precisaria buscar ou ser passado.
      int totalSectionsInBook =
          store.state.userState.totalSectionsPerBook[action.bookAbbrev] ?? 0;

      // Se totalSectionsInBook ainda é 0, tenta buscar do Firestore (se o documento de progresso já existe)
      // ou de uma fonte de metadados do livro. Esta parte pode precisar de mais lógica.
      if (totalSectionsInBook == 0) {
        DocumentSnapshot? progressDoc = await firestoreService
            .getBibleBookProgress(userId, action.bookAbbrev);
        if (progressDoc != null && progressDoc.exists) {
          totalSectionsInBook = (progressDoc.data()
                  as Map<String, dynamic>)['totalSectionsInBook'] as int? ??
              0;
        }
        // Se ainda for 0, é um problema de dados - o progresso percentual pode não ser calculável corretamente.
        if (totalSectionsInBook == 0) {
          print(
              "AVISO: totalSectionsInBook é 0 para ${action.bookAbbrev} ao tentar marcar seção. O status 'completed' pode não ser atualizado corretamente.");
          // Você pode querer buscar o total de seções de uma coleção 'books_metadata' ou similar aqui.
          // Por simplicidade, vamos prosseguir, mas o cálculo de 'completed' pode falhar.
        }
      }

      await firestoreService.toggleBibleSectionReadStatus(
        userId,
        action.bookAbbrev,
        action.sectionId,
        action.markAsRead,
        totalSectionsInBook, // Passa o total para o serviço do Firestore
      );
      print(
          "BibleProgressMiddleware: Status da seção atualizado no Firestore.");

      // Após atualizar no Firestore, recarrega o progresso do livro para ter os dados mais recentes
      store.dispatch(LoadBibleBookProgressAction(action.bookAbbrev,
          knownTotalSections:
              totalSectionsInBook > 0 ? totalSectionsInBook : null));
      // Opcionalmente, se essa ação também afeta estatísticas globais do usuário (como total de seções lidas na Bíblia)
      // store.dispatch(LoadUserStatsAction()); // Se você tiver um contador geral de seções lidas.
    } catch (e) {
      print("Erro em _handleToggleSectionReadStatus: $e");
      store.dispatch(BibleProgressFailureAction(
          "Erro ao atualizar status da seção ${action.sectionId}: $e"));
    }
  }

  // Handler para LoadAllBibleProgressAction
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
      print(
          "BibleProgressMiddleware: Carregando todo o progresso bíblico do usuário.");
      final allProgressData =
          await firestoreService.getAllBibleProgress(userId);
      store.dispatch(AllBibleProgressLoadedAction(allProgressData));
      print(
          "BibleProgressMiddleware: Progresso de todos os livros carregado: ${allProgressData.length} livros com progresso.");
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
