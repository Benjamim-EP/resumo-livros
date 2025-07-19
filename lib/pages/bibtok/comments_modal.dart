// lib/pages/bibtok/comments_modal.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/bibtok/comment_widget.dart';
import 'package:septima_biblia/redux/store.dart';

class CommentsModal extends StatefulWidget {
  final String quoteId;
  final String quoteText;
  const CommentsModal(
      {super.key, required this.quoteId, required this.quoteText});

  @override
  State<CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isPosting = false;
  String? _replyingToCommentId;
  String? _replyingToAuthorName;

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final store = StoreProvider.of<AppState>(context, listen: false);
    final userDetails = store.state.userState.userDetails;
    if (user == null || userDetails == null) return;

    setState(() => _isPosting = true);

    try {
      final quoteRef =
          FirebaseFirestore.instance.collection('quotes').doc(widget.quoteId);
      final commentsRef = quoteRef.collection('comments');

      final commentData = {
        'authorId': user.uid,
        'authorName': userDetails['nome'] ?? 'Anônimo',
        'authorPhotoUrl': userDetails['photoURL'] ?? '',
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
        if (_replyingToCommentId != null) 'parentId': _replyingToCommentId,
      };

      await commentsRef.add(commentData);
      await quoteRef.set(
          {'commentCount': FieldValue.increment(1)}, SetOptions(merge: true));
      if (_replyingToCommentId != null) {
        await commentsRef.doc(_replyingToCommentId).set(
            {'replyCount': FieldValue.increment(1)}, SetOptions(merge: true));
      }

      _commentController.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _replyingToCommentId = null;
        _replyingToAuthorName = null;
      });
    } catch (e) {
      print("Erro ao postar comentário: $e");
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text('Comentários', style: theme.textTheme.titleMedium),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('quotes')
                      .doc(widget.quoteId)
                      .collection('comments')
                      .orderBy('timestamp')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final allDocs = snapshot.data!.docs;
                    final Map<String, List<DocumentSnapshot>> repliesMap = {};
                    final List<DocumentSnapshot> topLevelComments = [];

                    for (var doc in allDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final parentId = data['parentId'] as String?;
                      if (parentId == null) {
                        topLevelComments.add(doc);
                      } else {
                        repliesMap.putIfAbsent(parentId, () => []).add(doc);
                      }
                    }

                    if (topLevelComments.isEmpty) {
                      return const Center(
                          child: Text("Seja o primeiro a comentar!"));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: topLevelComments.length,
                      itemBuilder: (context, index) {
                        final commentDoc = topLevelComments[index];
                        return CommentWidget(
                          commentDoc: commentDoc,
                          allReplies: repliesMap,
                          onReplyTapped: (parentId, authorName) {
                            setState(() {
                              _replyingToCommentId = parentId;
                              _replyingToAuthorName = authorName;
                            });
                            _commentFocusNode.requestFocus();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 16,
                    right: 16,
                    top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToCommentId != null)
                      Row(
                        children: [
                          Expanded(
                              child: Text(
                                  "Respondendo a @_replyingToAuthorName",
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() {
                              _replyingToCommentId = null;
                              _replyingToAuthorName = null;
                            }),
                          )
                        ],
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            decoration: InputDecoration(
                                hintText: _replyingToAuthorName == null
                                    ? "Adicionar um comentário..."
                                    : "Adicionar uma resposta..."),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        IconButton(
                          icon: _isPosting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send),
                          onPressed: _isPosting ? null : _postComment,
                          color: theme.colorScheme.primary,
                        )
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
