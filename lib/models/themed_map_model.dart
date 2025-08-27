// lib/models/themed_map_model.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// Representa uma categoria de mapas temáticos, como "Viagens de Paulo"
class ThemedMapCategory {
  final String title;
  final List<ThemedJourney> journeys;

  ThemedMapCategory({required this.title, required this.journeys});

  factory ThemedMapCategory.fromFirestore(Map<String, dynamic> data) {
    return ThemedMapCategory(
      title: data['title'] ?? 'Categoria Desconhecida',
      journeys: (data['journeys'] as List<dynamic>? ?? [])
          .map((j) => ThemedJourney.fromJson(j))
          .toList(),
    );
  }
}

// Representa uma única viagem/mapa temático
class ThemedJourney {
  final String id;
  final String title;
  final String description;
  final Color color;
  final String style;
  final List<JourneyLocation> locations;

  ThemedJourney({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.style,
    required this.locations,
  });

  factory ThemedJourney.fromJson(Map<String, dynamic> json) {
    Color _hexToColor(String hexString) {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    }

    return ThemedJourney(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Viagem Desconhecida',
      description: json['description'] ?? '',
      color: _hexToColor(json['color'] ?? '#8E24AA'),
      style: json['style'] ?? 'solid',
      locations: (json['locations'] as List<dynamic>? ?? [])
          .map((loc) => JourneyLocation.fromJson(loc))
          .toList(),
    );
  }
}

// Representa um local dentro de uma viagem
class JourneyLocation {
  final String name;
  final LatLng point;
  final String? description;

  JourneyLocation({
    required this.name,
    required this.point,
    this.description,
  });

  factory JourneyLocation.fromJson(Map<String, dynamic> json) {
    return JourneyLocation(
      name: json['name'] ?? 'Local Desconhecido',
      point: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lon'] as num?)?.toDouble() ?? 0.0,
      ),
      description: json['description'],
    );
  }
}
