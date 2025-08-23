// lib/services/bible_version_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// Modelo para os metadados de uma versão
class BibleVersionMeta {
  final String id;
  final String fullName;
  final String year;
  final String description;

  BibleVersionMeta({
    required this.id,
    required this.fullName,
    required this.year,
    required this.description,
  });

  factory BibleVersionMeta.fromJson(Map<String, dynamic> json) {
    return BibleVersionMeta(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? 'Nome Desconhecido',
      year: json['year'] ?? 'N/A',
      description: json['description'] ?? 'Sem descrição.',
    );
  }
}

// Serviço para carregar os metadados
class BibleVersionService {
  BibleVersionService._();
  static final BibleVersionService instance = BibleVersionService._();

  List<BibleVersionMeta>? _versions;

  Future<List<BibleVersionMeta>> getVersions() async {
    if (_versions != null) {
      return _versions!;
    }

    try {
      final jsonString = await rootBundle
          .loadString('assets/metadata/bible_versions_meta.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _versions =
          jsonList.map((json) => BibleVersionMeta.fromJson(json)).toList();
      return _versions!;
    } catch (e) {
      print("Erro ao carregar metadados das versões da Bíblia: $e");
      return [];
    }
  }
}
