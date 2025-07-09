// lib/services/denomination_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:septima_biblia/models/denomination_model.dart';

class DenominationService {
  List<Denomination>? _cachedDenominations;

  // Carrega e armazena em cache todas as denominações do JSON.
  Future<List<Denomination>> getAllDenominations() async {
    if (_cachedDenominations != null) {
      return _cachedDenominations!;
    }

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/denominations.json');
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
