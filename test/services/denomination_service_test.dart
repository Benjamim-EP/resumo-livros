// test/services/denomination_service_test.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/models/denomination_model.dart';
import 'package:septima_biblia/services/denomination_service.dart';

// 1. Criamos uma classe que simula o AssetBundle para nossos testes.
class FakeAssetBundle extends CachingAssetBundle {
  final Map<String, String> stringAssets;

  FakeAssetBundle(this.stringAssets);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (stringAssets.containsKey(key)) {
      return stringAssets[key]!;
    }
    throw FlutterError('FakeAssetBundle: Unable to load asset: $key');
  }

  // A classe CachingAssetBundle é abstrata e exige a implementação de load(),
  // mesmo que não a usemos diretamente em nosso teste.
  @override
  Future<ByteData> load(String key) async {
    if (stringAssets.containsKey(key)) {
      final bytes = utf8.encode(stringAssets[key]!);
      return ByteData.view(bytes.buffer);
    }
    throw FlutterError('FakeAssetBundle: Unable to load asset: $key');
  }
}

void main() {
  // Simula a resposta do arquivo JSON que será usada nos testes.
  const mockJsonString = '''
  [
    {"id": 1, "nome": "Igreja Batista", "ramo_principal": "Protestantismo", "caminho": "C > P > B", "numero_adeptos": "100 milhões"},
    {"id": 2, "nome": "Igreja Presbiteriana", "ramo_principal": "Protestantismo", "caminho": "C > P > C", "numero_adeptos": "75 milhões"}
  ]
  ''';

  group('DenominationService', () {
    test('getAllDenominations deve carregar e parsear as denominações do JSON',
        () async {
      // DADO (Arrange):
      // 1. Cria o nosso bundle falso com o JSON mockado.
      final fakeBundle = FakeAssetBundle({
        'assets/data/denominations.json': mockJsonString,
      });
      // 2. Injeta o bundle falso diretamente no serviço.
      final service = DenominationService(bundle: fakeBundle);

      // QUANDO (Act):
      final denominations = await service.getAllDenominations();

      // ENTÃO (Assert):
      expect(denominations, isA<List<Denomination>>());
      expect(denominations.length, 2);
      expect(denominations.first.name, 'Igreja Batista');
    });

    test('getAllDenominations deve retornar dados do cache na segunda chamada',
        () async {
      // DADO:
      final fakeBundle = FakeAssetBundle({
        'assets/data/denominations.json': mockJsonString,
      });
      final service = DenominationService(bundle: fakeBundle);

      // QUANDO:
      final result1 = await service.getAllDenominations(); // Popula o cache.
      final result2 = await service.getAllDenominations(); // Deve vir do cache.

      // ENTÃO:
      expect(result2.length, 2);
      // A verificação `identical` prova que a segunda chamada não recriou a lista,
      // mas retornou a mesma instância da memória, confirmando o uso do cache.
      expect(identical(result1, result2), isTrue);
    });
  });
}
