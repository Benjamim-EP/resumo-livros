// lib/pages/bibtok/comment_widget.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CommentWidget extends StatefulWidget {
  final DocumentSnapshot commentDoc;
  final Map<String, List<DocumentSnapshot>> allReplies;
  final Function(String parentId, String authorName) onReplyTapped;

  const CommentWidget({
    super.key,
    required this.commentDoc,
    required this.allReplies,
    required this.onReplyTapped,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  bool _showReplies = false;

  String _formatTimeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Agora';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.commentDoc.data() as Map<String, dynamic>;
    final authorName = data['authorName'] ?? 'Anônimo';
    final authorPhotoUrl = data['authorPhotoUrl'] as String?;
    final content = data['content'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final timeAgo = timestamp != null ? _formatTimeAgo(timestamp.toDate()) : '';
    final replies = widget.allReplies[widget.commentDoc.id] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    (authorPhotoUrl != null && authorPhotoUrl.isNotEmpty)
                        ? NetworkImage(authorPhotoUrl)
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(
                              text: authorName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: '  '),
                          TextSpan(text: content),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(timeAgo, style: theme.textTheme.bodySmall),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => widget.onReplyTapped(
                              widget.commentDoc.id, authorName),
                          child: Text("Responder",
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.favorite_border,
                  size: 18, color: theme.iconTheme.color?.withOpacity(0.5)),
            ],
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 50.0, top: 8.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showReplies = !_showReplies),
                    child: Text(
                        _showReplies
                            ? "Ocultar respostas"
                            : "Ver ${replies.length} respostas",
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  if (_showReplies)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        children: replies
                            .map((replyDoc) => CommentWidget(
                                  commentDoc: replyDoc,
                                  allReplies: widget.allReplies,
                                  onReplyTapped: widget.onReplyTapped,
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
