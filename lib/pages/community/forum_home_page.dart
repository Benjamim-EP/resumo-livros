// lib/pages/community/forum_home_page.dart (Versão Final Refatorada)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/community/post_detail_page.dart';
import 'package:septima_biblia/redux/actions/community_actions.dart';
import 'package:septima_biblia/redux/reducers/community_search_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/custom_page_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForumHomePage extends StatefulWidget {
  const ForumHomePage({super.key});

  @override
  State<ForumHomePage> createState() => _ForumHomePageState();
}

class _ForumHomePageState extends State<ForumHomePage> {
  // --- CHAVES E CONSTANTES ---
  static const String _unlockedPostsKey = 'unlocked_forum_posts';
  static const int _postsPerPage = 20;

  // --- ESTADO PARA GERENCIAR PAGINAÇÃO E FILTROS ---
  String? _selectedCategory;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<DocumentSnapshot> _posts = [];
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();

  // --- ESTADO PARA A BUSCA ---
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'value': 'apologetica', 'label': 'Apologética'},
    {'value': 'teologia_sistematica', 'label': 'Teologia'},
    {'value': 'vida_crista', 'label': 'Vida Cristã'},
    {'value': 'duvidas_gerais', 'label': 'Dúvidas'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialPosts();
    _scrollController.addListener(_scrollListener);
    // Adiciona um listener para reconstruir a UI quando o texto de busca muda (para mostrar/esconder o botão de limpar)
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _fetchMorePosts();
    }
  }

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true);

    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query;
  }

  Future<void> _fetchInitialPosts() async {
    // Sempre que buscamos os posts iniciais, limpamos qualquer resultado de busca anterior
    StoreProvider.of<AppState>(context, listen: false)
        .dispatch(ClearCommunitySearchResultsAction());

    try {
      Query query = _buildQuery().limit(_postsPerPage);
      final querySnapshot = await query.get();

      if (mounted) {
        setState(() {
          _posts = querySnapshot.docs;
          _lastDocument =
              querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
          _hasMore = querySnapshot.docs.length == _postsPerPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erro ao buscar posts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      Query query =
          _buildQuery().startAfterDocument(_lastDocument!).limit(_postsPerPage);
      final querySnapshot = await query.get();
      if (mounted) {
        setState(() {
          _posts.addAll(querySnapshot.docs);
          _lastDocument = querySnapshot.docs.isNotEmpty
              ? querySnapshot.docs.last
              : _lastDocument;
          _hasMore = querySnapshot.docs.length == _postsPerPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print("Erro ao buscar mais posts: $e");
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // <<< FUNÇÃO ATUALIZADA >>>
  // Agora, ao filtrar, também limpamos a busca semântica
  void _onFilterChanged(String? newCategory) {
    if (_selectedCategory == newCategory) return;

    // Limpa a busca ao aplicar um filtro
    _searchController.clear();
    StoreProvider.of<AppState>(context, listen: false)
        .dispatch(ClearCommunitySearchResultsAction());

    setState(() {
      _selectedCategory = newCategory;
      _posts = [];
      _lastDocument = null;
      _hasMore = true;
      _isLoading = true;
    });

    _fetchInitialPosts();
  }

  // <<< FUNÇÃO ATUALIZADA >>>
  // Ao buscar, limpamos o filtro de categoria para não limitar a busca
  void _triggerSearch() {
    final query = _searchController.text.trim();
    FocusScope.of(context).unfocus();

    if (query.isNotEmpty) {
      // Reseta o filtro de categoria para que a busca seja ampla
      setState(() {
        _selectedCategory = null;
      });
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(SearchCommunityPostsAction(query));
    } else {
      // Se a busca for vazia, limpa tudo
      _clearAllFilters();
    }
  }

  // <<< NOVA FUNÇÃO PARA LIMPAR TUDO >>>
  void _clearAllFilters() {
    _searchController.clear();
    StoreProvider.of<AppState>(context, listen: false)
        .dispatch(ClearCommunitySearchResultsAction());
    // Chama a função de filtro com null, que já reseta e busca a lista inicial
    _onFilterChanged(null);
  }

  // (O resto das suas funções de helper como _handlePostTap, _getCategoryLabel, etc., permanecem iguais)
  Future<void> _handlePostTap(
      BuildContext context, String postId, bool isProtected) async {
    if (!isProtected) {
      Navigator.push(
          context, FadeScalePageRoute(page: PostDetailPage(postId: postId)));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final List<String> unlockedPosts =
        prefs.getStringList(_unlockedPostsKey) ?? [];
    if (unlockedPosts.contains(postId)) {
      Navigator.push(
          context, FadeScalePageRoute(page: PostDetailPage(postId: postId)));
    } else {
      final String? enteredPassword = await _showPasswordDialog(context);
      if (enteredPassword != null && enteredPassword.isNotEmpty) {
        await _verifyPassword(context, postId, enteredPassword);
      }
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Post Protegido por Senha"),
        content: TextField(
          controller: passwordController,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: "Senha", icon: Icon(Icons.lock_outline)),
          onSubmitted: (_) =>
              Navigator.pop(dialogContext, passwordController.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar")),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, passwordController.text),
              child: const Text("Entrar")),
        ],
      ),
    );
  }

  Future<void> _verifyPassword(
      BuildContext context, String postId, String password) async {
    showDialog(
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    try {
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('verifyPostPassword');
      final result = await callable
          .call<Map<String, dynamic>>({'postId': postId, 'password': password});
      if (!context.mounted) return;
      Navigator.pop(context);
      if (result.data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final List<String> unlockedPosts =
            prefs.getStringList(_unlockedPostsKey) ?? [];
        if (!unlockedPosts.contains(postId)) {
          unlockedPosts.add(postId);
          await prefs.setStringList(_unlockedPostsKey, unlockedPosts);
        }
        Navigator.push(
            context, FadeScalePageRoute(page: PostDetailPage(postId: postId)));
      } else {
        CustomNotificationService.showError(
            context, "Senha incorreta. Tente novamente.");
      }
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      CustomNotificationService.showError(
          context, e.message ?? "Ocorreu um erro ao verificar a senha.");
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      CustomNotificationService.showError(
          context, "Um erro inesperado ocorreu.");
    }
  }

  String _getCategoryLabel(String categoryValue) {
    final category = _categories.firstWhere(
        (cat) => cat['value'] == categoryValue,
        orElse: () => {'label': 'Geral'});
    return category['label']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StoreConnector<AppState, CommunitySearchState>(
        converter: (store) => store.state.communitySearchState,
        builder: (context, searchState) {
          final bool isSearchActive =
              searchState.currentQuery.isNotEmpty || searchState.isLoading;

          return Column(
            children: [
              _buildSearchAndFilterBar(),
              Expanded(
                child: isSearchActive
                    ? _buildSearchResults(searchState)
                    : _buildInitialPostList(),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/createPost'),
        tooltip: "Fazer uma pergunta",
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }

  /// <<< WIDGET DA BARRA DE FILTROS TOTALMENTE REFATORADO >>>
  Widget _buildSearchAndFilterBar() {
    final theme = Theme.of(context);
    final bool isAnyFilterActive =
        _selectedCategory != null || _searchController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _selectedCategory != null
                    ? "Buscar em '${_getCategoryLabel(_selectedCategory!)}'..."
                    : "Buscar no fórum...",
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _triggerSearch(),
              textInputAction: TextInputAction.search,
            ),
          ),

          // ✅ INÍCIO DA MUDANÇA

          // Botão para Recarregar a Lista
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.iconTheme.color),
            tooltip: "Recarregar Perguntas",
            // Desabilita o botão se já estiver carregando para evitar cliques duplos
            onPressed: _isLoading || _isLoadingMore ? null : _fetchInitialPosts,
          ),

          // ✅ FIM DA MUDANÇA

          // Menu Suspenso de Filtros
          PopupMenuButton<String?>(
            icon: Icon(Icons.filter_list, color: theme.iconTheme.color),
            tooltip: "Filtrar por Categoria",
            onSelected: _onFilterChanged,
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String?>(
                  value: null,
                  child: Text("Todas as Categorias",
                      style: TextStyle(
                          fontWeight: _selectedCategory == null
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ),
                ..._categories.map((category) {
                  return PopupMenuItem<String?>(
                    value: category['value'],
                    child: Text(category['label']!,
                        style: TextStyle(
                            fontWeight: _selectedCategory == category['value']
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  );
                }).toList(),
              ];
            },
          ),

          // Botão para limpar TUDO (só aparece se houver filtro ou busca)
          if (isAnyFilterActive)
            IconButton(
              icon: Icon(Icons.clear, size: 22, color: theme.colorScheme.error),
              tooltip: "Limpar Busca e Filtros",
              onPressed: _clearAllFilters,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(CommunitySearchState state) {
    // ... (seu código para _buildSearchResults permanece o mesmo, está correto)
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(child: Text("Erro: ${state.error}"));
    }
    if (state.results.isEmpty) {
      return Center(
          child: Text(
              "Nenhum resultado encontrado para '${state.currentQuery}'."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final result = state.results[index];
        final bool isProtected = result['isPasswordProtected'] ??
            false; // Adicione isso se o metadata tiver

        // Reutilizamos o Card do post, mas com os dados da busca
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _handlePostTap(context, result['id'], isProtected),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result['title'] ?? 'Sem Título',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(result['content_preview'] ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                          label: Text(
                              _getCategoryLabel(result['category'] ?? ''),
                              style: const TextStyle(fontSize: 10))),
                      const Spacer(),
                      Text(result['authorName'] ?? 'Anônimo',
                          style: Theme.of(context).textTheme.bodySmall)
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitialPostList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _selectedCategory == null
                ? "Nenhuma pergunta foi feita ainda.\nSeja o primeiro!"
                : "Nenhuma pergunta encontrada nesta categoria.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // ✅ INÍCIO DA MUDANÇA
    // Envolvemos o ListView.builder com o RefreshIndicator.
    return RefreshIndicator(
      // A mágica acontece aqui: onRefresh chama a mesma função que você usa para o carregamento inicial.
      onRefresh: _fetchInitialPosts,
      child: ListView.builder(
        // O ListView agora é um filho (child) do RefreshIndicator
        controller: _scrollController,
        padding: const EdgeInsets.all(12.0),
        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // A sua lógica de itemBuilder permanece exatamente a mesma.
          if (index == _posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final post = _posts[index];
          final data = post.data() as Map<String, dynamic>;
          final theme = Theme.of(context);
          final timestamp = data['timestamp'] as Timestamp?;
          final date = timestamp != null
              ? DateFormat('dd/MM/yy').format(timestamp.toDate())
              : '';
          final bibleReference = data['bibleReference'] as String?;
          final isProtected = data['isPasswordProtected'] ?? false;
          final authorPhotoUrl = data['authorPhotoUrl'] as String?;
          final authorName = data['authorName'] ?? 'Anônimo';
          final title = data['title'] ?? 'Pergunta sem título';
          final content = data['content'] as String?;
          final category =
              _getCategoryLabel(data['category'] ?? 'duvidas_gerais');
          final answerCount = (data['answerCount'] ?? 0).toString();

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _handlePostTap(context, post.id, isProtected),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-1.0, -1.0),
                    radius: 1.5,
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.1),
                      theme.cardColor,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (bibleReference != null && bibleReference.isNotEmpty)
                          _buildTagChip(theme, bibleReference,
                              isReference: true),
                        if (bibleReference != null && bibleReference.isNotEmpty)
                          const SizedBox(width: 8),
                        _buildTagChip(theme, category),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: (authorPhotoUrl != null &&
                                  authorPhotoUrl.isNotEmpty)
                              ? NetworkImage(authorPhotoUrl)
                              : null,
                          child: (authorPhotoUrl == null ||
                                  authorPhotoUrl.isEmpty)
                              ? Text(
                                  authorName.isNotEmpty ? authorName[0] : '?')
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$authorName • $date',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (content != null && content.isNotEmpty)
                      Text(
                        content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (content != null && content.isNotEmpty)
                      const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.comment_outlined,
                            size: 16, color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 6),
                        Text(answerCount, style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        if (isProtected)
                          Icon(Icons.lock_outline,
                              size: 18,
                              color: theme.textTheme.bodySmall?.color),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(
                  duration: 400.ms, delay: (100 * (index % _postsPerPage)).ms)
              .slideY(begin: 0.2, curve: Curves.easeOut);
        },
      ),
    );
    // ✅ FIM DA MUDANÇA
  }

  Widget _buildTagChip(ThemeData theme, String label,
      {bool isReference = false}) {
    // ... (seu código para _buildTagChip permanece o mesmo, está correto)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isReference
            ? theme.colorScheme.primaryContainer.withOpacity(0.6)
            : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isReference
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
