// lib/pages/community/post_detail_page.dart (Versão Final com Anonimato em TODOS os níveis)

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
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:flutter_redux/flutter_redux.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  @override
  void dispose() {
    _replyController.dispose();

    final store = StoreProvider.of<AppState>(context, listen: false);
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;

    if (!isPremium) {
      interstitialManager.tryShowInterstitial(
          fromScreen: "PostDetailPage_Dispose");
    }

    super.dispose();
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
                        return _buildRepliesList(repliesSnapshot.data!.docs,
                            _postData!, _isPostAuthor);
                      },
                    ),
                  ],
                ),
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
    final bool isAnonymous = data['isAnonymous'] ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                                  'photoURL': data['authorPhotoUrl'],
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
          Text("Respostas", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
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
