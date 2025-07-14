// lib/pages/library_page/book_search_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/library_page/recommendation_card.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart'; // Importa para ter acesso ao BookSearchState
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BookSearchPage extends StatefulWidget {
  const BookSearchPage({super.key});

  @override
  State<BookSearchPage> createState() => _BookSearchPageState();
}

class _BookSearchPageState extends State<BookSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  // O Timer de debounce não é mais necessário
  // Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Limpa os resultados de buscas anteriores ao entrar na tela, se houver
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (StoreProvider.of<AppState>(context, listen: false)
          .state
          .bookSearchState
          .recommendations
          .isNotEmpty) {
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(ClearBookRecommendationsAction());
      }
    });
  }

  // ✅ NOVA FUNÇÃO: Aciona a busca e gerencia o foco
  void _triggerSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      // Remove o foco do TextField para esconder o teclado
      FocusScope.of(context).unfocus();
      // Despacha a ação para o Redux iniciar a busca
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(SearchBookRecommendationsAction(query));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    // _debounce?.cancel(); // Não é mais necessário
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
            child: StoreConnector<AppState, bool>(
              // Conecta-se apenas ao estado de isLoading para o sufixo do TextField
              converter: (store) => store.state.bookSearchState.isLoading,
              builder: (context, isLoading) {
                return TextField(
                  controller: _searchController,
                  autofocus: true,
                  // onChanged: _onSearchChanged, // ✅ REMOVIDO: Não busca mais ao digitar

                  // ✅ NOVO: Aciona a busca ao pressionar Enter/Search no teclado
                  onSubmitted: (_) => _triggerSearch(),

                  // ✅ NOVO: Define a ação do teclado como "pesquisar"
                  textInputAction: TextInputAction.search,

                  decoration: InputDecoration(
                    hintText: "Descreva o que você busca ou sente...",
                    prefixIcon: const Icon(Icons.search_rounded),
                    // ✅ NOVO: Ícone de busca ou loading no final do campo
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded),
                            tooltip: "Buscar",
                            onPressed: _triggerSearch,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StoreConnector<AppState, BookSearchState>(
              converter: (store) => store.state.bookSearchState,
              builder: (context, state) {
                // ... (O resto do builder permanece exatamente o mesmo, pois já lida com os estados)
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
