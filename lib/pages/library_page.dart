// lib/pages/library_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/components/custom_search_bar.dart';
import 'package:septima_biblia/pages/library_page/bible_timeline_page.dart';
import 'package:septima_biblia/pages/library_page/church_history_index_page.dart';
import 'package:septima_biblia/pages/library_page/generic_book_viewer_page.dart';
import 'package:septima_biblia/pages/library_page/gods_word_to_women/gods_word_to_women_index_page.dart';
import 'package:septima_biblia/pages/library_page/library_recommendation_page.dart';
import 'package:septima_biblia/pages/library_page/promises_page.dart';
import 'package:septima_biblia/pages/library_page/spurgeon_sermons_index_page.dart';
import 'package:septima_biblia/pages/biblie_page/study_hub_page.dart';
import 'package:septima_biblia/pages/library_page/turretin_elenctic_theology/turretin_index_page.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/pages/themed_maps_list_page.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:septima_biblia/services/custom_page_route.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:redux/redux.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

// ✅ LISTA DE ITENS DA BIBLIOTECA - AGORA É PÚBLICA E FINAL
final List<Map<String, dynamic>> allLibraryItems = [
  {
    'title': "Gravidade e Graça",
    'description':
        "Todos os movimentos naturais da alma são regidos por leis análogas...",
    'author': 'Simone Weil',
    'pageCount': '39 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/gravidade_e_graca_cover.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'gravidade-e-graca', bookTitle: "Gravidade e Graça"),
  },
  {
    'title': "O Enraizamento",
    'description': "A obediência é uma necessidade vital da alma humana...",
    'author': 'Simone Weil',
    'pageCount': '15 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/enraizamento.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'o-enraizamento', bookTitle: "O Enraizamento"),
  },
  {
    'title': "Ortodoxia",
    'description':
        "A única desculpa possível para este livro é que ele é uma resposta a um desafio.",
    'author': 'G.K. Chesterton',
    'pageCount': '9 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/ortodoxia.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'ortodoxia', bookTitle: "Ortodoxia"),
  },
  {
    'title': "Hereges",
    'description':
        "É tolo, de modo geral, que um filósofo ateie fogo a outro...",
    'author': 'G.K. Chesterton',
    'pageCount': '20 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/hereges.webp',
    'destinationPage':
        const GenericBookViewerPage(bookId: 'hereges', bookTitle: "Hereges"),
  },
  {
    'title': "Carta a um Religioso",
    'description': "...quando leio o catecismo do Concílio de Trento...",
    'author': 'Simone Weil',
    'pageCount': '1 capítulo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/cartas_a_um_religioso.webp',
    'destinationPage': const GenericBookViewerPage(
        bookId: 'carta-a-um-religioso', bookTitle: "Carta a um Religioso"),
  },
  {
    'title': "Mapas Temáticos",
    'description':
        "Explore as jornadas dos apóstolos e outros eventos bíblicos.",
    'author': 'Septima',
    'pageCount': '4 Viagens',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/themed_maps_cover.webp',
    'destinationPage': const ThemedMapsListPage(),
  },
  {
    'title': "Sermões de Spurgeon",
    'description':
        "Uma vasta coleção dos sermões do 'Príncipe dos Pregadores'.",
    'author': 'C.H. Spurgeon',
    'pageCount': '+3000 sermões',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/spurgeon_cover.webp',
    'destinationPage': const SpurgeonSermonsIndexPage(),
  },
  {
    'title': "A Palavra às Mulheres",
    'description':
        "Uma análise profunda das escrituras sobre o papel da mulher.",
    'author': 'K. C. Bushnell',
    'pageCount': '+500 páginas',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/gods_word_to_women_cover.webp',
    'destinationPage': const GodsWordToWomenIndexPage(),
  },
  {
    'title': "Promessas da Bíblia",
    'description': "Um compêndio de promessas divinas organizadas por tema.",
    'author': 'Samuel Clarke',
    'pageCount': '+1500 promessas',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/promessas_cover.webp',
    'destinationPage': const PromisesPage(),
  },
  {
    'title': "História da Igreja",
    'description':
        "A jornada da igreja cristã desde os apóstolos até a era moderna.",
    'author': 'Philip Schaff',
    'pageCount': '+5000 páginas',
    'isFullyPremium': true,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/historia_igreja.webp',
    'destinationPage': const ChurchHistoryIndexPage(),
  },
  {
    'title': "Teologia Apologética",
    'description': "A obra monumental da teologia sistemática reformada.",
    'author': 'Francis Turretin',
    'pageCount': '+2000 páginas',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/turretin_cover.webp',
    'destinationPage': const TurretinIndexPage(),
  },
  {
    'title': "Estudos Rápidos",
    'description':
        "Guias e rotas de estudo temáticos para aprofundar seu conhecimento.",
    'author': 'Séptima',
    'pageCount': '10+ estudos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/estudos_tematicos_cover.webp',
    'destinationPage': const StudyHubPage(),
  },
  {
    'title': "Linha do Tempo",
    'description': "Contextualize os eventos bíblicos com a história mundial.",
    'author': 'Septima',
    'pageCount': 'Interativo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/timeline_cover.webp',
    'destinationPage': const BibleTimelinePage(),
  },
];

// ViewModel para obter o status de premium do usuário
class _LibraryViewModel {
  final bool isPremium;
  _LibraryViewModel({required this.isPremium});
  static _LibraryViewModel fromStore(Store<AppState> store) {
    bool isCurrentlyPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    if (!isCurrentlyPremium) {
      final userDetails = store.state.userState.userDetails;
      if (userDetails != null) {
        final status = userDetails['subscriptionStatus'] as String?;
        final endDateTimestamp =
            userDetails['subscriptionEndDate'] as Timestamp?;
        if (status == 'active' &&
            endDateTimestamp != null &&
            endDateTimestamp.toDate().isAfter(DateTime.now())) {
          isCurrentlyPremium = true;
        }
      }
    }
    return _LibraryViewModel(isPremium: isCurrentlyPremium);
  }
}

// Widget do Card de Recurso
class ResourceCard extends StatefulWidget {
  final String title;
  final String description;
  final String author;
  final String pageCount;
  final ImageProvider? coverImage;
  final VoidCallback onTap;
  final bool isFullyPremium;
  final bool hasPremiumFeature;

  const ResourceCard({
    super.key,
    required this.title,
    required this.description,
    required this.author,
    required this.pageCount,
    this.coverImage,
    required this.onTap,
    this.isFullyPremium = false,
    this.hasPremiumFeature = false,
  });

  @override
  State<ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<ResourceCard> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) => setState(() => _isPressed = true);
  void _onTapUp(TapUpDetails details) => setState(() => _isPressed = false);
  void _onTapCancel() => setState(() => _isPressed = false);

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon,
            size: 14,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.9)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double scale = _isPressed ? 0.96 : 1.0;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: widget.isFullyPremium || widget.hasPremiumFeature
                ? BorderSide(color: Colors.amber.shade700, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: widget.coverImage != null
                          ? Image(image: widget.coverImage!, fit: BoxFit.cover)
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest),
                    ),
                    if (widget.isFullyPremium || widget.hasPremiumFeature)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle),
                          child: Icon(Icons.workspace_premium_rounded,
                              color: Colors.amber.shade600, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 120,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(widget.description,
                          style:
                              theme.textTheme.bodySmall?.copyWith(height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      _buildInfoRow(
                          context, Icons.person_outline, widget.author),
                      const SizedBox(height: 4),
                      _buildInfoRow(
                          context, Icons.menu_book_outlined, widget.pageCount),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A página principal da Biblioteca agora é StatefulWidget
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  // Lista de itens agora é estática para ser acessível de outros lugares
  static final List<Map<String, dynamic>> libraryItems = allLibraryItems;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredLibraryItems = [];

  @override
  void initState() {
    super.initState();
    _filteredLibraryItems = allLibraryItems;
    _searchController.addListener(_filterLibrary);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterLibrary);
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String text) {
    return unorm
        .nfd(text)
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .toLowerCase();
  }

  void _filterLibrary() {
    final query = _normalize(_searchController.text);
    if (query.isEmpty) {
      setState(() => _filteredLibraryItems = allLibraryItems);
      return;
    }
    final filtered = allLibraryItems.where((item) {
      final title = _normalize(item['title'] ?? '');
      final author = _normalize(item['author'] ?? '');
      final description = _normalize(item['description'] ?? '');
      return title.contains(query) ||
          author.contains(query) ||
          description.contains(query);
    }).toList();
    setState(() => _filteredLibraryItems = filtered);
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content:
            const Text('Este recurso é exclusivo para assinantes Premium.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Agora não')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SubscriptionSelectionPage()));
            },
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: CustomSearchBar(
                    controller: _searchController,
                    hintText: "Buscar na biblioteca...",
                    onChanged: (value) => _filterLibrary(),
                    onClear: _clearSearch,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.auto_awesome,
                      color: theme.colorScheme.primary),
                  tooltip: "Recomendação com IA",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const LibraryRecommendationPage()),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StoreConnector<AppState, _LibraryViewModel>(
              converter: (store) => _LibraryViewModel.fromStore(store),
              builder: (context, viewModel) {
                if (_filteredLibraryItems.isEmpty) {
                  return const Center(child: Text("Nenhum item encontrado."));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.45,
                  ),
                  itemCount: _filteredLibraryItems.length,
                  itemBuilder: (context, index) {
                    final itemData = _filteredLibraryItems[index];
                    final bool isFullyPremium = itemData['isFullyPremium'];
                    final String coverPath = itemData['coverImagePath'] ?? '';

                    VoidCallback onTapAction = () {
                      AnalyticsService.instance
                          .logLibraryResourceOpened(itemData['title']);
                      if (isFullyPremium && !viewModel.isPremium) {
                        _showPremiumDialog(context);
                      } else {
                        if (!viewModel.isPremium) {
                          interstitialManager.tryShowInterstitial(
                              fromScreen: "Library_To_${itemData['title']}");
                        }
                        Navigator.push(
                          context,
                          FadeScalePageRoute(page: itemData['destinationPage']),
                        );
                      }
                    };

                    return ResourceCard(
                      title: itemData['title'],
                      description: itemData['description'],
                      author: itemData['author'],
                      pageCount: itemData['pageCount'],
                      coverImage:
                          coverPath.isNotEmpty ? AssetImage(coverPath) : null,
                      isFullyPremium: isFullyPremium,
                      hasPremiumFeature:
                          itemData['hasPremiumFeature'] as bool? ?? false,
                      onTap: onTapAction,
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (100 * index).ms);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
