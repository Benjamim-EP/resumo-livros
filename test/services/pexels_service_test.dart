// test/services/pexels_service_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ 1. IMPORTAR DOTENV
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:septima_biblia/models/pexels_model.dart';
import 'package:septima_biblia/services/pexels_service.dart';

// Cria o Mock para o http.Client
class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockHttpClient;
  late PexelsService pexelsService;

  // ✅ 2. setUpAll PARA CARREGAR O .ENV DE TESTE
  // É executado uma única vez antes de todos os testes neste arquivo.
  setUpAll(() async {
    // Carrega as variáveis de ambiente do nosso arquivo de teste.
    await dotenv.load(fileName: "test.env");
  });

  setUp(() {
    registerFallbackValue(Uri());
    mockHttpClient = MockHttpClient();
    pexelsService = PexelsService(client: mockHttpClient);
  });

  // Função auxiliar para criar uma resposta JSON mockada
  String mockPexelsResponse({int photoCount = 1}) {
    final photos = List.generate(
        photoCount,
        (index) => {
              "id": 12345 + index,
              "photographer": "Mock Photographer",
              "src": {
                "original": "url_original",
                "large2x": "url_large2x",
                "medium": "url_medium",
                "small": "url_small"
              }
            });
    return json.encode({"photos": photos});
  }

  group('PexelsService', () {
    // Cenário 1: Busca bem-sucedida (Status 200)
    test(
        'searchPhotos deve retornar uma lista de PexelsPhoto em caso de sucesso (200)',
        () async {
      // DADO
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              http.Response(mockPexelsResponse(photoCount: 2), 200));

      // QUANDO
      final result = await pexelsService.searchPhotos('natureza');

      // ENTÃO
      expect(result, isA<List<PexelsPhoto>>());
      expect(result.length, 2);
      expect(result.first.photographer, 'Mock Photographer');
    });

    // Cenário 2: Falha na API (Status 401 - Não Autorizado)
    test(
        'searchPhotos deve retornar uma lista vazia se a API retornar um erro (ex: 401)',
        () async {
      // DADO
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Invalid API Key', 401));

      // QUANDO
      final result = await pexelsService.searchPhotos('qualquer coisa');

      // ENTÃO
      expect(result, isEmpty);
    });

    // Cenário 3: Erro de Rede
    test(
        'getCuratedPhotos deve retornar uma lista vazia em caso de erro de rede',
        () async {
      // DADO
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(const SocketException('Falha ao conectar'));

      // QUANDO
      final result = await pexelsService.getCuratedPhotos();

      // ENTÃO
      expect(result, isEmpty);
    });

    // Teste extra para a função de fotos curadas
    test(
        'getCuratedPhotos deve retornar uma lista de PexelsPhoto em caso de sucesso (200)',
        () async {
      // DADO
      when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async =>
              http.Response(mockPexelsResponse(photoCount: 5), 200));

      // QUANDO
      final result = await pexelsService.getCuratedPhotos();

      // ENTÃO
      expect(result.length, 5);
    });
  });
}
