// lib/services/denomination_service.dart
import 'dart:convert';
import 'package:flutter/services.dart'
    show AssetBundle, rootBundle; // Importe ambos
import 'package:septima_biblia/models/denomination_model.dart';

class DenominationService {
  List<Denomination>? _cachedDenominations;
  final AssetBundle _bundle; // Dependência agora é uma variável de instância
// O construtor usa o rootBundle global por padrão,
// mas permite que injetemos um diferente (para testes).
  DenominationService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  Future<List<Denomination>> getAllDenominations() async {
    if (_cachedDenominations != null) {
      return _cachedDenominations!;
    }
    try {
// Usa a instância do bundle que foi fornecida ou a padrão
      final String jsonString =
          await _bundle.loadString('assets/data/denominations.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedDenominations =
          jsonList.map((json) => Denomination.fromJson(json)).toList();
      return _cachedDenominations!;
    } catch (e) {
      print("Erro ao carregar denominações: $e");
      return [];
    }
  }
}
