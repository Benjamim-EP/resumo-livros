// lib/pages/book_details_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:septima_biblia/components/loadingauthorspage.dart'; // Reutilizando um placeholder de loading
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:redux/redux.dart';

// ViewModel para conectar a UI aos dados do livro no Redux
class _ViewModel {
  final Map<String, dynamic>? bookDetails;
  final bool isLoading;

  _ViewModel({this.bookDetails, required this.isLoading});

  static _ViewModel fromStore(Store<AppState> store, String bookId) {
    // Verifica se os detalhes deste livro específico já estão no estado
    final details = store.state.booksState.bookDetails?[bookId];
    return _ViewModel(
      bookDetails: details,
      // O loading pode ser um estado global ou derivado (se os detalhes são nulos, está carregando)
      isLoading: details == null,
    );
  }
}

class BookDetailsPage extends StatefulWidget {
  final String bookId;

  const BookDetailsPage({super.key, required this.bookId});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Função para abrir links da Amazon
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o link: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _ViewModel>(
      onInit: (store) {
        // Dispara a ação para carregar os detalhes do livro se ainda não estiverem no estado
        if (store.state.booksState.bookDetails?[widget.bookId] == null) {
          store.dispatch(LoadBookDetailsAction(widget.bookId));
        }
      },
      converter: (store) => _ViewModel.fromStore(store, widget.bookId),
      builder: (context, viewModel) {
        if (viewModel.isLoading) {
          // Reutilizando um placeholder existente para uma boa experiência de loading
          return const Scaffold(body: AuthorPageLoadingPlaceholder());
        }

        if (viewModel.bookDetails == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
                child: Text("Não foi possível carregar os detalhes do livro.")),
          );
        }

        final details = viewModel.bookDetails!;
        final String coverUrl = details['cover'] ?? '';
        final String title = details['titulo'] ?? 'Sem Título';
        final String author = details['authorId'] ??
            'Autor Desconhecido'; // Note que aqui vem o ID do autor

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 250.0,
                  floating: false,
                  pinned: true,
                  stretch: true,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.0,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                      ),
                    ),
                    background: coverUrl.isNotEmpty
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            color: Colors.black.withOpacity(0.4),
                            colorBlendMode: BlendMode.darken,
                          )
                        : Container(color: Colors.grey),
                  ),
                ),
              ];
            },
            body: Column(
              children: [
                // Informações básicas abaixo da AppBar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      // TODO: No futuro, você pode querer buscar o nome do autor a partir do 'authorId'
                      Text(author,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),

                // Abas para organizar o conteúdo
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Sobre'),
                    Tab(text: 'Aplicações'),
                    Tab(text: 'Versões'),
                  ],
                ),

                // Conteúdo das abas
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Aba "Sobre"
                      _buildMarkdownContent(
                          details['resumo'], details['temas']),

                      // Aba "Aplicações"
                      _buildMarkdownContent(
                          details['aplicacoes'], details['perfil_leitor']),

                      // Aba "Versões"
                      _buildVersionsList(
                          details['versoes'] as List<dynamic>? ?? []),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget para renderizar conteúdo Markdown
  Widget _buildMarkdownContent(String? mainContent, String? secondaryContent) {
    String fullContent =
        (mainContent ?? '') + '\n\n' + (secondaryContent ?? '');
    if (fullContent.trim().isEmpty) {
      return const Center(child: Text("Nenhuma informação disponível."));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: MarkdownBody(
        data: fullContent,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ),
    );
  }

  // Widget para listar as versões disponíveis para compra
  Widget _buildVersionsList(List<dynamic> versions) {
    if (versions.isEmpty) {
      return const Center(child: Text("Nenhuma versão de compra encontrada."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final version = versions[index] as Map<String, dynamic>;
        final String formato = version['formato'] ?? 'Formato desconhecido';
        final String link = version['link_amazon_br'] ?? '';
        final String tipo = version['tipo'] ?? '';

        IconData icon;
        switch (tipo.toLowerCase()) {
          case 'kindle':
            icon = Icons.menu_book_rounded;
            break;
          case 'impresso':
            icon = Icons.book_outlined;
            break;
          default:
            icon = Icons.shopping_cart_outlined;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: ListTile(
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(formato),
            trailing: const Icon(Icons.open_in_new, size: 20),
            onTap: link.isNotEmpty ? () => _launchURL(link) : null,
          ),
        );
      },
    );
  }
}
