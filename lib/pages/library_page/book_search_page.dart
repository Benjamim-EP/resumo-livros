// lib/pages/library_page/book_search_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/library_page/recommendation_card.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BookSearchPage extends StatefulWidget {
  const BookSearchPage({super.key});

  @override
  State<BookSearchPage> createState() => _BookSearchPageState();
}

class _BookSearchPageState extends State<BookSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Limpa os resultados anteriores ao entrar na tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(ClearBookRecommendationsAction());
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), () {
      if (query.trim().length > 3) {
        // Só busca se tiver mais de 3 caracteres
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(SearchBookRecommendationsAction(query.trim()));
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Encontre um Livro"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Descreva o que você busca ou sente...",
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: StoreConnector<AppState, BookSearchState>(
              converter: (store) => store.state.bookSearchState,
              builder: (context, state) {
                // Estado de Loading
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Estado de Erro
                if (state.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        "Ocorreu um erro: ${state.error}",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  );
                }

                // Estado de Sucesso com Resultados
                if (state.recommendations.isNotEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: state.recommendations.length,
                    itemBuilder: (context, index) {
                      final recommendation = state.recommendations[index];
                      return RecommendationCard(recommendation: recommendation)
                          .animate()
                          .fadeIn(duration: 500.ms, delay: (150 * index).ms)
                          .slideY(begin: 0.2, curve: Curves.easeOutCubic);
                    },
                  );
                }

                // Estado Inicial ou Sem Resultados
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      state.currentQuery.isEmpty
                          ? "Descreva um sentimento, uma dúvida ou um tema para encontrar o livro perfeito para você."
                          : "Nenhum livro encontrado para '${state.currentQuery}'. Tente outros termos.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.7)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
