import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:resumo_dos_deuses_flutter/pages/chat_page/message_model.dart';
import 'package:resumo_dos_deuses_flutter/pages/chat_page/openai_chat_service.dart';
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _chatCollection =
      FirebaseFirestore.instance.collection("chats");

  void _sendMessage() async {
  final user = _auth.currentUser;
  if (user == null || _messageController.text.trim().isEmpty) return;

  String messageText = _messageController.text.trim();
  _messageController.clear();

  // 🔹 Criar um ID único para a conversa do usuário
  String chatId = user.uid;

  // 🔹 Referência para a coleção de mensagens do usuário no Firestore
  DocumentReference userChatRef =
      _chatCollection.doc(chatId).collection("messages").doc();

  // 🔹 Salva a mensagem do usuário no Firestore
  await userChatRef.set({
    "senderId": user.uid,
    "senderName": user.displayName ?? "Usuário",
    "text": messageText,
    "timestamp": Timestamp.now(),
    "isUser": true,
  });

  // 🔹 Obtém a resposta da OpenAI
  String botResponse = await OpenAIService.sendMessageToGPT(messageText);

  // 🔹 Salva a resposta do bot no Firestore
  await _chatCollection
      .doc(chatId)
      .collection("messages")
      .add({
        "senderId": "AI",
        "senderName": "Assistente",
        "text": botResponse,
        "timestamp": Timestamp.now(),
        "isUser": false,
      });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat"),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatCollection
                  .doc(_auth.currentUser?.uid) // 🔹 Obtém apenas as mensagens do usuário atual
                  .collection("messages")
                  .orderBy("timestamp", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<ChatMessage> messages = snapshot.data!.docs
                    .map((doc) => ChatMessage.fromFirestore(doc))
                    .toList();

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(messages[index]);
                  },
                );
              },
            ),

          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    bool isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.greenAccent : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp.toDate()),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Digite sua mensagem...",
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.greenAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
