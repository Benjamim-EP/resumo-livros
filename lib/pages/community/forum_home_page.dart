// lib/pages/community/forum_home_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/community/post_detail_page.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/custom_page_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForumHomePage extends StatefulWidget {
  const ForumHomePage({super.key});

  @override
  State<ForumHomePage> createState() => _ForumHomePageState();
}

class _ForumHomePageState extends State<ForumHomePage> {
  // Chave para salvar os IDs dos posts desbloqueados no armazenamento local
  static const String _unlockedPostsKey = 'unlocked_forum_posts';

  /// Função principal que gerencia o toque em um post.
  /// Decide se deve navegar diretamente ou iniciar o fluxo de desbloqueio.
  Future<void> _handlePostTap(
      BuildContext context, String postId, bool isProtected) async {
    if (!isProtected) {
      // Se o post for público, navega diretamente
      Navigator.push(
          context, FadeScalePageRoute(page: PostDetailPage(postId: postId)));
      return;
    }

    // Se for protegido, verifica se já foi desbloqueado localmente
    final prefs = await SharedPreferences.getInstance();
    final List<String> unlockedPosts =
        prefs.getStringList(_unlockedPostsKey) ?? [];

    if (unlockedPosts.contains(postId)) {
      // Se o ID já está na lista, navega diretamente
      print("Post $postId já desbloqueado localmente. Navegando...");
      Navigator.push(
          context, FadeScalePageRoute(page: PostDetailPage(postId: postId)));
    } else {
      // Se não foi desbloqueado, pede a senha
      final String? enteredPassword = await _showPasswordDialog(context);

      if (enteredPassword != null && enteredPassword.isNotEmpty) {
        // Se o usuário inseriu uma senha, verifica no backend
        await _verifyPassword(context, postId, enteredPassword);
      }
    }
  }

  /// Exibe um AlertDialog para o usuário inserir a senha.
  /// Retorna a senha digitada ou null se o usuário cancelar.
  Future<String?> _showPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Post Protegido por Senha"),
        content: TextField(
          controller: passwordController,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Senha",
            icon: Icon(Icons.lock_outline),
          ),
          onSubmitted: (_) {
            // Permite submeter com o Enter do teclado
            Navigator.pop(dialogContext, passwordController.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, passwordController.text);
            },
            child: const Text("Entrar"),
          ),
        ],
      ),
    );
  }

  /// Chama a Cloud Function para verificar a senha e lida com o resultado.
  Future<void> _verifyPassword(
      BuildContext context, String postId, String password) async {
    // Mostra um indicador de loading para o usuário
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('verifyPostPassword');
      final result = await callable.call<Map<String, dynamic>>({
        'postId': postId,
        'password': password,
      });

      if (!context.mounted) return;
      Navigator.pop(context); // Fecha o loading

      if (result.data['success'] == true) {
        // Se a senha estiver correta, salva o ID localmente para não pedir de novo
        final prefs = await SharedPreferences.getInstance();
        final List<String> unlockedPosts =
            prefs.getStringList(_unlockedPostsKey) ?? [];
        if (!unlockedPosts.contains(postId)) {
          unlockedPosts.add(postId);
          await prefs.setStringList(_unlockedPostsKey, unlockedPosts);
          print("Post $postId salvo como desbloqueado localmente.");
        }

        // E navega para a página de detalhes
        Navigator.push(
            context, FadeScalePageRoute(page: PostDetailPage(postId: postId)));
      } else {
        // Se a senha estiver incorreta
        CustomNotificationService.showError(
            context, "Senha incorreta. Tente novamente.");
      }
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Fecha o loading
      CustomNotificationService.showError(
          context, e.message ?? "Ocorreu um erro ao verificar a senha.");
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      CustomNotificationService.showError(
          context, "Um erro inesperado ocorreu.");
    }
  }

  @override
  Widget build(BuildContext context) {
    // A query busca todos os posts, ordenados pelos mais recentes.
    final Query query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          // --- Tratamento de Estados da Stream ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Erro no Stream do Fórum: ${snapshot.error}");
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
              ),
            );
          }
          // --- Fim do Tratamento de Estados ---

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
              final isProtected = data['isPasswordProtected'] ?? false;

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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone de cadeado para posts protegidos
                      if (isProtected)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.lock_outline,
                              size: 20,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      // Contador de respostas
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text((data['answerCount'] ?? 0).toString(),
                              style: Theme.of(context).textTheme.titleMedium),
                          const Text("Resp.", style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  onTap: () => _handlePostTap(context, post.id, isProtected),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navega para a tela de criação de post
          Navigator.pushNamed(context, '/createPost');
        },
        tooltip: "Fazer uma pergunta",
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}
