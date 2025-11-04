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

// ### START OF CORRECTION 1/3: ADDING 'with WidgetsBindingObserver' BACK ###
class _BibTokPageState extends State<BibTokPage> with WidgetsBindingObserver {
  // Estados do feed principal
  final PageController _pageController = PageController();
  bool _isLoading = true;
  bool _isFetchingMore = false;
  List<Map<String, dynamic>> _feedItems = [];
  Set<String> _persistentSeenIds = {};
  Set<String> _sessionOnlySeenIds = {};
  static const int _chunkSize = 10000;
  static const String _seenQuotesPrefsKey = 'bibtok_seen_ids_cache';
  final List<Map<String, dynamic>> _personalizedBuffer = [];
  final List<Map<String, dynamic>> _randomBuffer = [];
  final int _adInterval = 7;
  int _currentPageIndex = 0;

  // Estados da busca
  bool _isSearchModeActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  // ### START OF CORRECTION 2/3: RE-ADDING LIFECYCLE METHODS ###
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Register the observer
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
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this); // Unregister the observer
    _persistSessionIds(); // Final save on dispose
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // This is the crucial part that was missing
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistSessionIds();
    }
  }
  // ### END OF CORRECTION 2/3 ###

  // ... (O resto das suas funções permanece o mesmo)
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResults = [];
    });

    try {
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('semanticQuoteSearch');
      final result =
          await callable.call<Map<String, dynamic>>({'query': query});

      if (mounted) {
        final List<dynamic> resultsRaw = result.data['results'] ?? [];
        setState(() {
          _searchResults = resultsRaw
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted)
        setState(() => _searchError = e.message ?? "Ocorreu um erro na busca.");
    } catch (e) {
      if (mounted)
        setState(() => _searchError = "Falha na conexão. Tente novamente.");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearchModeActive = !_isSearchModeActive;
      if (!_isSearchModeActive) {
        _searchController.clear();
        _searchResults = [];
        _searchError = null;
      }
    });
  }

  void _onLikeChanged(String quoteId, bool isNowLiked, int newLikeCount) {
    if (!mounted) return;

    _updateItemInList(_feedItems, quoteId, isNowLiked, newLikeCount);
    _updateItemInList(_searchResults, quoteId, isNowLiked, newLikeCount);

    setState(() {});
  }

  void _updateItemInList(List<Map<String, dynamic>> list, String quoteId,
      bool isNowLiked, int newLikeCount) {
    final index = list.indexWhere((quote) => quote['id'] == quoteId);
    if (index == -1) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    list[index]['likeCount'] = newLikeCount;
    final List<dynamic> likedBy = List.from(list[index]['likedBy'] ?? []);
    if (isNowLiked) {
      if (!likedBy.contains(currentUserId)) likedBy.add(currentUserId);
    } else {
      likedBy.remove(currentUserId);
    }
    list[index]['likedBy'] = likedBy;
  }

  void _onCommentPosted(String quoteId) async {
    if (!mounted) return;
    try {
      final quoteDoc = await FirebaseFirestore.instance
          .collection('quotes')
          .doc(quoteId)
          .get();
      if (!quoteDoc.exists) return;
      final newCommentCount = quoteDoc.data()?['commentCount'] ?? 0;

      final feedIndex =
          _feedItems.indexWhere((quote) => quote['id'] == quoteId);
      if (feedIndex != -1)
        _feedItems[feedIndex]['commentCount'] = newCommentCount;

      final searchIndex =
          _searchResults.indexWhere((quote) => quote['id'] == quoteId);
      if (searchIndex != -1)
        _searchResults[searchIndex]['commentCount'] = newCommentCount;

      setState(() {});
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
    if (mounted) {
      setState(() {
        if (isInitialLoad)
          _isLoading = true;
        else
          _isFetchingMore = true;
      });
    }
    try {
      bool primaryFeedSuccess = false;
      if (_personalizedBuffer.length < 5 || _randomBuffer.length < 15) {
        primaryFeedSuccess = await _fetchAndFillBuffers();
      } else {
        primaryFeedSuccess = true;
      }
      if (!primaryFeedSuccess) {
        await _fetchFallbackQuotesFromFirestore();
      }
      final List<Map<String, dynamic>> newItemsToDisplay = [];
      int itemsAdded = 0;
      const int batchSize = 10;
      while (itemsAdded < batchSize &&
          (_personalizedBuffer.isNotEmpty || _randomBuffer.isNotEmpty)) {
        if (_personalizedBuffer.isNotEmpty) {
          newItemsToDisplay.add(_personalizedBuffer.removeAt(0));
          itemsAdded++;
        }
        int randomsToAdd = 0;
        while (randomsToAdd < 3 && _randomBuffer.isNotEmpty) {
          newItemsToDisplay.add(_randomBuffer.removeAt(0));
          randomsToAdd++;
          itemsAdded++;
        }
      }
      if (newItemsToDisplay.isNotEmpty && mounted) {
        setState(() {
          _feedItems.addAll(newItemsToDisplay);
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<bool> _fetchAndFillBuffers() async {
    try {
      const int personalizedCount = 10;
      const int randomCount = 30;
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('getBibTokFeed');
      final result = await callable.call<Map<String, dynamic>>(
          {'count': max(personalizedCount, randomCount)});
      final data = result.data;
      final List<dynamic> personalized = data['personalized_quotes'] ?? [];
      final List<dynamic> random = data['random_quotes'] ?? [];
      if (personalized.isEmpty && random.isEmpty) return false;
      final allSeenIdsToFilter = {
        ..._persistentSeenIds,
        ..._sessionOnlySeenIds
      };
      final unseenPersonalized = personalized
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((quote) =>
              !allSeenIdsToFilter.contains(quote['id']) &&
              !_personalizedBuffer.any((b) => b['id'] == quote['id']));
      final unseenRandom = random
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((quote) =>
              !allSeenIdsToFilter.contains(quote['id']) &&
              !_randomBuffer.any((b) => b['id'] == quote['id']));
      _personalizedBuffer.addAll(unseenPersonalized);
      _randomBuffer.addAll(unseenRandom);
      return true;
    } catch (e) {
      print("Erro ao preencher os buffers de frases (Cloud Function): $e");
      return false;
    }
  }

  Future<void> _fetchFallbackQuotesFromFirestore() async {
    try {
      const int fallbackLimit = 20;
      final allSeenIdsToFilter = {
        ..._persistentSeenIds,
        ..._sessionOnlySeenIds
      };
      String randomId =
          FirebaseFirestore.instance.collection('quotes').doc().id;
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('quotes')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: randomId)
          .limit(fallbackLimit)
          .get();
      if (snapshot.docs.length < fallbackLimit) {
        final secondSnapshot = await FirebaseFirestore.instance
            .collection('quotes')
            .limit(fallbackLimit - snapshot.docs.length)
            .get();
        snapshot.docs.addAll(secondSnapshot.docs);
      }
      final newQuotes = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          })
          .where((quote) =>
              !allSeenIdsToFilter.contains(quote['id']) &&
              !_randomBuffer.any((b) => b['id'] == quote['id']))
          .toList();
      if (newQuotes.isNotEmpty) _randomBuffer.addAll(newQuotes);
    } catch (e) {
      print("BibTokPage Fallback: ERRO ao buscar frases do Firestore: $e");
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
          'createdAt': FieldValue.serverTimestamp()
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

  AppBar _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    if (_isSearchModeActive) {
      return AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: _toggleSearchMode),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Buscar por tema, autor, sentimento...',
              border: InputBorder.none),
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _performSearch)
        ],
      );
    } else {
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              tooltip: "Buscar Frases",
              onPressed: _toggleSearchMode)
        ],
      );
    }
  }

  Widget _buildSearchResultsView() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0), child: Text(_searchError!)));
    }
    if (_searchResults.isEmpty) {
      return const Center(
          child: Text("Nenhum resultado encontrado para sua busca."));
    }
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final quoteData = _searchResults[index];
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

  Widget _buildFeedView(BuildContext context, _BibTokViewModel viewModel) {
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
                  "Não foi possível carregar o feed. Toque para tentar novamente."),
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
    } else {
      return buildFeedWithAds();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _BibTokViewModel>(
      converter: (store) => _BibTokViewModel.fromStore(store),
      onInit: (store) {
        final userState = store.state.userState;
        if ((userState.isGuestUser || userState.userDetails != null) &&
            !_isSearchModeActive) {
          _initializeFeed();
        }
      },
      onWillChange: (previousViewModel, newViewModel) {
        if (previousViewModel?.userDetails == null &&
            newViewModel.userDetails != null &&
            !_isSearchModeActive) {
          _initializeFeed();
        }
      },
      builder: (context, viewModel) {
        return Scaffold(
          extendBodyBehindAppBar: !_isSearchModeActive,
          appBar: _buildAppBar(context),
          body: _isSearchModeActive
              ? _buildSearchResultsView()
              : _buildFeedView(context, viewModel),
        );
      },
    );
  }

  Widget buildFeedWithAds() {
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
              pageController: _pageController, currentPageIndex: index);
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
                image:
                    NetworkImage("https://picsum.photos/seed/$quoteId/450/800"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.4), BlendMode.darken),
              ),
            ),
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
