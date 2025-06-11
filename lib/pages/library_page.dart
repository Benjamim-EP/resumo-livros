// lib/pages/library_page.dart
import 'package:flutter/material.dart';
// Importe suas páginas de destino
import 'package:septima_biblia/pages/spurgeon_sermons_index_page.dart';
import 'package:septima_biblia/pages/biblie_page/study_hub_page.dart';
import 'package:septima_biblia/services/interstitial_manager.dart'; // Reutilizando para Estudos Temáticos

class ResourceCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData? icon; // Ícone é opcional se a imagem for fornecida
  final String? coverImagePath; // Caminho para imagem local nos assets
  final VoidCallback onTap;

  const ResourceCard({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.coverImagePath,
    required this.onTap,
  }) : assert(icon != null || coverImagePath != null,
            'Deve ser fornecido um ícone ou um caminho de imagem de capa.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasCoverImage =
        coverImagePath != null && coverImagePath!.isNotEmpty;

    return Card(
      elevation: 5,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // Camada 1: Imagem de Fundo (ou ícone se não houver imagem)
            Positioned.fill(
              child: hasCoverImage
                  ? Image.asset(
                      coverImagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color:
                              theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          child: Center(
                              child: Icon(icon ?? Icons.broken_image,
                                  size: 60,
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.7))),
                        );
                      },
                    )
                  : Container(
                      color:
                          theme.colorScheme.primaryContainer.withOpacity(0.3),
                      child: Center(
                          child: Icon(icon!,
                              size: 60, color: theme.colorScheme.primary)),
                    ),
            ),

            // Camada 2: Overlay Escuro (Gradiente para legibilidade do texto)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.75), // Mais escuro na base
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Camada 3: Conteúdo de Texto
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(0.0, 1.0),
                            blurRadius: 3.0,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.90),
                          shadows: [
                            Shadow(
                              offset: const Offset(0.0, 1.0),
                              blurRadius: 2.0,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ]),
                      maxLines: 3, // Aumentado para caber mais descrição
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]
                ],
              ),
            ),
            // Camada 4: Ícone de seta (opcional)
            Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.6), size: 18),
            )
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
  // Lista de itens para a biblioteca
  // Cada item é um Map para configurar o ResourceCard
  List<Map<String, dynamic>> get libraryItems => [
        {
          'title': "Sermões de C.H. Spurgeon",
          'description': "3000+ de Sermôes",
          'icon': Icons.campaign_outlined,
          'coverImagePath': 'assets/covers/spurgeon_cover.webp',
          'onTap': () {
            // Tenta mostrar o anúncio ANTES de navegar
            interstitialManager
                .tryShowInterstitial(
                    fromScreen: "LibraryPage_To_SpurgeonSermons")
                .then((_) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SpurgeonSermonsIndexPage()),
              );
            });
          },
        },
        {
          'title': "Estudos Bíblicos Temáticos",
          'description': "Temas da Bíblia com guias e referências.",
          'icon': Icons.menu_book_outlined,
          'coverImagePath':
              null, // Ou uma imagem genérica para estudos: 'assets/covers/study_cover.webp'
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StudyHubPage()),
            );
          },
        },
        {
          'title': "Cursos (Em Breve)",
          'description':
              "Cursos estruturados sobre teologia, vida cristã e mais.",
          'icon': Icons.school_outlined,
          'coverImagePath': null, // 'assets/covers/courses_cover.webp'
          'onTap': () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cursos (Em breve!)')),
            );
          },
        },
        {
          'title': "Biografias (Em Breve)",
          'description':
              "Conheça a vida de grandes homens e mulheres de fé que marcaram a história.",
          'icon': Icons.person_search_outlined,
          'coverImagePath': null, // 'assets/covers/biographies_cover.webp'
          'onTap': () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biografias (Em breve!)')),
            );
          },
        },
        {
          'title': "Recursos Adicionais",
          'description':
              "Ferramentas, dicionários e outros materiais para auxiliar seu estudo.",
          'icon': Icons.extension_outlined,
          'coverImagePath': null,
          'onTap': () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recursos Adicionais (Em breve!)')),
            );
          },
        },
        {
          'title': "Mapas Bíblicos (Em Breve)",
          'description':
              "Explore os locais da Bíblia com mapas interativos e informações.",
          'icon': Icons.map_outlined,
          'coverImagePath': null,
          'onTap': () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mapas Bíblicos (Em breve!)')),
            );
          },
        },
      ];

  @override
  Widget build(BuildContext context) {
    // O AppBar é gerenciado pela MainAppScreen, então não é necessário aqui.
    return Scaffold(
      body: GridView.count(
        padding: const EdgeInsets.all(16.0), // Padding ao redor da grade
        crossAxisCount: 2, // Número de colunas
        crossAxisSpacing: 16.0, // Espaçamento horizontal entre os cards
        mainAxisSpacing: 16.0, // Espaçamento vertical entre os cards
        childAspectRatio:
            0.8, // Proporção largura/altura dos cards (ajuste fino aqui)
        // Valores comuns: 1.0 (quadrado), 2/3 (retrato), 3/2 (paisagem)
        // Para imagem de fundo e texto, um valor menor que 1 (ex: 0.7 a 0.9) pode ficar bom.
        children: libraryItems.map((itemData) {
          return ResourceCard(
            title: itemData['title'] as String,
            description: itemData['description'] as String,
            icon: itemData['icon'] as IconData?,
            coverImagePath: itemData['coverImagePath'] as String?,
            onTap: itemData['onTap'] as VoidCallback,
          );
        }).toList(),
      ),
    );
  }
}
