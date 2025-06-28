// lib/pages/library_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/library_page/bible_timeline_page.dart';
import 'package:septima_biblia/pages/library_page/church_history_index_page.dart';
import 'package:septima_biblia/pages/library_page/promises_page.dart';
import 'package:septima_biblia/pages/library_page/spurgeon_sermons_index_page.dart';
import 'package:septima_biblia/pages/biblie_page/study_hub_page.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';

class ResourceCard extends StatelessWidget {
  final String title;
  final String description;
  final String author;
  final String pageCount;
  final String? coverImagePath;
  final VoidCallback onTap;

  const ResourceCard({
    super.key,
    required this.title,
    required this.description,
    required this.author,
    required this.pageCount,
    this.coverImagePath,
    required this.onTap,
  });

  // Widget auxiliar para as linhas de informação (agora mais simples)
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
          borderRadius: BorderRadius.circular(15)), // Bordas mais arredondadas
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Parte 1: Imagem (com mais espaço) ---
            // Usando Expanded para que a imagem ocupe o máximo de espaço possível na Column
            Expanded(
              flex: 3, // Dando mais peso para a imagem
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Positioned.fill(
                    child: hasCoverImage
                        ? Image.asset(
                            coverImagePath!,
                            // >>> MUDANÇA 1/3: Mantém a proporção e cobre a área <<<
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: theme.colorScheme.surfaceVariant),
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
                  // O Chip de Categoria foi REMOVIDO
                ],
              ),
            ),

            // --- Parte 2: Detalhes em 3 Linhas ---
            // Usando um flex menor para garantir que a imagem tenha mais espaço
            Expanded(
              flex: 2, // Menos peso para a área de texto
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly, // Distribui o espaço
                  children: [
                    // Linha 1: Descrição
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Divider(height: 12, thickness: 0.5),
                    // Linha 2: Autor
                    _buildInfoRow(context, Icons.person_outline, author),
                    // Linha 3: Páginas
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
  // Dados atualizados sem a chave 'category'
  List<Map<String, dynamic>> get libraryItems => [
        {
          'title': "Sermões de Spurgeon",
          'description':
              "Uma vasta coleção dos sermões do 'Príncipe dos Pregadores'.",
          'author': 'C.H. Spurgeon',
          'pageCount': '+3000 sermões / +20000 páginas',
          'coverImagePath': 'assets/covers/spurgeon_cover.webp',
          'onTap': () {
            interstitialManager
                .tryShowInterstitial(
                    fromScreen: "LibraryPage_To_SpurgeonSermons")
                .then((_) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SpurgeonSermonsIndexPage()),
                );
              }
            });
          },
        },
        {
          'title': "História da Igreja",
          'description':
              "A jornada da igreja cristã desde os apóstolos até a era moderna.",
          'author': 'Philip Schaff',
          'pageCount': '8 volumes / +5000 páginas',
          'coverImagePath': 'assets/covers/historia_igreja.webp',
          'onTap': () {
            interstitialManager
                .tryShowInterstitial(fromScreen: "LibraryPage_To_ChurchHistory")
                .then((_) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ChurchHistoryIndexPage()),
                );
              }
            });
          },
        },
        {
          'title': "Estudos Rápidos",
          'description':
              "Guias e rotas de estudo temáticos para aprofundar seu conhecimento.",
          'author': 'Séptima',
          'pageCount': '10+ estudos',
          'coverImagePath': 'assets/covers/estudos_tematicos_cover.webp',
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StudyHubPage()),
            );
          },
        },
        {
          'title': "Linha do Tempo Bíblica",
          'description':
              "Contextualize os eventos bíblicos com a história mundial.",
          'author': 'Septima',
          'pageCount': 'Interativo',
          'coverImagePath': 'assets/covers/timeline_cover.webp',
          'onTap': () {
            interstitialManager
                .tryShowInterstitial(fromScreen: "LibraryPage_To_BibleTimeline")
                .then((_) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BibleTimelinePage()),
                );
              }
            });
          },
        },
        {
          'title': "Promessas da Bíblia",
          'description':
              "Um compêndio de promessas divinas organizadas por tema.",
          'author': 'Samuel Clarke',
          'pageCount': '+800 promessas',
          'coverImagePath': 'assets/covers/promessas_cover.webp',
          'onTap': () {
            interstitialManager
                .tryShowInterstitial(fromScreen: "LibraryPage_To_Promises")
                .then((_) {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PromisesPage()),
                );
              }
            });
          },
        },
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          // >>> MUDANÇA 2/3: AJUSTE DA PROPORÇÃO PARA DEIXAR OS CARDS MAIS ALTOS <<<
          childAspectRatio: 0.45,
        ),
        itemCount: libraryItems.length,
        itemBuilder: (context, index) {
          final itemData = libraryItems[index];
          return ResourceCard(
            title: itemData['title'] as String,
            description: itemData['description'] as String,
            author: itemData['author'] as String,
            pageCount: itemData['pageCount'] as String,
            coverImagePath: itemData['coverImagePath'] as String?,
            onTap: itemData['onTap'] as VoidCallback,
          );
        },
      ),
    );
  }
}
