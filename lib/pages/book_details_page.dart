// lib/pages/book_details_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:septima_biblia/components/loadingauthorspage.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:redux/redux.dart'; // Mantido para o tipo Store

// ViewModel (sem alterações)
class _ViewModel {
  final Map<String, dynamic>? bookDetails;
  final bool isLoading;

  _ViewModel({this.bookDetails, required this.isLoading});

  static _ViewModel fromStore(Store<AppState> store, String bookId) {
    final details = store.state.booksState.bookDetails?[bookId];
    return _ViewModel(
      bookDetails: details,
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
    // ✅ 1. AUMENTA O NÚMERO DE ABAS PARA 4
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir o link: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _ViewModel>(
      onInit: (store) {
        if (store.state.booksState.bookDetails?[widget.bookId] == null) {
          store.dispatch(LoadBookDetailsAction(widget.bookId));
        }
      },
      converter: (store) => _ViewModel.fromStore(store, widget.bookId),
      builder: (context, viewModel) {
        if (viewModel.isLoading) {
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
        final String authorId = details['authorId'] ?? 'Autor Desconhecido';

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  expandedHeight: 280.0,
                  floating: false,
                  pinned: true,
                  stretch: true,
                  flexibleSpace: FlexibleSpaceBar(
                    centerTitle: true,
                    titlePadding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 12),
                    title: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        coverUrl.isNotEmpty
                            ? Image.network(coverUrl, fit: BoxFit.cover)
                            : Container(color: Colors.grey.shade800),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8)
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(authorId,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),

                // ✅ 2. ATUALIZA A TABBAR COM A NOVA ABA "TEMAS"
                TabBar(
                  controller: _tabController,
                  // ✅ CORREÇÃO: Removido isScrollable, pois não é mais necessário
                  tabs: const [
                    // ✅ CORREÇÃO: Abas agora contêm apenas o ícone
                    Tab(icon: Icon(Icons.info_outline), text: "Resumo"),
                    Tab(icon: Icon(Icons.class_outlined), text: "Temas"),
                    Tab(
                        icon: Icon(Icons.lightbulb_outline),
                        text: "Aplicações"),
                    Tab(
                        icon: Icon(Icons.shopping_cart_outlined),
                        text: "Versões"),
                  ],
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ✅ 3. REORGANIZA O CONTEÚDO DAS ABAS
                      // Aba "Resumo" - Apenas o resumo
                      _buildMarkdownContent(context,
                          title: null, content: details['resumo']),

                      // Aba "Temas" - Apenas os temas
                      _buildMarkdownContent(context,
                          title: null, content: details['temas']),

                      // Aba "Aplicações" - Aplicações e Perfil do Leitor
                      _buildMarkdownContent(
                        context,
                        title: "Aplicações Práticas",
                        content: details['aplicacoes'],
                        secondaryTitle: "Recomendado Para",
                        secondaryContent: details['perfil_leitor'],
                      ),

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
  Widget _buildMarkdownContent(
    BuildContext context, {
    String? title,
    String? content,
    String? secondaryTitle,
    String? secondaryContent,
  }) {
    final theme = Theme.of(context);
    final List<Widget> children = [];

    if (title != null) {
      children.add(Text(title, style: theme.textTheme.titleLarge));
      children.add(const SizedBox(height: 8));
    }

    if (content != null && content.isNotEmpty) {
      children.add(MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            listBullet: theme.textTheme.bodyLarge),
      ));
    }

    if (secondaryTitle != null &&
        secondaryContent != null &&
        secondaryContent.isNotEmpty) {
      children.add(const Divider(height: 32));
      children.add(Text(secondaryTitle, style: theme.textTheme.titleLarge));
      children.add(const SizedBox(height: 8));
      children.add(MarkdownBody(
        data: secondaryContent,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            listBullet: theme.textTheme.bodyLarge),
      ));
    }

    if (children.isEmpty) {
      return const Center(child: Text("Nenhuma informação disponível."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // Widget para listar as versões disponíveis para compra
  Widget _buildVersionsList(List<dynamic> versions) {
    // ... (esta função permanece a mesma)
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
