import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIService {
  // Mantenha a chave fora do código se possível (variável de ambiente, etc.)
  static const String _apiKey = "SUA_CHAVE_API_OPENAI_AQUI"; // Substitua!
  static const String _embeddingUrl = 'https://api.openai.com/v1/embeddings';
  static const String _chatUrl = "https://api.openai.com/v1/chat/completions";

  Future<List<double>> generateEmbedding(String text) async {
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'input': text,
      'model': 'text-embedding-3-large', // Ou outro modelo de embedding
    });

    final response =
        await http.post(Uri.parse(_embeddingUrl), headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['data'] != null && data['data'].isNotEmpty) {
        return List<double>.from(data['data'][0]['embedding']);
      } else {
        throw Exception(
            'Resposta da API de embedding inválida: ${response.body}');
      }
    } else {
      print("Erro OpenAI Embedding Status: ${response.statusCode}");
      print("Erro OpenAI Embedding Body: ${response.body}");
      throw Exception('Erro ao gerar embeddings: ${response.statusCode}');
    }
  }

  Future<String> sendMessageToGPT({
    required String userMessage,
    required String systemContext,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_chatUrl),
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gpt-4o-mini", // Ou outro modelo de chat
          "messages": [
            {"role": "system", "content": systemContext},
            {"role": "user", "content": userMessage},
          ],
          "temperature": 0.7, // Ajuste conforme necessário
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8
            .decode(response.bodyBytes)); // Usa utf8 para caracteres especiais
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'].trim();
        } else {
          throw Exception("Resposta da API de chat inválida: ${response.body}");
        }
      } else {
        print("Erro OpenAI Chat Status: ${response.statusCode}");
        print("Erro OpenAI Chat Body: ${response.body}");
        throw Exception("Erro na resposta da OpenAI: ${response.statusCode}");
      }
    } catch (e) {
      print("Erro ao conectar com a IA (sendMessageToGPT): $e");
      return "Erro ao conectar com a IA."; // Retorna mensagem de erro genérica
    }
  }

  // Função para análise de tribo (extraída do middleware original)
  Future<Map<String, String>?> getTribeAnalysis(String userText) async {
    const systemPrompt = """
     Você é um assistente especializado em associar características fornecidas pelo usuário às tribos descritas.
     Baseado no texto do usuário, retorne as 3 tribos que mais se assemelham com as características fornecidas. As tribos possuem as seguintes características:
     [... DESCRIÇÃO DAS TRIBOS COMO NO ORIGINAL ...]
     Formato da resposta (JSON), a reposta só deve ser feita exclusivamente nesse formato:
     {
       "tribos": {"tribo1":"Motivo...", "tribo2":"Motivo...", "tribo3":"Motivo..."}
     }
     """;

    try {
      final response = await http.post(
        Uri.parse(_chatUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': "Texto do usuário: '$userText'"}
          ],
          'max_tokens': 300, // Ajuste conforme necessário
          'temperature': 0.5, // Mais determinístico para análise
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        String textResponse =
            responseData['choices'][0]['message']['content'].trim();

        // Limpeza da resposta (remover ```json)
        textResponse =
            textResponse.replaceAll(RegExp(r'^```json|```$'), '').trim();

        if (textResponse.startsWith('{') && textResponse.endsWith('}')) {
          final parsedResponse = jsonDecode(textResponse);
          if (parsedResponse['tribos'] is Map) {
            // Converte para Map<String, String> explicitamente
            return Map<String, String>.from(parsedResponse['tribos']);
          } else {
            print(
                'Formato inesperado para "tribos": ${parsedResponse['tribos']}');
            return null;
          }
        } else {
          print('Formato JSON inválido após limpeza: $textResponse');
          return null;
        }
      } else {
        print(
            'Erro na API OpenAI (Tribe Analysis): ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erro ao processar análise de tribo: $e');
      return null;
    }
  }
}
