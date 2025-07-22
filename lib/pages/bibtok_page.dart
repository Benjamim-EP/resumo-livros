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

  bool _isScrollLocked = false;

  final int _adInterval = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        // Despacha a ação para buscar os detalhes do usuário.
        // O `_initializeFeed` será chamado pelo `StoreConnector` quando os dados chegarem.
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
      // >>>>> INÍCIO DA CORREÇÃO <<<<<
      // Lê o estado MAIS ATUALIZADO diretamente da store antes de fazer a chamada.
      final interactions =
          store.state.userState.userDetails?['recentInteractions'];
      final bool hasInteractions =
          interactions != null && (interactions as List).isNotEmpty;

      print(
          "BibTokPage: Verificando interações antes de chamar o backend. hasInteractions: $hasInteractions");

      const batchSize = 10;
      List<Map<String, dynamic>> newQuotes = [];
      Set<String> allSeenIdsToFilter = {
        ..._persistentSeenIds,
        ..._sessionOnlySeenIds
      };

      if (hasInteractions) {
        print(
            "BibTokPage: ESTRATÉGIA MISTA. Chamando 'personalized' e 'random'.");
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
        print("BibTokPage: ESTRATÉGIA ALEATÓRIA. Chamando apenas 'random'.");
        newQuotes =
            await _fetchQuotesFromBackend(type: 'random', count: batchSize);
      }
      // >>>>> FIM DA CORREÇÃO <<<<<

      final unseenQuotes = newQuotes
          .where((quote) => !allSeenIdsToFilter.contains(quote['id']))
          .toList();

      if (mounted) {
        setState(() {
          _feedItems.addAll(unseenQuotes);

          // >>>>> CORREÇÃO 1: REMOVER A LÓGICA DE "VISTO" DAQUI <<<<<
          // A lógica de adicionar aos `_seenQuotesIds` e `_sessionOnlySeenIds`
          // será movida para o `onPageChanged` do PageView.

          // Se for o carregamento inicial e tivermos itens, marcamos o PRIMEIRO item como visto.
          if (isInitialLoad && _feedItems.isNotEmpty) {
            final firstQuoteId = _feedItems.first['id'] as String?;
            if (firstQuoteId != null &&
                !_sessionOnlySeenIds.contains(firstQuoteId)) {
              print(
                  "BibTok: Marcando o primeiro item '${firstQuoteId.substring(0, 8)}...' como visto.");
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

      // Adicionando log para ver exatamente o que está sendo enviado
      print("--> Chamando getBibTokFeed com: type='$type', count=$count");

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

  Widget buildQuoteOnlyFeed() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _feedItems.length + (_isFetchingMore ? 1 : 0),
      onPageChanged: (index) {
        // Lógica de onPageChanged original, sem cálculo de offset
        if (index < _feedItems.length) {
          final quoteData = _feedItems[index];
          final quoteId = quoteData['id'] as String?;
          final allCurrentlySeenIds = {
            ..._persistentSeenIds,
            ..._sessionOnlySeenIds
          };

          if (quoteId != null && !allCurrentlySeenIds.contains(quoteId)) {
            print(
                "BibTok (Premium): Nova frase VISUALIZADA no índice $index. Marcando '${quoteId.substring(0, 8)}...' como visto.");
            setState(() {
              _sessionOnlySeenIds.add(quoteId);
              _persistentSeenIds.add(quoteId);
            });
          }
        }

        // Lógica de paginação
        if (index >= _feedItems.length - 3 && !_isFetchingMore) {
          _fetchAndBuildFeed();
        }
      },
      itemBuilder: (context, index) {
        // Mostra o loader no final, se estiver buscando mais
        if (index == _feedItems.length) {
          return const Center(child: CircularProgressIndicator());
        }

        // Constrói o card da frase
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
        // 1. Estado de Carregamento Inicial
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Estado de Feed Vazio (após o carregamento)
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

        // 3. Lógica Principal: Divide a UI com base no status Premium

        // Se o usuário for premium, mostramos o feed simples e sem anúncios.
        if (viewModel.isPremium) {
          return buildQuoteOnlyFeed();
        }

        // Se não for premium, construímos o feed com os anúncios intercalados.
        final adCount = (_feedItems.length / _adInterval).floor();
        final totalItemCount =
            _feedItems.length + adCount + (_isFetchingMore ? 1 : 0);
        final adSlotRatio = _adInterval + 1; // O anúncio é o 8º item (índice 7)

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          // Trava o scroll se a flag _isScrollLocked for verdadeira
          physics:
              _isScrollLocked ? const NeverScrollableScrollPhysics() : null,
          itemCount: totalItemCount,
          onPageChanged: (index) {
            // A lógica de marcar como visto precisa ajustar o índice
            // para ignorar os anúncios.
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
                print(
                    "BibTok: Nova frase VISUALIZADA no índice $quoteIndex. Marcando '${quoteId.substring(0, 8)}...' como visto.");
                setState(() {
                  _sessionOnlySeenIds.add(quoteId);
                  _persistentSeenIds.add(quoteId);
                });
              }
            }

            // Lógica de paginação ajustada para carregar mais itens
            if (quoteIndex >= _feedItems.length - 3 && !_isFetchingMore) {
              _fetchAndBuildFeed();
            }
          },
          itemBuilder: (context, index) {
            // Se for o último item da lista e estivermos buscando mais, mostra o loader.
            if (index == totalItemCount - 1 && _isFetchingMore) {
              return const Center(child: CircularProgressIndicator());
            }

            // Verifica se a posição atual é um "slot" para o anúncio
            if ((index + 1) % adSlotRatio == 0 && index != 0) {
              return PremiumAdCard(
                onTimerStart: () => setState(() => _isScrollLocked = true),
                onTimerEnd: () => setState(() => _isScrollLocked = false),
              );
            }

            // Se não for um anúncio, calcula o índice correto para a lista de frases
            final adOffset = ((index + 1) / adSlotRatio).floor();
            final quoteIndex = index - adOffset;

            // Verificação de segurança para evitar RangeError em casos raros
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
                        "https://picsum.photos/seed/$quoteId/450/800"),
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
      },
    );
  }
}
