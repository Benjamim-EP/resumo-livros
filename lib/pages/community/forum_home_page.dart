// lib/pages/community/forum_home_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/pages/community/post_detail_page.dart';
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

  // Mapa de categorias para construir os chips de filtro
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
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    // Se o usuário rolou até 90% do final da lista, carrega mais
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _fetchMorePosts();
    }
  }

  /// Constrói a query do Firestore dinamicamente com base no filtro selecionado.
  Query _buildQuery() {
    Query query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true);

    if (_selectedCategory != null) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query;
  }

  /// Busca a primeira página de posts.
  Future<void> _fetchInitialPosts() async {
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

  /// Busca as páginas seguintes de posts.
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

  /// Reseta a lista e busca do zero quando um filtro é alterado.
  void _onFilterChanged(String? newCategory) {
    if (_selectedCategory == newCategory) return;

    setState(() {
      _selectedCategory = newCategory;
      _posts = [];
      _lastDocument = null;
      _hasMore = true;
      _isLoading = true;
    });

    _fetchInitialPosts();
  }

  /// Função principal que gerencia o toque em um post.
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

  /// Exibe um AlertDialog para o usuário inserir a senha.
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

  /// Chama a Cloud Function para verificar a senha e lida com o resultado.
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

  /// Converte o valor da categoria para o seu rótulo de exibição.
  String _getCategoryLabel(String categoryValue) {
    final category = _categories.firstWhere(
        (cat) => cat['value'] == categoryValue,
        orElse: () => {'label': 'Geral'});
    return category['label']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            _selectedCategory == null
                                ? "Nenhuma pergunta foi feita ainda.\nSeja o primeiro!"
                                : "Nenhuma pergunta encontrada nesta categoria.",
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12.0),
                        itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
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
                              ? DateFormat('dd/MM/yy')
                                  .format(timestamp.toDate())
                              : '';
                          final bibleReference =
                              data['bibleReference'] as String?;
                          final isProtected =
                              data['isPasswordProtected'] ?? false;
                          final authorPhotoUrl =
                              data['authorPhotoUrl'] as String?;
                          final authorName = data['authorName'] ?? 'Anônimo';
                          final title = data['title'] ?? 'Pergunta sem título';
                          final content = data['content'] as String?;
                          final category = _getCategoryLabel(
                              data['category'] ?? 'duvidas_gerais');
                          final answerCount =
                              (data['answerCount'] ?? 0).toString();

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () =>
                                  _handlePostTap(context, post.id, isProtected),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: const Alignment(-1.0, -1.0),
                                    radius: 1.5,
                                    colors: [
                                      theme.colorScheme.primary
                                          .withOpacity(0.1),
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
                                        if (bibleReference != null &&
                                            bibleReference.isNotEmpty)
                                          _buildTagChip(theme, bibleReference,
                                              isReference: true),
                                        if (bibleReference != null &&
                                            bibleReference.isNotEmpty)
                                          const SizedBox(width: 8),
                                        _buildTagChip(theme, category),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      title,
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
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
                                          backgroundImage:
                                              (authorPhotoUrl != null &&
                                                      authorPhotoUrl.isNotEmpty)
                                                  ? NetworkImage(authorPhotoUrl)
                                                  : null,
                                          child: (authorPhotoUrl == null ||
                                                  authorPhotoUrl.isEmpty)
                                              ? Text(authorName.isNotEmpty
                                                  ? authorName[0]
                                                  : '?')
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
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: theme
                                              .textTheme.bodyMedium?.color
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
                                            size: 16,
                                            color: theme
                                                .textTheme.bodySmall?.color),
                                        const SizedBox(width: 6),
                                        Text(answerCount,
                                            style: theme.textTheme.bodyMedium),
                                        const Spacer(),
                                        if (isProtected)
                                          Icon(Icons.lock_outline,
                                              size: 18,
                                              color: theme
                                                  .textTheme.bodySmall?.color),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                  duration: 400.ms,
                                  delay: (100 * (index % _postsPerPage)).ms)
                              .slideY(begin: 0.2, curve: Curves.easeOut);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/createPost');
        },
        tooltip: "Fazer uma pergunta",
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }

  /// Constrói a barra de filtros rolável com chips de categoria.
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            FilterChip(
              label: const Text('Todos'),
              selected: _selectedCategory == null,
              onSelected: (isSelected) {
                _onFilterChanged(null);
              },
            ),
            const SizedBox(width: 8),
            ..._categories.map((category) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FilterChip(
                  label: Text(category['label']!),
                  selected: _selectedCategory == category['value'],
                  onSelected: (isSelected) {
                    final newCategory = isSelected ? category['value'] : null;
                    _onFilterChanged(newCategory);
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Widget auxiliar para criar as "tags" no topo do card.
  Widget _buildTagChip(ThemeData theme, String label,
      {bool isReference = false}) {
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
