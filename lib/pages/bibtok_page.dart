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

class _BibTokPageState extends State<BibTokPage> {
  final PageController _pageController = PageController();

  // Estados para gerenciar o feed
  bool _isLoading = true;
  bool _isFetchingMore = false;
  List<Map<String, dynamic>> _feedItems = [];

  // --- NOVOS ESTADOS PARA PERSISTÊNCIA ---
  Set<String> _persistentSeenIds = {}; // IDs de chunks do Firestore
  Set<String> _sessionSeenIds = {}; // IDs vistos apenas nesta sessão

  static const int _chunkSize = 10000; // Limite de IDs por documento

  @override
  void initState() {
    super.initState();
    _initializeFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _persistSessionIds(); // <<<< CHAMA A PERSISTÊNCIA AO SAIR
    super.dispose();
  }

  /// Carrega os dados iniciais e busca a primeira página do feed.
  Future<void> _initializeFeed() async {
    await _loadPersistentSeenQuotes();
    await _fetchAndBuildFeed(isInitialLoad: true);
  }

  /// Carrega TODOS os IDs já vistos do Firestore para a memória.
  Future<void> _loadPersistentSeenQuotes() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('viewed_quotes_chunks')
          .get();

      Set<String> allSeenIds = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('quotes') && data['quotes'] is List) {
          allSeenIds.addAll(List<String>.from(data['quotes']));
        }
      }

      if (mounted) {
        setState(() {
          _persistentSeenIds = allSeenIds;
        });
      }
    } catch (e) {
      print("Erro ao carregar chunks de frases vistas: $e");
    }
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
      Set<String> allSeenIds = {..._persistentSeenIds, ..._sessionSeenIds};

      if (hasInteractions) {
        final personalizedCount = (batchSize * 0.7).round();
        final randomCount = batchSize - personalizedCount;

        final results = await Future.wait([
          _fetchQuotesFromBackend(
              type: 'personalized',
              count: personalizedCount,
              seenIds: allSeenIds),
          _fetchQuotesFromBackend(
              type: 'random', count: randomCount, seenIds: allSeenIds),
        ]);

        newQuotes.addAll(results[0]);
        newQuotes.addAll(results[1]);
      } else {
        newQuotes = await _fetchQuotesFromBackend(
            type: 'random', count: batchSize, seenIds: allSeenIds);
      }

      // Filtra localmente os IDs que já foram vistos nesta sessão (dupla garantia)
      final unseenQuotes = newQuotes
          .where((quote) => !_sessionSeenIds.contains(quote['id']))
          .toList();

      if (mounted) {
        setState(() {
          _feedItems.addAll(unseenQuotes);
          // Adiciona os novos IDs à lista de vistos da sessão
          for (var quote in unseenQuotes) {
            _sessionSeenIds.add(quote['id']);
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

  /// Função auxiliar que chama a Cloud Function.
  /// AGORA ELA NÃO ENVIA MAIS OS IDs VISTOS, POIS A FUNÇÃO FOI SIMPLIFICADA
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
        // O backend foi simplificado e não recebe mais os seenIds
      });
      final List<Map<String, dynamic>> fetchedQuotes =
          (result.data['quotes'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

      // A filtragem agora acontece AQUI no frontend
      return fetchedQuotes
          .where((quote) => !seenIds.contains(quote['id']))
          .toList();
    } catch (e) {
      print("Erro ao chamar getQuotesFromPinecone (type: $type): $e");
      return [];
    }
  }

  /// Salva os IDs vistos na sessão para o Firestore.
  Future<void> _persistSessionIds() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _sessionSeenIds.isEmpty) return;

    print(
        "Persistindo ${_sessionSeenIds.length} novos IDs vistos para o Firestore...");

    try {
      final chunksRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('viewed_quotes_chunks');

      // 1. Encontra o último chunk para ver se há espaço
      final lastChunkQuery =
          chunksRef.orderBy('createdAt', descending: true).limit(1);
      final lastChunkSnapshot = await lastChunkQuery.get();

      DocumentReference targetChunkRef;
      List<dynamic> currentQuotes = [];
      int newChunkId = 0;

      if (lastChunkSnapshot.docs.isNotEmpty) {
        final lastChunkDoc = lastChunkSnapshot.docs.first;
        currentQuotes = List.from(lastChunkDoc.data()['quotes'] ?? []);

        if (currentQuotes.length < _chunkSize) {
          targetChunkRef = lastChunkDoc.reference;
          newChunkId = int.parse(lastChunkDoc.id);
        } else {
          // Chunk está cheio, prepara para criar um novo
          newChunkId = int.parse(lastChunkDoc.id) + 1;
          targetChunkRef = chunksRef.doc(newChunkId.toString());
          currentQuotes = []; // O novo chunk começa vazio
        }
      } else {
        // Nenhum chunk existe, cria o primeiro
        targetChunkRef = chunksRef.doc('0');
      }

      List<String> idsToProcess = _sessionSeenIds.toList();

      while (idsToProcess.isNotEmpty) {
        final spaceLeft = _chunkSize - currentQuotes.length;
        final idsToAdd = idsToProcess.take(spaceLeft).toList();
        idsToProcess = idsToProcess.sublist(idsToAdd.length);

        // Atualiza o chunk atual
        if (targetChunkRef.path.contains(newChunkId.toString())) {
          // Verifica se estamos no chunk correto
          await targetChunkRef.set({
            'quotes': FieldValue.arrayUnion(idsToAdd),
            'count': FieldValue.increment(idsToAdd.length),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Se ainda houver IDs restantes, cria um novo chunk para eles
        if (idsToProcess.isNotEmpty) {
          newChunkId++;
          targetChunkRef = chunksRef.doc(newChunkId.toString());
          currentQuotes = []; // Reseta para o próximo loop
        }
      }

      // Limpa os IDs da sessão após salvar
      _sessionSeenIds.clear();
      print("Persistência no Firestore concluída.");
    } catch (e) {
      print("Erro ao persistir IDs vistos no Firestore: $e");
      // Opcional: Salvar no SharedPreferences como fallback em caso de erro
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_feedItems.isEmpty) {
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
      itemCount: _feedItems.length + 1,
      onPageChanged: (index) {
        if (index >= _feedItems.length - 3) {
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
