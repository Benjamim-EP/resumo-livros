// lib/pages/community/reply_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

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

  // --- FUNÇÕES DE EXCLUSÃO ---

  /// Exibe um diálogo de confirmação genérico.
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
            child: const Text("Cancelar"),
          ),
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

  /// Lógica para excluir a resposta principal (Nível 1).
  Future<void> _deleteReply() async {
    if (!await _showDeleteConfirmationDialog(context, "resposta")) return;

    try {
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final replyRef = postRef.collection('replies').doc(widget.replyDoc.id);

      // Usamos um batch para garantir que as duas operações ocorram juntas
      final batch = FirebaseFirestore.instance.batch();

      batch.delete(replyRef);
      batch.update(postRef, {'answerCount': FieldValue.increment(-1)});

      await batch.commit();

      if (mounted) {
        CustomNotificationService.showSuccess(context, "Resposta excluída.");
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao excluir a resposta.");
      }
      print("Erro ao excluir resposta: $e");
    }
  }

  /// Lógica para excluir um comentário aninhado (Nível 2).
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

      if (mounted) {
        CustomNotificationService.showSuccess(context, "Comentário excluído.");
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao excluir o comentário.");
      }
      print("Erro ao excluir comentário: $e");
    }
  }

  // --- FIM DAS FUNÇÕES DE EXCLUSÃO ---

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

    // --- LÓGICA DE PERMISSÃO PARA EXCLUIR A RESPOSTA PRINCIPAL ---
    final replyAuthorId = replyData['authorId'] as String?;
    final bool canDeleteReply = widget.isPostAuthor ||
        (currentUserId != null && currentUserId == replyAuthorId);

    final cardContent = Card(
      // ... (código do Card, Container e BoxDecoration permanecem os mesmos) ...
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
            // Cabeçalho da resposta
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: (replyData['authorPhotoUrl'] != null &&
                          replyData['authorPhotoUrl']!.isNotEmpty)
                      ? NetworkImage(replyData['authorPhotoUrl']!)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    replyData['authorName'] ?? 'Anônimo',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    // Garante que nomes muito longos não quebrem a linha e mostrem "..."
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

                // --- BOTÃO DE OPÇÕES (EXCLUIR) PARA A RESPOSTA PRINCIPAL ---
                if (canDeleteReply)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 20,
                        color: theme.iconTheme.color?.withOpacity(0.6)),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteReply();
                      }
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
            const SizedBox(height: 12),

            // Conteúdo da resposta
            MarkdownBody(
              data: replyData['content'] ?? '',
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 8),

            // Ações (Upvote, Responder, etc.)
            Row(
              children: [
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
                      widget.replyDoc.id,
                      replyData['authorId'],
                      replyData['authorName'] ?? 'Anônimo'),
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
                    child: Text("Marcar como melhor",
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade600)),
                  ),
              ],
            ),

            // Seção de comentários
            if (commentCount > 0)
              TextButton(
                onPressed: () => setState(() => _showComments = !_showComments),
                child: Text(
                  _showComments
                      ? "Ocultar ${commentCount} Respostas"
                      : "Ver ${commentCount} Respostas",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            if (_showComments) _buildCommentsSection(),
          ],
        ),
      ),
    );

    // --- LÓGICA DA ANIMAÇÃO (permanece a mesma) ---
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

  /// Constrói a seção de comentários aninhados (Nível 2)
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
                final authorName = commentData['authorName'] ?? 'Anônimo';
                final replyingToName = commentData['replyingToUserName'] ?? '';
                final content = commentData['content'] ?? '';

                // --- LÓGICA DE PERMISSÃO PARA EXCLUIR O COMENTÁRIO ---
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

                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundImage: (commentData['authorPhotoUrl'] != null &&
                            commentData['authorPhotoUrl']!.isNotEmpty)
                        ? NetworkImage(commentData['authorPhotoUrl']!)
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(date, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: RichText(text: contentSpan),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- BOTÃO DE RESPOSTA ---
                      IconButton(
                        icon: const Icon(Icons.reply, size: 16),
                        tooltip: "Responder a este comentário",
                        onPressed: () => widget.onReply(widget.replyDoc.id,
                            commentData['authorId'], authorName),
                      ),
                      // --- BOTÃO DE EXCLUSÃO (CONDICIONAL) ---
                      if (canDeleteComment)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.redAccent),
                          tooltip: "Excluir comentário",
                          onPressed: () => _deleteComment(doc),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
