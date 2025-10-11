// lib/pages/bibtok_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/bibtok/premium_ad_card.dart';
import 'package:septima_biblia/pages/bibtok/quote_card_widget.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:redux/redux.dart';

class _BibTokViewModel {
  final bool isPremium;
  final Map<String, dynamic>? userDetails;

  _BibTokViewModel({required this.isPremium, this.userDetails});

  static _BibTokViewModel fromStore(Store<AppState> store) {
    return _BibTokViewModel(
      isPremium: store.state.subscriptionState.status ==
          SubscriptionStatus.premiumActive,
      userDetails: store.state.userState.userDetails,
    );
  }
}

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

  final int _adInterval = 7;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        store.dispatch(LoadUserDetailsAction());
      }
    });
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
      _persistSessionIds();
    }
  }

  // ✅ 1. NOVA FUNÇÃO DE CALLBACK PARA CURTIDAS
  /// Atualiza o estado da lista `_feedItems` quando uma curtida muda.
  void _onLikeChanged(String quoteId, bool isNowLiked, int newLikeCount) {
    if (!mounted) return;

    final index = _feedItems.indexWhere((quote) => quote['id'] == quoteId);
    if (index == -1) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      _feedItems[index]['likeCount'] = newLikeCount;

      // Garante que a lista 'likedBy' local esteja sincronizada
      final List<dynamic> likedBy =
          List.from(_feedItems[index]['likedBy'] ?? []);
      if (isNowLiked) {
        if (!likedBy.contains(currentUserId)) {
          likedBy.add(currentUserId);
        }
      } else {
        likedBy.remove(currentUserId);
      }
      _feedItems[index]['likedBy'] = likedBy;
    });
  }

  // ✅ 2. NOVA FUNÇÃO DE CALLBACK PARA COMENTÁRIOS
  /// Busca a contagem de comentários mais recente do Firestore.
  void _onCommentPosted(String quoteId) async {
    if (!mounted) return;

    try {
      final quoteDoc = await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quoteId)
          .get();
      if (!quoteDoc.exists) return;

      final newCommentCount = quoteDoc.data()?['commentCount'] ?? 0;
      final index = _feedItems.indexWhere((quote) => quote['id'] == quoteId);
      if (index == -1) return;

      if (_feedItems[index]['commentCount'] != newCommentCount) {
        setState(() {
          _feedItems[index]['commentCount'] = newCommentCount;
        });
      }
    } catch (e) {
      print("Erro ao atualizar contagem de comentários na BibTokPage: $e");
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
    if (mounted) setState(() => _persistentSeenIds = seenList.toSet());
  }

  Future<void> _syncWithPersistentStorage() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
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
      final interactions =
          store.state.userState.userDetails?['recentInteractions'];
      final bool hasInteractions =
          interactions != null && (interactions as List).isNotEmpty;

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
          if (isInitialLoad && _feedItems.isNotEmpty) {
            final firstQuoteId = _feedItems.first['id'] as String?;
            if (firstQuoteId != null &&
                !_sessionOnlySeenIds.contains(firstQuoteId)) {
              _sessionOnlySeenIds.add(firstQuoteId);
            }
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
              .httpsCallable('getBibTokFeed');
      final result = await callable
          .call<Map<String, dynamic>>({'type': type, 'count': count});
      return (result.data['quotes'] as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      print("Erro ao chamar getBibTokFeed (type: $type): $e");
      return [];
    }
  }

  Future<void> _persistSessionIds() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _sessionOnlySeenIds.isEmpty) return;
    final Set<String> idsToSave = Set.from(_sessionOnlySeenIds);
    if (mounted) setState(() => _sessionOnlySeenIds.clear());
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
    return StoreConnector<AppState, _BibTokViewModel>(
      converter: (store) => _BibTokViewModel.fromStore(store),
      onInit: (store) {
        if (store.state.userState.userDetails != null) {
          _initializeFeed();
        }
      },
      onWillChange: (previousViewModel, newViewModel) {
        if (previousViewModel?.userDetails == null &&
            newViewModel.userDetails != null) {
          _initializeFeed();
        }
      },
      builder: (context, viewModel) {
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
                  const Text(
                      "Não foi possível carregar o feed. Toque para tentar novamente ou interaja com o app para obter recomendações."),
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

        if (viewModel.isPremium) {
          return buildQuoteOnlyFeed();
        }

        final adCount = (_feedItems.length / _adInterval).floor();
        final totalItemCount =
            _feedItems.length + adCount + (_isFetchingMore ? 1 : 0);
        final adSlotRatio = _adInterval + 1;

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemCount: totalItemCount,
          onPageChanged: (index) {
            setState(() => _currentPageIndex = index);

            final adOffset = ((index + 1) / adSlotRatio).floor();
            final quoteIndex = index - adOffset;

            if (quoteIndex >= 0 && quoteIndex < _feedItems.length) {
              final quoteData = _feedItems[quoteIndex];
              final quoteId = quoteData['id'] as String?;
              final allCurrentlySeenIds = {
                ..._persistentSeenIds,
                ..._sessionOnlySeenIds
              };
              if (quoteId != null && !allCurrentlySeenIds.contains(quoteId)) {
                setState(() {
                  _sessionOnlySeenIds.add(quoteId);
                  _persistentSeenIds.add(quoteId);
                });
              }
            }
            if (quoteIndex >= _feedItems.length - 3 && !_isFetchingMore) {
              _fetchAndBuildFeed();
            }
          },
          itemBuilder: (context, index) {
            if (index == totalItemCount - 1 && _isFetchingMore) {
              return const Center(child: CircularProgressIndicator());
            }

            if ((index + 1) % adSlotRatio == 0 && index != 0) {
              return PremiumAdCard(
                pageController: _pageController,
                currentPageIndex: index,
              );
            }

            final adOffset = ((index + 1) / adSlotRatio).floor();
            final quoteIndex = index - adOffset;

            if (quoteIndex >= _feedItems.length) {
              return const SizedBox.shrink();
            }

            final quoteData = _feedItems[quoteIndex];
            final quoteId = quoteData['id'] as String;
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(
                        "https://picsum.photos/seed/$quoteId/225/400"),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4), BlendMode.darken),
                  ),
                ),
                // ✅ 3. PASSA AS FUNÇÕES DE CALLBACK PARA O WIDGET FILHO
                child: QuoteCardWidget(
                  quoteData: quoteData,
                  onLikeChanged: _onLikeChanged,
                  onCommentPosted: _onCommentPosted,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildQuoteOnlyFeed() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _feedItems.length + (_isFetchingMore ? 1 : 0),
      onPageChanged: (index) {
        if (index < _feedItems.length) {
          final quoteData = _feedItems[index];
          final quoteId = quoteData['id'] as String?;
          final allCurrentlySeenIds = {
            ..._persistentSeenIds,
            ..._sessionOnlySeenIds
          };
          if (quoteId != null && !allCurrentlySeenIds.contains(quoteId)) {
            setState(() {
              _sessionOnlySeenIds.add(quoteId);
              _persistentSeenIds.add(quoteId);
            });
          }
        }
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
            // ✅ 4. PASSA AS FUNÇÕES DE CALLBACK AQUI TAMBÉM (PARA USUÁRIOS PREMIUM)
            child: QuoteCardWidget(
              quoteData: quoteData,
              onLikeChanged: _onLikeChanged,
              onCommentPosted: _onCommentPosted,
            ),
          ),
        );
      },
    );
  }
}
