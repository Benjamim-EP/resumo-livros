// lib/pages/community/reply_card_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

class ReplyCardWidget extends StatefulWidget {
  final DocumentSnapshot replyDoc;
  final String bookId;
  final String postId;

  const ReplyCardWidget({
    super.key,
    required this.replyDoc,
    required this.bookId,
    required this.postId,
  });

  @override
  State<ReplyCardWidget> createState() => _ReplyCardWidgetState();
}

class _ReplyCardWidgetState extends State<ReplyCardWidget> {
  late int _likeCount;
  late bool _isLiked;
  bool _isProcessingLike = false;

  @override
  void initState() {
    super.initState();
    _updateStateFromData();
  }

  @override
  void didUpdateWidget(covariant ReplyCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.replyDoc.data() as Map<String, dynamic>)['likeCount'] !=
        (oldWidget.replyDoc.data() as Map<String, dynamic>)['likeCount']) {
      _updateStateFromData();
    }
  }

  void _updateStateFromData() {
    final data = widget.replyDoc.data() as Map<String, dynamic>;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    setState(() {
      _likeCount = data['likeCount'] ?? 0;
      _isLiked = currentUserId != null && likedBy.contains(currentUserId);
    });
  }

  Future<void> _toggleLike() async {
    if (_isProcessingLike) return;

    final originalIsLiked = _isLiked;
    final originalLikeCount = _likeCount;

    setState(() {
      _isProcessingLike = true;
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });

    try {
      await StoreProvider.of<AppState>(context, listen: false)
          .dispatch(ToggleBookClubReplyLikeAction(
            bookId: widget.bookId,
            postId: widget.postId,
            replyId: widget.replyDoc.id,
            isLiked: _isLiked,
          ))
          .future;
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao registrar o like.");
        setState(() {
          _isLiked = originalIsLiked;
          _likeCount = originalLikeCount;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingLike = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.replyDoc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd/MM/yy').format(timestamp.toDate())
        : '';
    final authorPhotoUrl = data['authorPhotoUrl'] as String?;
    final authorName = data['authorName'] ?? 'Anônimo';
    final content = data['content'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                (authorPhotoUrl != null && authorPhotoUrl.isNotEmpty)
                    ? NetworkImage(authorPhotoUrl)
                    : null,
            child: (authorPhotoUrl == null || authorPhotoUrl.isEmpty)
                ? Text(authorName.isNotEmpty ? authorName[0] : '?')
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(date, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(content),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                          _isLiked
                              ? Icons.thumb_up_alt_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 18,
                          color: _isLiked
                              ? theme.colorScheme.primary
                              : theme.iconTheme.color),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _toggleLike,
                    ),
                    const SizedBox(width: 4),
                    Text(_likeCount.toString(),
                        style: theme.textTheme.bodySmall),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
