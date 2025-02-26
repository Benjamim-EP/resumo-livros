import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String apiKey = "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"; // 🔹 Substitua pela sua chave
  static const String apiUrl = "https://api.openai.com/v1/chat/completions";

  static Future<String> sendMessageToGPT({
    required String userMessage,
    required String systemContext,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": systemContext},
            {"role": "user", "content": userMessage},
          ],
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        throw Exception("Erro na resposta da OpenAI: ${response.body}");
      }
    } catch (e) {
      return "Erro ao conectar com a IA.";
    }
  }
}
