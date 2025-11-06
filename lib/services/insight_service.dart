// lib/services/insight_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InsightService {
  InsightService._privateConstructor();
  static final InsightService instance = InsightService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cache em memória para evitar leituras repetidas do SharedPreferences na mesma sessão
  final Map<String, String> _inMemoryCache = {};

  /// Busca o insight para uma seção específica.
  /// 1. Tenta buscar no cache em memória.
  /// 2. Se não encontrar, tenta buscar no SharedPreferences (cache local).
  /// 3. Se não encontrar, busca no Firestore.
  /// 4. Salva no SharedPreferences e no cache em memória para acessos futuros.
  Future<String?> getInsight(String sectionId) async {
    // 1. Verifica o cache em memória
    if (_inMemoryCache.containsKey(sectionId)) {
      print(
          "InsightService: Insight '$sectionId' encontrado no cache em memória.");
      return _inMemoryCache[sectionId];
    }

    // 2. Verifica o SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final String? cachedInsight = prefs.getString('insight_$sectionId');

    if (cachedInsight != null) {
      print(
          "InsightService: Insight '$sectionId' encontrado no SharedPreferences.");
      _inMemoryCache[sectionId] = cachedInsight; // Atualiza o cache em memória
      return cachedInsight;
    }

    // 3. Busca no Firestore (fallback)
    print(
        "InsightService: Insight '$sectionId' não encontrado localmente. Buscando no Firestore...");
    try {
      final docSnapshot =
          await _db.collection('insights_lexico').doc(sectionId).get();

      if (docSnapshot.exists) {
        final insightContent = docSnapshot.data()?['insight'] as String?;
        if (insightContent != null) {
          // 4. Salva nos caches para o futuro
          await prefs.setString('insight_$sectionId', insightContent);
          _inMemoryCache[sectionId] = insightContent;
          print("InsightService: Insight '$sectionId' salvo localmente.");
          return insightContent;
        }
      }
      print(
          "InsightService: Insight '$sectionId' não encontrado no Firestore.");
      return null; // Retorna nulo se não encontrar no Firestore
    } catch (e) {
      print(
          "InsightService: ERRO ao buscar insight '$sectionId' no Firestore: $e");
      return "Ocorreu um erro ao carregar a análise. Verifique sua conexão.";
    }
  }
}
