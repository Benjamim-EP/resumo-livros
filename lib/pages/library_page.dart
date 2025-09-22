// lib/pages/library_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/components/custom_search_bar.dart';
import 'package:septima_biblia/pages/library_page/bible_timeline_page.dart';
import 'package:septima_biblia/pages/library_page/church_history_index_page.dart';
import 'package:septima_biblia/pages/library_page/compact_resource_card.dart';
import 'package:septima_biblia/pages/library_page/generic_book_viewer_page.dart';
import 'package:septima_biblia/pages/library_page/gods_word_to_women/gods_word_to_women_index_page.dart';
import 'package:septima_biblia/pages/library_page/library_recommendation_page.dart';
import 'package:septima_biblia/pages/library_page/promises_page.dart';
import 'package:septima_biblia/pages/library_page/resource_detail_modal.dart';
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

// Lista estática e pública com os metadados de todos os recursos da biblioteca
final List<Map<String, dynamic>> allLibraryItems = [
  // --- LIVROS ADICIONADOS ---
  {
    'title': "O Peregrino",
    'description':
        "A jornada alegórica de Cristão da Cidade da Destruição à Cidade Celestial.",
    'author': 'John Bunyan',
    'pageCount': '2 partes',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/o-peregrino.webp', // ATUALIZADO
    'destinationPage': const GenericBookViewerPage(
        bookId: 'john-bunyan-o-peregrino', bookTitle: "O Peregrino"),
    'ficcao': true,
    'dificuldade': 4,
  },
  {
    'title': "A Divina Comédia",
    'description':
        "Uma jornada épica através do Inferno, Purgatório e Paraíso, explorando a teologia e a moralidade medieval.",
    'author': 'Dante Alighieri',
    'pageCount': '100 cantos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/a-divina-comedia.webp', // ATUALIZADO
    'destinationPage': const GenericBookViewerPage(
        bookId: 'dante-alighieri-a-divina-comedia',
        bookTitle: "A Divina Comédia"),
    'ficcao': true,
    'dificuldade': 7,
  },
  {
    'title': "Ben-Hur: Uma História de Cristo",
    'description':
        "A épica história de um nobre judeu que, após ser traído, encontra redenção e fé durante a época de Jesus Cristo.",
    'author': 'Lew Wallace',
    'pageCount': '8 partes',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/ben-hur.webp', // ATUALIZADO
    'destinationPage': const GenericBookViewerPage(
        bookId: 'lew-wallace-ben-hur',
        bookTitle: "Ben-Hur: Uma História de Cristo"),
    'ficcao': true,
    'dificuldade': 4,
  },
  {
    'title': "Elogio da Loucura",
    'description':
        "Uma sátira espirituosa da sociedade, costumes e religião do século XVI, narrada pela própria Loucura.",
    'author': 'Desiderius Erasmus',
    'pageCount': '68 seções',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/elogio-loucura.webp', // ATUALIZADO
    'destinationPage': const GenericBookViewerPage(
        bookId: 'erasmus-elogio-da-loucura', bookTitle: "Elogio da Loucura"),
    'ficcao': false,
    'dificuldade': 6,
  },
  {
    'title': "Anna Karenina",
    'description':
        "Um retrato complexo da sociedade russa e das paixões humanas através da história de uma mulher que desafia as convenções.",
    'author': 'Leo Tolstoy',
    'pageCount': '239 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/anna-karenina.webp', // ATUALIZADO
    'destinationPage': const GenericBookViewerPage(
        bookId: 'leo-tolstoy-anna-karenina', bookTitle: "Anna Karenina"),
    'ficcao': true,
    'dificuldade': 7,
  },
  {
    'title': "Lilith",
    'description':
        "Uma fantasia sombria e alegórica sobre a vida, a morte e a redenção, explorando temas de egoísmo e sacrifício.",
    'author': 'George MacDonald',
    'pageCount': '47 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/lilith.webp', // OK
    'destinationPage': const GenericBookViewerPage(
        bookId: 'george-macdonald-lilith', bookTitle: "Lilith"),
    'ficcao': true,
    'dificuldade': 6,
  },
  {
    'title': "Donal Grant",
    'description':
        "A história de um jovem poeta e tutor que navega pelos desafios do amor, fé e mistério em um castelo escocês.",
    'author': 'George MacDonald',
    'pageCount': '78 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/donal-grant.webp', // ATUALIZADO
    'destinationPage': const GenericBookViewerPage(
        bookId: 'george-macdonald-donal-grant', bookTitle: "Donal Grant"),
    'ficcao': true,
    'dificuldade': 5,
  },
  {
    'title': "David Elginbrod",
    'description':
        "Um romance que explora a fé, o espiritismo e a natureza do bem e do mal através de seus personagens memoráveis.",
    'author': 'George MacDonald',
    'pageCount': '58 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/david-elginbrod.webp', // ATUALIZADO
    'destinationPage': const GenericBookViewerPage(
        bookId: 'george-macdonald-david-elginbrod',
        bookTitle: "David Elginbrod"),
    'ficcao': true,
    'dificuldade': 5,
  },
  // --- ITENS EXISTENTES ATUALIZADOS ---
  {
    'title': "Gravidade e Graça",
    'description':
        "Todos os movimentos naturais da alma são regidos por leis análogas às da gravidade física. A graça é a única exceção.",
    'author': 'Simone Weil',
    'pageCount': '39 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/gravidade_e_graca_cover.webp', // OK
    'destinationPage': const GenericBookViewerPage(
        bookId: 'gravidade-e-graca', bookTitle: "Gravidade e Graça"),
    'ficcao': false,
    'dificuldade': 6,
  },
  {
    'title': "O Enraizamento",
    'description':
        "A obediência é uma necessidade vital da alma humana. Ela é de duas espécies: obediência a regras estabelecidas e obediência a seres humanos.",
    'author': 'Simone Weil',
    'pageCount': '15 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/enraizamento.webp', // OK
    'destinationPage': const GenericBookViewerPage(
        bookId: 'o-enraizamento', bookTitle: "O Enraizamento"),
    'ficcao': false,
    'dificuldade': 6,
  },
  {
    'title': "Ortodoxia",
    'description':
        "A única desculpa possível para este livro é que ele é uma resposta a um desafio. Mesmo um mau atirador é digno quando aceita um duelo.",
    'author': 'G.K. Chesterton',
    'pageCount': '9 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/ortodoxia.webp', // OK
    'destinationPage': const GenericBookViewerPage(
        bookId: 'ortodoxia', bookTitle: "Ortodoxia"),
    'ficcao': false,
    'dificuldade': 5,
  },
  {
    'title': "Hereges",
    'description':
        "É tolo, de modo geral, que um filósofo ateie fogo a outro filósofo porque não concordam em sua teoria do universo.",
    'author': 'G.K. Chesterton',
    'pageCount': '20 capítulos',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/hereges.webp', // OK
    'destinationPage':
        const GenericBookViewerPage(bookId: 'hereges', bookTitle: "Hereges"),
    'ficcao': false,
    'dificuldade': 5,
  },
  {
    'title': "Carta a um Religioso",
    'description':
        "Quando leio o catecismo do Concílio de Trento, tenho a impressão de que não tenho nada em comum com a religião que nele se expõe.",
    'author': 'Simone Weil',
    'pageCount': '1 capítulo',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/cartas_a_um_religioso.webp', // OK
    'destinationPage': const GenericBookViewerPage(
        bookId: 'carta-a-um-religioso', bookTitle: "Carta a um Religioso"),
    'ficcao': false,
    'dificuldade': 6,
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
    'ficcao': false,
    'dificuldade': 2,
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
    'ficcao': false,
    'dificuldade': 3,
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
    'ficcao': false,
    'dificuldade': 4,
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
    'ficcao': false,
    'dificuldade': 2,
  },
  {
    'title': "História da Igreja",
    'description':
        "A jornada da igreja cristã desde os apóstolos até a era moderna.",
    'author': 'Philip Schaff',
    'pageCount': '+5000 páginas',
    'isFullyPremium': false,
    'hasPremiumFeature': false,
    'coverImagePath': 'assets/covers/historia_igreja.webp',
    'destinationPage': const ChurchHistoryIndexPage(),
    'ficcao': false,
    'dificuldade': 6,
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
    'ficcao': false,
    'dificuldade': 7,
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
    'ficcao': false,
    'dificuldade': 2,
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
    'ficcao': false,
    'dificuldade': 2,
  },
];

// ViewModel
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

// Página principal da Biblioteca
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

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
                  padding: const EdgeInsets.all(12.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12.0,
                    mainAxisSpacing: 12.0,
                    childAspectRatio:
                        0.45, // Proporção mais "alta" para a imagem
                  ),
                  itemCount: _filteredLibraryItems.length,
                  itemBuilder: (context, index) {
                    final itemData = _filteredLibraryItems[index];
                    final bool isFullyPremium = itemData['isFullyPremium'];
                    final String coverPath = itemData['coverImagePath'] ?? '';

                    void startReadingAction() {
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
                    }

                    void openDetailsModal() {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => ResourceDetailModal(
                          itemData: itemData,
                          onStartReading: () {
                            Navigator.pop(ctx);
                            startReadingAction();
                          },
                        ),
                      );
                    }

                    return CompactResourceCard(
                      title: itemData['title'],
                      author: itemData['author'],
                      coverImage:
                          coverPath.isNotEmpty ? AssetImage(coverPath) : null,
                      isPremium: isFullyPremium,
                      onCardTap: startReadingAction,
                      onExpandTap: openDetailsModal,
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (50 * index).ms);
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
