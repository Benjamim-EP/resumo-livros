// lib/pages/bibtok_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Este será o widget do card da frase, que estilizaremos mais tarde.
class QuoteCardWidget extends StatelessWidget {
  final Map<String, dynamic> quoteData;
  const QuoteCardWidget({super.key, required this.quoteData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.2)
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '"${quoteData['text']}"',
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
              "- ${quoteData['author']}, em '${quoteData['book']}'",
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
      print("BibTok: App pausado. Persistindo IDs da sessão...");
      _persistSessionIds();
    }
  }

  /// Carrega os dados iniciais e busca a primeira página do feed.
  Future<void> _initializeFeed() async {
    await _loadSeenQuotesFromPrefs();
    await _fetchAndBuildFeed(isInitialLoad: true);
    _syncWithPersistentStorage();
  }

  /// Carrega a lista de IDs já vistos do cache local (SharedPreferences).
  Future<void> _loadSeenQuotesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final seenList = prefs.getStringList(_seenQuotesPrefsKey) ?? [];
    if (mounted) {
      setState(() {
        _persistentSeenIds = seenList.toSet();
      });
    }
  }

  /// Sincroniza o cache local com o armazenamento de longo prazo do Firestore.
  Future<void> _syncWithPersistentStorage() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    print(
        "BibTok: Iniciando sincronização com Firestore..."); // << SEU PRINT ESTÁ AQUI

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

  /// Salva a lista completa de IDs vistos no cache local.
  Future<void> _saveSeenQuotesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final limitedList =
        _persistentSeenIds.toList().reversed.take(1000).toList();
    await prefs.setStringList(_seenQuotesPrefsKey, limitedList);
  }

  /// Orquestra a busca, filtragem e construção do feed.
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
              seenIdsToFilter: allSeenIdsToFilter),
          _fetchQuotesFromBackend(
              type: 'random',
              count: randomCount,
              seenIdsToFilter: allSeenIdsToFilter),
        ]);
        newQuotes.addAll(results[0]);
        newQuotes.addAll(results[1]);
      } else {
        newQuotes = await _fetchQuotesFromBackend(
            type: 'random',
            count: batchSize,
            seenIdsToFilter: allSeenIdsToFilter);
      }

      if (mounted) {
        setState(() {
          _feedItems.addAll(newQuotes);
          for (var quote in newQuotes) {
            _sessionOnlySeenIds.add(quote['id']);
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

  /// Função auxiliar que chama a Cloud Function e filtra localmente.
  Future<List<Map<String, dynamic>>> _fetchQuotesFromBackend(
      {required String type,
      required int count,
      required Set<String> seenIdsToFilter}) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('getQuotesFromPinecone');
      final result = await callable
          .call<Map<String, dynamic>>({'type': type, 'count': count});
      final List<Map<String, dynamic>> fetchedQuotes =
          (result.data['quotes'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      return fetchedQuotes
          .where((quote) => !seenIdsToFilter.contains(quote['id']))
          .toList();
    } catch (e) {
      print("Erro ao chamar getQuotesFromPinecone (type: $type): $e");
      return [];
    }
  }

  /// Salva os IDs vistos na sessão para o Firestore.
  Future<void> _persistSessionIds() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _sessionOnlySeenIds.isEmpty) return;

    // Faz uma cópia dos IDs para salvar e limpa a lista da sessão imediatamente
    final Set<String> idsToSave = Set.from(_sessionOnlySeenIds);
    if (mounted) {
      setState(() {
        _sessionOnlySeenIds.clear();
      });
    }

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
      // Atualiza o cache principal em memória com os novos IDs salvos
      if (mounted) {
        setState(() {
          _persistentSeenIds.addAll(idsToSave);
        });
        await _saveSeenQuotesToPrefs(); // Atualiza também o cache do dispositivo
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
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(
                    "https://picsum.photos/900/1600?random=${Random().nextInt(1000)}"),
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
