// lib/pages/library_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/library_page/bible_timeline_page.dart';
import 'package:septima_biblia/pages/library_page/church_history_index_page.dart';
import 'package:septima_biblia/pages/library_page/gods_word_to_women/gods_word_to_women_index_page.dart';
import 'package:septima_biblia/pages/library_page/promises_page.dart';
import 'package:septima_biblia/pages/library_page/spurgeon_sermons_index_page.dart';
import 'package:septima_biblia/pages/biblie_page/study_hub_page.dart';
import 'package:septima_biblia/pages/library_page/turretin_elenctic_theology/turretin_index_page.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:redux/redux.dart';

// ViewModel simples para esta página
class _LibraryViewModel {
  final bool isPremium;

  _LibraryViewModel({required this.isPremium});

  static _LibraryViewModel fromStore(Store<AppState> store) {
    // Lógica para determinar se o usuário é premium
    // Esta lógica pode ser movida para um seletor mais robusto no futuro
    final subscriptionState = store.state.subscriptionState;
    bool isCurrentlyPremium =
        subscriptionState.status == SubscriptionStatus.premiumActive;

    // Fallback verificando os detalhes do usuário se a assinatura ainda não foi processada no estado
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

class ResourceCard extends StatelessWidget {
  final String title;
  final String description;
  final String author;
  final String pageCount;
  final String? coverImagePath;
  final VoidCallback onTap;

  final bool isFullyPremium;
  final bool hasPremiumFeature;

  const ResourceCard({
    super.key,
    required this.title,
    required this.description,
    required this.author,
    required this.pageCount,
    this.coverImagePath,
    required this.onTap,
    this.isFullyPremium = false,
    this.hasPremiumFeature = false,
  });

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
        ),
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
    final bool hasCoverImage =
        coverImagePath != null && coverImagePath!.isNotEmpty;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: isFullyPremium || hasPremiumFeature
            ? BorderSide(color: Colors.amber.shade700, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Positioned.fill(
                    child: hasCoverImage
                        ? Image.asset(
                            coverImagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color:
                                    theme.colorScheme.surfaceContainerHighest),
                          )
                        : Container(color: theme.colorScheme.primaryContainer),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0.0, 0.8],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        shadows: [
                          const Shadow(blurRadius: 3.0, color: Colors.black87)
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isFullyPremium || hasPremiumFeature)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.amber.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Divider(height: 12, thickness: 0.5),
                    _buildInfoRow(context, Icons.person_outline, author),
                    _buildInfoRow(context, Icons.menu_book_outlined, pageCount),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Map<String, dynamic>> get libraryItems => [
        {
          'title': "Sermões de C.H. Spurgeon",
          'description':
              "Uma vasta coleção dos sermões do 'Príncipe dos Pregadores'.",
          'author': 'C.H. Spurgeon',
          'pageCount': '+3000 sermões / +20000 páginas',
          'isFullyPremium': false,
          'hasPremiumFeature': false,
          'coverImagePath': 'assets/covers/spurgeon_cover.webp',
          'destinationPage': const SpurgeonSermonsIndexPage(),
        },
        {
          'title': "A Palavra de Deus às Mulheres",
          'description':
              "Uma análise profunda das escrituras sobre o papel da mulher na igreja e na sociedade.",
          'author': 'Katharine C. Bushnell',
          'pageCount': '100 Lições / +500 páginas',
          'isFullyPremium': true, // Marcar como conteúdo premium
          'hasPremiumFeature': false,
          'coverImagePath':
              'assets/covers/gods_word_to_women_cover.webp', // Crie uma capa para ele!
          'destinationPage': const GodsWordToWomenIndexPage(),
        },
        {
          'title': "Promessas da Bíblia",
          'description':
              "Um compêndio de promessas divinas organizadas por tema.",
          'author': 'Samuel Clarke',
          'pageCount': '+1500 promessas / 180 tópicos',
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
          'pageCount': '8 volumes / +5000 páginas',
          'isFullyPremium': true,
          'hasPremiumFeature': false,
          'coverImagePath': 'assets/covers/historia_igreja.webp',
          'destinationPage': const ChurchHistoryIndexPage(),
        },
        {
          'title': "Institutos de Teologia Elenctica",
          'description': "A obra monumental da teologia sistemática reformada.",
          'author': 'Francis Turretin',
          'pageCount': '3 volumes / +2000 páginas',
          'isFullyPremium': true, // Totalmente premium
          'hasPremiumFeature': false,
          'coverImagePath':
              'assets/covers/turretin_cover.webp', // Crie uma capa para ele!
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
          'title': "Linha do Tempo Bíblica",
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

              VoidCallback onTapAction = () {
                if (isFullyPremium && !viewModel.isPremium) {
                  _showPremiumDialog(context);
                } else {
                  if (!viewModel.isPremium) {
                    interstitialManager.tryShowInterstitial(
                        fromScreen: "Library_To_${itemData['title']}");
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => itemData['destinationPage']),
                  );
                }
              };

              return ResourceCard(
                title: itemData['title'],
                description: itemData['description'],
                author: itemData['author'],
                pageCount: itemData['pageCount'],
                coverImagePath: itemData['coverImagePath'],
                isFullyPremium: isFullyPremium,
                hasPremiumFeature: itemData['hasPremiumFeature'],
                onTap: onTapAction,
              );
            },
          );
        },
      ),
    );
  }
}
