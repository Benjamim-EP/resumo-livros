// lib/pages/community/post_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/community/create_post_page.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _replyController = TextEditingController();
  bool _isReplying = false;

  // Função para adicionar uma nova resposta
  Future<void> _addReply() async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted)
        CustomNotificationService.showError(
            context, "Você precisa estar logado para responder.");
      return;
    }

    setState(() => _isReplying = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();

      final replyData = {
        'authorId': user.uid,
        'authorName': userData?['nome'] ?? 'Anônimo',
        'authorPhotoUrl': userData?['photoURL'] ?? '',
        'content': replyText,
        'timestamp': FieldValue.serverTimestamp(),
        'upvoteCount': 0,
        'upvotedBy': [], // Inicia o campo para evitar erros
      };

      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      await postRef.collection('replies').add(replyData);
      await postRef.update({'answerCount': FieldValue.increment(1)});

      _replyController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao enviar resposta.");
      }
    } finally {
      if (mounted) {
        setState(() => _isReplying = false);
      }
    }
  }

  // Função para deletar um post
  Future<void> _deletePost() async {
    // A exibição do diálogo de confirmação permanece a mesma
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: const Text(
            "Tem certeza que deseja excluir esta pergunta? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancelar")),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text("Excluir",
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    // Se o usuário não confirmou, não fazemos nada.
    if (confirm != true) return;

    // Mostra um indicador de loading para o usuário saber que algo está acontecendo
    if (mounted) {
      CustomNotificationService.showSuccess(context, "Excluindo pergunta...");
    }

    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      // Deleta as respostas (esta lógica pode ser movida para um gatilho de Cloud Function no futuro para mais robustez)
      final replies = await postRef.collection('replies').get();
      if (replies.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in replies.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Deleta o post principal
      await postRef.delete();

      // ✅ CORREÇÃO PRINCIPAL APLICADA AQUI
      // Se chegamos até aqui, a exclusão foi um sucesso.
      // Agora, usamos um pequeno atraso ANTES de fechar a página.

      // Opcional: Mostra uma notificação de sucesso final, se desejar.
      // if (mounted) {
      //   CustomNotificationService.showSuccess(context, "Pergunta excluída.");
      // }

      await Future.delayed(
          const Duration(milliseconds: 100)); // Pequeno respiro

      if (mounted) {
        // Agora, com o Navigator "desbloqueado", podemos fechar a página com segurança.
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao excluir a pergunta.");
      }
    }
  }

  // Função para navegar para a tela de edição
  void _editPost(Map<String, dynamic> currentData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostPage(
          postId: widget.postId,
          initialData: currentData,
        ),
      ),
    );
  }

  // Função para dar ou remover upvote em uma resposta
  Future<void> upvoteReply(String replyId, List<String> currentUpvoters) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      CustomNotificationService.showError(
          context, "Você precisa estar logado para votar.");
      return;
    }

    final replyRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('replies')
        .doc(replyId);

    final bool hasUpvoted = currentUpvoters.contains(user.uid);

    try {
      if (hasUpvoted) {
        await replyRef.update({
          'upvotedBy': FieldValue.arrayRemove([user.uid]),
          'upvoteCount': FieldValue.increment(-1),
        });
      } else {
        await replyRef.update({
          'upvotedBy': FieldValue.arrayUnion([user.uid]),
          'upvoteCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao registrar o voto.");
      }
    }
  }

  // Função para marcar uma resposta como a melhor
  Future<void> markAsBestAnswer(String replyId) async {
    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);

    try {
      await postRef.update({'bestAnswerId': replyId});
      if (mounted) {
        CustomNotificationService.showSuccess(
            context, "Resposta marcada como a melhor!");
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao marcar a resposta.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pergunta da Comunidade")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .get(),
        builder: (context, postSnapshot) {
          if (postSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
            return const Center(
                child: Text(
                    "Esta pergunta não foi encontrada. Pode ter sido excluída."));
          }

          final postData = postSnapshot.data!.data() as Map<String, dynamic>;
          final bool isPostAuthor =
              FirebaseAuth.instance.currentUser?.uid == postData['authorId'];

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildPostHeader(postData, isPostAuthor),
                    ),
                    // O StreamBuilder para as respostas é aninhado aqui
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.postId)
                          .collection('replies')
                          .orderBy('timestamp')
                          .snapshots(),
                      builder: (context, repliesSnapshot) {
                        if (!repliesSnapshot.hasData) {
                          return const SliverToBoxAdapter(
                              child: Center(
                                  child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          )));
                        }
                        if (repliesSnapshot.data!.docs.isEmpty) {
                          return const SliverToBoxAdapter(
                              child: Center(
                                  child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                                "Ninguém respondeu ainda. Seja o primeiro!"),
                          )));
                        }
                        return _buildRepliesList(
                            repliesSnapshot.data!.docs, postData, isPostAuthor);
                      },
                    ),
                  ],
                ),
              ),
              _buildReplyComposer(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPostHeader(Map<String, dynamic> data, bool isAuthor) {
    final theme = Theme.of(context);
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd/MM/yy \'às\' HH:mm').format(timestamp.toDate())
        : '';
    final bibleReference = data['bibleReference'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: (data['authorPhotoUrl'] != null &&
                      data['authorPhotoUrl']!.isNotEmpty)
                  ? NetworkImage(data['authorPhotoUrl']!)
                  : null,
            ),
            title: Text(data['authorName'] ?? 'Anônimo'),
            subtitle: Text("Postado em $date"),
            trailing: isAuthor
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit')
                        _editPost(data);
                      else if (value == 'delete') _deletePost();
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Excluir')),
                      ),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(data['title'] ?? '',
              style: Theme.of(context).textTheme.headlineSmall),
          if (bibleReference != null && bibleReference.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Chip(label: Text(bibleReference)),
            ),
          if (data['content'] != null && data['content'].isNotEmpty) ...[
            const Divider(height: 24),
            MarkdownBody(data: data['content']),
          ],
          const Divider(height: 32),
          Text("Respostas", style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildRepliesList(List<QueryDocumentSnapshot> replies,
      Map<String, dynamic> postData, bool isPostAuthor) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bestAnswerId = postData['bestAnswerId'] as String?;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final replyDoc = replies[index];
          final replyData = replyDoc.data() as Map<String, dynamic>;
          final isBestAnswer = replyDoc.id == bestAnswerId;
          final upvoters = List<String>.from(replyData['upvotedBy'] ?? []);
          final userHasUpvoted =
              currentUserId != null && upvoters.contains(currentUserId);

          return Card(
            elevation: isBestAnswer ? 4 : 0.5,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color:
                    isBestAnswer ? Colors.green.shade300 : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundImage: (replyData['authorPhotoUrl'] != null &&
                              replyData['authorPhotoUrl']!.isNotEmpty)
                          ? NetworkImage(replyData['authorPhotoUrl']!)
                          : null,
                    ),
                    title: Text(replyData['authorName'] ?? 'Anônimo',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: isBestAnswer
                        ? const Text("Melhor Resposta",
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: replyData['content'] ?? '',
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                      p: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(height: 1.5),
                    ),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => upvoteReply(replyDoc.id, upvoters),
                        icon: Icon(
                          userHasUpvoted
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 18,
                          color: userHasUpvoted
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        label: Text(
                          upvoters.length.toString(),
                          style: TextStyle(
                              color: userHasUpvoted
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey),
                        ),
                      ),
                      if (isPostAuthor && !isBestAnswer)
                        TextButton(
                          onPressed: () => markAsBestAnswer(replyDoc.id),
                          child: const Text("Melhor Resposta",
                              style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
        childCount: replies.length,
      ),
    );
  }

  Widget _buildReplyComposer() {
    return Material(
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            8.0, 8.0, 8.0, 8.0 + MediaQuery.of(context).viewInsets.bottom),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                decoration: const InputDecoration(
                  hintText: "Adicionar uma resposta...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                maxLines: null,
              ),
            ),
            IconButton(
              icon: _isReplying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              onPressed: _isReplying ? null : _addReply,
            ),
          ],
        ),
      ),
    );
  }
}
