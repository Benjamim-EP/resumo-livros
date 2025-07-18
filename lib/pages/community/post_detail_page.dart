// lib/pages/community/post_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/community/create_post_page.dart';
import 'package:septima_biblia/pages/community/public_profile_page.dart';
import 'package:septima_biblia/pages/community/reply_card.dart';
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

  // Estados para armazenar os dados do post e do autor
  Map<String, dynamic>? _postData;
  bool _isPostAuthor = false;
  bool _isLoadingPost = true;

  String? _replyingToId; // ID da resposta pai à qual estamos respondendo
  String? _replyingToName; // Nome do autor da resposta pai
  String? _replyingToUserId;

  @override
  void initState() {
    super.initState();
    _loadPostData(); // Carrega os dados do post apenas uma vez
  }

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

      // Verifica se é uma resposta aninhada (Nível 2) ou uma resposta principal (Nível 1)
      if (_replyingToId != null) {
        // --- CENÁRIO 2: ADICIONANDO UM COMENTÁRIO ANINHADO (NÍVEL 2) ---

        // Monta os dados para o novo documento na subcoleção "comments"
        final commentData = {
          'authorId': user.uid,
          'authorName': userData?['nome'] ?? 'Anônimo',
          'authorPhotoUrl': userData?['photoURL'] ?? '',
          'content': replyText,
          'timestamp': FieldValue.serverTimestamp(),

          'replyingToUserId':
              _replyingToUserId, // ✅ Salva o ID do usuário mencionado
          'replyingToUserName': _replyingToName,
        };

        // Referência para a resposta "pai" (Nível 1)
        final replyRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('replies')
            .doc(_replyingToId!);

        // Escreve o novo comentário na sub-subcoleção e incrementa o contador
        await replyRef.collection('comments').add(commentData);
        await replyRef.update({'commentCount': FieldValue.increment(1)});
      } else {
        // --- CENÁRIO 1: ADICIONANDO UMA RESPOSTA PRINCIPAL (NÍVEL 1) ---

        // Monta os dados para o novo documento na subcoleção "replies"
        final replyData = {
          'authorId': user.uid,
          'authorName': userData?['nome'] ?? 'Anônimo',
          'authorPhotoUrl': userData?['photoURL'] ?? '',
          'content': replyText,
          'timestamp': FieldValue.serverTimestamp(),
          'upvoteCount': 0,
          'upvotedBy': [],
          'commentCount':
              0, // Inicia o contador de comentários aninhados como 0
        };

        final postRef =
            FirebaseFirestore.instance.collection('posts').doc(widget.postId);

        // Adiciona a nova resposta e incrementa o contador de respostas no post principal
        await postRef.collection('replies').add(replyData);
        await postRef.update({'answerCount': FieldValue.increment(1)});
      }

      // Limpa o estado e a UI após o envio bem-sucedido
      _replyController.clear();
      FocusScope.of(context).unfocus(); // Esconde o teclado
      if (mounted) {
        setState(() {
          _replyingToId = null;
          _replyingToName = null;
          _isReplying = false;
        });
      }
    } catch (e) {
      print("Erro ao enviar resposta/comentário: $e");
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao enviar resposta.");
        setState(() =>
            _isReplying = false); // Garante que o loading para em caso de erro
      }
    }
    // O 'finally' não é mais necessário aqui, pois o setState é chamado no sucesso e no erro.
  }

  // Carrega os dados do post principal no início
  Future<void> _loadPostData() async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();
      if (mounted && postDoc.exists) {
        setState(() {
          _postData = postDoc.data();
          _isPostAuthor =
              FirebaseAuth.instance.currentUser?.uid == _postData?['authorId'];
          _isLoadingPost = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingPost = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPost = false);
      print("Erro ao carregar dados do post: $e");
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
      if (mounted)
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
      await replyRef.update({
        'upvotedBy': hasUpvoted
            ? FieldValue.arrayRemove([user.uid])
            : FieldValue.arrayUnion([user.uid]),
        'upvoteCount':
            hasUpvoted ? FieldValue.increment(-1) : FieldValue.increment(1),
      });
    } catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, "Erro ao registrar o voto.");
    }
  }

  // Função para marcar uma resposta como a melhor
  Future<void> markAsBestAnswer(String replyId) async {
    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    try {
      await postRef.update({'bestAnswerId': replyId});
      if (mounted)
        CustomNotificationService.showSuccess(
            context, "Resposta marcada como a melhor!");
    } catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, "Erro ao marcar a resposta.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pergunta da Comunidade")),

      // ✅ O CORPO DO SCAFFOLD AGORA É APENAS O FUTUREBUILDER
      body: _isLoadingPost
          ? const Center(child: CircularProgressIndicator())
          : _postData == null
              ? const Center(
                  child: Text(
                      "Esta pergunta não foi encontrada. Pode ter sido excluída."))
              : CustomScrollView(
                  slivers: [
                    // O cabeçalho e a lista de respostas continuam aqui
                    SliverToBoxAdapter(
                      child: _buildPostHeader(_postData!, _isPostAuthor),
                    ),
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
                        return _buildRepliesList(repliesSnapshot.data!.docs,
                            _postData!, _isPostAuthor);
                      },
                    ),
                  ],
                ),

      // ✅ O COMPOSITOR DE RESPOSTA AGORA VAI PARA O bottomNavigationBar
      // O SafeArea garante que ele não fique embaixo dos botões de sistema do Android/iOS
      bottomNavigationBar: SafeArea(
        child: _buildReplyComposer(),
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
    final authorId = data['authorId'] as String?;

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
            // A ação de clique será no ListTile inteiro
            onTap: () {
              // Navega apenas se o ID do autor existir e não for o perfil do próprio usuário logado
              if (authorId != null &&
                  authorId != FirebaseAuth.instance.currentUser?.uid) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PublicProfilePage(userId: authorId, initialUserData: {
                        'userId': authorId,
                        'nome': data['authorName'],
                        'photoURL': data['authorPhotoUrl'],
                        'descrição': data[
                            'descrição'] // Pode ser nulo, a PublicProfilePage deve lidar com isso
                      }),
                    ));
              }
            },
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
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return ReplyCard(
            replyDoc: replies[index],
            postData: postData,
            isPostAuthor: isPostAuthor,
            postId: widget.postId,
            onUpvote: upvoteReply,
            onMarkAsBest: markAsBestAnswer,
            // ✅ CORREÇÃO AQUI: Passa os 3 parâmetros para onReply
            onReply: (replyId, authorId, authorName) {
              FocusScope.of(context).requestFocus();
              setState(() {
                _replyingToId = replyId;
                _replyingToUserId = authorId;
                _replyingToName = authorName;
              });
            },
          );
        },
        childCount: replies.length,
      ),
    );
  }

  Widget _buildReplyComposer() {
    final theme = Theme.of(context);
    final isReplyingToComment = _replyingToId != null;

    return Material(
      elevation: 8,
      color: theme.scaffoldBackgroundColor,
      child: Container(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Faz a coluna encolher ao seu conteúdo
          children: [
            // Barra que indica a quem você está respondendo
            if (isReplyingToComment)
              Container(
                color: theme.colorScheme.primary.withOpacity(0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Respondendo a @${_replyingToName ?? 'Anônimo'}",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Cancelar resposta",
                      onPressed: () {
                        setState(() {
                          _replyingToId = null;
                          _replyingToName = null;
                          _replyingToUserId = null; // Limpa também o ID
                        });
                      },
                    )
                  ],
                ),
              ),

            // Campo de texto e botão de enviar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: TextField(
                        controller: _replyController,
                        autofocus:
                            isReplyingToComment, // Dá o foco automaticamente ao clicar em "Responder"
                        decoration: const InputDecoration(
                          hintText: "Adicionar uma resposta...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        maxLines: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isReplying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    onPressed: _isReplying ? null : _addReply,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
