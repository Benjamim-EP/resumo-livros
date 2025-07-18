// lib/pages/community/forum_home_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  /// Converte o valor da categoria (ex: 'apologetica') para o seu rótulo de exibição (ex: 'Apologética').
  String _getCategoryLabel(String categoryValue) {
    const categories = {
      'apologetica': 'Apologética',
      'teologia_sistematica': 'Teologia',
      'vida_crista': 'Vida Cristã',
      'duvidas_gerais': 'Dúvidas Gerais',
    };
    return categories[categoryValue] ?? 'Geral';
  }

  @override
  Widget build(BuildContext context) {
    final Query query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
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

          final posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>;
              final theme = Theme.of(context);

              // Coleta de dados do post
              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? DateFormat('dd/MM/yy').format(timestamp.toDate())
                  : '';
              final bibleReference = data['bibleReference'] as String?;
              final isProtected = data['isPasswordProtected'] ?? false;
              final authorPhotoUrl = data['authorPhotoUrl'] as String?;
              final authorName = data['authorName'] ?? 'Anônimo';
              final title = data['title'] ?? 'Pergunta sem título';
              final content = data['content'] as String?;
              final category =
                  _getCategoryLabel(data['category'] ?? 'duvidas_gerais');
              final answerCount = (data['answerCount'] ?? 0).toString();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _handlePostTap(context, post.id, isProtected),
                  child: Container(
                    decoration: BoxDecoration(
                      // O RadialGradient cria um efeito de luz a partir de um ponto
                      gradient: RadialGradient(
                        // O centro do gradiente fica no canto superior esquerdo
                        center: Alignment(-1.0, -1.0),
                        // O raio de 1.5 faz a luz se espalhar suavemente por todo o card
                        radius: 2,
                        colors: [
                          // A cor primária com opacidade MUITO baixa para um brilho sutil
                          theme.colorScheme.primary.withOpacity(0.1),
                          // A cor normal do card
                          theme.cardColor,
                        ],
                        // O stop em 0.0 garante que o brilho comece exatamente no canto
                        stops: const [0.0, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 1. TAGS / REFERÊNCIA ---
                        Row(
                          children: [
                            if (bibleReference != null &&
                                bibleReference.isNotEmpty)
                              _buildTagChip(theme, bibleReference,
                                  isReference: true),
                            if (bibleReference != null &&
                                bibleReference.isNotEmpty)
                              const SizedBox(width: 8),
                            _buildTagChip(theme, category),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // --- 2. TÍTULO DA PERGUNTA ---
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // --- 3. INFORMAÇÕES DO AUTOR ---
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: (authorPhotoUrl != null &&
                                      authorPhotoUrl.isNotEmpty)
                                  ? NetworkImage(authorPhotoUrl)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$authorName • $date',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // --- 4. SNIPPET DO CONTEÚDO ---
                        if (content != null && content.isNotEmpty)
                          Text(
                            content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (content != null && content.isNotEmpty)
                          const SizedBox(height: 16),

                        // --- 5. RODAPÉ ---
                        Row(
                          children: [
                            Icon(Icons.comment_outlined,
                                size: 16,
                                color: theme.textTheme.bodySmall?.color),
                            const SizedBox(width: 6),
                            Text(answerCount,
                                style: theme.textTheme.bodyMedium),
                            const Spacer(),
                            if (isProtected)
                              Icon(Icons.lock_outline,
                                  size: 18,
                                  color: theme.textTheme.bodySmall?.color),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (100 * index).ms)
                  .slideY(begin: 0.2, curve: Curves.easeOut);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/createPost');
        },
        tooltip: "Fazer uma pergunta",
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }

  /// Widget auxiliar para criar as "tags" do topo do card.
  Widget _buildTagChip(ThemeData theme, String label,
      {bool isReference = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isReference
            ? theme.colorScheme.primaryContainer.withOpacity(0.6)
            : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isReference
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
