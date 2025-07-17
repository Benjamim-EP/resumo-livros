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
      };

      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      // Adiciona a resposta na subcoleção
      await postRef.collection('replies').add(replyData);

      // Incrementa o contador de respostas no documento principal do post
      await postRef.update({'answerCount': FieldValue.increment(1)});

      _replyController.clear();
      FocusScope.of(context).unfocus(); // Esconde o teclado
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

  // Função placeholder para editar um post
  void _editPost(Map<String, dynamic> currentData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostPage(
          // Passa o ID e os dados do post a ser editado
          postId: widget.postId,
          initialData: currentData,
        ),
      ),
    );
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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text(
                    "Esta pergunta não foi encontrada. Pode ter sido excluída."));
          }

          final postData = snapshot.data!.data() as Map<String, dynamic>;
          final bool isAuthor =
              FirebaseAuth.instance.currentUser?.uid == postData['authorId'];

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildPostHeader(postData, isAuthor),
                    ),
                    _buildRepliesList(),
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
                      if (value == 'edit') {
                        _editPost(data);
                      } else if (value == 'delete') {
                        _deletePost();
                      }
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
              child: Chip(
                avatar: Icon(Icons.menu_book,
                    size: 14, color: theme.colorScheme.primary),
                label: Text(bibleReference),
              ),
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

  Widget _buildRepliesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('replies')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          )));
        }
        if (snapshot.hasError) {
          return const SliverToBoxAdapter(
              child: Center(child: Text("Erro ao carregar respostas.")));
        }
        if (snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text("Ninguém respondeu ainda. Seja o primeiro!"),
          )));
        }

        final replies = snapshot.data!.docs;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final replyData = replies[index].data() as Map<String, dynamic>;
              return Card(
                elevation: 0,
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
                          backgroundImage:
                              (replyData['authorPhotoUrl'] != null &&
                                      replyData['authorPhotoUrl']!.isNotEmpty)
                                  ? NetworkImage(replyData['authorPhotoUrl']!)
                                  : null,
                        ),
                        title: Text(replyData['authorName'] ?? 'Anônimo',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      MarkdownBody(
                        data: replyData['content'] ?? '',
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(Theme.of(context))
                                .copyWith(
                          p: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: replies.length,
          ),
        );
      },
    );
  }

  Widget _buildReplyComposer() {
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
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
