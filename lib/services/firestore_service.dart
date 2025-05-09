// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatar datas

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
          .collection('users')
          .doc(userId)
          .collection('comment_highlights') // Nome da subcoleção
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id, // Importante para remoção posterior
          ...data,
        };
      }).toList();
    } catch (e) {
      print("FirestoreService: Erro ao carregar destaques de comentários: $e");
      return [];
    }
  }

  Future<DocumentReference> addCommentHighlight(
      String userId, Map<String, dynamic> highlightData) async {
    try {
      final dataWithTimestamp = {
        ...highlightData,
        'timestamp': highlightData['timestamp'] ?? FieldValue.serverTimestamp(),
      };
      final docRef = await _db
          .collection('users')
          .doc(userId)
          .collection('comment_highlights')
          .add(dataWithTimestamp);
      print(
          "FirestoreService: Destaque de comentário adicionado com ID: ${docRef.id}");
      return docRef;
    } catch (e) {
      print("FirestoreService: Erro ao adicionar destaque de comentário: $e");
      rethrow;
    }
  }

  Future<void> removeCommentHighlight(String userId, String highlightId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('comment_highlights')
          .doc(highlightId)
          .delete();
      print("FirestoreService: Destaque de comentário removido: $highlightId");
    } catch (e) {
      print(
          "FirestoreService: Erro ao remover destaque de comentário $highlightId: $e");
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
    // Tenta carregar o mapa localmente se ainda não carregado (poderia ser injetado)
    // Map<String, dynamic>? localBooksMap;
    // try { localBooksMap = await BiblePageHelper.loadBooksMap(); } catch(e) {}

    // if (localBooksMap != null && localBooksMap.containsKey(abbrev)) {
    //   return localBooksMap[abbrev]?['nome'] as String?;
    // }

    // Fallback: Busca no Firestore (menos eficiente se chamado muitas vezes)
    try {
      final bookData = await getBookDataByAbbrev(abbrev);
      return bookData?['titulo'] as String?;
    } catch (e) {
      print(
          "FirestoreService: Erro ao buscar nome do livro (Firestore) para $abbrev: $e");
      return null;
    }
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
  Future<void> saveHighlight(
      String userId, String verseId, String colorHex) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('user_highlights')
          .doc(verseId)
          .set({
        'verseId': verseId,
        'color': colorHex,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("FirestoreService: Erro ao salvar destaque $verseId: $e");
      rethrow;
    }
  }

  /// Remove um destaque de versículo.
  Future<void> removeHighlight(String userId, String verseId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('user_highlights')
          .doc(verseId)
          .delete();
    } catch (e) {
      print("FirestoreService: Erro ao remover destaque $verseId: $e");
      rethrow;
    }
  }

  /// Carrega todos os destaques de um usuário.
  Future<Map<String, String>> loadUserHighlights(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('user_highlights')
          .get();
      Map<String, String> highlights = {};
      for (var doc in snapshot.docs) {
        highlights[doc.id] = doc.data()['color'] as String;
      }
      return highlights;
    } catch (e) {
      print(
          "FirestoreService: Erro ao carregar destaques do usuário $userId: $e");
      return {};
    }
  }

  // --- Note Methods ---

  /// Salva ou atualiza uma nota de versículo.
  Future<void> saveNote(String userId, String verseId, String text) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('user_notes')
          .doc(verseId)
          .set({
        'verseId': verseId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("FirestoreService: Erro ao salvar nota $verseId: $e");
      rethrow;
    }
  }

  /// Remove uma nota de versículo.
  Future<void> removeNote(String userId, String verseId) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('user_notes')
          .doc(verseId)
          .delete();
    } catch (e) {
      print("FirestoreService: Erro ao remover nota $verseId: $e");
      rethrow;
    }
  }

  /// Carrega todas as notas de um usuário.
  Future<Map<String, String>> loadUserNotes(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('user_notes')
          .get();
      Map<String, String> notes = {};
      for (var doc in snapshot.docs) {
        notes[doc.id] = doc.data()['text'] as String;
      }
      return notes;
    } catch (e) {
      print("FirestoreService: Erro ao carregar notas do usuário $userId: $e");
      return {};
    }
  }

  // --- Reading History Methods ---

  /// Adiciona uma entrada ao histórico de leitura do usuário.
  Future<void> addReadingHistoryEntry(
      String userId, String bookAbbrev, int chapter, String bookName) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('reading_history')
          .add({
        'bookAbbrev': bookAbbrev,
        'chapter': chapter,
        'bookName': bookName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("FirestoreService: Erro ao adicionar histórico de leitura: $e");
      rethrow;
    }
  }

  /// Carrega o histórico de leitura do usuário, limitado por `limit`.
  Future<List<Map<String, dynamic>>> loadReadingHistory(String userId,
      {int limit = 50}) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('reading_history')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        return {
          'id': doc.id,
          'bookAbbrev': data['bookAbbrev'],
          'chapter': data['chapter'],
          'bookName': data['bookName'] ?? data['bookAbbrev'],
          'timestamp': timestamp?.toDate(),
        };
      }).toList();
    } catch (e) {
      print("FirestoreService: Erro ao carregar histórico de leitura: $e");
      return [];
    }
  }

  /// Atualiza o último local lido no documento principal do usuário.
  Future<void> updateLastReadLocation(
      String userId, String bookAbbrev, int chapter) async {
    try {
      await _db.collection('users').doc(userId).set({
        'lastReadBookAbbrev': bookAbbrev,
        'lastReadChapter': chapter,
        'lastReadTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("FirestoreService: Erro ao atualizar última leitura: $e");
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

  // --- Helpers ---

  /// Extrai o número do capítulo do nome do capítulo (se existir).
  int? extractChapterIndex(String? chapterName) {
    if (chapterName == null) return null;
    final match = RegExp(r'^\d+').firstMatch(chapterName);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }
}
