// lib/pages/community/book_club_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/pages/community/post_card_widget.dart';
import 'package:septima_biblia/pages/community/create_book_club_post_page.dart';
import 'package:septima_biblia/pages/community/book_club_post_detail_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

// O ViewModel não muda
class _ViewModel {
  final Set<String> subscribedClubs;
  final Set<String> booksRead;
  final Set<String> booksToRead;

  _ViewModel({
    required this.subscribedClubs,
    required this.booksRead,
    required this.booksToRead,
  });

  static _ViewModel fromStore(Store<AppState> store) {
    final userDetails = store.state.userState.userDetails ?? {};
    return _ViewModel(
      subscribedClubs:
          Set<String>.from(userDetails['subscribedBookClubs'] ?? []),
      booksRead: Set<String>.from(userDetails['booksRead'] ?? []),
      booksToRead: Set<String>.from(userDetails['booksToRead'] ?? []),
    );
  }
}

// Enum para os tipos de ordenação
enum PostSortOrder { mostRelevant, newest, oldest }

// --- ALTERAÇÃO PRINCIPAL: Convertido para StatefulWidget ---
class BookClubDetailPage extends StatefulWidget {
  final String bookId;
  const BookClubDetailPage({super.key, required this.bookId});

  @override
  State<BookClubDetailPage> createState() => _BookClubDetailPageState();
}

class _BookClubDetailPageState extends State<BookClubDetailPage> {
  // Estado para guardar a ordenação atual
  PostSortOrder _currentSortOrder = PostSortOrder.mostRelevant;

  // Função para construir a query do Firestore dinamicamente
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
        // Ordena por likes e depois por data para desempate
        // IMPORTANTE: O Firestore exigirá um índice composto para esta query.
        // O erro no console do Flutter te dará um link para criá-lo com um clique.
        return query
            .orderBy('likeCount', descending: true)
            .orderBy('timestamp', descending: true)
            .snapshots();
    }
  }

  // Função para construir o botão de ordenação
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
              _buildSliverAppBar(clubData),
              _buildActionButtons(context, clubData),
              _buildPostListHeader(context),
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

  SliverAppBar _buildSliverAppBar(Map<String, dynamic> clubData) {
    // ... (este widget não muda)
    final String coverUrl = clubData['bookCover'] ?? '';
    final String title = clubData['bookTitle'] ?? 'Clube do Livro';

    return SliverAppBar(
      expandedHeight: 250.0,
      floating: false,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 6, color: Colors.black)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl.isNotEmpty) Image.network(coverUrl, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, Map<String, dynamic> clubData) {
    // ... (este widget não muda)
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: StoreConnector<AppState, _ViewModel>(
        converter: (store) => _ViewModel.fromStore(store),
        builder: (context, vm) {
          final isParticipating = vm.subscribedClubs.contains(widget.bookId);
          final hasRead = vm.booksRead.contains(widget.bookId);
          final wantsToRead = vm.booksToRead.contains(widget.bookId);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: Icon(isParticipating
                        ? Icons.notifications_active
                        : Icons.notifications_none_outlined),
                    label: Text(isParticipating
                        ? "Inscrito (Receber Notificações)"
                        : "Participar do Clube"),
                    onPressed: () {
                      StoreProvider.of<AppState>(context, listen: false)
                          .dispatch(ToggleBookClubSubscriptionAction(
                              bookId: widget.bookId,
                              isSubscribing: !isParticipating));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: isParticipating
                          ? Colors.green.shade700
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                            hasRead
                                ? Icons.bookmark_added
                                : Icons.bookmark_border,
                            color: hasRead ? Colors.green : null),
                        label: const Text("Já li"),
                        style: OutlinedButton.styleFrom(
                          side: hasRead
                              ? BorderSide(color: Colors.green, width: 2)
                              : null,
                        ),
                        onPressed: () {
                          final newStatus = hasRead
                              ? BookReadStatus.none
                              : BookReadStatus.isRead;
                          StoreProvider.of<AppState>(context, listen: false)
                              .dispatch(UpdateBookReadingStatusAction(
                                  bookId: widget.bookId, status: newStatus));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                            wantsToRead
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                            color: wantsToRead ? Colors.blue : null),
                        label: const Text("Quero ler"),
                        style: OutlinedButton.styleFrom(
                          side: wantsToRead
                              ? BorderSide(color: Colors.blue, width: 2)
                              : null,
                        ),
                        onPressed: () {
                          final newStatus = wantsToRead
                              ? BookReadStatus.none
                              : BookReadStatus.toRead;
                          StoreProvider.of<AppState>(context, listen: false)
                              .dispatch(UpdateBookReadingStatusAction(
                                  bookId: widget.bookId, status: newStatus));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- CABEÇALHO DA LISTA ATUALIZADO ---
  Widget _buildPostListHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Discussões",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            _buildSortPopupMenu(), // Adiciona o botão de filtro
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(String bookId) {
    return StreamBuilder<QuerySnapshot>(
      // --- USA A NOVA FUNÇÃO PARA OBTER O STREAM DINÂMICO ---
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
                  child: Text("Nenhuma discussão iniciada. Seja o primeiro!")),
            ),
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
