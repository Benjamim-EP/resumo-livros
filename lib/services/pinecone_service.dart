import 'dart:convert';
import 'package:http/http.dart' as http;

class PineconeService {
  // Mantenha fora do código se possível
  static const String _apiKey = "SUA_CHAVE_API_PINECONE_AQUI"; // Substitua!
  static const String _apiUrl = "SEU_ENDPOINT_PINECONE_AQUI"; // Substitua!

  Future<List<Map<String, dynamic>>> queryPinecone(
      List<double> vector, int topK) async {
    final body = jsonEncode({
      "vector": vector,
      "topK": topK,
      "includeValues": false, // Geralmente não precisamos dos vetores de volta
      "includeMetadata":
          true, // Precisamos dos metadados (conteúdo, livro, etc.)
    });

    final headers = {
      'Api-Key': _apiKey,
      'Content-Type': 'application/json',
      'Accept': 'application/json', // Adicionado para clareza
    };

    try {
      final response =
          await http.post(Uri.parse(_apiUrl), headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['matches'] != null && data['matches'] is List) {
          // Converte a lista dinâmica para o tipo correto
          return List<Map<String, dynamic>>.from((data['matches'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map)));
        } else {
          print(
              "Resposta Pinecone inválida ou sem 'matches': ${response.body}");
          return []; // Retorna lista vazia se não houver matches
        }
      } else {
        print("Erro Pinecone Status: ${response.statusCode}");
        print("Erro Pinecone Body: ${response.body}");
        throw Exception('Erro ao buscar no Pinecone: ${response.statusCode}');
      }
    } catch (e) {
      print("Erro na chamada Pinecone: $e");
      throw Exception(
          'Erro de conexão com Pinecone: $e'); // Relança para o middleware tratar
    }
  }
}
