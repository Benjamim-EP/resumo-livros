import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page/bible_reference_highlighter.dart';
class DiaryList extends StatelessWidget {
  final List<Map<String, dynamic>> userDiaries;

  const DiaryList({super.key, required this.userDiaries});

  @override
  Widget build(BuildContext context) {
    return userDiaries.isEmpty
        ? const Center(
            child: Text(
              "Nenhum diário encontrado.",
              style: TextStyle(color: Colors.white70),
            ),
          )
        : ListView.builder(
            itemCount: userDiaries.length,
            itemBuilder: (context, index) {
              final diary = userDiaries[index];

              return FutureBuilder<RichText>(
                future: BibleReferenceHighlighter.highlightBibleReferences(diary['conteudo']),
                builder: (context, snapshot) {
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
                      subtitle: snapshot.data ?? Text(diary['conteudo'], style: const TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.book, color: Colors.white70),
                      onTap: () {
                        _showDiaryContent(context, diary['titulo'], diary['conteudo']);
                      },
                    ),
                  );
                },
              );
            },
          );
  }

  void _showDiaryContent(BuildContext context, String title, String content) async {
    final highlightedContent = await BibleReferenceHighlighter.highlightBibleReferences(content);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(child: highlightedContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text("Fechar"),
            ),
          ],
        );
      },
    );
  }
}
