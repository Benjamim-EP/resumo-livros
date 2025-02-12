import 'package:flutter/material.dart';

class DiaryList extends StatelessWidget {
  final List<Map<String, dynamic>> userDiaries;

  const DiaryList({super.key, required this.userDiaries});

  @override
  Widget build(BuildContext context) {
    if (userDiaries.isEmpty) {
      return const Center(
        child: Text(
          "Nenhum diário encontrado.",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: userDiaries.length,
      itemBuilder: (context, index) {
        final diary = userDiaries[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 4.0,
          color: const Color(0xFF313333),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              diary['titulo'],
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            subtitle: Text(
              diary['data'] ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            trailing: const Icon(Icons.book, color: Colors.white70),
            onTap: () {
              _showDiaryContent(context, diary['titulo'], diary['conteudo']);
            },
          ),
        );
      },
    );
  }

  void _showDiaryContent(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Text(content, style: const TextStyle(color: Colors.white70)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Fechar", style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }
}
