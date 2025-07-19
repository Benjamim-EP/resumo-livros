// lib/pages/bibtok_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- WIDGET DO CARD DA FRASE ---
class QuoteCardWidget extends StatefulWidget {
  final Map<String, dynamic> quoteData;
  const QuoteCardWidget({super.key, required this.quoteData});

  @override
  State<QuoteCardWidget> createState() => _QuoteCardWidgetState();
}

class _QuoteCardWidgetState extends State<QuoteCardWidget> {
  // Estado local para otimismo na UI de curtidas
  late int _likeCount;
  late bool _isLiked;

  bool _isLikeProcessing = false;

  @override
  void initState() {
    super.initState();
    // Inicializa o estado local com os dados recebidos.
    _likeCount = widget.quoteData['likeCount'] ?? 0;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final List<dynamic> likedBy = widget.quoteData['likedBy'] ?? [];
    _isLiked = currentUserId != null && likedBy.contains(currentUserId);
  }

  /// Lida com a ação de curtir/descurtir.
  Future<void> _toggleLike() async {
    if (_isLikeProcessing) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      // Opcional: mostrar um diálogo de login se o usuário for convidado
      return;
    }

    setState(() {
      _isLikeProcessing = true;
      if (_isLiked) {
        _likeCount--;
      } else {
        _likeCount++;
      }
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
      // Reverte a atualização otimista em caso de erro
      setState(() {
        if (_isLiked) {
          _likeCount++;
        } else {
          _likeCount--;
        }
        _isLiked = !_isLiked;
      });
    } finally {
      if (mounted) {
        setState(() => _isLikeProcessing = false);
      }
    }
  }

  /// Abre o modal de comentários.
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
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.redAccent : Colors.white,
                  size: 32,
                ),
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

// --- MODAL DE COMENTÁRIOS ---
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
  bool _isPosting = false;

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

      await commentsRef.add({
        'authorId': user.uid,
        'authorName': userDetails['nome'] ?? 'Anônimo',
        'authorPhotoUrl': userDetails['photoURL'] ?? '',
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await quoteRef.set(
          {'commentCount': FieldValue.increment(1)}, SetOptions(merge: true));

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      print("Erro ao postar comentário: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erro ao enviar comentário.")));
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
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
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Comentários sobre: "${widget.quoteText}"',
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('quotes')
                      .doc(widget.quoteId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text("Seja o primeiro a comentar!"));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final comment = snapshot.data!.docs[index];
                        final data = comment.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundImage: (data['authorPhotoUrl'] != null &&
                                    data['authorPhotoUrl'].isNotEmpty)
                                ? NetworkImage(data['authorPhotoUrl'])
                                : null,
                          ),
                          title: Text(data['authorName'] ?? 'Anônimo',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(data['content'] ?? ''),
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                            hintText: "Adicionar um comentário..."),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    IconButton(
                      icon: _isPosting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      onPressed: _isPosting ? null : _postComment,
                      color: theme.colorScheme.primary,
                    )
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

// --- PÁGINA PRINCIPAL DO BIBTOK ---
class BibTokPage extends StatefulWidget {
  const BibTokPage({super.key});

  @override
  State<BibTokPage> createState() => _BibTokPageState();
}

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
    WidgetsBinding.instance.addObserver(this);
    _initializeFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _persistSessionIds();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      print("BibTok: App pausado. Persistindo IDs da sessão...");
      _persistSessionIds();
    }
  }

  Future<void> _initializeFeed() async {
    await _loadSeenQuotesFromPrefs();
    await _fetchAndBuildFeed(isInitialLoad: true);
    _syncWithPersistentStorage();
  }

  Future<void> _loadSeenQuotesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final seenList = prefs.getStringList(_seenQuotesPrefsKey) ?? [];
    if (mounted) {
      setState(() => _persistentSeenIds = seenList.toSet());
      print(
          "BibTok: Carregados ${_persistentSeenIds.length} IDs vistos do cache local.");
    }
  }

  Future<void> _syncWithPersistentStorage() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    print("BibTok: Iniciando sincronização com Firestore...");
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
        setState(() => _persistentSeenIds.addAll(allSeenIdsFromFirestore));
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
              type: 'personalized',
              count: personalizedCount,
              seenIds: allSeenIdsToFilter),
          _fetchQuotesFromBackend(
              type: 'random', count: randomCount, seenIds: allSeenIdsToFilter),
        ]);
        newQuotes.addAll(results[0]);
        newQuotes.addAll(results[1]);
      } else {
        newQuotes = await _fetchQuotesFromBackend(
            type: 'random', count: batchSize, seenIds: allSeenIdsToFilter);
      }

      final unseenQuotes = newQuotes; // Filtragem agora é no backend via query

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
      {required String type,
      required int count,
      required Set<String> seenIds}) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('getQuotesFromPinecone');
      final result = await callable.call<Map<String, dynamic>>({
        'type': type,
        'count': count,
      });

      final List<Map<String, dynamic>> fetchedQuotes =
          (result.data['quotes'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

      // A filtragem acontece no frontend para velocidade
      return fetchedQuotes
          .where((quote) => !seenIds.contains(quote['id']))
          .toList();
    } catch (e) {
      print("Erro ao chamar getQuotesFromPinecone (type: $type): $e");
      return [];
    }
  }

  Future<void> _persistSessionIds() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _sessionOnlySeenIds.isEmpty) return;

    final Set<String> idsToSave = Set.from(_sessionOnlySeenIds);
    if (mounted) setState(() => _sessionOnlySeenIds.clear());

    print(
        "Persistindo ${idsToSave.length} novos IDs vistos para o Firestore...");

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
      print("Persistência no Firestore concluída.");
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
        final quoteId = quoteData['id'] as String; // Pega o ID único da frase
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                // --- INÍCIO DA CORREÇÃO ---
                image: NetworkImage(
                    // 1. Resolução reduzida para 450x800 (carregamento muito mais rápido)
                    // 2. Usa o ID da frase como "semente" para a imagem, permitindo o cache
                    "https://picsum.photos/seed/$quoteId/450/800"),
                // --- FIM DA CORREÇÃO ---
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
