// lib/pages/library_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/library_page/bible_timeline_page.dart';
import 'package:septima_biblia/pages/library_page/book_search_page.dart';
import 'package:septima_biblia/pages/library_page/church_history_index_page.dart';
import 'package:septima_biblia/pages/library_page/generic_book_viewer_page.dart';
import 'package:septima_biblia/pages/library_page/glowing_resource_card.dart';
import 'package:septima_biblia/pages/library_page/gods_word_to_women/gods_word_to_women_index_page.dart';
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

// O ResourceCard agora é um StatefulWidget para a animação de toque
class ResourceCard extends StatefulWidget {
  final String title;
  final String description;
  final String author;
  final String pageCount;
  final ImageProvider?
      coverImage; // Aceita qualquer ImageProvider (Asset ou Network)
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
              // ✅ 1. ÁREA DA IMAGEM: USA FLEXIBLE EM VEZ DE EXPANDED
              // Flexible ocupa o espaço restante após a área de texto ter sua altura fixa.
              Flexible(
                flex:
                    1, // O flex aqui ainda é útil para manter a proporção se a altura total mudar
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
              // ✅ 2. ÁREA DE INFORMAÇÕES: USA SIZEDBOX COM ALTURA FIXA
              SizedBox(
                height: 120, // <--- AJUSTE ESTE VALOR CONFORME NECESSÁRIO
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

// A página principal da Biblioteca agora é StatelessWidget
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  // Lista estática com os metadados de todos os recursos da biblioteca
  List<Map<String, dynamic>> get libraryItems => [
        // Card Especial de IA
        // {
        //   'title': "Recomendação de Livros",
        //   'description':
        //       "Encontre o livro perfeito para o seu momento, dúvida ou sentimento.",
        //   'author': 'Septima AI',
        //   'pageCount': '70+ Livros / 7+ Autores',
        //   'isFullyPremium': false,
        //   'hasPremiumFeature': false,
        //   'coverImagePath': 'assets/covers/book_recommendation_cover.webp',
        //   'destinationPage': const BookSearchPage(),
        //   'isSpecial': true,
        // },
        // Livros do Firestore
        {
          'title': "Gravidade e Graça",
          'description':
              "Todos os movimentos naturais da alma são regidos por leis análogas às da gravidade física. A graça é a única exceção.",
          'author': 'Simone Weil',
          'pageCount': '39 capítulos',
          'isFullyPremium': false,
          'hasPremiumFeature': false,
          'coverImagePath':
              'assets/covers/gravidade_e_graca_cover.webp', // Capa nos assets
          'destinationPage': const GenericBookViewerPage(
            bookId: 'gravidade-e-graca', // ID do documento no Firestore
            bookTitle: "Gravidade e Graça",
          ),
        },
        {
          'title': "O Enraizamento",
          'description':
              "A obediência é uma necessidade vital da alma humana. Ela é de duas espécies: obediência a regras estabelecidas e obediência a seres humanos considerad...",
          'author': 'Simone Weil',
          'pageCount': '15 capítulos',
          'isFullyPremium': false,
          'hasPremiumFeature': false,
          'coverImagePath': 'assets/covers/enraizamento.webp',
          'destinationPage': const GenericBookViewerPage(
            bookId: 'o-enraizamento',
            bookTitle: "O Enraizamento",
          ),
        },
        {
          'title': "Ortodoxia",
          'description':
              "A única desculpa possível para este livro é que ele é uma resposta a um desafio. Mesmo um mau atirador é digno quando aceita um duelo.",
          'author': 'G.K. Chesterton',
          'pageCount': '9 capítulos',
          'isFullyPremium': false,
          'hasPremiumFeature': false,
          'coverImagePath': 'assets/covers/ortodoxia.webp',
          'destinationPage': const GenericBookViewerPage(
            bookId: 'ortodoxia',
            bookTitle: "Ortodoxia",
          ),
        },
        {
          'title': "Hereges",
          'description':
              "É tolo, de modo geral, que um filósofo ateie fogo a outro filósofo no Mercado de Smithfield porque não concordam em sua teoria do universo.",
          'author': 'G.K. Chesterton',
          'pageCount': '20 capítulos',
          'isFullyPremium': false,
          'hasPremiumFeature': false,
          'coverImagePath': 'assets/covers/hereges.webp',
          'destinationPage': const GenericBookViewerPage(
            bookId: 'hereges',
            bookTitle: "Hereges",
          ),
        },
        {
          'title': "Carta a um Religioso",
          'description':
              "...quando leio o catecismo do Concílio de Trento, tenho a impressão de que não tenho nada em comum com a religião que nele se expõe.",
          'author': 'Simone Weil',
          'pageCount': '1 capítulo', // Corrigido para o singular
          'isFullyPremium': false,
          'hasPremiumFeature': false,
          'coverImagePath': 'assets/covers/cartas_a_um_religioso.webp',
          'destinationPage': const GenericBookViewerPage(
            bookId: 'carta-a-um-religioso',
            bookTitle: "Carta a um Religioso",
          ),
        },
        // Adicione aqui os metadados de outros livros do Firestore
        // {
        //   'title': "Heréticos",
        //   'description': "Uma defesa da ortodoxia e uma crítica às filosofias modernas.",
        //   'author': 'G.K. Chesterton',
        //   'pageCount': '20 capítulos',
        //   'isFullyPremium': false,
        //   'hasPremiumFeature': false,
        //   'coverImagePath': 'assets/covers/hereticos_cover.webp',
        //   'destinationPage': const GenericBookViewerPage(
        //     bookId: 'heretics', // ID do documento no Firestore
        //     bookTitle: "Heréticos",
        //   ),
        // },

        // Recursos Estáticos do App
        {
          'title': "Mapas Temáticos",
          'description':
              "Explore as jornadas dos apóstolos e outros eventos bíblicos visualmente.",
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
          'description':
              "Um compêndio de promessas divinas organizadas por tema.",
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
          'isFullyPremium': false,
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
          'description':
              "Contextualize os eventos bíblicos com a história mundial.",
          'author': 'Septima',
          'pageCount': 'Interativo',
          'isFullyPremium': false,
          'hasPremiumFeature': false,
          'coverImagePath': 'assets/covers/timeline_cover.webp',
          'destinationPage': const BibleTimelinePage(),
        },
      ];

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content: const Text(
            'Este recurso é exclusivo para assinantes Premium. Desbloqueie todo o conteúdo e funcionalidades!'),
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
    return Scaffold(
      body: StoreConnector<AppState, _LibraryViewModel>(
        converter: (store) => _LibraryViewModel.fromStore(store),
        builder: (context, viewModel) {
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.45,
            ),
            itemCount: libraryItems.length,
            itemBuilder: (context, index) {
              final itemData = libraryItems[index];
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

              if (itemData['isSpecial'] == true) {
                return GlowingResourceCard(
                  itemData: itemData,
                  onTap: onTapAction,
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scaleXY(begin: 0.9, curve: Curves.easeOutBack);
              }

              return ResourceCard(
                title: itemData['title'],
                description: itemData['description'],
                author: itemData['author'],
                pageCount: itemData['pageCount'],
                coverImage: coverPath.isNotEmpty ? AssetImage(coverPath) : null,
                isFullyPremium: isFullyPremium,
                hasPremiumFeature:
                    itemData['hasPremiumFeature'] as bool? ?? false,
                onTap: onTapAction,
              )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: (150 * (index % 2)).ms)
                  .scaleXY(begin: 0.9, curve: Curves.easeOutBack);
            },
          );
        },
      ),
    );
  }
}
