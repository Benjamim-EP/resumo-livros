import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:resumo_dos_deuses_flutter/pages/chat_page/message_model.dart';
import 'package:resumo_dos_deuses_flutter/pages/chat_page/openai_chat_service.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';

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

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    String userMessage = _messageController.text.trim();
    _messageController.clear();

    // 🔹 Dispara a action do Redux para processar a mensagem
    StoreProvider.of<AppState>(context).dispatch(SendMessageAction(userMessage));
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
            child: Column(
              children: [
                // 🔹 Exibe a resposta da OpenAI do Redux antes das mensagens salvas
                StoreConnector<AppState, String?>(
                  converter: (store) => store.state.chatState.latestResponse, // 🔹 Agora funciona
                  builder: (context, botResponse) {
                    if (botResponse == null) return const SizedBox.shrink();
                    
                    return _buildMessageItem(ChatMessage(
                      id: "bot-${DateTime.now().millisecondsSinceEpoch}", // 🔹 Gera um ID único
                      senderId: "AI",
                      senderName: "Assistente",
                      text: botResponse,
                      timestamp: Timestamp.now(),
                      isUser: false,
                    ));
                  },
                ),

                // 🔹 Lista de mensagens do Firestore
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatCollection
                        .doc(_auth.currentUser?.uid)
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
                          final message = messages[index];
                          return _buildMessageItem(ChatMessage(
                            id: message.id, // 🔹 Agora passamos um ID válido
                            senderId: message.senderId,
                            senderName: message.senderName,
                            text: message.text,
                            timestamp: message.timestamp,
                            isUser: message.isUser,
                          ));
                        },
                      );
                    },
                  ),
                ),
              ],
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
