// lib/models/featured_content.dart

/// Representa as informações de um item em destaque (Guia de Estudo ou Sequência)
/// para ser exibido no carrossel da Biblioteca.
/// Esta classe contém apenas os dados necessários para a pré-visualização no carrossel.
class FeaturedContent {
  final String id;
  final String type;
  final String title;
  final String description;
  final String featuredImage; // Caminho para a imagem de capa do asset
  final String duration;

  // Construtor da classe
  FeaturedContent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.featuredImage,
    required this.duration,
  });

  /// Construtor de fábrica para criar uma instância de [FeaturedContent] a partir de um mapa JSON.
  /// Isso é crucial para converter os dados lidos dos nossos arquivos .json em objetos Dart seguros.
  factory FeaturedContent.fromJson(Map<String, dynamic> json) {
    return FeaturedContent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? 'Sem Título',
      description: json['description'] as String? ?? '',
      featuredImage: json['featuredImage'] as String? ??
          'assets/images/guias/placeholder.webp', // Um placeholder é uma boa prática
      duration: json['duration'] as String? ?? '',
    );
  }
}
