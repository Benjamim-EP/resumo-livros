// lib/pages/library_page.dart
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/study_hub_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/spurgeon_sermons_index_page.dart';
// Importe aqui a futura página de índice dos sermões
// import 'spurgeon_sermons_index_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

// Placeholder para o ResourceCard que será criado no Passo 1.3
class ResourceCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const ResourceCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: theme.iconTheme.color?.withOpacity(0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // O AppBar será gerenciado pela MainAppScreen, então não precisamos de um aqui
      // a menos que você queira um AppBar específico para esta página.
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // Passo 1.3 será implementado aqui
          ResourceCard(
            title: "Sermões de C.H. Spurgeon",
            description:
                "Explore a vasta coleção de sermões do Príncipe dos Pregadores.",
            icon: Icons.campaign_outlined, // Ícone de megafone/pregação
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SpurgeonSermonsIndexPage()),
              );
            },
          ),
          // Adicione outros ResourceCards aqui no futuro
          ResourceCard(
            title: "Estudos Bíblicos Temáticos",
            description: "Aprofunde-se em temas específicos da Bíblia.",
            icon: Icons.menu_book_outlined,
            onTap: () {
              // Reutilizar a StudyHubPage existente para estudos temáticos por enquanto
              // Ou criar uma página específica se a StudyHubPage for só para cursos/sermões
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const StudyHubPage()), // Reutilizando StudyHubPage
              );
              print("Navegar para Estudos Temáticos (StudyHubPage)");
            },
          ),
          ResourceCard(
            title: "Cursos (Em Breve)",
            description:
                "Cursos estruturados sobre teologia, vida cristã e mais.",
            icon: Icons.school_outlined,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cursos (Em breve!)')),
              );
            },
          ),
        ],
      ),
    );
  }
}
