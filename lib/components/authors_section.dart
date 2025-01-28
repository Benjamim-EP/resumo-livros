import 'package:flutter/material.dart';

class AuthorsSection extends StatelessWidget {
  final List<Map<String, dynamic>> authors;

  const AuthorsSection({required this.authors, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: authors.length,
      itemBuilder: (context, index) {
        final author = authors[index];
        final String? coverUrl = author['cover']; // URL da imagem do autor
        final List<String> tags =
            (author['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        final String? authorId = author['nome']; // ID do autor para navegação

        return GestureDetector(
          onTap: () {
            if (authorId != null) {
              Navigator.pushNamed(
                context,
                '/authorPage',
                arguments: authorId,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID do autor não encontrado')),
              );
            }
          },
          child: Card(
            color: const Color(0xFF313333), // Cor do card
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15), // Bordas arredondadas
            ),
            elevation: 5, // Sombra para dar mais destaque
            child: SizedBox(
              height: 120, // Altura fixa do card
              child: Stack(
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircleAvatar(
                          radius: 35, // Tamanho da imagem circular
                          backgroundImage:
                              coverUrl != null && coverUrl.isNotEmpty
                                  ? NetworkImage(coverUrl)
                                  : null, // Imagem da URL
                          child: coverUrl == null || coverUrl.isEmpty
                              ? const Icon(Icons.person,
                                  size: 35,
                                  color: Colors.white) // Ícone fallback
                              : null,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                author['nome'] ?? 'Sem Nome',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                author['descricao'] ?? 'Sem descrição',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tags.isNotEmpty
                                    ? tags.join(', ') // Concatena as tags
                                    : 'Sem tags',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Text(
                      '${author['curtidas'] ?? 0} curtidas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
