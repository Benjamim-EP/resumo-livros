// lib/models/featured_content.dart

class FeaturedContent {
  final String id;
  final String type;
  final String title;
  final String description;
  final String featuredImage;
  final String duration;
  final String assetPath; // <-- 1. NOVA PROPRIEDADE

  FeaturedContent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.featuredImage,
    required this.duration,
    required this.assetPath, // <-- 2. ADICIONADO AO CONSTRUTOR
  });

  /// Agora, o construtor de fábrica precisa do assetPath para criar o objeto.
  factory FeaturedContent.fromJson(
      Map<String, dynamic> json, String assetPath) {
    // <-- 3. NOVO PARÂMETRO
    return FeaturedContent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? 'Sem Título',
      description: json['description'] as String? ?? '',
      featuredImage: json['featuredImage'] as String? ??
          'assets/images/guias/placeholder.webp',
      duration: json['duration'] as String? ?? '',
      assetPath: assetPath, // <-- 4. ATRIBUINDO O VALOR
    );
  }
}
