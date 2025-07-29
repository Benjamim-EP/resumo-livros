// lib/pages/community/book_club_post_detail_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/community/reply_card_widget.dart'; // Importa o novo widget
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

class BookClubPostDetailPage extends StatefulWidget {
  final String bookId;
  final String postId;

  const BookClubPostDetailPage({
    super.key,
    required this.bookId,
    required this.postId,
  });

  @override
  State<BookClubPostDetailPage> createState() => _BookClubPostDetailPageState();
}

class _BookClubPostDetailPageState extends State<BookClubPostDetailPage> {
  final _replyController = TextEditingController();
  bool _isReplying = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  // --- LÓGICA PARA ADICIONAR RESPOSTA ---
  Future<void> _addReply() async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final store = StoreProvider.of<AppState>(context, listen: false);
    final userDetails = store.state.userState.userDetails;

    if (user == null || userDetails == null) {
      CustomNotificationService.showError(
          context, "Você precisa estar logado para responder.");
      return;
    }

    setState(() => _isReplying = true);

    try {
      final postRef = FirebaseFirestore.instance
          .collection('bookClubs')
          .doc(widget.bookId)
          .collection('posts')
          .doc(widget.postId);

      final authorData = {
        'authorId': user.uid,
        'authorName': userDetails['nome'] ?? 'Anônimo',
        'authorPhotoUrl': userDetails['photoURL'] ?? '',
        'content': replyText,
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'likedBy': [],
      };

      // Adiciona a nova resposta
      await postRef.collection('replies').add(authorData);

      // Incrementa o contador no post principal
      await postRef.update({'replyCount': FieldValue.increment(1)});

      _replyController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao enviar resposta: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isReplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookClubs')
            .doc(widget.bookId)
            .collection('posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, postSnapshot) {
          if (!postSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!postSnapshot.data!.exists) {
            return const Center(
                child:
                    Text("Esta discussão não foi encontrada ou foi removida."));
          }
          final postData = postSnapshot.data!.data() as Map<String, dynamic>;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(postData),
              _buildPostContent(context, postData),
              _buildRepliesHeader(context, postData),
              _buildRepliesList(),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: _buildReplyComposer(),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(Map<String, dynamic> postData) {
    return SliverAppBar(
      title: Text(postData['title'] ?? 'Discussão',
          overflow: TextOverflow.ellipsis, maxLines: 1),
      pinned: true,
    );
  }

  Widget _buildPostContent(
      BuildContext context, Map<String, dynamic> postData) {
    // (Este widget não muda)
    final theme = Theme.of(context);
    final timestamp = postData['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd/MM/yy \'às\' HH:mm').format(timestamp.toDate())
        : '';
    final authorPhotoUrl = postData['authorPhotoUrl'] as String?;
    final authorName = postData['authorName'] ?? 'Anônimo';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage:
                    (authorPhotoUrl != null && authorPhotoUrl.isNotEmpty)
                        ? NetworkImage(authorPhotoUrl)
                        : null,
                child: (authorPhotoUrl == null || authorPhotoUrl.isEmpty)
                    ? Text(authorName.isNotEmpty ? authorName[0] : '?')
                    : null,
              ),
              title: Text(authorName),
              subtitle: Text("Postado em $date"),
            ),
            const SizedBox(height: 16),
            if (postData['title'] != null &&
                (postData['title'] as String).isNotEmpty)
              Text(
                postData['title'],
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 12),
            MarkdownBody(
              data: postData['content'] ?? '',
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepliesHeader(
      BuildContext context, Map<String, dynamic> postData) {
    // (Este widget não muda)
    final replyCount = postData['replyCount'] ?? 0;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          "$replyCount Respostas",
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }

  // --- LISTA DE RESPOSTAS AGORA USA O ReplyCardWidget ---
  Widget _buildRepliesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookClubs')
          .doc(widget.bookId)
          .collection('posts')
          .doc(widget.postId)
          .collection('replies')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Text("Seja o primeiro a responder."),
            )),
          );
        }

        final replies = snapshot.data!.docs;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ReplyCardWidget(
                  replyDoc: replies[index],
                  bookId: widget.bookId,
                  postId: widget.postId,
                ),
              );
            },
            childCount: replies.length,
          ),
        );
      },
    );
  }

  // --- COMPOSITOR DE RESPOSTAS (SEM MUDANÇAS) ---
  Widget _buildReplyComposer() {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 12,
          right: 12,
          top: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                decoration: const InputDecoration(
                  hintText: "Adicionar uma resposta...",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
