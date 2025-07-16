// test/models/promise_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/models/promise_model.dart';

void main() {
  group('PromiseBook.fromJson', () {
    test('deve parsear corretamente um JSON válido e completo', () {
      // DADO
      final mockJson = {
        "book": "As Promessas de Deus",
        "author": "Samuel Clarke",
        "parts": [
          {
            "part_number": 1,
            "title": "PARTE UM",
            "chapters": [
              {
                "chapter_number": 1,
                "title": "Promessas sobre Bênçãos Temporais",
                "sections": [
                  {
                    "section_number": 1,
                    "title": "Provisão de Todas as Coisas Boas",
                    "verses": [
                      {
                        "text": "O Senhor Deus é sol e escudo...",
                        "reference": "Salmo 84:11"
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      };

      // QUANDO
      final promiseBook = PromiseBook.fromJson(mockJson);

      // ENTÃO
      expect(promiseBook.bookTitle, 'As Promessas de Deus');
      expect(promiseBook.parts.length, 1);
      expect(promiseBook.parts.first.chapters.first.title,
          'Promessas sobre Bênçãos Temporais');
      expect(
          promiseBook.parts.first.chapters.first.sections.first.verses?.first
              .reference,
          'Salmo 84:11');
    });

    test('deve usar valores padrão quando campos obrigatórios são nulos', () {
      // DADO
      final mockJsonWithNulls = {
        "book": null, // Título do livro é nulo
        "author": "Autor Desconhecido",
        "parts": [
          {
            "title": null, // Título da parte é nulo
            "chapters": []
          }
        ]
      };

      // QUANDO
      final promiseBook = PromiseBook.fromJson(mockJsonWithNulls);

      // ENTÃO
      expect(promiseBook.bookTitle,
          'Promessas da Bíblia'); // Valor padrão do factory
      expect(promiseBook.parts.first.title,
          'Parte Desconhecida'); // Valor padrão do factory
    });
  });
}
