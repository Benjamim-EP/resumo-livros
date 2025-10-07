// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/models/bible_saga_model.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/library_reference_reducer.dart'; // Para formatar datas

class FirestoreService {
  final FirebaseFirestore _db;
  static const int READING_HISTORY_LIMIT = 20;

  FirestoreService({FirebaseFirestore? firestoreInstance})
      : _db = firestoreInstance ?? FirebaseFirestore.instance;

  Future<Map<String, List<Map<String, dynamic>>>>
      fetchAllCommentariesForChapter(String bookAbbrev, int chapterNumber,
          List<Map<String, dynamic>> sections) async {
    if (sections.isEmpty) return {};

    final Map<String, List<Map<String, dynamic>>> results = {};
    String abbrevForFirestore =
        bookAbbrev.toLowerCase() == 'job' ? 'jó' : bookAbbrev;

    // Constrói a lista de IDs de documentos de comentários a serem buscados
    List<String> commentaryDocIds = sections
        .map((section) {
          final List<int> verseNumbers =
              (section['verses'] as List?)?.cast<int>() ?? [];
          if (verseNumbers.isEmpty) return null;
          final String versesRangeStr = verseNumbers.length == 1
              ? verseNumbers.first.toString()
              : "${verseNumbers.first}-${verseNumbers.last}";
          return "${abbrevForFirestore}_c${chapterNumber}_v$versesRangeStr";
        })
        .whereType<String>()
        .toList();

    if (commentaryDocIds.isEmpty) return {};

    // O Firestore permite buscar até 30 documentos por vez com `whereIn`
    final querySnapshot = await _db
        .collection('commentary_sections')
        .where(FieldPath.documentId, whereIn: commentaryDocIds)
        .get();

    for (var doc in querySnapshot.docs) {
      final commentaryData = doc.data();
      final List<Map<String, dynamic>> items =
          (commentaryData['commentary'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e))
                  .toList() ??
              [];

      // Mapeia de volta para a chave 'versesRangeStr'
      final String docId = doc.id;
      final String versesRangeStr = docId.split('_v').last;

      results[versesRangeStr] = items;
    }

    return results;
  }

  Future<List<BibleSaga>> fetchBibleSagas() async {
    try {
      final snapshot = await _db.collection('bibleSagas').get();
      if (snapshot.docs.isEmpty) {
        print(
            "FirestoreService: Nenhuma saga bíblica encontrada na coleção 'bibleSagas'.");
        return [];
      }
      return snapshot.docs
          .map((doc) => BibleSaga.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print("FirestoreService: ERRO ao buscar sagas bíblicas: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserNotifications(
      String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true) // Mais recentes primeiro
          .limit(50) // Limita a 50 notificações para performance
          .get();

      return snapshot.docs.map((doc) {
        // Inclui o ID do documento da notificação para uso futuro (ex: marcar como lida)
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      print("FirestoreService: Erro ao buscar notificações para $userId: $e");
      // Retorna uma lista vazia em caso de erro para não quebrar a UI
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadLikedQuotes(String userId) async {
    try {
      final snapshot = await _db
          .collection('quotes')
          // A query principal: encontra documentos onde o array 'likedBy' contém o ID do usuário.
          .where('likedBy', arrayContains: userId)
          // Opcional: ordenar pelas mais recentes, se houver um campo de timestamp.
          // Assumindo que você tem um campo 'createdAt' nos seus documentos de 'quotes'.
          // Se não tiver, pode remover esta linha.
          // .orderBy('createdAt', descending: true)
          .limit(100) // Limita a 100 para evitar carregar dados demais.
          .get();

      // Mapeia os documentos encontrados para um formato que a UI pode usar.
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Adicionamos um campo 'type' para que o ViewModel e a UI saibam
        // que este item é uma frase curtida e deve ser tratado de forma diferente.
        return {
          'id': doc.id,
          'type': 'liked_quote',
          'text': data['text'] ?? 'Frase indisponível',
          'author': data['author'] ?? 'Autor desconhecido',
          'book': data['book'] ?? 'Livro desconhecido',
          'timestamp': data['createdAt'] // Para ordenação na UI
        };
      }).toList();
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar frases curtidas para $userId: $e");
      return []; // Retorna uma lista vazia em caso de erro.
    }
  }

  /// Adiciona um novo texto de interação ao perfil do usuário para alimentar as recomendações.
  /// A lógica de "fila" (adicionar no início, remover do final) é gerenciada
  /// atomicamente por uma transação no Firestore.
  Future<void> addRecentInteraction(
      String userId, String interactionText) async {
    if (interactionText.trim().isEmpty) return;

    final userDocRef = _db.collection('users').doc(userId);
    const int maxInteractions = 7; // Limite de interações a serem mantidas

    try {
      await _db.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(userDocRef);

        if (!docSnapshot.exists) {
          // Se o documento do usuário não existir por algum motivo, não faz nada.
          print(
              "FirestoreService: Documento do usuário $userId não encontrado para adicionar interação.");
          return;
        }

        // Pega a lista atual de interações do documento.
        final List<dynamic> currentInteractions =
            docSnapshot.data()?['recentInteractions'] ?? [];

        // Cria a nova entrada de interação.
        final newInteraction = {
          'text': interactionText,
          'timestamp':
              Timestamp.now(), // Usa o timestamp do cliente para a transação.
        };

        // Adiciona a nova interação no início da lista.
        final List<dynamic> updatedInteractions = [
          newInteraction,
          ...currentInteractions
        ];

        // Se a lista exceder o limite, remove os itens mais antigos.
        final finalInteractions = updatedInteractions.length > maxInteractions
            ? updatedInteractions.sublist(0, maxInteractions)
            : updatedInteractions;

        // Atualiza o documento dentro da transação.
        transaction
            .update(userDocRef, {'recentInteractions': finalInteractions});
      });

      print(
          "FirestoreService: Interação recente adicionada para o usuário $userId.");
    } catch (e) {
      print(
          "FirestoreService: ERRO ao adicionar interação recente para $userId: $e");
      // Não relançamos o erro para não quebrar a funcionalidade principal (ex: salvar uma nota).
      // Apenas registramos o erro no log.
    }
  }

  // ✅ CORREÇÃO: IMPLEMENTAÇÃO COMPLETA DO MÉTODO QUE FALTAVA
  Future<Map<String, dynamic>?> fetchBookDetails(String bookId) async {
    try {
      final bookSnapshot = await _db.collection('livros').doc(bookId).get();

      if (bookSnapshot.exists) {
        final data = bookSnapshot.data()!;

        // Mapeia os dados do Firestore para um formato consistente
        return {
          'bookId': bookId,
          'titulo': data['titulo'] ?? 'Título Desconhecido',
          'authorId': data['autor'] ?? 'Autor Desconhecido',
          'cover': data['cover_principal'] ?? '',
          'resumo': data['resumo'] ?? '',
          'temas': data['temas'] ?? '',
          'aplicacoes': data['aplicacoes'] ?? '',
          'perfil_leitor': data['perfil_leitor'] ?? '',
          'versoes': data['versoes'] as List<dynamic>? ?? [],
        };
      } else {
        print('Livro com ID $bookId não encontrado na coleção "livros".');
        return null;
      }
    } catch (e) {
      print("Erro ao buscar detalhes do livro $bookId: $e");
      rethrow; // Relança o erro para o middleware tratar
    }
  }

  Future<Map<String, Map<String, dynamic>>> fetchUsersByIds(
      List<String> userIds) async {
    if (userIds.isEmpty) {
      return {};
    }

    final Map<String, Map<String, dynamic>> usersMap = {};
    const chunkSize = 30; // Limite do 'whereIn' no Firestore

    // Processa os IDs em lotes de 30 para respeitar o limite do Firestore
    for (var i = 0; i < userIds.length; i += chunkSize) {
      final chunk = userIds.sublist(
          i, i + chunkSize > userIds.length ? userIds.length : i + chunkSize);

      try {
        final querySnapshot = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in querySnapshot.docs) {
          if (doc.exists) {
            // Guarda os dados usando o ID do usuário como chave para fácil acesso
            usersMap[doc.id] = doc.data();
          }
        }
      } catch (e) {
        print("FirestoreService: Erro ao buscar lote de usuários por IDs: $e");
        // Continua para o próximo lote em vez de falhar completamente
      }
    }
    return usersMap;
  }

  // --- User Methods ---
  Future<List<Map<String, dynamic>>> getUserRoutes(String userId) async {
    try {
      // Assumindo uma subcoleção 'user_routes' dentro do documento do usuário
      // Ajuste o nome da coleção se for diferente
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('user_routes') // <<< NOME DA SUBCOLEÇÃO AQUI
          .orderBy('createdAt', descending: true) // Ordena pelas mais recentes
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Mapeia os campos esperados pela ação UserRoutesLoadedAction
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Rota sem nome', // Campo 'name' da rota
          'topics': data['topics'] ?? [], // Lista de IDs de tópicos na rota
          'createdAt': data['createdAt'], // Timestamp de criação
          // Adicione outros campos se existirem no seu documento de rota
        };
      }).toList();
    } catch (e) {
      print("FirestoreService: Erro ao buscar rotas do usuário $userId: $e");
      return []; // Retorna lista vazia em caso de erro
    }
  }

  Future<List<String>> loadUserTags(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('userTags')
          .orderBy('createdAt',
              descending: true) // Opcional: ordenar pelas mais recentes
          .get();

      // O nome da tag está no ID do documento.
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar as tags do usuário $userId: $e");
      return []; // Retorna lista vazia em caso de erro.
    }
  }

  /// Garante que uma tag exista na coleção de tags do usuário.
  /// Se não existir, cria. Se existir, pode (opcionalmente) incrementar um contador.
  Future<void> ensureUserTagExists(String userId, String tagName) async {
    if (tagName.trim().isEmpty) return;

    // Normaliza o nome da tag para ser usado como ID do documento (evita problemas com caracteres especiais)
    final String tagId = tagName.toLowerCase().replaceAll(RegExp(r'\s+'), '-');

    final tagDocRef =
        _db.collection('users').doc(userId).collection('userTags').doc(tagId);

    try {
      // Usamos uma transação para garantir a atomicidade da operação (verificar e escrever)
      await _db.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(tagDocRef);

        if (!docSnapshot.exists) {
          // Se a tag não existe, cria o documento
          transaction.set(tagDocRef, {
            'name': tagName, // Salva o nome original para exibição
            'createdAt': FieldValue.serverTimestamp(),
            'count': 1,
          });
          print(
              "FirestoreService: Tag '$tagName' criada para o usuário $userId.");
        } else {
          // Se a tag já existe, incrementa o contador
          transaction.update(tagDocRef, {
            'count': FieldValue.increment(1),
          });
          print(
              "FirestoreService: Contador da tag '$tagName' incrementado para o usuário $userId.");
        }
      });
    } catch (e) {
      print(
          "FirestoreService: Erro ao garantir a existência da tag '$tagName' para $userId: $e");
      rethrow;
    }
  }

  Future<void> updateUserCoinsAndAdStats(
    String userId,
    int newCoinAmount,
    DateTime lastAdWatchTime,
    int adsWatchedToday,
  ) async {
    try {
      await _db.collection('users').doc(userId).update({
        'userCoins': newCoinAmount,
        'lastRewardedAdWatchTime':
            Timestamp.fromDate(lastAdWatchTime), // Salva como Timestamp
        'rewardedAdsWatchedToday': adsWatchedToday,
      });
    } catch (e) {
      print(
          "FirestoreService: Erro ao atualizar moedas e estatísticas de anúncios: $e");
      rethrow;
    }
  }

  /// Busca as estatísticas gerais do usuário (Tópicos, Livros, Dias).
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print("FirestoreService: Erro ao buscar stats do usuário $userId: $e");
      return null;
    }
  }

  // --- Comment Highlight Methods ---
  Future<List<Map<String, dynamic>>> loadUserCommentHighlights(
      String userId) async {
    try {
      final snapshot = await _db
          .collection('userCommentHighlights') // Coleção de Nível Superior
          .doc(userId) // Documento do Usuário
          .collection('highlights') // Subcoleção de Destaques
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data}; // Inclui o ID do documento do destaque
      }).toList();
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar destaques de comentários para $userId: $e");
      return [];
    }
  }

  Future<DocumentSnapshot?> getBibleProgressDocument(String userId) async {
    try {
      final docRef = _db.collection('userBibleProgress').doc(userId);
      return await docRef.get();
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar documento de progresso bíblico para $userId: $e");
      return null;
    }
  }

  Future<DocumentReference> addCommentHighlight(
      String userId, Map<String, dynamic> highlightData) async {
    try {
      final dataWithTimestampAndTags = {
        ...highlightData,
        'tags': highlightData['tags'] ?? [], // Garante que o campo exista
        'timestamp': highlightData['timestamp'] ?? FieldValue.serverTimestamp(),
      };

      await _db.collection('userCommentHighlights').doc(userId).set(
          {'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      final docRef = await _db
          .collection('userCommentHighlights')
          .doc(userId)
          .collection('highlights')
          .add(dataWithTimestampAndTags);
      return docRef;
    } catch (e) {
      print(
          "FirestoreService: Erro ao adicionar destaque de comentário para $userId: $e");
      rethrow;
    }
  }

  Future<void> removeCommentHighlight(
      String userId, String highlightDocId) async {
    try {
      await _db
          .collection('userCommentHighlights')
          .doc(userId)
          .collection('highlights')
          .doc(highlightDocId) // ID do documento do destaque específico
          .delete();
      print(
          "FirestoreService: Destaque de comentário removido: $highlightDocId para usuário $userId");
    } catch (e) {
      print(
          "FirestoreService: Erro ao remover destaque de comentário $highlightDocId para $userId: $e");
      rethrow;
    }
  }

  /// Busca todos os detalhes do documento do usuário.
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print("FirestoreService: Erro ao buscar detalhes do usuário $userId: $e");
      return null;
    }
  }

  /// Busca informações sobre o status premium do usuário.
  @Deprecated('Usar getUserDetails e verificar campos de assinatura')
  Future<Map<String, dynamic>?> getUserPremiumStatus(String userId) async {
    // Esta função pode ser obsoleta se os dados estão em userDetails
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.data()?['isPremium'] as Map<String, dynamic>?;
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar status premium do usuário $userId: $e");
      return null;
    }
  }

  /// Busca as coleções salvas (tópicos e versículos) do usuário.
  Future<Map<String, List<String>>?> getUserCollections(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final data = doc.data();
      if (data != null && data['topicSaves'] is Map) {
        return (data['topicSaves'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, List<String>.from(value as List)),
        );
      }
      return {}; // Retorna mapa vazio se 'topicSaves' não existir ou não for mapa
    } catch (e) {
      print("FirestoreService: Erro ao buscar coleções do usuário $userId: $e");
      return null;
    }
  }

  /// Salva um tópico em uma coleção específica do usuário.
  Future<void> saveTopicToCollection(
      String userId, String collectionName, String topicId) async {
    try {
      final userDoc = _db.collection('users').doc(userId);
      await userDoc.set(
          {
            // Use set com merge para criar a coleção se não existir
            'topicSaves': {
              collectionName: FieldValue.arrayUnion([topicId])
            }
          },
          SetOptions(
              merge:
                  true)); // Merge garante que outras coleções não sejam sobrescritas
    } catch (e) {
      print(
          "FirestoreService: Erro ao salvar tópico $topicId na coleção $collectionName: $e");
      rethrow; // Relança para o middleware/UI tratar
    }
  }

  /// Salva um versículo em uma coleção específica do usuário.
  Future<void> saveVerseToCollection(
      String userId, String collectionName, String verseId) async {
    try {
      final userDoc = _db.collection('users').doc(userId);
      await userDoc.set({
        'topicSaves': {
          collectionName: FieldValue.arrayUnion([verseId])
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print(
          "FirestoreService: Erro ao salvar versículo $verseId na coleção $collectionName: $e");
      rethrow;
    }
  }

  /// Deleta uma coleção inteira de tópicos/versículos salvos.
  Future<void> deleteTopicCollection(
      String userId, String collectionName) async {
    try {
      await _db.collection('users').doc(userId).update({
        'topicSaves.$collectionName': FieldValue.delete(),
      });
    } catch (e) {
      print(
          "FirestoreService: Erro ao deletar coleção $collectionName para usuário $userId: $e");
      rethrow;
    }
  }

  /// Deleta um único tópico ou versículo de uma coleção.
  Future<void> deleteSingleTopicFromCollection(
      String userId, String collectionName, String itemId) async {
    try {
      await _db.collection('users').doc(userId).update({
        'topicSaves.$collectionName': FieldValue.arrayRemove([itemId]),
      });
    } catch (e) {
      print(
          "FirestoreService: Erro ao deletar item $itemId da coleção $collectionName: $e");
      rethrow;
    }
  }

  /// Busca o progresso bruto de todos os livros que o usuário iniciou.
  Future<Map<String, dynamic>?> getBooksProgressRaw(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.data()?['booksProgress'] as Map<String, dynamic>?;
    } catch (e) {
      print("FirestoreService: Erro ao buscar progresso bruto dos livros: $e");
      return null;
    }
  }

  /// Busca o progresso específico de um livro para o usuário.
  Future<Map<String, dynamic>?> getBookProgress(
      String userId, String bookId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final progressMap = doc.data()?['booksProgress'] as Map<String, dynamic>?;
      return progressMap?[bookId] as Map<String, dynamic>?;
    } catch (e) {
      print("FirestoreService: Erro ao buscar progresso do livro $bookId: $e");
      return null;
    }
  }

  /// Atualiza um campo específico no documento do usuário.
  Future<void> updateUserField(
      String userId, String field, dynamic value) async {
    try {
      await _db.collection('users').doc(userId).update({field: value});
    } catch (e) {
      print("FirestoreService: Erro ao atualizar campo $field: $e");
      rethrow;
    }
  }

  /// Salva ou atualiza as características (features) do usuário.
  Future<void> updateUserFeatures(
      String userId, Map<String, dynamic> features) async {
    try {
      // Usa set com merge para não sobrescrever outros campos
      await _db
          .collection('users')
          .doc(userId)
          .set({'userFeatures': features}, SetOptions(merge: true));
    } catch (e) {
      print("FirestoreService: Erro ao salvar features do usuário $userId: $e");
      rethrow;
    }
  }

  /// Verifica se é o primeiro login do usuário e marca como não sendo mais.
  Future<bool> checkAndSetFirstLogin(String userId) async {
    try {
      final userDoc = _db.collection('users').doc(userId);
      final docSnapshot = await userDoc.get();
      if (docSnapshot.exists) {
        final isFirst = docSnapshot.data()?['firstLogin'] ?? false;
        // Se for o primeiro login, marca como false (opcional, depende se você quer que isso mude ou não)
        // if (isFirst) {
        //   await userDoc.update({'firstLogin': false});
        // }
        return isFirst;
      } else {
        // Se o documento não existe (caso raro após autenticação), cria com firstLogin = true
        await userDoc.set({'firstLogin': true}, SetOptions(merge: true));
        return true;
      }
    } catch (e) {
      print("FirestoreService: Erro ao verificar/definir firstLogin: $e");
      rethrow; // Relança para o middleware tratar
    }
  }

  /// Busca as indicações de tópicos salvas para o usuário.
  Future<Map<String, List<String>>?> getUserIndicacoes(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      final data = doc.data();
      if (data != null && data['indicacoes'] is Map) {
        return (data['indicacoes'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, List<String>.from(value as List)),
        );
      }
      return null;
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar indicações do usuário $userId: $e");
      return null;
    }
  }

  /// Busca as features salvas do usuário.
  Future<Map<String, dynamic>?> getUserFeatures(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      return doc.data()?['userFeatures'] as Map<String, dynamic>?;
    } catch (e) {
      print("FirestoreService: Erro ao buscar features do usuário $userId: $e");
      return null;
    }
  }

  /// Atualiza o campo 'indicacoes' no documento do usuário.
  Future<void> updateUserIndicacoes(
      String userId, Map<String, List<String>> indicacoes) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .update({'indicacoes': indicacoes});
    } catch (e) {
      print(
          "FirestoreService: Erro ao atualizar indicações do usuário $userId: $e");
      rethrow;
    }
  }

  /// Adiciona uma nova entrada ao diário do usuário.
  Future<String> addDiaryEntry(
      String userId, String title, String content) async {
    try {
      // Cria o post na coleção principal 'posts'
      final newDiaryRef = await _db.collection('posts').add({
        "titulo": title,
        "conteudo": content,
        "data": FieldValue.serverTimestamp(), // Usa timestamp do servidor
        "userId": userId,
      });

      // Adiciona a referência na subcoleção 'user_diaries' (ou outra estrutura)
      await _db
          .collection('users')
          .doc(userId)
          .collection('user_diaries')
          .doc(newDiaryRef.id)
          .set({
        'postId': newDiaryRef.id, // Referência ao post principal
        'createdAt': FieldValue
            .serverTimestamp(), // Timestamp de adição à coleção do usuário
      });

      return newDiaryRef.id;
    } catch (e) {
      print("FirestoreService: Erro ao adicionar entrada no diário: $e");
      rethrow;
    }
  }

  /// Carrega as entradas do diário do usuário.
  Future<List<Map<String, dynamic>>> loadUserDiaries(String userId) async {
    try {
      // Busca os IDs dos posts do diário do usuário
      final diaryRefsSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('user_diaries')
          .orderBy('createdAt', descending: true) // Ordena por data de adição
          .get();

      final diaryPostIds = diaryRefsSnapshot.docs
          .map((doc) => doc.data()['postId'] as String?)
          .where((id) => id != null)
          .toList();

      if (diaryPostIds.isEmpty) {
        return []; // Retorna lista vazia se não houver IDs
      }

      // Busca os documentos correspondentes na coleção 'posts'
      // Nota: O Firestore 'whereIn' tem um limite de 30 itens por consulta.
      // Se houver mais, será necessário dividir em chunks.
      List<Map<String, dynamic>> diaries = [];
      const chunkSize = 30;
      for (var i = 0; i < diaryPostIds.length; i += chunkSize) {
        final chunk = diaryPostIds.sublist(
            i,
            i + chunkSize > diaryPostIds.length
                ? diaryPostIds.length
                : i + chunkSize);
        final postsSnapshot = await _db
            .collection('posts')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var postDoc in postsSnapshot.docs) {
          if (postDoc.exists) {
            final data = postDoc.data();
            final timestamp = data['data'] as Timestamp?;
            diaries.add({
              'id': postDoc.id,
              'titulo': data['titulo'] ?? 'Sem Título',
              'conteudo': data['conteudo'] ?? '',
              // Formata a data aqui para consistência
              'data': timestamp != null
                  ? DateFormat('dd/MM/yy HH:mm').format(timestamp.toDate())
                  : 'Data inválida',
              'timestamp':
                  timestamp // Mantém o timestamp original para ordenação se necessário
            });
          }
        }
      }

      // Ordena pela data original do post (opcional, se a ordenação inicial não for suficiente)
      diaries.sort((a, b) {
        final Timestamp? tsA = a['timestamp'];
        final Timestamp? tsB = b['timestamp'];
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1; // Nulos no final
        if (tsB == null) return -1;
        return tsB.compareTo(tsA); // Mais recente primeiro
      });

      return diaries;
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar diários do usuário $userId: $e");
      return []; // Retorna lista vazia em caso de erro
    }
  }

  // --- Book Progress Methods ---

  /// Garante que o progresso de um livro seja iniciado se ainda não existir.
  Future<void> startBookProgressIfNeeded(String userId, String bookId) async {
    try {
      final userDocRef = _db.collection('users').doc(userId);
      final bookDocRef = _db.collection('books').doc(bookId);

      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocRef);
        final booksProgress = Map<String, dynamic>.from(
            userSnapshot.data()?['booksProgress'] ?? {});

        if (!booksProgress.containsKey(bookId)) {
          final bookSnapshot = await transaction.get(bookDocRef);
          if (bookSnapshot.exists) {
            final bookData = bookSnapshot.data();
            booksProgress[bookId] = {
              'progress': 0,
              'readTopics': [],
              'chaptersIniciados': [],
              'title': bookData?['titulo'] ?? '?',
              'cover': bookData?['cover'] ?? '',
              'author': bookData?['autorId'] ?? '?',
              'totalTopicos': bookData?['totalTopicos'] ?? 1,
            };
            transaction.set(userDocRef, {'booksProgress': booksProgress},
                SetOptions(merge: true));
          } else {
            print(
                'FirestoreService: Livro $bookId não encontrado para iniciar progresso.');
          }
        }
      });
    } catch (e) {
      print("FirestoreService: Erro ao iniciar progresso do livro $bookId: $e");
      rethrow;
    }
  }

  /// Marca um tópico como lido e atualiza o progresso do livro.
  Future<bool> markTopicAsRead(String userId, String bookId, String topicId,
      String chapterId, int totalTopicos) async {
    try {
      final userDocRef = _db.collection('users').doc(userId);
      bool updated = false;

      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userDocRef);
        final booksProgress = Map<String, dynamic>.from(
            userSnapshot.data()?['booksProgress'] ?? {});

        if (booksProgress.containsKey(bookId)) {
          final bookData = Map<String, dynamic>.from(booksProgress[bookId]);
          final readTopics = List<String>.from(bookData['readTopics'] ?? []);
          final chaptersIniciados =
              List<String>.from(bookData['chaptersIniciados'] ?? []);

          if (!readTopics.contains(topicId)) {
            readTopics.add(topicId);
            final progress = totalTopicos > 0
                ? ((readTopics.length / totalTopicos) * 100)
                    .toInt()
                    .clamp(0, 100)
                : 0;
            bookData['progress'] = progress;
            bookData['readTopics'] = readTopics;
            if (!chaptersIniciados.contains(chapterId)) {
              chaptersIniciados.add(chapterId);
              bookData['chaptersIniciados'] = chaptersIniciados;
            }
            booksProgress[bookId] = bookData;

            transaction.update(userDocRef, {
              'booksProgress': booksProgress,
              'Tópicos': FieldValue.increment(1) // Incrementa contador global
            });
            updated = true;
          }
        }
      });
      return updated;
    } catch (e) {
      print("FirestoreService: Erro ao marcar tópico $topicId como lido: $e");
      return false; // Retorna false em caso de erro
    }
  }

  // --- Book Data Methods ---

  /// Busca as recomendações semanais (ex: 10 livros mais bem avaliados).
  Future<List<Map<String, dynamic>>> fetchWeeklyRecommendations() async {
    try {
      final querySnapshot = await _db.collection('books').get();
      List<Map<String, dynamic>> books = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final nota = data['nota'] as Map<String, dynamic>? ?? {};
        final score = (nota['score'] as num?) ?? 0;
        final votes = (nota['votes'] as num?) ?? 0;
        return {
          'id': doc.id,
          'cover': data['cover'] ?? '',
          'bookName': data['titulo'] ?? '?',
          'autor': data['autorId'] ?? '?',
          'nota': score,
          'votes': votes,
        };
      }).toList();
      books.sort((a, b) {
        int scoreCompare = (b['nota'] as num).compareTo(a['nota'] as num);
        return scoreCompare != 0
            ? scoreCompare
            : (b['votes'] as num).compareTo(a['votes'] as num);
      });
      return books.take(10).toList();
    } catch (e) {
      print("FirestoreService: Erro ao buscar recomendações semanais: $e");
      return [];
    }
  }

  /// Busca os dados de um livro específico pelo ID.
  Future<Map<String, dynamic>?> getBookData(String bookId) async {
    try {
      final doc = await _db.collection('books').doc(bookId).get();
      return doc.data();
    } catch (e) {
      print("FirestoreService: Erro ao buscar dados do livro $bookId: $e");
      return null;
    }
  }

  /// Busca os dados de um livro pela sua abreviação.
  Future<Map<String, dynamic>?> getBookDataByAbbrev(String abbrev) async {
    try {
      // Assumindo que a abreviação está no próprio documento do livro
      // Se não estiver, você precisaria de uma coleção de mapeamento ou buscar em todos os livros (ineficiente)
      final querySnapshot = await _db
          .collection('books')
          .where('abbrev', isEqualTo: abbrev.toLowerCase())
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      print("FirestoreService: Livro com abrev '$abbrev' não encontrado.");
      return null; // Ou tenta buscar pelo nome completo como fallback se necessário
    } catch (e) {
      print("FirestoreService: Erro ao buscar livro por abrev '$abbrev': $e");
      return null;
    }
  }

  /// Busca livros associados a uma tag específica.
  Future<List<Map<String, String>>> fetchBooksByTag(String tag) async {
    try {
      final tagSnapshot = await _db
          .collection('tags')
          .where('tag_name', isEqualTo: tag)
          .limit(1)
          .get();
      if (tagSnapshot.docs.isEmpty) return [];
      final tagDoc = tagSnapshot.docs.first;
      final bookIds = List<String>.from(tagDoc.data()['livros'] ?? []);
      final List<Map<String, String>> books = [];
      for (final bookId in bookIds) {
        final bookSnapshot = await _db.collection('books').doc(bookId).get();
        if (bookSnapshot.exists) {
          books.add({
            'cover': bookSnapshot.data()?['cover'] as String? ?? '',
            'title': bookSnapshot.data()?['titulo'] as String? ?? '',
            'bookId': bookId,
          });
        }
      }
      return books;
    } catch (e) {
      print("FirestoreService: Erro ao buscar livros pela tag $tag: $e");
      return [];
    }
  }

  /// Busca o nome completo de um livro a partir de sua abreviação.
  /// Otimizado para usar o mapa local `abbrev_map.json` se possível.
  Future<String?> getBookNameFromAbbrev(String abbrev) async {
    // Esta função agora se torna menos útil se todos os dados de mapeamento de livros
    // estão em JSONs locais. Considere remover ou apenas retornar a abreviação.
    // Se BiblePage._localBooksMap é a fonte da verdade, esta função pode não ser necessária.
    print(
        "FirestoreService.getBookNameFromAbbrev chamada para $abbrev - CONSIDERAR REMOÇÃO SE NÃO USADA MAIS PELO FIRESTORE");
    // return abbrev.toUpperCase(); // Opção simples para evitar erro de Firestore
    return null; // Ou retornar null e tratar na chamada
  }

  // --- Topic Methods ---

  /// Busca os dados de um tópico específico pelo ID.
  Future<Map<String, dynamic>?> getTopicData(String topicId) async {
    try {
      final doc = await _db.collection('topics').doc(topicId).get();
      return doc.data();
    } catch (e) {
      print("FirestoreService: Erro ao buscar dados do tópico $topicId: $e");
      return null;
    }
  }

  /// Busca os dados de múltiplos tópicos a partir de uma lista de IDs.
  Future<List<Map<String, dynamic>>> fetchTopicsByIds(
      List<String> topicIds) async {
    if (topicIds.isEmpty) return [];
    List<Map<String, dynamic>> topics = [];
    const chunkSize = 30; // Limite do 'whereIn'
    try {
      for (var i = 0; i < topicIds.length; i += chunkSize) {
        final chunk = topicIds.sublist(i,
            i + chunkSize > topicIds.length ? topicIds.length : i + chunkSize);
        final querySnapshot = await _db
            .collection('topics')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          topics.add({
            'id': doc.id,
            'cover': data['cover'] ?? '',
            'bookName': data['bookName'] ?? '',
            'chapterName': data['chapterName'] ?? '',
            'conteudo': data['conteudo'] ?? '',
            'autor': data['authorName'] ?? '',
            'bookId': data['bookId'] ?? '',
            'titulo': data['titulo'] ?? '',
          });
        }
      }
    } catch (e) {
      print("FirestoreService: Erro ao buscar tópicos por IDs: $e");
    }
    return topics;
  }

  /// Busca os tópicos similares a um tópico específico.
  Future<List<Map<String, dynamic>>> getSimilarTopics(String topicId) async {
    try {
      final doc = await _db.collection('topics').doc(topicId).get();
      final data = doc.data();
      if (data != null && data['similar_topics'] is List) {
        return List<Map<String, dynamic>>.from((data['similar_topics'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)));
      }
      return [];
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar tópicos similares para $topicId: $e");
      return [];
    }
  }

  // --- Chat Methods ---

  /// Salva uma mensagem de chat no Firestore.
  Future<void> saveChatMessage(
      String chatId, Map<String, dynamic> messageData) async {
    try {
      await _db
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add(messageData);
    } catch (e) {
      print("FirestoreService: Erro ao salvar mensagem de chat: $e");
      rethrow;
    }
  }

  // --- Section Commentary Methods ---

  /// Busca o comentário associado a uma seção específica da Bíblia.
  Future<Map<String, dynamic>?> getSectionCommentary(
      String commentaryDocId) async {
    try {
      final docSnapshot = await _db
          .collection('commentary_sections')
          .doc(commentaryDocId)
          .get();
      if (docSnapshot.exists) {
        return docSnapshot.data();
      } else {
        print(
            'FirestoreService: Comentário da seção não encontrado: $commentaryDocId');
        return null;
      }
    } catch (e) {
      print(
          'FirestoreService: Erro ao buscar comentário da seção $commentaryDocId: $e');
      return null;
    }
  }

  // --- Highlight Methods ---

  /// Salva ou atualiza um destaque de versículo.
  Future<void> saveHighlight(String userId, String verseId, String colorHex,
      {List<String>? tags, String? fullVerseText}) async {
    // <<< ADICIONE O NOVO PARÂMETRO
    try {
      await _db.collection('userVerseHighlights').doc(userId).set(
          {'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      await _db
          .collection('userVerseHighlights')
          .doc(userId)
          .collection('highlights')
          .doc(verseId)
          .set({
        'color': colorHex,
        'tags': tags ?? [],
        'fullVerseText': fullVerseText ??
            '[Texto não encontrado]', // <<< GARANTE QUE SEJA SALVO
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print(
          "FirestoreService: Erro ao salvar destaque $verseId para $userId: $e");
      rethrow;
    }
  }

  /// Remove um destaque de versículo.
  Future<void> removeHighlight(String userId, String verseId) async {
    try {
      await _db
          .collection('userVerseHighlights')
          .doc(userId)
          .collection('highlights')
          .doc(verseId)
          .delete();
    } catch (e) {
      print(
          "FirestoreService: Erro ao remover destaque $verseId para $userId: $e");
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> loadUserHighlights(
      String userId) async {
    try {
      final snapshot = await _db
          .collection('userVerseHighlights')
          .doc(userId)
          .collection('highlights')
          .get();

      Map<String, Map<String, dynamic>> highlights = {};
      for (var doc in snapshot.docs) {
        // Agora, pegamos todos os dados do documento, não apenas a cor.
        highlights[doc.id] = doc.data();
      }
      return highlights;
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar destaques de versículos para $userId: $e");
      return {};
    }
  }

  // --- Note Methods ---
  Future<Map<String, Map<String, dynamic>>> loadUserNotesRaw(
      String userId) async {
    try {
      final snapshot = await _db
          .collection('userVerseNotes')
          .doc(userId)
          .collection('notes')
          .get();
      Map<String, Map<String, dynamic>> notes = {};
      for (var doc in snapshot.docs) {
        notes[doc.id] = doc.data();
      }
      return notes;
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar dados brutos das notas para $userId: $e");
      return {};
    }
  }

  /// Salva ou atualiza uma nota de versículo.
  Future<void> saveNote(String userId, String verseId, String text) async {
    try {
      await _db.collection('userVerseNotes').doc(userId).set(
          {'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      await _db
          .collection('userVerseNotes')
          .doc(userId)
          .collection('notes')
          .doc(verseId)
          .set({
        'text': text,
        // <<< ADICIONE ESTA LINHA >>>
        'timestamp':
            FieldValue.serverTimestamp(), // Adiciona o timestamp do servidor
      });
      print(
          "FirestoreService: Nota para $verseId salva para usuário $userId com timestamp.");
    } catch (e) {
      print(
          "FirestoreService: Erro ao salvar nota para $verseId (usuário $userId): $e");
      rethrow;
    }
  }

  Future<void> removeNote(String userId, String verseId) async {
    try {
      await _db
          .collection('userVerseNotes')
          .doc(userId)
          .collection('notes')
          .doc(verseId)
          .delete();
      print(
          "FirestoreService: Nota para $verseId removida para usuário $userId");
    } catch (e) {
      print(
          "FirestoreService: Erro ao remover nota para $verseId (usuário $userId): $e");
      rethrow;
    }
  }

  Future<Map<String, String>> loadUserNotes(String userId) async {
    try {
      final snapshot = await _db
          .collection('userVerseNotes')
          .doc(userId)
          .collection('notes')
          .get();
      Map<String, String> notes = {};
      for (var doc in snapshot.docs) {
        notes[doc.id] = doc.data()['text'] as String; // doc.id é o verseId
      }
      return notes;
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar notas de versículos para $userId: $e");
      return {};
    }
  }

  // --- Reading History Methods ---

  /// Adiciona uma entrada ao histórico de leitura do usuário.
  Future<void> addReadingHistoryEntry(
      String userId, String bookAbbrev, int chapter, String bookName) async {
    try {
      final historyCollectionRef =
          _db.collection('users').doc(userId).collection('reading_history');

      // 1. Adicionar a nova entrada de histórico
      await historyCollectionRef.add({
        'bookAbbrev': bookAbbrev,
        'chapter': chapter,
        'bookName':
            bookName, // Nome completo do livro para exibição no histórico
        'timestamp': FieldValue.serverTimestamp(),
      });
      print(
          "FirestoreService: Nova entrada de histórico adicionada para $userId: $bookName $chapter");

      // 2. Manter o histórico dentro do limite (ex: 20 entradas)
      // Esta operação pode ser feita em uma Cloud Function para melhor desempenho e
      // para evitar múltiplas leituras/escritas do cliente se o histórico for muito ativo.
      // Mas, para uma implementação no cliente:
      final QuerySnapshot snapshot = await historyCollectionRef
          .orderBy('timestamp', descending: true) // Mais recentes primeiro
          .get();

      if (snapshot.docs.length > READING_HISTORY_LIMIT) {
        // Determinar quantos documentos deletar
        int docsToDeleteCount = snapshot.docs.length - READING_HISTORY_LIMIT;

        // Pegar os IDs dos documentos mais antigos para deletar
        // Os documentos já estão ordenados do mais recente para o mais antigo,
        // então pegamos os últimos 'docsToDeleteCount' da lista.
        List<DocumentSnapshot> docsToDelete =
            snapshot.docs.sublist(READING_HISTORY_LIMIT);

        // Deletar os documentos excedentes em um batch para eficiência
        WriteBatch batch = _db.batch();
        for (var doc in docsToDelete) {
          batch.delete(doc.reference);
          // print(
          //     "FirestoreService: Marcado para deleção (histórico antigo): ${doc.id} - ${doc.data()?['bookName']} ${doc.data()?['chapter']}");
        }
        await batch.commit();
        print(
            "FirestoreService: Histórico antigo (além de ${READING_HISTORY_LIMIT} entradas) deletado para $userId.");
      }
    } catch (e) {
      print(
          "FirestoreService: Erro ao adicionar/limpar histórico de leitura para $userId: $e");
      // Não relançar o erro necessariamente, pois a adição principal pode ter funcionado.
      // A limpeza é uma tarefa de manutenção.
    }
  }

  /// Carrega o histórico de leitura do usuário, já limitado pelo Firestore.
  Future<List<Map<String, dynamic>>> loadReadingHistory(String userId) async {
    // Removido {int limit = 50}
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('reading_history')
          .orderBy('timestamp', descending: true)
          .limit(READING_HISTORY_LIMIT) // <<< USA O LIMITE DEFINIDO
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        return {
          'id': doc.id,
          'bookAbbrev': data['bookAbbrev'],
          'chapter': data['chapter'],
          'bookName': data['bookName'] ??
              data['bookAbbrev'], // Fallback para abreviação
          'timestamp': timestamp?.toDate(),
        };
      }).toList();
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar histórico de leitura para $userId: $e");
      return [];
    }
  }

  /// Atualiza o último local lido no documento principal do usuário.
  Future<void> updateLastReadLocation(
      String userId, String bookAbbrev, int chapter) async {
    try {
      final docRef = _db.collection('userBibleProgress').doc(userId);
      // Usa set com merge:true para criar o documento se não existir, ou atualizar campos existentes.
      await docRef.set({
        'lastReadBookAbbrev': bookAbbrev,
        'lastReadChapter': chapter,
        'lastReadTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print(
          "FirestoreService: Última leitura atualizada em userBibleProgress para $userId: $bookAbbrev cap $chapter");
    } catch (e) {
      print(
          "FirestoreService: Erro ao atualizar última leitura em userBibleProgress para $userId: $e");
      rethrow;
    }
  }

  // --- Stripe/Subscription Methods ---

  /// Encontra o userId do Firebase associado a um stripeCustomerId.
  Future<String?> findUserIdByStripeCustomerId(String stripeCustomerId) async {
    try {
      final querySnapshot = await _db
          .collection('users')
          .where('stripeCustomerId', isEqualTo: stripeCustomerId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      print(
          "FirestoreService: Nenhum usuário Firebase encontrado com Stripe Customer ID: $stripeCustomerId");
      return null;
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar usuário por Stripe Customer ID: $e");
      return null;
    }
  }

  /// Atualiza (ou cria) os campos de assinatura no documento do usuário.
  Future<void> updateUserSubscriptionStatus({
    required String userId,
    required String status,
    required String customerId,
    String? subscriptionId,
    Timestamp? endDate,
    String? priceId,
  }) async {
    try {
      final userDocRef = _db.collection('users').doc(userId);
      final updateData = {
        'stripeCustomerId': customerId,
        'subscriptionStatus': status,
        if (subscriptionId != null) 'stripeSubscriptionId': subscriptionId,
        if (endDate != null) 'subscriptionEndDate': endDate,
        if (priceId != null) 'activePriceId': priceId,
      };
      await userDocRef.set(updateData, SetOptions(merge: true));
      print(
          "FirestoreService: Status da assinatura atualizado no Firestore para usuário $userId: $status");
    } catch (e) {
      print(
          "FirestoreService: Erro ao atualizar status da assinatura no Firestore para $userId: $e");
      rethrow;
    }
  }

  // --- Métodos para Progresso de Leitura Bíblica ---

  Future<BibleBookProgressData?> getBibleBookProgress(
      String userId, String bookAbbrev) async {
    try {
      final docSnapshot =
          await _db.collection('userBibleProgress').doc(userId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        // Acessa o mapa 'books' e depois a entrada específica do bookAbbrev
        final booksData = data['books'] as Map<String, dynamic>? ?? {};
        final bookProgressMap = booksData[bookAbbrev] as Map<String, dynamic>?;

        if (bookProgressMap != null) {
          return BibleBookProgressData(
            readSections: Set<String>.from(
                bookProgressMap['readSections'] as List<dynamic>? ?? []),
            totalSections: bookProgressMap['totalSectionsInBook'] as int? ?? 0,
            completed: bookProgressMap['completed'] as bool? ?? false,
            lastReadTimestamp: bookProgressMap['lastReadTimestampBook']
                as Timestamp?, // Assumindo que você terá este campo por livro
          );
        }
      }
      // print("FirestoreService: Nenhum progresso encontrado para livro $bookAbbrev ou usuário $userId não tem doc em userBibleProgress.");
      return null;
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar progresso do livro $bookAbbrev para usuário $userId: $e");
      return null;
    }
  }

  Future<void> toggleBibleSectionReadStatus(
    String userId,
    String bookAbbrev,
    String sectionId,
    bool markAsRead,
    int totalSectionsInBookFromMetadata,
  ) async {
    final docRef = _db.collection('userBibleProgress').doc(userId);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);

      // Se o documento do usuário não existir na coleção 'userBibleProgress', inicializa os dados.
      Map<String, dynamic> userData = snapshot.exists
          ? (snapshot.data() as Map<String, dynamic>? ?? {})
          : {
              'books': {},
              'lastReadBookAbbrev': null,
              'lastReadChapter': null,
              'lastReadTimestamp': null
            };

      Map<String, dynamic> booksProgress =
          Map<String, dynamic>.from(userData['books'] ?? {});
      Map<String, dynamic> bookData =
          Map<String, dynamic>.from(booksProgress[bookAbbrev] ?? {});

      Set<String> readSections =
          Set<String>.from(bookData['readSections'] as List<dynamic>? ?? []);
      int currentTotalInDb = bookData['totalSectionsInBook'] as int? ?? 0;

      // Usa o total de seções dos metadados se não houver no DB ou se o do DB for 0 e o dos metadados for maior.
      // Isso é importante para a primeira vez que o progresso de um livro é atualizado.
      int finalTotalSections = (currentTotalInDb > 0 &&
              currentTotalInDb >= totalSectionsInBookFromMetadata)
          ? currentTotalInDb
          : totalSectionsInBookFromMetadata;
      // Garante que se o metadado tiver um valor e o DB não, use o do metadado.
      if (finalTotalSections == 0 && totalSectionsInBookFromMetadata > 0) {
        finalTotalSections = totalSectionsInBookFromMetadata;
      }

      if (markAsRead) {
        readSections.add(sectionId);
      } else {
        readSections.remove(sectionId);
      }

      // Calcula o status 'completed' apenas se soubermos o total de seções.
      bool newCompletedStatus = (finalTotalSections > 0)
          ? readSections.length >= finalTotalSections
          : false;

      // Atualiza os dados específicos do livro
      bookData['readSections'] =
          readSections.toList(); // Salva como List no Firestore
      bookData['totalSectionsInBook'] =
          finalTotalSections; // Garante que o total correto está salvo
      bookData['completed'] = newCompletedStatus;
      bookData['lastReadTimestampBook'] = FieldValue
          .serverTimestamp(); // Timestamp da última interação com este livro

      booksProgress[bookAbbrev] =
          bookData; // Coloca os dados atualizados do livro de volta no mapa de livros

      // Prepara os dados para serem escritos/atualizados no documento principal userBibleProgress/{userId}
      Map<String, dynamic> dataToSet = {
        'books':
            booksProgress, // O mapa completo de progresso de todos os livros
        'lastReadBookAbbrev':
            bookAbbrev, // Assume que a última seção lida é deste livro
        'lastReadChapter':
            int.tryParse(sectionId.split('_c')[1].split('_v')[0]) ??
                0, // Tenta extrair capítulo da sectionId
        'lastReadTimestamp':
            FieldValue.serverTimestamp(), // Timestamp geral da última leitura
      };

      if (snapshot.exists) {
        transaction.update(docRef, dataToSet);
      } else {
        // Se o documento /userBibleProgress/{userId} não existe, cria ele com todos os dados.
        transaction.set(docRef, dataToSet);
      }
    });
    print(
        "Progresso para $userId/$bookAbbrev/$sectionId atualizado. MarkAsRead: $markAsRead");
  }

  Future<Map<String, BibleBookProgressData>> getAllBibleProgress(
      String userId) async {
    Map<String, BibleBookProgressData> allProgress = {};
    try {
      DocumentSnapshot userProgressDoc =
          await _db.collection('userBibleProgress').doc(userId).get();
      if (userProgressDoc.exists && userProgressDoc.data() != null) {
        final data = userProgressDoc.data() as Map<String, dynamic>;
        final booksData = data['books'] as Map<String, dynamic>? ??
            {}; // Acessa o mapa 'books'

        booksData.forEach((bookAbbrev, bookProgressMap) {
          if (bookProgressMap is Map) {
            // Converte o mapa aninhado para o tipo correto
            final typedBookProgressMap =
                Map<String, dynamic>.from(bookProgressMap);
            allProgress[bookAbbrev] = BibleBookProgressData(
              readSections: Set<String>.from(
                  typedBookProgressMap['readSections'] as List<dynamic>? ?? []),
              totalSections:
                  typedBookProgressMap['totalSectionsInBook'] as int? ?? 0,
              completed: typedBookProgressMap['completed'] as bool? ?? false,
              lastReadTimestamp:
                  typedBookProgressMap['lastReadTimestampBook'] as Timestamp?,
            );
          }
        });
      }
      return allProgress;
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar todo o progresso bíblico para usuário $userId: $e");
      return {}; // Retorna mapa vazio em caso de erro
    }
  }

  Future<void> batchUpdateBibleProgress(
    String userId,
    String bookAbbrev,
    List<String> sectionsToAdd,
    List<String> sectionsToRemove,
    int totalSectionsInBookFromMetadata, // Total de seções do livro vindo dos metadados
  ) async {
    final docRef = _db.collection('userBibleProgress').doc(userId);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);

      Map<String, dynamic> userData = snapshot.exists
          ? (snapshot.data() as Map<String, dynamic>? ?? {})
          : {'books': {}};

      Map<String, dynamic> booksProgress =
          Map<String, dynamic>.from(userData['books'] ?? {});
      Map<String, dynamic> bookData =
          Map<String, dynamic>.from(booksProgress[bookAbbrev] ?? {});

      Set<String> currentReadSections =
          Set<String>.from(bookData['readSections'] as List<dynamic>? ?? []);
      int currentTotalInDb = bookData['totalSectionsInBook'] as int? ?? 0;

      int finalTotalSections = (currentTotalInDb > 0 &&
              currentTotalInDb >= totalSectionsInBookFromMetadata)
          ? currentTotalInDb
          : totalSectionsInBookFromMetadata;
      if (finalTotalSections == 0 && totalSectionsInBookFromMetadata > 0) {
        finalTotalSections = totalSectionsInBookFromMetadata;
      }

      currentReadSections.addAll(sectionsToAdd);
      currentReadSections.removeAll(sectionsToRemove);

      bool newCompletedStatus = (finalTotalSections > 0)
          ? currentReadSections.length >= finalTotalSections
          : false;

      bookData['readSections'] = currentReadSections.toList();
      bookData['totalSectionsInBook'] = finalTotalSections;
      bookData['completed'] = newCompletedStatus;
      bookData['lastReadTimestampBook'] = FieldValue.serverTimestamp();

      booksProgress[bookAbbrev] = bookData;

      Map<String, dynamic> dataToSet = {'books': booksProgress};
      // Não atualiza o lastRead geral aqui, pois é um batch. A última leitura real do usuário é mais relevante.

      if (snapshot.exists) {
        transaction.update(docRef, dataToSet);
      } else {
        transaction.set(docRef, dataToSet);
      }
    });
    print(
        "Progresso da Bíblia para $userId/$bookAbbrev atualizado em lote. Adicionadas: ${sectionsToAdd.length}, Removidas: ${sectionsToRemove.length}.");
  }

  // --- Helpers ---

  /// Extrai o número do capítulo do nome do capítulo (se existir).
  int? extractChapterIndex(String? chapterName) {
    if (chapterName == null) return null;
    final match = RegExp(r'^\d+').firstMatch(chapterName);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  // NOVA FUNÇÃO para buscar detalhes de um sermão específico
  Future<Map<String, dynamic>?> getSermonDetailsFromFirestore(
      String generatedSermonId) async {
    try {
      final docSnapshot =
          await _db.collection('spurgeon_sermons').doc(generatedSermonId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data();
      } else {
        print(
            "FirestoreService: Sermão com ID Gerado '$generatedSermonId' não encontrado na coleção 'spurgeon_sermons'.");
        return null; // Retorna nulo se o documento não existe (não é um erro de conexão)
      }
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar detalhes do sermão '$generatedSermonId': $e");
      rethrow; // ✅ CORREÇÃO: Relança o erro para a camada superior (a página) poder tratá-lo.
    }
  }

  // Busca a entrada do diário para uma data específica.
  /// A data é formatada como 'YYYY-MM-DD' para ser o ID do documento.
  Future<Map<String, dynamic>?> getDiaryEntry(
      String userId, DateTime date) async {
    final String entryId = DateFormat('yyyy-MM-dd').format(date);
    try {
      final docSnapshot = await _db
          .collection('diaries')
          .doc(userId)
          .collection('entries')
          .doc(entryId)
          .get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null; // Retorna nulo se não houver entrada para este dia
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar entrada do diário para $entryId: $e");
      return null;
    }
  }

  /// Salva ou atualiza o texto do diário para uma data específica.
  Future<void> updateJournalText(
      String userId, DateTime date, String text) async {
    final String entryId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db
        .collection('diaries')
        .doc(userId)
        .collection('entries')
        .doc(entryId);

    try {
      // Usa set com merge:true para criar o documento se não existir
      await docRef.set({
        'journalText': text,
        'date': Timestamp.fromDate(date),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print(
          "FirestoreService: Erro ao atualizar o texto do diário para $entryId: $e");
      rethrow;
    }
  }

  /// Adiciona um novo pedido de oração para uma data específica.
  Future<void> addPrayerPoint(
      String userId, DateTime date, String prayerText) async {
    final String entryId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db
        .collection('diaries')
        .doc(userId)
        .collection('entries')
        .doc(entryId);

    // >>> INÍCIO DA CORREÇÃO <<<
    // Usamos Timestamp.now() que gera o timestamp no cliente, o que é permitido em arrayUnion.
    final newPrayerPoint = {
      'text': prayerText,
      'answered': false,
      'createdAt': Timestamp.now(), // <-- MUDANÇA ESSENCIAL AQUI
    };
    // >>> FIM DA CORREÇÃO <<<

    try {
      // Tenta adicionar o novo pedido ao array 'prayerPoints' existente.
      await docRef.update({
        'prayerPoints': FieldValue.arrayUnion([newPrayerPoint])
      });
    } catch (e) {
      // Se a atualização falhar (provavelmente porque o documento ou o array não existem),
      // cria o documento com o novo pedido de oração.
      if (e is FirebaseException && e.code == 'not-found') {
        await docRef.set({
          'prayerPoints': [newPrayerPoint],
          'date': Timestamp.fromDate(date),
          'lastUpdated': FieldValue
              .serverTimestamp(), // serverTimestamp é permitido aqui em 'set'.
        }, SetOptions(merge: true));
      } else {
        // Se for outro erro, relança para depuração.
        print(
            "FirestoreService: Erro ao adicionar pedido de oração para $entryId: $e");
        rethrow;
      }
    }
  }

  /// Atualiza o status de um pedido de oração.
  /// Isso é mais complexo, pois requer ler, modificar e reescrever o array inteiro.
  Future<void> updatePrayerPoint(String userId, DateTime date, int prayerIndex,
      Map<String, dynamic> updatedPrayerData) async {
    final String entryId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db
        .collection('diaries')
        .doc(userId)
        .collection('entries')
        .doc(entryId);

    try {
      final doc = await docRef.get();
      if (doc.exists) {
        List<dynamic> prayerPoints =
            List.from(doc.data()?['prayerPoints'] ?? []);
        if (prayerIndex >= 0 && prayerIndex < prayerPoints.length) {
          prayerPoints[prayerIndex] = updatedPrayerData;
          await docRef.update({'prayerPoints': prayerPoints});
        }
      }
    } catch (e) {
      print(
          "FirestoreService: Erro ao atualizar pedido de oração para $entryId: $e");
      rethrow;
    }
  }

  /// Remove um pedido de oração.
  Future<void> removePrayerPoint(String userId, DateTime date,
      Map<String, dynamic> prayerPointToRemove) async {
    final String entryId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db
        .collection('diaries')
        .doc(userId)
        .collection('entries')
        .doc(entryId);

    try {
      await docRef.update({
        'prayerPoints': FieldValue.arrayRemove([prayerPointToRemove])
      });
    } catch (e) {
      print("FirestoreService: Erro ao remover pedido de oração: $e");
      rethrow;
    }
  }

  /// Adiciona uma promessa selecionada a um diário específico.
  Future<void> addPromiseToDiary(
      String userId, DateTime date, Map<String, String> promise) async {
    final String entryId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db
        .collection('diaries')
        .doc(userId)
        .collection('entries')
        .doc(entryId);

    // O objeto 'promise' terá a forma {'text': '...', 'reference': '...'}
    final Map<String, dynamic> promiseData = {
      'text': promise['text'],
      'reference': promise['reference'],
      'addedAt': Timestamp.now(), // Timestamp do cliente
    };

    try {
      await docRef.update({
        'attachedPromises': FieldValue.arrayUnion([promiseData])
      });
    } catch (e) {
      if (e is FirebaseException && e.code == 'not-found') {
        await docRef.set({
          'attachedPromises': [promiseData],
          'date': Timestamp.fromDate(date),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        print("FirestoreService: Erro ao adicionar promessa ao diário: $e");
        rethrow;
      }
    }
  }

  /// Remove uma promessa de um diário específico.
  Future<void> removePromiseFromDiary(String userId, DateTime date,
      Map<String, dynamic> promiseToRemove) async {
    final String entryId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db
        .collection('diaries')
        .doc(userId)
        .collection('entries')
        .doc(entryId);

    try {
      await docRef.update({
        'attachedPromises': FieldValue.arrayRemove([promiseToRemove])
      });
    } catch (e) {
      print("FirestoreService: Erro ao remover promessa do diário: $e");
      rethrow;
    }
  }

  Future<Map<String, List<LibraryReference>>> fetchLibraryReferencesForSections(
      List<String> sectionIds) async {
    if (sectionIds.isEmpty) {
      print(
          "FirestoreService: Nenhum ID de seção fornecido para buscar referências da biblioteca.");
      return {};
    }

    final Map<String, List<LibraryReference>> results = {};
    // O Firestore tem um limite de 30 itens para a cláusula 'whereIn'
    const chunkSize = 30;

    // Processa os IDs em lotes para respeitar o limite
    for (var i = 0; i < sectionIds.length; i += chunkSize) {
      final chunk = sectionIds.sublist(
          i,
          i + chunkSize > sectionIds.length
              ? sectionIds.length
              : i + chunkSize);

      try {
        print(
            "FirestoreService: Buscando referências para o lote de seções: $chunk");
        final querySnapshot = await _db
            .collection(
                'cross_references_biblioteca_cursos') // <<< NOME CORRETO DA SUA COLEÇÃO
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in querySnapshot.docs) {
          final recommendationsRaw =
              doc.data()['recommendations'] as List<dynamic>? ?? [];
          final recommendations = recommendationsRaw
              .map((item) =>
                  LibraryReference.fromJson(item as Map<String, dynamic>))
              .toList();
          results[doc.id] = recommendations;
        }
        print(
            "FirestoreService: Lote processado com ${querySnapshot.docs.length} resultados.");
      } catch (e) {
        print(
            "FirestoreService: ERRO ao buscar lote de referências da biblioteca: $e");
        // Continua para o próximo lote em vez de falhar completamente
      }
    }
    print(
        "FirestoreService: Busca de referências da biblioteca concluída. Total de seções encontradas: ${results.length}");
    return results;
  }

  Future<List<Map<String, dynamic>>?> getChapterMapData(
      String chapterId) async {
    try {
      final docSnapshot =
          await _db.collection('bibleChapterMaps').doc(chapterId).get();

      if (docSnapshot.exists) {
        // Se o documento existe, retorna o array 'places' dentro dele.
        // Usamos 'cast' para garantir a tipagem correta.
        final data = docSnapshot.data();
        return (data?['places'] as List<dynamic>?)
            ?.map((place) => Map<String, dynamic>.from(place))
            .toList();
      } else {
        // Se o documento não existe, significa que não há dados de mapa para este capítulo.
        print(
            "FirestoreService: Nenhum dado de mapa encontrado para o capítulo: $chapterId");
        return null;
      }
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar dados do mapa para o capítulo $chapterId: $e");
      // Em caso de erro, também retornamos nulo.
      return null;
    }
  }

  Future<Map<String, dynamic>?> getThemedMapCategory(
      String categoryDocumentId) async {
    try {
      final docSnapshot =
          await _db.collection('themedMaps').doc(categoryDocumentId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      print(
          "FirestoreService: Documento de mapa temático não encontrado: $categoryDocumentId");
      return null;
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar mapa temático $categoryDocumentId: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getMindMap(String mapId) async {
    try {
      final docSnapshot = await _db.collection('mindMaps').doc(mapId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      print(
          "FirestoreService: Nenhum mapa mental encontrado para o ID: $mapId");
      return null;
    } catch (e) {
      print("FirestoreService: Erro ao buscar mapa mental $mapId: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getBookChapters(String bookId) async {
    try {
      final snapshot = await _db
          .collection('Books')
          .doc(bookId)
          .collection('chapters')
          .orderBy(FieldPath
              .documentId) // Ordena pelo ID do documento (que é o 'play_order')
          .get();

      if (snapshot.docs.isEmpty) {
        print(
            "FirestoreService: Nenhum capítulo encontrado para o livro ID: $bookId");
        return [];
      }

      // Mapeia cada documento para um mapa de dados
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar capítulos para o livro $bookId: $e");
      // Retorna uma lista vazia em caso de erro para não quebrar a UI
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchInProgressContent(
      String userId) async {
    try {
      print(
          "FirestoreService: Buscando conteúdo em progresso para o usuário $userId...");
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('userReadingProgress') // A nova subcoleção que planejamos
          .orderBy('lastAccessed', descending: true)
          .limit(10) // Limitamos a 10 para a UI não ficar sobrecarregada
          .get();

      final items = snapshot.docs.map((doc) => doc.data()).toList();
      print(
          "FirestoreService: Encontrados ${items.length} itens em progresso.");
      return items;
    } catch (e) {
      print("FirestoreService: ERRO ao buscar conteúdo em progresso: $e");
      return []; // Retorna uma lista vazia em caso de erro
    }
  }

  Future<List<Map<String, dynamic>>> fetchLibraryShelves() async {
    try {
      final snapshot = await _db
          .collection('libraryShelves')
          .orderBy('order') // Ordena pela ordem definida no documento
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("FirestoreService: ERRO ao buscar prateleiras da biblioteca: $e");
      return [];
    }
  }

  Future<void> updateUnifiedReadingProgress(
      String userId, String contentId, double progressPercentage) async {
    // Garante que o progresso esteja entre 0.0 e 1.0
    final clampedProgress = progressPercentage.clamp(0.0, 1.0);

    try {
      final docRef = _db
          .collection('users')
          .doc(userId)
          .collection('userReadingProgress')
          .doc(contentId); // O ID do documento é o ID do conteúdo

      await docRef.set({
        'contentId': contentId,
        'progressPercentage': clampedProgress,
        'lastAccessed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // 'merge: true' cria ou atualiza o documento

      print(
          "FirestoreService: Progresso unificado para '$contentId' atualizado para ${(clampedProgress * 100).toStringAsFixed(1)}%.");
    } catch (e) {
      print(
          "FirestoreService: ERRO ao atualizar progresso unificado para '$contentId': $e");
      // Não relançamos o erro para não quebrar o fluxo principal de salvamento de progresso.
    }
  }
}
