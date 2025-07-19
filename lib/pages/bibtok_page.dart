// lib/pages/bibtok_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Este será o widget do card da frase, que estilizaremos mais tarde.
// Por enquanto, um placeholder aprimorado.
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
  Set<String> _seenQuotesIds =
      {}; // IDs vistos na sessão atual E em sessões passadas

  static const String _seenQuotesPrefsKey = 'bibtok_seen_ids_persistent';
  static const int _batchSize = 10; // Total de itens a buscar por vez

  @override
  void initState() {
    super.initState();
    _initializeFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Carrega os dados iniciais e busca a primeira página do feed.
  Future<void> _initializeFeed() async {
    await _loadSeenQuotesFromPrefs();
    await _fetchAndBuildFeed(isInitialLoad: true);
  }

  /// Carrega a lista de IDs já vistos do armazenamento local.
  Future<void> _loadSeenQuotesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final seenList = prefs.getStringList(_seenQuotesPrefsKey) ?? [];
    if (mounted) {
      setState(() {
        _seenQuotesIds = seenList.toSet();
      });
    }
  }

  /// Salva os IDs vistos no armazenamento local.
  Future<void> _saveSeenQuotesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Limita o armazenamento local a 1000 itens para não crescer indefinidamente
    final limitedList = _seenQuotesIds.toList().reversed.take(1000).toList();
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

      List<Map<String, dynamic>> newQuotes = [];

      if (hasInteractions) {
        // --- Estratégia Mista (Personalizada + Aleatória) ---
        final personalizedCount = (_batchSize * 0.7).round();
        final randomCount = _batchSize - personalizedCount;

        // Faz as duas chamadas em paralelo
        final results = await Future.wait([
          _fetchQuotesFromBackend(
              type: 'personalized', count: personalizedCount),
          _fetchQuotesFromBackend(type: 'random', count: randomCount),
        ]);

        final personalizedResults = results[0];
        final randomResults = results[1];
        newQuotes.addAll(personalizedResults);
        newQuotes.addAll(randomResults);
      } else {
        // --- Estratégia 100% Aleatória ---
        newQuotes =
            await _fetchQuotesFromBackend(type: 'random', count: _batchSize);
      }

      // Filtra localmente os IDs que já foram vistos
      final unseenQuotes = newQuotes
          .where((quote) => !_seenQuotesIds.contains(quote['id']))
          .toList();

      if (mounted) {
        setState(() {
          _feedItems.addAll(unseenQuotes);
          // Adiciona os novos IDs à lista de vistos da sessão
          for (var quote in unseenQuotes) {
            _seenQuotesIds.add(quote['id']);
          }
        });
      }
      // Salva a lista atualizada de vistos para a próxima sessão
      await _saveSeenQuotesToPrefs();
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
  Future<List<Map<String, dynamic>>> _fetchQuotesFromBackend(
      {required String type, required int count}) async {
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('getQuotesFromPinecone');

      final result = await callable.call<Map<String, dynamic>>({
        'type': type,
        'count': count,
      });

      return (result.data['quotes'] as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      print("Erro ao chamar getQuotesFromPinecone (type: $type): $e");
      return []; // Retorna lista vazia em caso de erro para não quebrar o fluxo
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
          // O último item é o indicador de "carregando mais"
          return const Center(child: CircularProgressIndicator());
        }

        final quoteData = _feedItems[index];
        return Padding(
          padding: const EdgeInsets.all(8.0),
          // Usando um placeholder com uma imagem de fundo aleatória para visualização
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(
                    "https://picsum.photos/900/1600?random=${Random().nextInt(1000)}"),
                fit: BoxFit.cover,
                // Um filtro escuro para melhorar a legibilidade do texto
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
