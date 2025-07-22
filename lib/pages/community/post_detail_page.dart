// lib/pages/community/post_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/pages/community/create_post_page.dart';
import 'package:septima_biblia/pages/community/public_profile_page.dart';
import 'package:septima_biblia/pages/community/reply_card.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

/// Define os tipos de ordenação disponíveis para as respostas.
enum ReplySortOrder {
  mostRelevant, // Mais relevantes (por upvotes, com desempate por data)
  newest, // Mais recentes (por data)
  oldest, // Mais antigos (por data)
}

class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _replyController = TextEditingController();
  bool _isReplying = false;

  Map<String, dynamic>? _postData;
  bool _isPostAuthor = false;
  bool _isLoadingPost = true;

  String? _replyingToId;
  String? _replyingToName;
  String? _replyingToUserId;

  ReplySortOrder _currentSortOrder = ReplySortOrder.mostRelevant;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  // ... (todas as suas funções de lógica como _addReply, _loadPostData, etc. permanecem aqui sem alterações)
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
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('submitReplyOrComment');
      final Map<String, dynamic> payload = {
        'postId': widget.postId,
        'content': replyText,
      };
      if (_replyingToId != null) {
        payload['parentReplyId'] = _replyingToId;
        payload['replyingToUserId'] = _replyingToUserId;
        payload['replyingToUserName'] = _replyingToName;
      }
      await callable.call(payload);
      _replyController.clear();
      FocusScope.of(context).unfocus();
      if (mounted) {
        setState(() {
          _replyingToId = null;
          _replyingToName = null;
          _replyingToUserId = null;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, e.message ?? "Erro ao enviar resposta.");
    } catch (e) {
      print("Erro ao chamar submitReplyOrComment: $e");
      if (mounted)
        CustomNotificationService.showError(
            context, "Ocorreu um erro inesperado.");
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

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

  Future<void> _deletePost() async {
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
    if (confirm != true) return;
    showDialog(
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('deletePost');
      await callable.call({'postId': widget.postId});
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context).pop();
        Future.microtask(() {
          if (navigatorKey.currentContext != null) {
            CustomNotificationService.showSuccess(
                navigatorKey.currentContext!, "Pergunta excluída com sucesso.");
          }
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        CustomNotificationService.showError(
            context, e.message ?? "Erro ao excluir a pergunta.");
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        CustomNotificationService.showError(
            context, "Ocorreu um erro inesperado.");
      }
    }
  }

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
      body: _isLoadingPost
          ? const Center(child: CircularProgressIndicator())
          : _postData == null
              ? const Center(
                  child:
                      Text("Esta pergunta não foi encontrada ou foi removida."))
              : CustomScrollView(
                  slivers: [
                    // O cabeçalho do post foi modificado para incluir a barra de filtro
                    SliverToBoxAdapter(
                      child:
                          _buildPostHeaderWithFilter(_postData!, _isPostAuthor),
                    ),
                    // O StreamBuilder agora apenas constrói a lista, sem a barra de filtro
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
                                      child: CircularProgressIndicator())));
                        }
                        if (repliesSnapshot.data!.docs.isEmpty) {
                          return const SliverToBoxAdapter(
                              child: Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Text(
                                          "Ninguém respondeu ainda. Seja o primeiro!"))));
                        }

                        final replies = List<QueryDocumentSnapshot>.from(
                            repliesSnapshot.data!.docs);

                        replies.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;
                          switch (_currentSortOrder) {
                            case ReplySortOrder.newest:
                              final tsA = dataA['timestamp'] as Timestamp? ??
                                  Timestamp(0, 0);
                              final tsB = dataB['timestamp'] as Timestamp? ??
                                  Timestamp(0, 0);
                              return tsB.compareTo(tsA);
                            case ReplySortOrder.oldest:
                              final tsA = dataA['timestamp'] as Timestamp? ??
                                  Timestamp(0, 0);
                              final tsB = dataB['timestamp'] as Timestamp? ??
                                  Timestamp(0, 0);
                              return tsA.compareTo(tsB);
                            case ReplySortOrder.mostRelevant:
                            default:
                              final upvotesA =
                                  dataA['upvoteCount'] as int? ?? 0;
                              final upvotesB =
                                  dataB['upvoteCount'] as int? ?? 0;
                              final upvoteCompare =
                                  upvotesB.compareTo(upvotesA);
                              if (upvoteCompare != 0) return upvoteCompare;
                              final tsA = dataA['timestamp'] as Timestamp? ??
                                  Timestamp(0, 0);
                              final tsB = dataB['timestamp'] as Timestamp? ??
                                  Timestamp(0, 0);
                              return tsB.compareTo(tsA);
                          }
                        });

                        return _buildRepliesList(
                            replies, _postData!, _isPostAuthor);
                      },
                    ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: _buildReplyComposer(),
      ),
    );
  }

  // ===================================
  // <<< WIDGET DO HEADER ATUALIZADO >>>
  // ===================================
  Widget _buildPostHeaderWithFilter(Map<String, dynamic> data, bool isAuthor) {
    final theme = Theme.of(context);
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd/MM/yy \'às\' HH:mm').format(timestamp.toDate())
        : '';
    final bibleReference = data['bibleReference'] as String?;
    final authorId = data['authorId'] as String?;
    final bool isAnonymous = data['isAnonymous'] ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informações do Autor (sem mudança)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundImage: (!isAnonymous &&
                      data['authorPhotoUrl'] != null &&
                      data['authorPhotoUrl']!.isNotEmpty)
                  ? NetworkImage(data['authorPhotoUrl']!)
                  : null,
              child: (isAnonymous ||
                      data['authorPhotoUrl'] == null ||
                      data['authorPhotoUrl']!.isEmpty)
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
            title: Text(data['authorName'] ?? 'Anônimo'),
            subtitle: Text("Postado em $date"),
            onTap: () {
              if (!isAnonymous &&
                  authorId != null &&
                  authorId != FirebaseAuth.instance.currentUser?.uid) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PublicProfilePage(
                                userId: authorId,
                                initialUserData: {
                                  'userId': authorId,
                                  'nome': data['authorName'],
                                  'photoURL': data['authorPhotoUrl']
                                })));
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
                      const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Editar'))),
                      const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Excluir'))),
                    ],
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // Título da Pergunta e Referência (sem mudança)
          Text(data['title'] ?? '',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          if (bibleReference != null && bibleReference.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Chip(
                  label: Text(bibleReference),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withOpacity(0.5)),
            ),
          if (data['content'] != null && data['content'].isNotEmpty) ...[
            const SizedBox(height: 16),
            MarkdownBody(
                data: data['content'],
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyLarge?.copyWith(height: 1.6))),
          ],
          const Divider(height: 32),

          // --- BARRA DE RESPOSTAS COM FILTRO ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("Respostas", style: Theme.of(context).textTheme.titleLarge),
              _buildSortPopupMenu(), // <<< O novo botão de filtro
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ===================================
  // <<< NOVO WIDGET: BOTÃO DE FILTRO POPUP >>>
  // ===================================
  Widget _buildSortPopupMenu() {
    // Helper para obter o texto do Enum
    String _getSortOrderText(ReplySortOrder order) {
      switch (order) {
        case ReplySortOrder.newest:
          return "Mais Recentes";
        case ReplySortOrder.oldest:
          return "Mais Antigos";
        case ReplySortOrder.mostRelevant:
        default:
          return "Mais Relevantes";
      }
    }

    return PopupMenuButton<ReplySortOrder>(
      initialValue: _currentSortOrder,
      onSelected: (ReplySortOrder newOrder) {
        setState(() {
          _currentSortOrder = newOrder;
        });
      },
      // O botão que o usuário vê
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 16),
            const SizedBox(width: 6),
            Text(
              _getSortOrderText(_currentSortOrder),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      // A lista de opções que aparece
      itemBuilder: (BuildContext context) => <PopupMenuEntry<ReplySortOrder>>[
        const PopupMenuItem<ReplySortOrder>(
          value: ReplySortOrder.mostRelevant,
          child: Text('Mais Relevantes'),
        ),
        const PopupMenuItem<ReplySortOrder>(
          value: ReplySortOrder.newest,
          child: Text('Mais Recentes'),
        ),
        const PopupMenuItem<ReplySortOrder>(
          value: ReplySortOrder.oldest,
          child: Text('Mais Antigos'),
        ),
      ],
    );
  }

  // A antiga barra de filtro foi removida
  // Widget _buildSortFilterBar() { ... } // <<<< REMOVER ESTA FUNÇÃO

  // ... (os métodos _buildRepliesList e _buildReplyComposer permanecem os mesmos)
  Widget _buildRepliesList(List<QueryDocumentSnapshot> replies,
      Map<String, dynamic> postData, bool isPostAuthor) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return ReplyCard(
            key: ValueKey(replies[index].id),
            replyDoc: replies[index],
            postData: postData,
            isPostAuthor: isPostAuthor,
            postId: widget.postId,
            onUpvote: upvoteReply,
            onMarkAsBest: markAsBestAnswer,
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
                Border(top: BorderSide(color: theme.dividerColor, width: 0.5))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                          overflow: TextOverflow.ellipsis),
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
                          _replyingToUserId = null;
                        });
                      },
                    )
                  ],
                ),
              ),
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
                          borderRadius: BorderRadius.circular(24.0)),
                      child: TextField(
                        controller: _replyController,
                        autofocus: isReplyingToComment,
                        decoration: const InputDecoration(
                            hintText: "Adicionar uma resposta...",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10)),
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
