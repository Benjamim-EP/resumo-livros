// lib/pages/community/book_club_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/pages/community/post_card_widget.dart';
import 'package:septima_biblia/pages/community/create_book_club_post_page.dart';
import 'package:septima_biblia/pages/community/book_club_post_detail_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';
import 'package:septima_biblia/pages/community/article_viewer_modal.dart';
import 'package:septima_biblia/pages/community/animated_article_button.dart';

// --- VIEWMODEL ATUALIZADO COM LÓGICA ROBUSTA ---
class _ViewModel {
  final Set<String> subscribedClubs;
  final Set<String> booksRead;
  final Set<String> booksToRead;
  final bool isPremium;

  _ViewModel({
    required this.subscribedClubs,
    required this.booksRead,
    required this.booksToRead,
    required this.isPremium,
  });

  static _ViewModel fromStore(Store<AppState> store) {
    final userDetails = store.state.userState.userDetails ?? {};

    // --- INÍCIO DA LÓGICA DE CORREÇÃO ---
    bool isConsideredPremium = false;

    // 1. Verifica o estado oficial da assinatura
    if (store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive) {
      isConsideredPremium = true;
    } else {
      // 2. Como fallback, verifica os dados brutos do Firestore
      final statusString = userDetails['subscriptionStatus'] as String?;
      final endDate =
          (userDetails['subscriptionEndDate'] as Timestamp?)?.toDate();

      if (statusString == 'active' &&
          endDate != null &&
          endDate.isAfter(DateTime.now())) {
        isConsideredPremium = true;
      }
    }
    // --- FIM DA LÓGICA DE CORREÇÃO ---

    return _ViewModel(
      subscribedClubs:
          Set<String>.from(userDetails['subscribedBookClubs'] ?? []),
      booksRead: Set<String>.from(userDetails['booksRead'] ?? []),
      booksToRead: Set<String>.from(userDetails['booksToRead'] ?? []),
      isPremium: isConsideredPremium, // Usa a nova variável robusta
    );
  }
}

enum PostSortOrder { mostRelevant, newest, oldest }

class BookClubDetailPage extends StatefulWidget {
  final String bookId;
  const BookClubDetailPage({super.key, required this.bookId});

  @override
  State<BookClubDetailPage> createState() => _BookClubDetailPageState();
}

class _BookClubDetailPageState extends State<BookClubDetailPage> {
  PostSortOrder _currentSortOrder = PostSortOrder.mostRelevant;

  Stream<QuerySnapshot> _getPostsStream() {
    Query query = FirebaseFirestore.instance
        .collection('bookClubs')
        .doc(widget.bookId)
        .collection('posts');

    switch (_currentSortOrder) {
      case PostSortOrder.newest:
        return query.orderBy('timestamp', descending: true).snapshots();
      case PostSortOrder.oldest:
        return query.orderBy('timestamp', descending: false).snapshots();
      case PostSortOrder.mostRelevant:
      default:
        return query
            .orderBy('likeCount', descending: true)
            .orderBy('timestamp', descending: true)
            .snapshots();
    }
  }

  Widget _buildSortPopupMenu() {
    String getSortOrderText(PostSortOrder order) {
      switch (order) {
        case PostSortOrder.newest:
          return "Mais Recentes";
        case PostSortOrder.oldest:
          return "Mais Antigos";
        case PostSortOrder.mostRelevant:
        default:
          return "Mais Relevantes";
      }
    }

    return PopupMenuButton<PostSortOrder>(
      initialValue: _currentSortOrder,
      onSelected: (newOrder) {
        setState(() {
          _currentSortOrder = newOrder;
        });
      },
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
              getSortOrderText(_currentSortOrder),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
            value: PostSortOrder.mostRelevant, child: Text('Mais Relevantes')),
        const PopupMenuItem(
            value: PostSortOrder.newest, child: Text('Mais Recentes')),
        const PopupMenuItem(
            value: PostSortOrder.oldest, child: Text('Mais Antigos')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookClubs')
            .doc(widget.bookId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final clubData = snapshot.data!.data() as Map<String, dynamic>;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, clubData),
              _buildPostListHeader(context, clubData),
              _buildPostList(widget.bookId),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CreateBookClubPostPage(bookId: widget.bookId),
            ),
          );
        },
        child: const Icon(Icons.add_comment_outlined),
        tooltip: "Iniciar uma discussão",
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
      BuildContext context, Map<String, dynamic> clubData) {
    final String coverUrl = clubData['bookCover'] ?? '';
    final String title = clubData['bookTitle'] ?? 'Clube do Livro';
    final String author = clubData['authorName'] ?? 'Desconhecido';
    final String articleContent = clubData['article'] as String? ?? '';

    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      stretch: true,
      actions: [
        StoreConnector<AppState, _ViewModel>(
          converter: (store) => _ViewModel.fromStore(store),
          builder: (context, vm) {
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'participate') {
                  final isParticipating =
                      vm.subscribedClubs.contains(widget.bookId);
                  StoreProvider.of<AppState>(context, listen: false).dispatch(
                      ToggleBookClubSubscriptionAction(
                          bookId: widget.bookId,
                          isSubscribing: !isParticipating));
                } else if (value == 'mark_read') {
                  final hasRead = vm.booksRead.contains(widget.bookId);
                  final newStatus =
                      hasRead ? BookReadStatus.none : BookReadStatus.isRead;
                  StoreProvider.of<AppState>(context, listen: false).dispatch(
                      UpdateBookReadingStatusAction(
                          bookId: widget.bookId, status: newStatus));
                } else if (value == 'mark_toread') {
                  final wantsToRead = vm.booksToRead.contains(widget.bookId);
                  final newStatus =
                      wantsToRead ? BookReadStatus.none : BookReadStatus.toRead;
                  StoreProvider.of<AppState>(context, listen: false).dispatch(
                      UpdateBookReadingStatusAction(
                          bookId: widget.bookId, status: newStatus));
                }
              },
              itemBuilder: (BuildContext context) {
                final isParticipating =
                    vm.subscribedClubs.contains(widget.bookId);
                final hasRead = vm.booksRead.contains(widget.bookId);
                final wantsToRead = vm.booksToRead.contains(widget.bookId);

                return [
                  PopupMenuItem<String>(
                    value: 'participate',
                    child: ListTile(
                      leading: Icon(isParticipating
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_active_outlined),
                      title: Text(isParticipating
                          ? 'Cancelar Inscrição'
                          : 'Participar (Notificações)'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'mark_read',
                    child: ListTile(
                      leading: Icon(
                          hasRead
                              ? Icons.bookmark_remove_outlined
                              : Icons.bookmark_added_outlined,
                          color: hasRead ? Colors.green : null),
                      title: Text(
                          hasRead ? 'Remover de "Lidos"' : 'Marcar como Lido'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'mark_toread',
                    child: ListTile(
                      leading: Icon(
                          wantsToRead
                              ? Icons.bookmark_remove_outlined
                              : Icons.bookmark_add_outlined,
                          color: wantsToRead ? Colors.blue : null),
                      title: Text(wantsToRead
                          ? 'Remover de "Quero Ler"'
                          : 'Adicionar a "Quero Ler"'),
                    ),
                  ),
                ];
              },
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl.isNotEmpty)
              Image.network(coverUrl,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.4),
                  colorBlendMode: BlendMode.darken),
            Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7)
                ],
                        stops: const [
                  0.3,
                  1.0
                ]))),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 70, bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Card(
                    elevation: 8,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: SizedBox(
                        width: 90,
                        height: 120,
                        child: coverUrl.isNotEmpty
                            ? Image.network(coverUrl, fit: BoxFit.cover)
                            : const Icon(Icons.book)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black)
                                ]),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(author,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14.0,
                                shadows: [
                                  Shadow(blurRadius: 2, color: Colors.black)
                                ])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostListHeader(
      BuildContext context, Map<String, dynamic> clubData) {
    final String articleContent = clubData['article'] as String? ?? '';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            if (articleContent.isNotEmpty)
              StoreConnector<AppState, _ViewModel>(
                converter: (store) => _ViewModel.fromStore(store),
                builder: (context, vm) {
                  return AnimatedArticleButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ArticleViewerModal(
                          title: clubData['bookTitle'] ?? 'Artigo',
                          content: articleContent,
                          isPremiumUser: vm.isPremium,
                        ),
                      );
                    },
                  );
                },
              ),
            if (articleContent.isNotEmpty) const SizedBox(width: 8),
            _buildSortPopupMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(String bookId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPostsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                    child:
                        Text("Nenhuma discussão iniciada. Seja o primeiro!"))),
          );
        }
        final posts = snapshot.data!.docs;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final postDoc = posts[index];
              final postData = postDoc.data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: PostCardWidget(
                  key: ValueKey(postDoc.id),
                  postData: postData,
                  bookId: bookId,
                  postId: postDoc.id,
                  onTap: () {
                    Navigator.push(
                      context,
                      FadeScalePageRoute(
                        page: BookClubPostDetailPage(
                          bookId: bookId,
                          postId: postDoc.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            childCount: posts.length,
          ),
        );
      },
    );
  }
}
