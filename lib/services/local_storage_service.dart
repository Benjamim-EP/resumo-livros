import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  Future<void> saveTopicsByFeature(String userId,
      Map<String, List<Map<String, dynamic>>> topicsByFeature) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(topicsByFeature);
    await prefs.setString('topicsByFeature_$userId', jsonString);
    print("Tópicos salvos localmente para $userId.");
  }

  Future<Map<String, List<Map<String, dynamic>>>?> loadTopicsByFeature(
      String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('topicsByFeature_$userId');

    if (jsonString != null) {
      try {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        // Converte corretamente o tipo interno da lista
        return decoded.map((key, value) {
          final list = value as List;
          final typedList = list
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          return MapEntry(key, typedList);
        });
      } catch (e) {
        print("Erro ao decodificar tópicos locais: $e");
        await clearTopicsByFeature(userId); // Limpa dados inválidos
        return null;
      }
    }
    print("Nenhum tópico local encontrado para $userId.");
    return null;
  }

  Future<void> clearTopicsByFeature(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('topicsByFeature_$userId');
    print("Cache de tópicos locais limpo para $userId.");
  }
}
