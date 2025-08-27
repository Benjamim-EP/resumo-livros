// lib/models/themed_map_model.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// Representa um único local dentro de uma viagem
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

// Representa uma viagem completa (ex: Primeira Viagem Missionária)
class ThemedJourney {
  final String id;
  final String title;
  final String description;
  final Color color;
  final List<JourneyLocation> locations;
  final String style; // <<< ADICIONE ESTA LINHA

  ThemedJourney({
    required this.id,
    required this.title,
    required this.description,
    required this.color,
    required this.locations,
    required this.style, // <<< ADICIONE AO CONSTRUTOR
  });

  factory ThemedJourney.fromJson(Map<String, dynamic> json) {
    // Função auxiliar para converter string de cor HEX (ex: "#E53935") para Color
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
      locations: (json['locations'] as List<dynamic>? ?? [])
          .map((loc) => JourneyLocation.fromJson(loc))
          .toList(),
      style: json['style'] ??
          'solid', // <<< ADICIONE ESTA LINHA (com um padrão 'solid')
    );
  }
}
