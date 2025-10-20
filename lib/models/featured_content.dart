class FeaturedContent {
  final String id;
  final String type;
  final String title;
  final String description;
  final String featuredImage;
  final String duration;
  final String assetPath;
  final String? contentPath; // <-- 1. NOVO CAMPO OPCIONAL

  FeaturedContent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.featuredImage,
    required this.duration,
    required this.assetPath,
    this.contentPath, // <-- 2. ADICIONADO AO CONSTRUTOR
  });

  factory FeaturedContent.fromJson(
      Map<String, dynamic> json, String assetPath) {
    return FeaturedContent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? 'Sem Título',
      description: json['description'] as String? ?? '',
      featuredImage: json['featuredImage'] as String? ??
          'assets/images/guias/placeholder.webp',
      duration: json['duration'] as String? ?? '',
      assetPath: assetPath,
      contentPath: json['contentPath'] as String?, // <-- 3. ATRIBUINDO O VALOR
    );
  }
}
