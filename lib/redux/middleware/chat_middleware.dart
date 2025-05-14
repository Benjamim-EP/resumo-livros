import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../actions.dart';
import '../store.dart';
import '../../services/openai_service.dart';
import '../../services/pinecone_service.dart';
import '../../services/firestore_service.dart'; // Supondo criação

List<Middleware<AppState>> createChatMiddleware() {
  final openAIService = OpenAIService();
  final pineconeService = PineconeService();
  final firestoreService = FirestoreService();

  return [
    TypedMiddleware<AppState, SendMessageAction>(_handleSendMessage(
            openAIService, pineconeService, firestoreService))
        .call,
  ];
}

void Function(Store<AppState>, SendMessageAction, NextDispatcher)
    _handleSendMessage(OpenAIService openAIService,
        PineconeService pineconeService, FirestoreService firestoreService) {
  return (Store<AppState> store, SendMessageAction action,
      NextDispatcher next) async {
    next(action);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      store.dispatch(SendMessageFailureAction('Usuário não autenticado.'));
      return;
    }

    String userMessage = action.userMessage;
    String chatId = user.uid;

    try {
      // 1. Salva mensagem do usuário
      await firestoreService.saveChatMessage(chatId, {
        "senderId": user.uid,
        "senderName": user.displayName ?? "Usuário",
        "text": userMessage,
        "timestamp": Timestamp.now(),
        "isUser": true,
      });

      // 2. Gera embedding e busca contexto no Pinecone
      final embedding = await openAIService.generateEmbedding(userMessage);
      final results = await pineconeService.queryPinecone(
          embedding, 10); // Ajustar topK para contexto

      // 3. Extrai contexto e metadados
      List<String> knowledgeBase = [];
      Set<String> usedBooks = {};
      Set<String> usedAuthors = {};

      for (var match in results) {
        // Assumindo que results é List<Map> diretamente
        final metadata =
            match['metadata'] as Map<String, dynamic>?; // Acessa metadata
        if (metadata != null) {
          String content = metadata['content']?.toString() ?? '';
          String book = metadata['book']?.toString() ?? 'Livro Desconhecido';
          String author =
              metadata['author']?.toString() ?? 'Autor Desconhecido';

          if (content.isNotEmpty) {
            // Adiciona apenas se houver conteúdo
            knowledgeBase.add("Livro: $book\nAutor: $author\n\n$content");
            usedBooks.add(book);
            usedAuthors.add(author);
          }
        }
      }
      print("Debug KnowledgeBase Para OpenAI:");
      print(knowledgeBase);
      print("Livros usados: $usedBooks");
      print("Autores usados: $usedAuthors");

      // 4. Monta prompt do sistema
      String systemMessage = """
      Você é um autor que responde aos questionamentos do usuário com base somente nos conhecimentos fornecidos.
      Na resposta, diga quais os livros e autores usados na base para sua resposta.

      Autores encontrados: ${usedAuthors.join(", ")}
      Livros usados: ${usedBooks.join(", ")}

      Responda com base nesses conhecimentos:\n\n${knowledgeBase.join("\n\n")}
      """;

      // 5. Obtém resposta do OpenAI
      String botResponse = await openAIService.sendMessageToGPT(
        userMessage: userMessage,
        systemContext: systemMessage,
      );

      // 6. Salva resposta da IA
      await firestoreService.saveChatMessage(chatId, {
        "senderId": "AI",
        "senderName": "Assistente",
        "text": botResponse,
        "timestamp": Timestamp.now(),
        "isUser": false,
      });

      // 7. Despacha sucesso (O estado do Redux pode não precisar guardar a resposta, já que o Firestore é a fonte)
      // store.dispatch(SendMessageSuccessAction(botResponse)); // Comentado pois a UI deve ouvir o Firestore
    } catch (e) {
      print("Erro ao processar mensagem: $e");
      store
          .dispatch(SendMessageFailureAction('Erro ao processar mensagem: $e'));
      // Opcional: Salvar mensagem de erro no chat
      await firestoreService.saveChatMessage(chatId, {
        "senderId": "System",
        "senderName": "Erro",
        "text": "Desculpe, ocorreu um erro ao processar sua mensagem.",
        "timestamp": Timestamp.now(),
        "isUser": false,
      });
    }
  };
}
