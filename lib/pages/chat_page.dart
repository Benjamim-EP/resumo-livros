import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat"),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: const Center(
        child: Text(
          "Área de Chat em construção...",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
