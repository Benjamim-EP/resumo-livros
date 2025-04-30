import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- User Methods ---
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getUserPremiumStatus(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['isPremium'] as Map<String, dynamic>?;
  }

  Future<Map<String, List<String>>?> getUserCollections(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data != null && data['topicSaves'] is Map) {
      // Converte corretamente para o tipo esperado
      return (data['topicSaves'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      );
    }
    return {};
  }

  Future<void> saveTopicToCollection(
      String userId, String collectionName, String topicId) async {
    final userDoc = _db.collection('users').doc(userId);
    // Usa FieldValue.arrayUnion para adicionar sem duplicar
    await userDoc.update({
      'topicSaves.$collectionName': FieldValue.arrayUnion([topicId])
    });
  }

  Future<void> saveVerseToCollection(
      String userId, String collectionName, String verseId) async {
    final userDoc = _db.collection('users').doc(userId);
    await userDoc.update({
      'topicSaves.$collectionName': FieldValue.arrayUnion([verseId])
    });
  }

  Future<Map<String, dynamic>?> getBooksProgressRaw(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['booksProgress'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getBookProgress(
      String userId, String bookId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final progressMap = doc.data()?['booksProgress'] as Map<String, dynamic>?;
    return progressMap?[bookId] as Map<String, dynamic>?;
  }

  Future<void> updateUserField(
      String userId, String field, dynamic value) async {
    await _db.collection('users').doc(userId).update({field: value});
  }

  Future<void> updateUserFeatures(
      String userId, Map<String, dynamic> features) async {
    await _db
        .collection('users')
        .doc(userId)
        .update({'userFeatures': features});
  }

  Future<bool> checkAndSetFirstLogin(String userId) async {
    final userDoc = _db.collection('users').doc(userId);
    final docSnapshot = await userDoc.get();
    if (docSnapshot.exists) {
      final isFirst = docSnapshot.data()?['firstLogin'] ?? false;
      return isFirst;
    } else {
      await userDoc.set({'firstLogin': true}); // Cria se não existir
      return true;
    }
  }

  Future<Map<String, List<String>>?> getUserIndicacoes(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data != null && data['indicacoes'] is Map) {
      return (data['indicacoes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserFeatures(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data()?['userFeatures'] as Map<String, dynamic>?;
  }

  Future<void> updateUserIndicacoes(
      String userId, Map<String, List<String>> indicacoes) async {
    await _db
        .collection('users')
        .doc(userId)
        .update({'indicacoes': indicacoes});
  }

  Future<void> deleteTopicCollection(
      String userId, String collectionName) async {
    await _db.collection('users').doc(userId).update({
      'topicSaves.$collectionName': FieldValue.delete(),
    });
  }

  Future<void> deleteSingleTopicFromCollection(
      String userId, String collectionName, String topicId) async {
    await _db.collection('users').doc(userId).update({
      'topicSaves.$collectionName': FieldValue.arrayRemove([topicId]),
    });
  }

  Future<String> addDiaryEntry(
      String userId, String title, String content) async {
    final newDiaryRef = await _db.collection('posts').add({
      "titulo": title,
      "conteudo": content,
      "data": Timestamp.now(),
      "userId": userId, // Adiciona referência ao usuário se necessário
    });

    // Adiciona o ID à coleção de posts do usuário
    await _db.collection('users_posts').doc(userId).set({
      // Use set com merge para criar se não existir
      "ids": FieldValue.arrayUnion([
        {"id": newDiaryRef.id}
      ])
    }, SetOptions(merge: true));

    return newDiaryRef.id;
  }

  Future<List<Map<String, dynamic>>> loadUserDiaries(String userId) async {
    final userPostsDoc = await _db.collection('users_posts').doc(userId).get();
    final diaryIdsAndRefs =
        (userPostsDoc.data()?['ids'] as List<dynamic>?) ?? [];

    List<Map<String, dynamic>> diaries = [];
    final postFutures = <Future<DocumentSnapshot>>[];

    // Cria uma lista de Futures para buscar todos os posts
    for (var diaryInfo in diaryIdsAndRefs) {
      if (diaryInfo is Map && diaryInfo.containsKey('id')) {
        final postId = diaryInfo['id'];
        postFutures.add(_db.collection('posts').doc(postId).get());
      }
    }

    // Aguarda todas as buscas terminarem
    final postSnapshots = await Future.wait(postFutures);

    // Processa os resultados
    for (var postDoc in postSnapshots) {
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>;
        final timestamp = data['data'] as Timestamp?;
        diaries.add({
          'id': postDoc.id,
          'titulo': data['titulo'] ?? 'Sem Título',
          'conteudo': data['conteudo'] ?? '',
          'data': timestamp != null
              ? DateFormat('dd MMM yyyy').format(timestamp.toDate())
              : '',
        });
      }
    }
    // Ordena por data (mais recente primeiro) se necessário
    diaries.sort((a, b) {
      DateTime? dateA =
          a['data'] != null ? DateFormat('dd MMM yyyy').parse(a['data']) : null;
      DateTime? dateB =
          b['data'] != null ? DateFormat('dd MMM yyyy').parse(b['data']) : null;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // Coloca nulos no final
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // Mais recente primeiro
    });

    return diaries;
  }

  // --- Book Methods ---
  Future<List<Map<String, dynamic>>> fetchWeeklyRecommendations() async {
    final querySnapshot = await _db.collection('books').get();
    List<Map<String, dynamic>> books = querySnapshot.docs.map((doc) {
      final data = doc.data();
      final nota = data['nota'] as Map<String, dynamic>? ?? {};
      final score = (nota['score'] as num?) ?? 0;
      final votes = (nota['votes'] as num?) ?? 0;
      return {
        'id': doc.id,
        'cover': data['cover'] ?? '',
        'bookName': data['titulo'] ?? 'Título desconhecido',
        'autor': data['autorId'] ?? 'Autor desconhecido',
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
  }

  Future<void> startBookProgressIfNeeded(String userId, String bookId) async {
    final userDocRef = _db.collection('users').doc(userId);
    final bookDocRef = _db.collection('books').doc(bookId);

    // Usa uma transação para garantir a atomicidade
    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDocRef);
      final booksProgress =
          userSnapshot.data()?['booksProgress'] as Map<String, dynamic>? ?? {};

      // Verifica se o livro já existe no progresso
      if (!booksProgress.containsKey(bookId)) {
        final bookSnapshot = await transaction.get(bookDocRef);
        if (bookSnapshot.exists) {
          final bookData = bookSnapshot.data();
          booksProgress[bookId] = {
            'progress': 0,
            'readTopics': [],
            'chaptersIniciados': [], // Inicializa vazio
            'title': bookData?['titulo'] ?? 'Título desconhecido',
            'cover': bookData?['cover'] ?? '',
            'author': bookData?['autorId'] ?? 'Autor desconhecido',
            'totalTopicos':
                bookData?['totalTopicos'] ?? 1, // Garante que existe
          };
          transaction.update(userDocRef, {'booksProgress': booksProgress});
        } else {
          print('Livro não encontrado no Firestore: $bookId');
          // Poderia lançar um erro aqui se preferir
        }
      }
    });
  }

  Future<bool> markTopicAsRead(String userId, String bookId, String topicId,
      String chapterId, int totalTopicos) async {
    final userDocRef = _db.collection('users').doc(userId);
    bool updated = false;

    await _db.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userDocRef);
      final booksProgress =
          userSnapshot.data()?['booksProgress'] as Map<String, dynamic>? ?? {};
      final userTopicsCount = userSnapshot.data()?['Tópicos'] as int? ?? 0;

      if (booksProgress.containsKey(bookId)) {
        final bookData = Map<String, dynamic>.from(
            booksProgress[bookId]); // Cria cópia mutável
        final readTopics = List<String>.from(bookData['readTopics'] ?? []);
        final chaptersIniciados =
            List<String>.from(bookData['chaptersIniciados'] ?? []);

        if (!readTopics.contains(topicId)) {
          readTopics.add(topicId);

          // Calcula progresso
          final progress = totalTopicos > 0
              ? ((readTopics.length / totalTopicos) * 100).toInt().clamp(0, 100)
              : 0;

          bookData['progress'] = progress;
          bookData['readTopics'] = readTopics;

          // Adiciona chapterId se não existir
          if (!chaptersIniciados.contains(chapterId)) {
            chaptersIniciados.add(chapterId);
            bookData['chaptersIniciados'] = chaptersIniciados;
          }

          booksProgress[bookId] = bookData; // Atualiza o mapa principal

          // Atualiza o documento do usuário
          transaction.update(userDocRef, {
            'booksProgress': booksProgress,
            'Tópicos': FieldValue.increment(1) // Incrementa contador global
          });
          updated = true; // Marca que houve atualização
        }
      } else {
        print(
            "Progresso para o livro $bookId não encontrado para marcar tópico.");
      }
    });
    return updated; // Retorna se houve atualização
  }

  Future<Map<String, dynamic>?> getBookData(String bookId) async {
    final doc = await _db.collection('books').doc(bookId).get();
    return doc.data();
  }

  Future<List<Map<String, String>>> fetchBooksByTag(String tag) async {
    final tagSnapshot = await _db
        .collection('tags')
        .where('tag_name', isEqualTo: tag)
        .limit(1)
        .get();
    if (tagSnapshot.docs.isEmpty) return [];

    final tagDoc = tagSnapshot.docs.first;
    final bookIds = List<String>.from(tagDoc.data()['livros'] ?? []);
    final List<Map<String, String>> books = [];

    // Busca os detalhes de cada livro
    // Para otimizar, poderia usar `whereIn` se a lista de IDs não for muito grande
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
  }

  // --- Topic Methods ---
  Future<Map<String, dynamic>?> getTopicData(String topicId) async {
    final doc = await _db.collection('topics').doc(topicId).get();
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> fetchTopicsByIds(
      List<String> topicIds) async {
    if (topicIds.isEmpty) return [];

    List<Map<String, dynamic>> topics = [];
    // O Firestore 'whereIn' tem um limite (geralmente 10 ou 30).
    // Se a lista for grande, divida em chunks.
    const chunkSize = 10;
    for (var i = 0; i < topicIds.length; i += chunkSize) {
      final chunk = topicIds.sublist(
          i, i + chunkSize > topicIds.length ? topicIds.length : i + chunkSize);
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
          'autor': data['authorName'] ?? '', // Inclui autor
          'bookId': data['bookId'] ?? '', // Inclui bookId
          'titulo': data['titulo'] ?? '', // Inclui titulo do tópico
        });
      }
    }
    return topics;
  }

  Future<List<Map<String, dynamic>>> getSimilarTopics(String topicId) async {
    final doc = await _db.collection('topics').doc(topicId).get();
    final data = doc.data();
    if (data != null && data['similar_topics'] is List) {
      // Converte a lista dinâmica para o tipo correto
      return List<Map<String, dynamic>>.from((data['similar_topics'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map)));
    }
    return [];
  }

  // --- Tag Methods ---
  // ... métodos para tags ...

  // --- Route Methods ---
  Future<List<Map<String, dynamic>>> getUserRoutes(String userId) async {
    final snapshot = await _db
        .collection('usersRoutes')
        .doc(userId)
        .collection('routes')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'],
        'topics': data[
            'topics'], // Assumindo que 'topics' é uma lista de IDs ou objetos
        'createdAt': data['createdAt'],
      };
    }).toList();
  }

  // --- Chat Methods ---
  Future<void> saveChatMessage(
      String chatId, Map<String, dynamic> messageData) async {
    await _db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .add(messageData);
  }

  // --- Helpers ---
  int? extractChapterIndex(String? chapterName) {
    if (chapterName == null) return null;
    final match = RegExp(r'^\d+').firstMatch(chapterName);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  // Método para obter nome completo do livro a partir da abreviação (usado em saved topics)
  Future<String?> getBookNameFromAbbrev(String abbrev) async {
    // Esta implementação é ineficiente se chamada muitas vezes.
    // O ideal seria carregar o abbrev_map.json uma vez e usá-lo.
    try {
      final querySnapshot = await _db
          .collection('books')
          .where('abbrev', isEqualTo: abbrev)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['titulo'] as String?;
      }
    } catch (e) {
      print("Erro ao buscar nome do livro pela abreviação $abbrev: $e");
    }
    return null; // Retorna nulo se não encontrar
  }
}
