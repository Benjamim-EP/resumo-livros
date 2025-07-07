// lib/models/pexels_model.dart

// Representa a estrutura de uma única foto retornada pela API Pexels.
class PexelsPhoto {
  final int id;
  final String photographer;
  final PexelsPhotoSource src;

  PexelsPhoto({
    required this.id,
    required this.photographer,
    required this.src,
  });

  // Factory constructor para criar uma instância a partir de um mapa JSON.
  factory PexelsPhoto.fromJson(Map<String, dynamic> json) {
    return PexelsPhoto(
      id: json['id'] ?? 0,
      photographer: json['photographer'] ?? 'Desconhecido',
      src: PexelsPhotoSource.fromJson(json['src'] ?? {}),
    );
  }
}

// Representa as diferentes URLs de tamanho para uma foto.
class PexelsPhotoSource {
  final String original;
  final String large2x; // Ótima para a imagem de fundo final
  final String medium; // Boa para a grade de miniaturas
  final String small;

  PexelsPhotoSource({
    required this.original,
    required this.large2x,
    required this.medium,
    required this.small,
  });

  // Factory constructor para criar a partir de um sub-mapa 'src' do JSON.
  factory PexelsPhotoSource.fromJson(Map<String, dynamic> json) {
    return PexelsPhotoSource(
      original: json['original'] ?? '',
      large2x: json['large2x'] ?? '',
      medium: json['medium'] ?? '',
      small: json['small'] ?? '',
    );
  }
}
