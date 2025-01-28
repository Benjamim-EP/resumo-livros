// redux/middleware.dart
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/components/bookFrame/book_details.dart';
import 'package:resumo_dos_deuses_flutter/services/author_service.dart';
import 'actions.dart';
import 'store.dart';
import '../services/tag_service.dart';
import '../services/book_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void tagMiddleware(
    Store<AppState> store, dynamic action, NextDispatcher next) async {
  next(action);

  // if (action is UserLoggedInAction) {
  //   // final tagService = TagService();
  //   // try {
  //   //   final randomTags = await tagService.fetchRandomTags(6);
  //   //   if (randomTags.isNotEmpty) {
  //   //     store.dispatch(TagsLoadedAction(randomTags));
  //   //   } else {
  //   //     print("Nenhuma tag encontrada com livros associados.");
  //   //   }
  //   // } catch (e) {
  //   //   print("Erro ao carregar tags: $e");
  //   // }
  // }
}

void userRoutesMiddleware(
    Store<AppState> store, dynamic action, NextDispatcher next) async {
  next(action);

  if (action is LoadUserRoutesAction) {
    final userId = store.state.userState.userId;
    if (userId == null) {
      store.dispatch(UserRoutesLoadFailedAction('Usuário não autenticado.'));
      return;
    }

    try {
      final routesSnapshot = await FirebaseFirestore.instance
          .collection('usersRoutes')
          .doc(userId)
          .collection('routes')
          .orderBy('createdAt', descending: true)
          .get();

      final routes = routesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'topics': data['topics'],
          'createdAt': data['createdAt'],
        };
      }).toList();

      store.dispatch(UserRoutesLoadedAction(routes));
    } catch (e) {
      store.dispatch(UserRoutesLoadFailedAction('Erro ao carregar rotas: $e'));
    }
  }
}

void bookMiddleware(
    Store<AppState> store, dynamic action, NextDispatcher next) async {
  next(action);

  if (action is TagsLoadedAction) {
    final bookService = BookService();
    try {
      for (final tag in action.tags) {
        final books = await bookService.fetchBooksByTag(tag);
        if (books.isNotEmpty) {
          store.dispatch(BooksLoadedByTagAction(tag, books));
        } else {
          print("Nenhum livro encontrado para a tag: $tag");
        }
      }
    } catch (e) {
      print("Erro ao carregar livros: $e");
    }
    // } else if (action is LoadAuthorDetailsAction) {
    //   print('Middleware: Carregando detalhes do autor ${action.authorId}');
    //   final authorService = AuthorService();
    //   try {
    //     final authorDetails =
    //         await authorService.fetchAuthorDetails(action.authorId);
    //     if (authorDetails != null) {
    //       print('Middleware: Detalhes encontrados: $authorDetails');
    //       store.dispatch(
    //           AuthorDetailsLoadedAction(action.authorId, authorDetails));
    //     } else {
    //       print(
    //           'Middleware: Nenhum detalhe encontrado para o autor ${action.authorId}');
    //     }
    //   } catch (e) {
    //     print('Middleware: Erro ao carregar detalhes do autor: $e');
    //   }
  } else if (action is LoadBookDetailsAction) {
    final bookService = BookService();
    try {
      final bookDetails = await bookService.fetchBookDetails(action.bookId);
      if (bookDetails != null) {
        store.dispatch(BookDetailsLoadedAction(action.bookId, bookDetails));
        print('Livro carregado: ${action.bookId} - ${bookDetails['titulo']}');
      } else {
        print('Livro não encontrado para ID: ${action.bookId}');
      }
    } catch (e) {
      print("Erro ao carregar detalhes do livro ${action.bookId}: $e");
    }
  } else if (action is StartBookProgressAction) {
    final userId = store.state.userState.userId;
    if (userId != null) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final userSnapshot = await userDoc.get();
        final booksProgress =
            userSnapshot.data()?['booksProgress'] as Map<String, dynamic>? ??
                {};

        // Verifica se o livro já está registrado no progresso
        if (!booksProgress.containsKey(action.bookId)) {
          // Busca os detalhes do livro no Firestore
          final bookDoc = await FirebaseFirestore.instance
              .collection('books')
              .doc(action.bookId)
              .get();

          if (bookDoc.exists) {
            final bookData = bookDoc.data();

            // Adiciona os detalhes do livro ao progresso
            booksProgress[action.bookId] = {
              'progress': 0, // Progresso inicial
              'readTopics': [], // Lista inicial de tópicos lidos
              'title': bookData?['titulo'] ?? 'Título desconhecido',
              'cover': bookData?['cover'] ?? '',
              'author': bookData?['autorId'] ?? 'Autor desconhecido',
              'totalTopicos': bookData?['totalTopicos'] ?? 0,
            };

            // Atualiza o documento do usuário no Firestore
            await userDoc.update({'booksProgress': booksProgress});
          } else {
            print('Livro não encontrado no Firestore: ${action.bookId}');
          }
        }
      } catch (e) {
        print('Erro ao iniciar progresso do livro: $e');
      }
    }
  } else if (action is MarkTopicAsReadAction) {
    final userId = store.state.userState.userId;
    if (userId != null) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final userSnapshot = await userDoc.get();
        final booksProgress =
            userSnapshot.data()?['booksProgress'] as Map<String, dynamic>? ??
                {};
        final userTopicsCount = userSnapshot.data()?['Tópicos'] as int? ?? 0;

        if (booksProgress.containsKey(action.bookId)) {
          final bookData = booksProgress[action.bookId];
          final readTopics = List<String>.from(bookData['readTopics'] ?? []);
          final chaptersIniciados =
              List<String>.from(bookData['chaptersIniciados'] ?? []);

          if (!readTopics.contains(action.topicId)) {
            readTopics.add(action.topicId);

            // Calcula o progresso com base nos tópicos lidos
            final totalTopicos = store.state.booksState
                    .bookDetails?[action.bookId]?['totalTopicos'] ??
                1;
            final progress = ((readTopics.length / totalTopicos) * 100).toInt();
            bookData['progress'] = progress;
            bookData['readTopics'] = readTopics;

            // Adiciona o chapterId ao chaptersIniciados
            if (!chaptersIniciados.contains(action.chapterId)) {
              chaptersIniciados.add(action.chapterId);
              bookData['chaptersIniciados'] = chaptersIniciados;
            }

            booksProgress[action.bookId] = bookData;

            // Atualiza o progresso no Firebase
            await userDoc.update({'booksProgress': booksProgress});

            // Incrementa o contador de tópicos lidos globalmente
            await userDoc.update({'Tópicos': userTopicsCount + 1});
          }
        }
      } catch (e) {
        print('Erro ao atualizar progresso do tópico: $e');
      }
    }
  }
}

void authorMiddleware(
    Store<AppState> store, dynamic action, NextDispatcher next) async {
  next(action);

  if (action is LoadAuthorsAction) {
    final authorService = AuthorService();

    try {
      final authors = await authorService.fetchAllAuthors();
      if (authors.isNotEmpty) {
        store.dispatch(AuthorsLoadedAction(authors));
      }
    } catch (e) {
      print('Erro ao carregar autores: $e');
    }
  } else if (action is LoadAuthorDetailsAction) {
    // final currentAuthorId = store.state.authorState.authorDetails?['nome'];
    // if (currentAuthorId == action.authorId) {
    //   //print('Autor já carregado: ${action.authorId}');
    //   return; // Não carrega novamente o mesmo autor
    // }
    //print("anasds");
    //print(store.state.authorState.authorDetails);

    //print('Middleware: Carregando detalhes do autor ${action.authorId}');
    final authorService = AuthorService();
    final bookService = BookService();
    try {
      final authorDetails =
          await authorService.fetchAuthorDetails(action.authorId);
      if (authorDetails != null) {
        //print('Middleware: Detalhes encontrados: $authorDetails');

        // Buscar os livros do autor
        final List<String> bookIds =
            List<String>.from(authorDetails['livros'] ?? []);
        final List<Map<String, dynamic>> books = [];

        for (final bookId in bookIds) {
          final bookDetails = await bookService.fetchBookDetails(bookId);
          if (bookDetails != null) {
            books.add(bookDetails);
          }
        }

        // Atualiza o estado com os detalhes do autor e livros
        store.dispatch(
            AuthorDetailsLoadedAction(action.authorId, authorDetails));
        store.dispatch(AuthorBooksLoadedAction(action.authorId, books));
      } else {
        print(
            'Middleware: Nenhum detalhe encontrado para o autor ${action.authorId}');
      }
    } catch (e) {
      print('Middleware: Erro ao carregar detalhes do autor: $e');
    }
  }
}

void userMiddleware(
    Store<AppState> store, dynamic action, NextDispatcher next) async {
  next(action);

  if (action is LoadUserStatsAction) {
    try {
      final userId = store.state.userState.userId;

      if (userId != null) {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final docSnapshot = await userDoc.get();

        if (docSnapshot.exists) {
          final stats = docSnapshot.data() ?? {};
          store.dispatch(UserStatsLoadedAction(stats));
        } else {
          print('Usuário não encontrado no Firestore.');
        }
      } else {
        print('UID do usuário está ausente no estado.');
      }
    } catch (e) {
      print('Erro ao carregar dados do usuário: $e');
    }
  } else if (action is LoadUserDetailsAction) {
    try {
      final userId = store.state.userState.userId;

      if (userId != null) {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final snapshot = await userDoc.get();

        if (snapshot.exists) {
          final data = snapshot.data() ?? {};
          store.dispatch(UserDetailsLoadedAction(data));
        }
      }
    } catch (e) {
      print('Erro ao carregar os detalhes do usuário: $e');
    }
  } else if (action is SaveTopicToCollectionAction) {
    final userId = store.state.userState.userId;
    if (userId != null) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);

        // Obtém as coleções do usuário
        final userSnapshot = await userDoc.get();
        final currentCollections =
            userSnapshot.data()?['topicSaves'] as Map<String, dynamic>? ?? {};

        // Obtém a coleção atual ou cria uma nova lista se não existir
        final updatedCollection = List<String>.from(
          currentCollections[action.collectionName] ?? [],
        );

        // Verifica se o tópico já está na coleção
        if (!updatedCollection.contains(action.topicId)) {
          updatedCollection.add(action.topicId);
          currentCollections[action.collectionName] = updatedCollection;

          // Atualiza o Firestore
          await userDoc.update({'topicSaves': currentCollections});

          // Atualiza o estado do Redux
          store.dispatch(UserTopicCollectionsLoadedAction(
            Map<String, List<String>>.from(currentCollections),
          ));

          print('Tópico salvo na coleção "${action.collectionName}".');
        } else {
          print('Tópico já está salvo na coleção "${action.collectionName}".');
        }
      } catch (e) {
        print('Erro ao salvar tópico: $e');
      }
    }
  } else if (action is LoadUserPremiumStatusAction) {
    try {
      final userId = store.state.userState.userId;

      if (userId != null) {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final docSnapshot = await userDoc.get();

        if (docSnapshot.exists) {
          final userData = docSnapshot.data() ?? {};
          final premiumStatus = userData['isPremium'] ?? {};

          // Dispara uma ação para salvar o status premium no estado global
          store.dispatch(UserPremiumStatusLoadedAction(premiumStatus));
        } else {
          print('Usuário não encontrado no Firestore.');
        }
      } else {
        print('UID do usuário está ausente no estado.');
      }
    } catch (e) {
      print('Erro ao carregar status premium do usuário: $e');
    }
  } else if (action is LoadUserTopicCollectionsAction) {
    final userId = store.state.userState.userId;
    if (userId != null) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final userSnapshot = await userDoc.get();
        final topicSaves = Map<String, List<String>>.from(
            userSnapshot.data()?['topicSaves'] ?? {});
        store.dispatch(UserTopicCollectionsLoadedAction(topicSaves));
        print('Coleções de tópicos carregadas.');
      } catch (e) {
        print('Erro ao carregar coleções de tópicos: $e');
      }
    }
  } else if (action is LoadUserCollectionsAction) {
    try {
      final userId = store.state.userState.userId;

      if (userId != null) {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final docSnapshot = await userDoc.get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data() ?? {};
          final topicSaves = (data['topicSaves'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(
                  key,
                  List<String>.from(value as List<dynamic>),
                ),
              ) ??
              {};
          store.dispatch(UserCollectionsLoadedAction(topicSaves));
        } else {
          print('Usuário não encontrado no Firestore.');
        }
      } else {
        print('UID do usuário está ausente no estado.');
      }
    } catch (e) {
      print('Erro ao carregar coleções do usuário: $e');
    }
  } else if (action is LoadBooksInProgressAction) {
    try {
      final userId = store.state.userState.userId;

      if (userId != null) {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        final snapshot = await userDoc.get();

        if (snapshot.exists) {
          final booksProgress =
              snapshot.data()?['booksProgress'] as Map<String, dynamic>? ?? {};
          final books = <Map<String, dynamic>>[];
          for (final bookId in booksProgress.keys) {
            final bookProgress = booksProgress[bookId];
            books.add({
              'id': bookId,
              'progress': bookProgress['progress'],
              'chaptersIniciados': bookProgress['chaptersIniciados'] ?? [],
            });
          }
          //print(books);

          store.dispatch(BooksInProgressLoadedAction(books));
        }
      }
    } catch (e) {
      print('Erro ao carregar progresso dos livros: $e');
    }
  } else if (action is UpdateUserFieldAction) {
    final userId = store.state.userState.userId;
    if (userId != null) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);
        await userDoc.update({action.field: action.value});

        // Atualiza o Redux após salvar no Firestore
        final updatedDetails =
            Map<String, dynamic>.from(store.state.userState.userDetails ?? {});
        updatedDetails[action.field] = action.value;

        store.dispatch(UserStatsLoadedAction(updatedDetails));
        print('Campo "${action.field}" atualizado com sucesso.');
      } catch (e) {
        print('Erro ao atualizar o campo "${action.field}": $e');
      }
    }
  } else if (action is SaveUserFeaturesAction) {
    final userId = store.state.userState.userId;

    if (userId != null) {
      try {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);

        // Salva no Firestore
        await userDoc.update({'userFeatures': action.features});

        // Atualiza no Redux
        store.dispatch(UserFeaturesLoadedAction(action.features));

        //print('Features do usuário salvas com sucesso.');
      } catch (e) {
        print('Erro ao salvar features do usuário: $e');
      }
    } else {
      print('UID do usuário ausente. Não é possível salvar features.');
    }
  } else if (action is CheckFirstLoginAction) {
    try {
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(action.userId);
      final docSnapshot = await userDoc.get();

      if (docSnapshot.exists) {
        final isFirstLogin = docSnapshot.data()?['firstLogin'] ?? false;
        store.dispatch(FirstLoginSuccessAction(isFirstLogin));
      } else {
        // Cria o documento do usuário se não existir
        await userDoc.set({'firstLogin': true});
        store.dispatch(FirstLoginSuccessAction(true));
      }
    } catch (e) {
      store.dispatch(FirstLoginFailureAction('Erro ao verificar login: $e'));
    }
  } else if (action is FetchTribeTopicsAction) {
    try {
      const String openAIKey =
          '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';
      const String pineconeKey =
          'pcsk_2iFivL_GQ9YfF88mkGJmbfjt3oXngVSxLnXpQcjpcEX6FwzBDWceiaAGRNqkz6fwSQB8YU';
      const String pineconeUrl =
          'https://septima-resumo-livros-hqija7a.svc.aped-4627-b74a.pinecone.io/query';

      Map<String, List<Map<String, dynamic>>> topicsByFeature = {};
      final updatedIndicacoes = <String, List<String>>{};

      final userId = store.state.userState.userId;
      if (userId == null) {
        print("Usuário não autenticado. Não é possível atualizar indicacoes.");
        return;
      }

      for (var feature in action.features.entries) {
        final key = feature.key;
        final value = feature.value;

        //print("Gerando embedding para feature: $key -> $value");
        final embedding = await _generateEmbedding(value, openAIKey);
        //print("Embedding gerado para $key: $embedding");

        final results = await _pineconeQuery(
          {'query': embedding},
          pineconeUrl,
          pineconeKey,
        );
        //print("Resultados do Pinecone para $key: $results");

        final topicIds = (results.first['matches'] as List<dynamic>)
            .map((match) => match['id'])
            .cast<String>()
            .toList();

        //print("IDs dos tópicos encontrados para $key: $topicIds");

        List<Map<String, dynamic>> topics = [];
        for (String topicId in topicIds) {
          try {
            final topicDoc = await FirebaseFirestore.instance
                .collection('topics')
                .doc(topicId)
                .get();

            if (topicDoc.exists) {
              topics.add({
                'id': topicDoc.id,
                'cover': topicDoc.data()?['cover'] ?? '',
                'bookName': topicDoc.data()?['bookName'] ?? '',
                'chapterName': topicDoc.data()?['chapterName'] ?? '',
                'conteudo': topicDoc.data()?['conteudo'] ?? '',
              });
            } else {
              print("Tópico não encontrado no Firestore: $topicId");
            }
          } catch (e) {
            print("Erro ao carregar tópico $topicId: $e");
          }
        }

        // Armazena os tópicos encontrados para a feature atual
        topicsByFeature[key] = topics;

        // Atualiza o campo indicacoes com os IDs dos tópicos
        updatedIndicacoes[key] = topicIds;
      }

      // Atualiza o campo indicacoes no Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'indicacoes': updatedIndicacoes});

      //print("Indicacoes atualizadas no Firestore: $updatedIndicacoes");

      // Despacha os resultados agrupados por feature
      store.dispatch(FetchTribeTopicsSuccessAction(topicsByFeature));
    } catch (e) {
      print("Erro no FetchTribeTopicsAction: $e");
      store.dispatch(
          FetchTribeTopicsFailureAction('Erro ao buscar tópicos: $e'));
    }
  } else if (action is LoadTopicsByFeatureAction) {
    try {
      final userId = store.state.userState.userId;

      const String openAIKey =
          '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';
      const String pineconeKey =
          'pcsk_2iFivL_GQ9YfF88mkGJmbfjt3oXngVSxLnXpQcjpcEX6FwzBDWceiaAGRNqkz6fwSQB8YU';
      const String pineconeUrl =
          'https://septima-resumo-livros-hqija7a.svc.aped-4627-b74a.pinecone.io/query';

      if (userId == null) {
        print(
            'Usuário não autenticado. Não é possível carregar topicsByFeature.');
        return;
      }
      // Busca os dados do usuário no Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      // Verifica se há "indicacoes" no Firestore
      final indicacoes = userDoc.data()?['indicacoes'] as Map<String, dynamic>?;
      if (indicacoes != null &&
          indicacoes.values.any((list) => list.isNotEmpty)) {
        print("Carregando tópicos de 'indicacoes' do Firestore...");

        Map<String, List<Map<String, dynamic>>> topicsByFeature = {};

        for (var key in indicacoes.keys) {
          final topicIds = indicacoes[key] as List<dynamic>? ?? [];

          List<Map<String, dynamic>> topics = [];
          for (String topicId in topicIds) {
            // Busca os detalhes do tópico no Firestore
            final topicDoc = await FirebaseFirestore.instance
                .collection('topics')
                .doc(topicId)
                .get();

            if (topicDoc.exists) {
              topics.add({
                'id': topicDoc.id,
                'cover': topicDoc.data()?['cover'] ?? '',
                'bookName': topicDoc.data()?['bookName'] ?? '',
                'chapterName': topicDoc.data()?['chapterName'] ?? '',
                'conteudo': topicDoc.data()?['conteudo'] ?? '',
                'autor': topicDoc.data()?['authorName'] ?? '',
                'bookId': topicDoc.data()?['bookId'] ?? '',
                'titulo': topicDoc.data()?['titulo'] ?? '',
              });
            } else {
              print("Tópico não encontrado no Firestore: $topicId");
            }
          }

          topicsByFeature[key] = topics;
        }

        // Despacha os tópicos carregados para o Redux
        store.dispatch(TopicsByFeatureLoadedAction(topicsByFeature));
        print("Busca de tópicos com userfeatures finalizada");
        return; // Encerrar aqui se os tópicos foram encontrados em "indicacoes"
      }

      print(
          'Nenhuma indicação encontrada no Firestore. Carregando por features...');

      // Nenhuma indicação encontrada. Executa a lógica de busca normal.
      final userFeatures =
          userDoc.data()?['userFeatures'] as Map<String, dynamic>?;

      if (userFeatures == null) {
        print('Nenhuma feature encontrada para o usuário.');
        return;
      }

      Map<String, List<Map<String, dynamic>>> topicsByFeature = {};

      for (var feature in userFeatures.entries) {
        final key = feature.key;
        final value = feature.value;

        // Gera o embedding para a feature
        final embedding = await _generateEmbedding(value, openAIKey);

        // Realiza a consulta no Pinecone
        final results = await _pineconeQuery(
          {'query': embedding},
          pineconeUrl,
          pineconeKey,
        );

        // Extrai os IDs dos tópicos correspondentes
        final topicIds = (results.first['matches'] as List<dynamic>)
            .map((match) => match['id'])
            .cast<String>()
            .toList();

        List<Map<String, dynamic>> topics = [];
        for (String topicId in topicIds) {
          try {
            // Busca os detalhes do tópico no Firestore
            final topicDoc = await FirebaseFirestore.instance
                .collection('topics')
                .doc(topicId)
                .get();

            if (topicDoc.exists) {
              topics.add({
                'id': topicDoc.id,
                'cover': topicDoc.data()?['cover'] ?? '',
                'bookName': topicDoc.data()?['bookName'] ?? '',
                'chapterName': topicDoc.data()?['chapterName'] ?? '',
                'conteudo': topicDoc.data()?['conteudo'] ?? '',
                'autor': topicDoc.data()?['authorName'] ?? '',
                'bookId': topicDoc.data()?['bookId'] ?? '',
                'titulo': topicDoc.data()?['titulo'] ?? '',
              });
            } else {
              print("Tópico não encontrado no Firestore: $topicId");
            }
          } catch (e) {
            print("Erro ao carregar tópico $topicId: $e");
          }
        }

        topicsByFeature[key] = topics;

        // Atualiza o campo "indicacoes" no Firestore
        final updatedIndicacoes = indicacoes ?? {};
        updatedIndicacoes[key] = topicIds;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'indicacoes': updatedIndicacoes});

        print('Indicacoes atualizadas no Firestore: $updatedIndicacoes');
      }
      // Despacha os tópicos carregados para o Redux
      store.dispatch(TopicsByFeatureLoadedAction(topicsByFeature));

      // excluir daqui para baixo
      // if (indicacoes != null &&
      //     indicacoes.values.any((list) => list.isNotEmpty)) {
      //   print("Carregando tópicos de 'indicacoes' do Firestore...");

      //   Map<String, List<Map<String, dynamic>>> topicsByFeature = {};

      //   for (var key in indicacoes.keys) {
      //     final topicIds = indicacoes[key] as List<dynamic>? ?? [];

      //     List<Map<String, dynamic>> topics = [];
      //     for (String topicId in topicIds) {
      //       // Busca os detalhes do tópico no Firestore
      //       final topicDoc = await FirebaseFirestore.instance
      //           .collection('topics')
      //           .doc(topicId)
      //           .get();

      //       if (topicDoc.exists) {
      //         topics.add({
      //           'id': topicDoc.id,
      //           'cover': topicDoc.data()?['cover'] ?? '',
      //           'bookName': topicDoc.data()?['bookName'] ?? '',
      //           'chapterName': topicDoc.data()?['chapterName'] ?? '',
      //           'conteudo': topicDoc.data()?['conteudo'] ?? '',
      //           'autor': topicDoc.data()?['authorName'] ?? '',
      //           'bookId': topicDoc.data()?['bookId'] ?? '',
      //         });
      //       } else {
      //         print("Tópico não encontrado no Firestore: $topicId");
      //       }
      //     }

      //     topicsByFeature[key] = topics;
      //   }
      //   // Despacha os tópicos carregados para o Redux
      //   store.dispatch(TopicsByFeatureLoadedAction(topicsByFeature));
      //   print("Busca de tópicos com userfeatures finalizada");
      //   return; // Encerrar aqui se os tópicos foram encontrados em "indicacoes"
      // }
    } catch (e) {
      print('Erro ao carregar topicsByFeature: $e');
    }
  } else if (action is LoadTopicsContentUserSavesAction) {
    try {
      final topicSaves = store.state.userState.topicSaves;
      final Map<String, List<Map<String, dynamic>>> topicsByCollection = {};

      // Itera sobre cada coleção de tópicos salvos
      for (var entry in topicSaves.entries) {
        final collectionName = entry.key;
        final topicIds = entry.value;

        final List<Map<String, dynamic>> topics = [];
        for (var topicId in topicIds) {
          try {
            final topicDoc = await FirebaseFirestore.instance
                .collection('topics')
                .doc(topicId)
                .get();

            if (topicDoc.exists) {
              topics.add({
                'id': topicDoc.id,
                'cover': topicDoc.data()?['cover'] ?? '',
                'bookName': topicDoc.data()?['bookName'] ?? '',
                'chapterName': topicDoc.data()?['chapterName'] ?? '',
                'conteudo': topicDoc.data()?['conteudo'] ?? '',
                'titulo': topicDoc.data()?['titulo'] ?? '',
              });
            } else {
              print('Tópico não encontrado no Firestore: $topicId');
            }
          } catch (e) {
            print('Erro ao carregar tópico $topicId: $e');
          }
        }

        topicsByCollection[collectionName] = topics;
      }

      store.dispatch(
          LoadTopicsContentUserSavesSuccessAction(topicsByCollection));
    } catch (e) {
      store.dispatch(LoadTopicsContentUserSavesFailureAction(
          'Erro ao carregar tópicos salvos: $e'));
    }
  } else if (action is LoadBooksDetailsAction) {
    try {
      final booksInProgress = store.state.userState.booksInProgress;

      if (booksInProgress.isEmpty) {
        throw Exception('Nenhum livro em progresso encontrado.');
      }

      final List<Map<String, dynamic>> booksDetails = [];
      for (final book in booksInProgress) {
        final bookId = book['id'];

        final bookDoc = await FirebaseFirestore.instance
            .collection('books')
            .doc(bookId)
            .get();
        //print("books debug");
        //print(bookDoc);
        if (bookDoc.exists) {
          final bookData = bookDoc.data();
          booksDetails.add({
            'id': bookId,
            'title': bookData?['titulo'] ?? 'Título desconhecido',
            'author': bookData?['autorId'] ?? 'Autor desconhecido',
            'cover': bookData?['cover'],
            'progress': book['progress'],
            'chaptersIniciados': book['chaptersIniciados'],
          });
        }
      }

      store.dispatch(LoadBooksDetailsSuccessAction(booksDetails));
    } catch (e) {
      store.dispatch(
        LoadBooksDetailsFailureAction(
            'Erro ao carregar detalhes dos livros: $e'),
      );
    }
  } else if (action is DeleteTopicCollectionAction) {
    try {
      final userId = store.state.userState.userId;

      if (userId != null) {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);

        // Remove a coleção do Firestore
        await userDoc.update({
          'topicSaves.${action.collectionName}': FieldValue.delete(),
        });

        // Atualiza o estado local
        final updatedCollections = Map<String, List<String>>.from(
          store.state.userState.topicSaves,
        );
        updatedCollections.remove(action.collectionName);

        store.dispatch(UserTopicCollectionsLoadedAction(updatedCollections));
      }
    } catch (e) {
      print('Erro ao excluir coleção de tópicos: $e');
    }
  } else if (action is DeleteSingleTopicFromCollectionAction) {
    try {
      final userId = store.state.userState.userId;

      if (userId != null) {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(userId);

        // Remove o tópico específico da coleção
        final currentCollections = store.state.userState.topicSaves;
        final updatedCollection = List<String>.from(
          currentCollections[action.collectionName] ?? [],
        );
        updatedCollection.remove(action.topicId);

        await userDoc.update({
          'topicSaves.${action.collectionName}': updatedCollection,
        });

        // Atualiza o estado local
        final updatedCollections = Map<String, List<String>>.from(
          currentCollections,
        );
        updatedCollections[action.collectionName] = updatedCollection;

        store.dispatch(UserTopicCollectionsLoadedAction(updatedCollections));
      }
    } catch (e) {
      print('Erro ao excluir tópico da coleção: $e');
    }
  }
}

// ajustar para não pegar somente 5 e adicionar em cada tópico (no firestore)
// o nome do capitulo o nome do livro e o cover
void topicMiddleware(
    Store<AppState> store, dynamic action, NextDispatcher next) async {
  next(action);

  if (action is LoadTopicContentAction) {
    try {
      final topicDoc = await FirebaseFirestore.instance
          .collection('topics')
          .doc(action.topicId)
          .get();

      if (topicDoc.exists) {
        final content = topicDoc.data()?['conteudo'] ?? '';
        final titulo = topicDoc.data()?['titulo'] ?? '';

        final topicmetadata = {
          'id': topicDoc.id,
          'cover': topicDoc.data()?['cover'] ?? '',
          'bookName': topicDoc.data()?['bookName'] ?? '',
          'chapterName': topicDoc.data()?['chapterName'] ?? '',
          'titulo': topicDoc.data()?['titulo'] ?? '',
          'bookId': topicDoc.data()?['bookId'] ?? '',
        };

        store.dispatch(
            TopicContentLoadedAction(action.topicId, content, titulo));
        //store.dispatch(
        //TopicMetadatasLoadedAction(action.topicId, topicmetadata));
      } else {
        print('Tópico ${action.topicId} não encontrado.');
      }
    } catch (e) {
      print('Erro ao carregar conteúdo do tópico: $e');
    }
  } else if (action is LoadSimilarTopicsAction) {
    try {
      //print('Middleware: Buscando tópico ${action.topicId} no Firestore');
      final topicDoc = await FirebaseFirestore.instance
          .collection('topics')
          .doc(action.topicId)
          .get();

      if (topicDoc.exists) {
        final similarTopics =
            (topicDoc.data()?['similar_topics'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

        //print('Middleware: similar_topics encontrados: $similarTopics');

        List<Map<String, dynamic>> detailedTopics = [];
        for (var topic in similarTopics.take(5)) {
          final similarTopicId = topic['similar_topic_id'];
          //print('Middleware: Processando tópico similar $similarTopicId');

          final similarTopicDoc = await FirebaseFirestore.instance
              .collection('topics')
              .doc(similarTopicId)
              .get();

          if (similarTopicDoc.exists) {
            //final bookId = similarTopicDoc.data()?['bookId'];
            //final chapterId = similarTopicDoc.data()?['capituloId'];
            //print(
            //    'Middleware: Tópico $similarTopicId pertence ao livro $bookId e capítulo $chapterId');
            detailedTopics.add({
              'similar_topic_id': similarTopicId,
              'similarity': topic['similarity'],
              'bookTitle': similarTopicDoc.data()?['bookName'],
              'chapterTitle': similarTopicDoc.data()?['chapterName'],
              'cover': similarTopicDoc.data()?['cover'],
              'titulo': similarTopicDoc.data()?['titulo'],
              'bookId': similarTopicDoc.data()?['bookId'],
            });

            // buscar livro
            // if (bookId != null && chapterId != null) {
            //   final bookDoc = await FirebaseFirestore.instance
            //       .collection('books')
            //       .doc(bookId)
            //       .get();

            //   if (bookDoc.exists) {
            //     final bookTitle = bookDoc.data()?['titulo'] ?? 'Sem título';
            //     final chapters =
            //         bookDoc.data()?['capitulos'] as List<dynamic> ?? [];
            //     final chapter = chapters.firstWhere(
            //         (chap) => chap['id'] == chapterId,
            //         orElse: () => null);

            //     final chapterTitle = chapter?['titulo'] ?? 'Sem título';

            //     //print(
            //     //  'Middleware: Livro "$bookTitle", Capítulo "$chapterTitle" carregados para tópico $similarTopicId');

            //     detailedTopics.add({
            //       'similar_topic_id': similarTopicId,
            //       'similarity': topic['similarity'],
            //       'bookTitle': bookTitle,
            //       'chapterTitle': chapterTitle,
            //     });
            //   }
            // }
          }
        }

        //print(
        //    'Middleware: Tópicos detalhados carregados: $detailedTopics para ${action.topicId}');
        store.dispatch(
            SimilarTopicsLoadedAction(action.topicId, detailedTopics));
      } else {
        print('Middleware: Tópico ${action.topicId} não encontrado.');
        store.dispatch(SimilarTopicsLoadedAction(action.topicId, []));
      }
    } catch (e) {
      print('Middleware: Erro ao carregar tópicos similares: $e');
      store.dispatch(SimilarTopicsLoadedAction(action.topicId, []));
    }
  } else if (action is LoadTopicsAction) {
    try {
      List<Map<String, dynamic>> topics = [];

      for (String topicId in action.topicIds) {
        final topicDoc = await FirebaseFirestore.instance
            .collection('topics')
            .doc(topicId)
            .get();

        if (topicDoc.exists) {
          topics.add({
            'id': topicDoc.id,
            'cover': topicDoc.data()?['cover'] ?? '',
            'bookName': topicDoc.data()?['bookName'] ?? '',
            'chapterName': topicDoc.data()?['chapterName'] ?? '',
            'conteudo': topicDoc.data()?['conteudo'] ?? '',
          });
        }
      }

      store.dispatch(TopicsLoadedAction(topics));
    } catch (e) {
      print('Erro ao carregar tópicos: $e');
    }
  }
}

// Embeddings e Vector Search
void embeddingMiddleware(
    Store<AppState> store, dynamic action, NextDispatcher next) async {
  next(action);

  const String openAIKey =
      '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';
  const String pineconeKey =
      'pcsk_2iFivL_GQ9YfF88mkGJmbfjt3oXngVSxLnXpQcjpcEX6FwzBDWceiaAGRNqkz6fwSQB8YU';
  const String pineconeUrl =
      'https://septima-resumo-livros-hqija7a.svc.aped-4627-b74a.pinecone.io/query';

  if (action is EmbedAndSearchFeaturesAction) {
    try {
      Map<String, List<double>> embeddings = {};

      // Gera embeddings para cada campo
      for (var entry in action.features.entries) {
        final embedding = await _generateEmbedding(entry.value, openAIKey);
        embeddings[entry.key] = embedding;
      }

      // Requisição ao Pinecone para cada embedding
      final searchResults =
          await _pineconeQuery(embeddings, pineconeUrl, pineconeKey);

      store.dispatch(EmbedAndSearchSuccessAction(searchResults));
    } catch (e) {
      store
          .dispatch(EmbedAndSearchFailureAction('Erro durante o processo: $e'));
    }
  } else if (action is SearchByQueryAction) {
    try {
      // Gera o embedding para a consulta
      final embedding = await _generateEmbedding(action.query, openAIKey);

      // Chama _pineconeQuery com apenas um namespace para busca simples
      final results = await _pineconeQuery({
        'query': embedding,
      }, pineconeUrl, pineconeKey);

      // print("debug Search query action");
      // print(results);

      // Extrai os IDs dos tópicos do Pinecone
      final topicIds = (results.first['matches'] as List<dynamic>)
          .map((match) => match['id'])
          .cast<String>()
          .toList();

      // Carrega os detalhes dos tópicos do Firestore
      List<Map<String, dynamic>> topics = [];
      for (String topicId in topicIds) {
        try {
          final topicDoc = await FirebaseFirestore.instance
              .collection('topics')
              .doc(topicId)
              .get();

          if (topicDoc.exists) {
            topics.add({
              'id': topicDoc.id,
              'cover': topicDoc.data()?['cover'] ?? '',
              'bookName': topicDoc.data()?['bookName'] ?? '',
              'chapterName': topicDoc.data()?['chapterName'] ?? '',
              'conteudo': topicDoc.data()?['conteudo'] ?? '',
            });
          } else {
            print('Tópico não encontrado no Firestore: $topicId');
          }
        } catch (e) {
          print('Erro ao carregar tópico $topicId: $e');
        }
      }

      // Despacha os tópicos carregados para o Redux
      store.dispatch(SearchSuccessAction(topics));
    } catch (e) {
      store.dispatch(SearchFailureAction('Erro durante a busca: $e'));
    }
  }
}

Future<List<double>> _generateEmbedding(String text, String apiKey) async {
  const String embeddingUrl = 'https://api.openai.com/v1/embeddings';
  final headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };
  final body = jsonEncode({
    'input': text,
    'model': 'text-embedding-3-large',
  });

  final response =
      await http.post(Uri.parse(embeddingUrl), headers: headers, body: body);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<double>.from(data['data'][0]['embedding']);
  } else {
    throw Exception('Erro ao gerar embeddings: ${response.body}');
  }
}

Future<List<Map<String, dynamic>>> _pineconeQuery(
  Map<String, List<double>> embeddings,
  String pineconeUrl,
  String apiKey,
) async {
  final List<Map<String, dynamic>> results = [];

  for (var entry in embeddings.entries) {
    final body = jsonEncode({
      "vector": entry.value,
      "topK": 5,
      "includeValues": false,
      "includeMetadata": true,
    });

    final headers = {
      'Api-Key': apiKey,
      'Content-Type': 'application/json',
    };

    final response =
        await http.post(Uri.parse(pineconeUrl), headers: headers, body: body);
    //print("debug pinecone");
    //print(response.body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      results.add({
        'namespace': entry.key,
        'matches': data['matches'],
      });
    } else {
      throw Exception(
          'Erro ao buscar no Pinecone (namespace: ${entry.key}): ${response.body}');
    }
  }

  return results;
}

// Função para gerar resposta com GPT
Future<Map<String, dynamic>?> getTribeAnalysis(String userText) async {
  const url = 'https://api.openai.com/v1/chat/completions';
  const projectKey =
      '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'; // Substitua pela sua chave de API

  final messages = [
    {
      'role': 'system',
      'content':
          'Você é um assistente especializado em associar características fornecidas pelo usuário às tribos descritas.'
    },
    {
      'role': 'user',
      'content': """
Baseado no texto do usuário, retorne as 3 tribos que mais se assemelham com as características fornecidas. As tribos possuem as seguintes características:

### Tribos:
1. Rúben - 
	Pontos fortes: Rúben, o primogênito, tinha o papel de liderança, mas perdeu a primazia devido a decisões impulsivas. Representa indivíduos com grande potencial, porém, muitas vezes, enfrentam dificuldades em concretizar suas capacidades. São carismáticos e têm forte senso de responsabilidade.
	Desafios: Instabilidade emocional, dificuldade em manter a consistência e lidar com falhas do passado. Podem agir com precipitação, comprometendo relações e oportunidades.
  Força: Resiliência emocional. Apesar de suas quedas, possuem um espírito de reinvenção e um coração disposto a se sacrificar pelos outros.
    
2. Simeão - 
	Características principais: Simeão é a tribo da paixão intensa e senso de justiça inato. Tem uma forte capacidade de se dedicar a causas nas quais acredita profundamente, mas tende a agir de forma extrema.
	Desafios:Tendência a ser inflexível e reativo quando confrontado com injustiças. Pode nutrir ressentimentos que dificultam o progresso emocional.
  Força:Simeão ensina sobre o poder da aliança e a capacidade de transformar paixão em algo positivo, tornando-se um pilar de força para sua comunidade.
    
3. Levi -
	Características principais: Levi simboliza compromisso espiritual e devoção. Sua tribo foi escolhida para servir como sacerdotes, mediando a relação entre Deus e o povo. Representa indivíduos disciplinados, focados e de elevados padrões morais.
	Desafios: Tendem a impor exigências rígidas tanto a si mesmos quanto aos outros, o que pode levar à alienação. Encontrar equilíbrio entre a vida espiritual e cotidiana é um desafio constante.
	Força: Seu zelo espiritual e capacidade de inspirar transformação destacam-se. Levi é capaz de unir comunidades por meio de princípios elevados.

4. Judá -
	Características principais: A tribo de Judá representa liderança e carisma. Seus membros têm um perfil visionário, sendo capazes de unir pessoas em torno de objetivos comuns.
	Desafios: Orgulho excessivo e dificuldade em delegar responsabilidades podem ser obstáculos. Também tendem a carregar fardos desnecessários.
	Força: Judá lidera com coragem, inspira em momentos de crise e está disposto a sacrificar-se pelo bem maior, sendo um líder confiável.

5. Issacar -
	Características principais: Representa sabedoria prática e trabalho árduo. Indivíduos com essas características possuem afinidade por estudos, meditação e busca de conhecimento aplicável.
	Desafios: Enfrentam dificuldades para equilibrar suas responsabilidades e cuidar de si mesmos, podendo se tornar excessivamente críticos ou teóricos.
	Força: Seu compromisso com a verdade e discernimento nas decisões são notáveis. A paciência de Issacar permite a construção de bases sólidas em qualquer área.

6. Zebulom -
	Características principais: Atribuído ao comércio, generosidade e à conexão entre o material e o espiritual, Zebulom reflete indivíduos visionários e práticos.
	Desafios: Podem ser vistos como superficiais ou excessivamente focados em resultados materiais. Lutam constantemente para equilibrar trabalho e espiritualidade.
	Força: Generosidade e visão são suas marcas. Zebulom facilita conexões e compartilha recursos com outros, sendo um financiador de sonhos.

7. Dã -
	Características principais: Dã simboliza senso de justiça, estratégia e pensamento crítico. É um juiz nato que busca corrigir desequilíbrios sociais e morais.
	Desafios: Há risco de excesso de julgamento ou envolvimento em vinganças pessoais. Sua busca por justiça pode gerar conflitos desnecessários.
	Força: Com coragem, Dã defende os desamparados e restaura a ordem onde há caos, sendo um exemplo de determinação e retidão.

8. Naftali -
	Características principais: Representa liberdade, criatividade e agilidade. São comunicadores natos, com mente aberta e capacidade de conectar ideias de forma fluida.
	Desafios: Tendem a procrastinar e a dispersar energia em múltiplos interesses, dificultando a conclusão de projetos.
	Força: Possuem soluções criativas e comunicação persuasiva. Naftali inspira com suas palavras e conecta pessoas com sua visão.

9. Gade -
	Características principais: Gade reflete coragem e resiliência, sendo um protetor nato e um guerreiro diante das adversidades.
	Desafios: Podem ser combativos ou inflexíveis em situações de conflito, criando tensões desnecessárias.
	Força: Perseverança e determinação são suas marcas. Gade se destaca em cenários competitivos e enfrenta desafios com tenacidade.

10. Aser -
	Características principais: Aser simboliza abundância e felicidade, trazendo otimismo, prazer nas pequenas coisas e harmonia ao seu redor.
	Desafios: Tendem ao comodismo ou indulgência excessiva, evitando confrontos necessários.
	Força: Promovem alegria e criam ambientes de paz e felicidade, sendo um farol de positividade para os outros.

11. José (Efraim e Manassés) -
	Características principais: José reflete visão de futuro, resiliência e superação de adversidades. É símbolo de sucesso alcançado por trabalho árduo e fé.
	Desafios: Podem sentir-se isolados ou desconectados devido às suas perspectivas únicas.
	Força: Persistência e capacidade de transformar desafios em oportunidades são suas marcas, inspirando outros por seu exemplo.

12. Benjamim -
	Características principais: Representa energia, criatividade e coragem. Indivíduos de Benjamim são adaptáveis e enfrentam desafios com entusiasmo e inovação.
	Desafios: Impulsividade e dificuldade em controlar emoções intensas podem ser obstáculos.
	Força: Renovação constante e superação de obstáculos destacam Benjamim como um símbolo de força interior e versatilidade.

Texto do usuário: '$userText'

Formato da resposta (JSON), a reposta só deve ser feita exclusivamente nesse formato:
{
  "tribos": {"tribo1":"Motivo da escolha e caracteristicas principais em comum com a tribo 1", "tribo2":"Motivo da escolha e caracteristicas principais em comum com a tribo 2", "tribo3":"Motivo da escolha e caracteristicas principais em comum com a tribo 3"},
}
"""
    }
  ];

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $projectKey',
    },
    body: jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': messages,
      'max_tokens': 200,
    }),
  );

  // print("debug tribos");
  // print(response.body);

  if (response.statusCode == 200) {
    try {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      String textResponse =
          responseData['choices'][0]['message']['content'].trim();

      // Remova os delimitadores de bloco de código (```json)
      if (textResponse.startsWith('```json')) {
        textResponse = textResponse.replaceAll('```json', '').trim();
      }
      if (textResponse.startsWith('```')) {
        textResponse = textResponse.replaceAll('```', '').trim();
      }

      // Certifique-se de que a resposta agora é um JSON válido
      if (textResponse.startsWith('{') && textResponse.endsWith('}')) {
        final parsedResponse = jsonDecode(textResponse);
        if (parsedResponse['tribos'] is Map<String, dynamic>) {
          return Map<String, String>.from(parsedResponse['tribos']);
        }
      }
      print('Formato inesperado após limpeza: $textResponse');
      return null;
    } catch (e) {
      print('Erro ao processar resposta: $e');
      return null;
    }
  } else {
    print('Erro na API: ${response.statusCode} - ${response.body}');
    return null;
  }
}
