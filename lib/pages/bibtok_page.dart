// lib/pages/bibtok_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// =======================================================================
// WIDGET DO CARD DA FRASE
// =======================================================================
class QuoteCardWidget extends StatefulWidget {
  final Map<String, dynamic> quoteData;
  const QuoteCardWidget({super.key, required this.quoteData});

  @override
  State<QuoteCardWidget> createState() => _QuoteCardWidgetState();
}

class _QuoteCardWidgetState extends State<QuoteCardWidget> {
  late int _likeCount;
  late bool _isLiked;
  bool _isLikeProcessing = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.quoteData['likeCount'] ?? 0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final List<dynamic> likedBy = widget.quoteData['likedBy'] ?? [];
    _isLiked = currentUserId != null && likedBy.contains(currentUserId);
  }

  Future<void> _toggleLike() async {
    if (_isLikeProcessing) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      _isLikeProcessing = true;
      _isLiked ? _likeCount-- : _likeCount++;
      _isLiked = !_isLiked;
    });

    try {
      final quoteRef = FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quoteData['id']);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshSnap = await transaction.get(quoteRef);
        if (!freshSnap.exists) {
          transaction.set(quoteRef, {
            'text': widget.quoteData['text'],
            'author': widget.quoteData['author'],
            'book': widget.quoteData['book'],
            'likeCount': 1,
            'commentCount': 0,
            'likedBy': [currentUserId],
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final currentLikedBy =
              List<String>.from(freshSnap.data()?['likedBy'] ?? []);
          if (currentLikedBy.contains(currentUserId)) {
            transaction.update(quoteRef, {
              'likeCount': FieldValue.increment(-1),
              'likedBy': FieldValue.arrayRemove([currentUserId])
            });
          } else {
            transaction.update(quoteRef, {
              'likeCount': FieldValue.increment(1),
              'likedBy': FieldValue.arrayUnion([currentUserId])
            });
          }
        }
      });
    } catch (e) {
      print("Erro ao curtir a frase: $e");
      setState(() {
        _isLiked ? _likeCount++ : _likeCount--;
        _isLiked = !_isLiked;
      });
    } finally {
      if (mounted) setState(() => _isLikeProcessing = false);
    }
  }

  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModal(
          quoteId: widget.quoteData['id'], quoteText: widget.quoteData['text']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '"${widget.quoteData['text']}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
                ),
                const SizedBox(height: 24),
                Text(
                  "- ${widget.quoteData['author']}, em '${widget.quoteData['book']}'",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)]),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.redAccent : Colors.white,
                    size: 32),
                onPressed: _toggleLike,
              ),
              Text(_likeCount.toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(Icons.comment_outlined,
                    color: Colors.white, size: 32),
                onPressed: _showCommentsModal,
              ),
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 32),
                onPressed: () {/* Adicionar lógica de compartilhamento */},
              ),
            ],
          ),
        )
      ],
    );
  }
}

// =======================================================================
// WIDGET DO MODAL DE COMENTÁRIOS
// =======================================================================
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

// =======================================================================
// WIDGET DE UM ÚNICO COMENTÁRIO (COM SUPORTE A RESPOSTAS)
// =======================================================================
class CommentWidget extends StatefulWidget {
  final DocumentSnapshot commentDoc;
  final Map<String, List<DocumentSnapshot>> allReplies;
  final Function(String parentId, String authorName) onReplyTapped;

  const CommentWidget(
      {super.key,
      required this.commentDoc,
      required this.allReplies,
      required this.onReplyTapped});

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

// =======================================================================
// PÁGINA PRINCIPAL DO BIBTOK
// =======================================================================
class BibTokPage extends StatefulWidget {
  const BibTokPage({super.key});

  @override
  State<BibTokPage> createState() => _BibTokPageState();
}

// >>>>> CORREÇÃO 1: Adicionar o `WidgetsBindingObserver` <<<<<
class _BibTokPageState extends State<BibTokPage> with WidgetsBindingObserver {
  final PageController _pageController = PageController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  List<Map<String, dynamic>> _feedItems = [];

  Set<String> _persistentSeenIds = {};
  Set<String> _sessionOnlySeenIds = {};

  static const int _chunkSize = 10000;
  static const String _seenQuotesPrefsKey = 'bibtok_seen_ids_cache';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addObserver(this); // Adiciona o observador de ciclo de vida
    _initializeFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this); // Remove o observador
    _persistSessionIds(); // Garante uma última tentativa de salvar ao sair
    super.dispose();
  }

  // >>>>> CORREÇÃO 2: Novo método para observar o ciclo de vida do app <<<<<
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Salva os dados sempre que o app for para o background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistSessionIds();
    }
  }

  Future<void> _initializeFeed() async {
    await _loadSeenQuotesFromPrefs();
    await _fetchAndBuildFeed(isInitialLoad: true);
    // A sincronização acontece em segundo plano para não atrasar a UI
    _syncWithPersistentStorage();
  }

  Future<void> _loadSeenQuotesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final seenList = prefs.getStringList(_seenQuotesPrefsKey) ?? [];
    if (mounted) {
      setState(() {
        _persistentSeenIds = seenList.toSet();
      });
    }
  }

  Future<void> _syncWithPersistentStorage() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    print("BibTok: Iniciando sincronização em segundo plano com Firestore...");

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('viewed_quotes_chunks')
          .get();

      Set<String> allSeenIdsFromFirestore = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('quotes') && data['quotes'] is List) {
          allSeenIdsFromFirestore.addAll(List<String>.from(data['quotes']));
        }
      }

      if (mounted) {
        setState(() {
          _persistentSeenIds.addAll(allSeenIdsFromFirestore);
        });
        await _saveSeenQuotesToPrefs();
        print(
            "BibTok: Sincronização com Firestore concluída. Total de IDs vistos: ${_persistentSeenIds.length}");
      }
    } catch (e) {
      print("Erro ao sincronizar com chunks de frases vistas: $e");
    }
  }

  Future<void> _saveSeenQuotesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final limitedList =
        _persistentSeenIds.toList().reversed.take(1000).toList();
    await prefs.setStringList(_seenQuotesPrefsKey, limitedList);
  }

  Future<void> _fetchAndBuildFeed({bool isInitialLoad = false}) async {
    if (_isFetchingMore) return;
    if (mounted)
      setState(() {
        if (isInitialLoad)
          _isLoading = true;
        else
          _isFetchingMore = true;
      });

    try {
      final store = StoreProvider.of<AppState>(context, listen: false);
      final hasInteractions = store
              .state.userState.userDetails?['recentInteractions']?.isNotEmpty ??
          false;
      const batchSize = 10;
      List<Map<String, dynamic>> newQuotes = [];
      Set<String> allSeenIdsToFilter = {
        ..._persistentSeenIds,
        ..._sessionOnlySeenIds
      };

      if (hasInteractions) {
        final personalizedCount = (batchSize * 0.7).round();
        final randomCount = batchSize - personalizedCount;
        final results = await Future.wait([
          _fetchQuotesFromBackend(
              type: 'personalized', count: personalizedCount),
          _fetchQuotesFromBackend(type: 'random', count: randomCount),
        ]);
        newQuotes.addAll(results[0]);
        newQuotes.addAll(results[1]);
      } else {
        newQuotes =
            await _fetchQuotesFromBackend(type: 'random', count: batchSize);
      }

      final unseenQuotes = newQuotes
          .where((quote) => !allSeenIdsToFilter.contains(quote['id']))
          .toList();

      if (mounted) {
        setState(() {
          _feedItems.addAll(unseenQuotes);
          for (var quote in unseenQuotes) {
            _sessionOnlySeenIds.add(quote['id']);
          }
        });
      }
    } catch (e) {
      print("Erro ao construir feed do BibTok: $e");
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchQuotesFromBackend(
      {required String type, required int count}) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('getQuotesFromPinecone');
      final result = await callable
          .call<Map<String, dynamic>>({'type': type, 'count': count});
      return (result.data['quotes'] as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      print("Erro ao chamar getQuotesFromPinecone (type: $type): $e");
      return [];
    }
  }

  Future<void> _persistSessionIds() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _sessionOnlySeenIds.isEmpty) return;

    // Faz uma cópia dos IDs para salvar e limpa a lista da sessão imediatamente
    final Set<String> idsToSave = Set.from(_sessionOnlySeenIds);
    if (mounted) setState(() => _sessionOnlySeenIds.clear());

    print(
        "BibTok: Persistindo ${idsToSave.length} novos IDs vistos para o Firestore...");

    try {
      final chunksRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('viewed_quotes_chunks');
      final lastChunkQuery =
          chunksRef.orderBy('createdAt', descending: true).limit(1);
      final lastChunkSnapshot = await lastChunkQuery.get();

      DocumentReference targetChunkRef;
      List<dynamic> currentQuotesInChunk = [];
      int newChunkId = 0;

      if (lastChunkSnapshot.docs.isNotEmpty) {
        final lastChunkDoc = lastChunkSnapshot.docs.first;
        currentQuotesInChunk = List.from(lastChunkDoc.data()['quotes'] ?? []);
        newChunkId = int.tryParse(lastChunkDoc.id) ?? 0;

        if (currentQuotesInChunk.length < _chunkSize) {
          targetChunkRef = lastChunkDoc.reference;
        } else {
          newChunkId++;
          targetChunkRef = chunksRef.doc(newChunkId.toString());
          currentQuotesInChunk = [];
        }
      } else {
        targetChunkRef = chunksRef.doc('0');
      }

      List<String> idsToProcess = idsToSave.toList();
      while (idsToProcess.isNotEmpty) {
        final spaceLeft = _chunkSize - currentQuotesInChunk.length;
        final idsToAdd = idsToProcess.take(spaceLeft).toList();
        idsToProcess = idsToProcess.sublist(idsToAdd.length);
        await targetChunkRef.set({
          'quotes': FieldValue.arrayUnion(idsToAdd),
          'count': FieldValue.increment(idsToAdd.length),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (idsToProcess.isNotEmpty) {
          newChunkId++;
          targetChunkRef = chunksRef.doc(newChunkId.toString());
          currentQuotesInChunk = [];
        }
      }

      print("BibTok: Persistência no Firestore concluída.");
      if (mounted) {
        setState(() => _persistentSeenIds.addAll(idsToSave));
        await _saveSeenQuotesToPrefs();
      }
    } catch (e) {
      print("Erro ao persistir IDs vistos no Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feedItems.isEmpty && !_isFetchingMore) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Não foi possível carregar o feed."),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                  onPressed: _initializeFeed,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Tentar Novamente"))
            ],
          ),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _feedItems.length + (_isFetchingMore ? 1 : 0),
      onPageChanged: (index) {
        if (index >= _feedItems.length - 3 && !_isFetchingMore) {
          _fetchAndBuildFeed();
        }
      },
      itemBuilder: (context, index) {
        if (index == _feedItems.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final quoteData = _feedItems[index];
        final quoteId = quoteData['id'] as String;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image:
                    NetworkImage("https://picsum.photos/seed/$quoteId/450/800"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.4), BlendMode.darken),
              ),
            ),
            child: QuoteCardWidget(quoteData: quoteData),
          ),
        );
      },
    );
  }
}
