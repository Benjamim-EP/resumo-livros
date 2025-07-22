// lib/pages/community/reply_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/community/public_profile_page.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class ReplyCard extends StatefulWidget {
  final QueryDocumentSnapshot replyDoc;
  final Map<String, dynamic> postData;
  final bool isPostAuthor;
  final String postId;
  final Function(String, List<String>) onUpvote;
  final Function(String) onMarkAsBest;
  final Function(String, String, String) onReply;

  const ReplyCard({
    super.key,
    required this.replyDoc,
    required this.postData,
    required this.isPostAuthor,
    required this.postId,
    required this.onUpvote,
    required this.onMarkAsBest,
    required this.onReply,
  });

  @override
  State<ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<ReplyCard>
    with SingleTickerProviderStateMixin {
  bool _showComments = false;
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _showDeleteConfirmationDialog(
      BuildContext context, String itemType) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("Excluir $itemType"),
        content: Text(
            "Tem certeza que deseja excluir permanentemente este $itemType? Esta ação não pode ser desfeita."),
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
    return confirmed ?? false;
  }

  Future<void> _deleteReply() async {
    if (!await _showDeleteConfirmationDialog(context, "resposta")) return;
    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final replyRef = postRef.collection('replies').doc(widget.replyDoc.id);
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(replyRef);
      batch.update(postRef, {'answerCount': FieldValue.increment(-1)});
      await batch.commit();
      if (mounted)
        CustomNotificationService.showSuccess(context, "Resposta excluída.");
    } catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, "Erro ao excluir a resposta.");
      print("Erro ao excluir resposta: $e");
    }
  }

  Future<void> _deleteComment(QueryDocumentSnapshot commentDoc) async {
    if (!await _showDeleteConfirmationDialog(context, "comentário")) return;
    try {
      final replyRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('replies')
          .doc(widget.replyDoc.id);
      final commentRef = replyRef.collection('comments').doc(commentDoc.id);
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(commentRef);
      batch.update(replyRef, {'commentCount': FieldValue.increment(-1)});
      await batch.commit();
      if (mounted)
        CustomNotificationService.showSuccess(context, "Comentário excluído.");
    } catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, "Erro ao excluir o comentário.");
      print("Erro ao excluir comentário: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final replyData = widget.replyDoc.data() as Map<String, dynamic>;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bestAnswerId = widget.postData['bestAnswerId'] as String?;
    final isBestAnswer = widget.replyDoc.id == bestAnswerId;
    final upvoters = List<String>.from(replyData['upvotedBy'] ?? []);
    final userHasUpvoted =
        currentUserId != null && upvoters.contains(currentUserId);
    final commentCount = replyData['commentCount'] ?? 0;
    final replyAuthorId = replyData['authorId'] as String?;
    final bool canDeleteReply = widget.isPostAuthor ||
        (currentUserId != null && currentUserId == replyAuthorId);

    final String authorName = replyData['authorName'] ?? 'Anônimo';
    final String? authorPhotoUrl = replyData['authorPhotoUrl'] as String?;
    final bool isAnonymous = authorName == "Autor Anônimo";

    final cardContent = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isBestAnswer ? Colors.green.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1.0, -1.0),
            radius: 1.5,
            colors: [
              theme.colorScheme.primary.withOpacity(isBestAnswer ? 0.08 : 0.03),
              theme.cardColor,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===================================
            // <<< INÍCIO DO NOVO LAYOUT DO HEADER DA RESPOSTA >>>
            // ===================================
            GestureDetector(
              onTap: () {
                if (!isAnonymous && replyAuthorId != null) {
                  Navigator.push(
                    context,
                    FadeScalePageRoute(
                      page: PublicProfilePage(
                        userId: replyAuthorId,
                        initialUserData: {
                          'userId': replyAuthorId,
                          'nome': authorName,
                          'photoURL': authorPhotoUrl,
                        },
                      ),
                    ),
                  );
                }
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: (!isAnonymous &&
                            authorPhotoUrl != null &&
                            authorPhotoUrl.isNotEmpty)
                        ? NetworkImage(authorPhotoUrl)
                        : null,
                    child: (isAnonymous ||
                            authorPhotoUrl == null ||
                            authorPhotoUrl.isEmpty)
                        ? const Icon(Icons.person_outline, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      authorName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isBestAnswer)
                    Chip(
                      avatar:
                          const Icon(Icons.star, color: Colors.green, size: 14),
                      label: const Text("Melhor Resposta"),
                      labelStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold),
                      backgroundColor: Colors.green.withOpacity(0.15),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  if (canDeleteReply)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          size: 20,
                          color: theme.iconTheme.color?.withOpacity(0.6)),
                      onSelected: (value) {
                        if (value == 'delete') _deleteReply();
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            title: Text('Excluir Resposta',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding:
                  const EdgeInsets.only(left: 48.0), // Indentação (18*2 + 12)
              child: MarkdownBody(
                data: replyData['content'] ?? '',
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ),
            // ===================================
            // <<< FIM DO NOVO LAYOUT >>>
            // ===================================
            Row(
              children: [
                const SizedBox(width: 32), // Espaço para alinhar com o avatar
                TextButton.icon(
                  onPressed: () =>
                      widget.onUpvote(widget.replyDoc.id, upvoters),
                  icon: Icon(
                    userHasUpvoted
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                    size: 16,
                    color: userHasUpvoted
                        ? theme.colorScheme.primary
                        : theme.iconTheme.color?.withOpacity(0.6),
                  ),
                  label: Text(
                    upvoters.length.toString(),
                    style: TextStyle(
                        color: userHasUpvoted
                            ? theme.colorScheme.primary
                            : theme.iconTheme.color?.withOpacity(0.6)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => widget.onReply(
                      widget.replyDoc.id, replyData['authorId'], authorName),
                  icon: Icon(Icons.reply,
                      size: 16, color: theme.iconTheme.color?.withOpacity(0.6)),
                  label: Text("Responder",
                      style: TextStyle(
                          fontSize: 12,
                          color: theme.iconTheme.color?.withOpacity(0.6))),
                ),
                const Spacer(),
                if (widget.isPostAuthor && !isBestAnswer)
                  TextButton(
                    onPressed: () => widget.onMarkAsBest(widget.replyDoc.id),
                    child: Text("Melhor",
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade600)),
                  ),
              ],
            ),
            if (commentCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 42.0),
                child: TextButton(
                  onPressed: () =>
                      setState(() => _showComments = !_showComments),
                  child: Text(
                    _showComments
                        ? "Ocultar ${commentCount} Respostas"
                        : "Ver ${commentCount} Respostas",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            if (_showComments) _buildCommentsSection(),
          ],
        ),
      ),
    );

    if (isBestAnswer) {
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final glowOpacity = (_animationController.value * 0.4) + 0.2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(glowOpacity),
                  blurRadius: 12.0,
                  spreadRadius: 1.0,
                ),
              ],
            ),
            child: child!,
          );
        },
        child: cardContent,
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: cardContent,
      );
    }
  }

  // ===================================
  // <<< SEÇÃO DE COMENTÁRIOS ATUALIZADA >>>
  // ===================================
  Widget _buildCommentsSection() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('replies')
            .doc(widget.replyDoc.id)
            .collection('comments')
            .orderBy('timestamp')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
                padding: EdgeInsets.all(8.0), child: LinearProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const SizedBox.shrink();

          return Container(
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: Theme.of(context).dividerColor, width: 2)),
            ),
            child: Column(
              children: snapshot.data!.docs.map((doc) {
                final commentData = doc.data() as Map<String, dynamic>;
                final timestamp = commentData['timestamp'] as Timestamp?;
                final date = timestamp != null
                    ? DateFormat('dd/MM/yy').format(timestamp.toDate())
                    : '';
                final String commentAuthorName =
                    commentData['authorName'] ?? 'Anônimo';
                final String? commentAuthorPhotoUrl =
                    commentData['authorPhotoUrl'] as String?;
                final bool isCommentAnonymous =
                    commentAuthorName == "Autor Anônimo";
                final replyingToName = commentData['replyingToUserName'] ?? '';
                final content = commentData['content'] ?? '';
                final commentAuthorId = commentData['authorId'] as String?;
                final bool canDeleteComment = widget.isPostAuthor ||
                    (currentUserId != null && currentUserId == commentAuthorId);

                final contentSpan = TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    if (replyingToName.isNotEmpty)
                      TextSpan(
                        text: "@$replyingToName ",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    TextSpan(text: content),
                  ],
                );

                // <<< INÍCIO DO NOVO LAYOUT DO COMENTÁRIO ANINHADO >>>
                return Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (!isCommentAnonymous && commentAuthorId != null) {
                            Navigator.push(
                              context,
                              FadeScalePageRoute(
                                page: PublicProfilePage(
                                  userId: commentAuthorId,
                                  initialUserData: {
                                    'userId': commentAuthorId,
                                    'nome': commentAuthorName,
                                    'photoURL': commentAuthorPhotoUrl,
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: (!isCommentAnonymous &&
                                      commentAuthorPhotoUrl != null &&
                                      commentAuthorPhotoUrl.isNotEmpty)
                                  ? NetworkImage(commentAuthorPhotoUrl)
                                  : null,
                              child: (isCommentAnonymous ||
                                      commentAuthorPhotoUrl == null ||
                                      commentAuthorPhotoUrl.isEmpty)
                                  ? const Icon(Icons.person_outline, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                commentAuthorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Text(date,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 11)),
                            if (canDeleteComment)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.redAccent),
                                tooltip: "Excluir comentário",
                                onPressed: () => _deleteComment(doc),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 36.0, top: 4.0, bottom: 4.0),
                        child: RichText(text: contentSpan),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 36.0),
                        child: TextButton(
                          onPressed: () => widget.onReply(widget.replyDoc.id,
                              commentData['authorId'], commentAuthorName),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            "Responder",
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    ],
                  ),
                );
                // <<< FIM DO NOVO LAYOUT >>>
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
