// lib/pages/community/forum_home_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/community/post_detail_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class ForumHomePage extends StatefulWidget {
  const ForumHomePage({super.key});

  @override
  State<ForumHomePage> createState() => _ForumHomePageState();
}

class _ForumHomePageState extends State<ForumHomePage> {
  // No futuro, você pode adicionar um estado para o filtro de categoria aqui.
  // String? _selectedCategoryFilter;

  @override
  Widget build(BuildContext context) {
    // Constrói a query do Firestore.
    // No futuro, você poderá adicionar '.where('category', isEqualTo: _selectedCategoryFilter)'
    // se o filtro estiver ativo.
    Query query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          // --- Estados da Stream ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar as perguntas."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "Nenhuma pergunta foi feita ainda.\nSeja o primeiro a iniciar uma discussão!",
                textAlign: TextAlign.center,
              ),
            ));
          }
          // --- Fim dos Estados da Stream ---

          final posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>;

              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? DateFormat('dd/MM/yy').format(timestamp.toDate())
                  : '';

              final bibleReference = data['bibleReference'] as String?;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(data['title'] ?? 'Pergunta sem título'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Por ${data['authorName'] ?? 'Anônimo'} • $date"),
                        // Mostra a referência bíblica se ela existir
                        if (bibleReference != null && bibleReference.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Chip(
                              avatar: Icon(Icons.menu_book,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary),
                              label: Text(bibleReference),
                              labelStyle: const TextStyle(fontSize: 11),
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text((data['answerCount'] ?? 0).toString(),
                          style: Theme.of(context).textTheme.titleMedium),
                      const Text("Resp.", style: TextStyle(fontSize: 10)),
                    ],
                  ),
                  onTap: () {
                    // Navega para a página de detalhes do post
                    Navigator.push(
                        context,
                        FadeScalePageRoute(
                          page: PostDetailPage(postId: post.id),
                        ));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navega para a tela de criação de post usando a rota nomeada
          Navigator.pushNamed(context, '/createPost');
        },
        tooltip: "Fazer uma pergunta",
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}
