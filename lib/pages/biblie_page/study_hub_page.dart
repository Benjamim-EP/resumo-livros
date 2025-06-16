// lib/pages/biblie_page/study_hub_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Importe as páginas de visualização específicas para cada tipo de estudo/curso
// Exemplo:
import 'package:septima_biblia/pages/biblie_page/bible_routes/profecias_de_sua_vinda_page.dart';
import 'package:septima_biblia/pages/biblie_page/bible_routes/palavras_do_fim_dos_tempos_page.dart';
import 'package:septima_biblia/pages/biblie_page/bible_routes/eventos_vida_de_jesus_page.dart';
// Se você tiver um visualizador genérico para os JSONs de curso/outros estudos:
// import 'generic_study_viewer_page.dart';

class StudyHubPage extends StatelessWidget {
  const StudyHubPage({super.key});

  // Defina a estrutura do seu conteúdo de estudo aqui
  // Adapte 'assetPath' para o caminho correto e 'dataKey' para a chave no seu JSON que contém a lista principal de itens
  List<Map<String, dynamic>> get _studyCategories => [
        {
          'categoryTitle': 'Estudos Temáticos',
          'items': [
            {
              'title': 'Profecias de Vinda do Messias',
              'description':
                  'Explore as profecias do Antigo Testamento sobre a vinda do Messias.',
              'assetPath':
                  'assets/Biblia/rotas_biblia/profeciasdesuavinda.json',
              'dataKey':
                  'profecias', // A chave no JSON que contém a lista de profecias
              'pageBuilder': (List<dynamic> data) =>
                  ProfeciasDeSuaVindaPage(profecias: data),
            },
            {
              'title': 'Palavras do Fim dos Tempos',
              'description':
                  'Um estudo sobre termos e conceitos escatológicos importantes.',
              'assetPath':
                  'assets/Biblia/rotas_biblia/palavrasdofimdostempos.json',
              'dataKey': 'termos',
              'pageBuilder': (List<dynamic> data) =>
                  PalavrasDoFimDosTemposPage(termos: data),
            },
            {
              'title': 'Eventos da Vida de Jesus',
              'description':
                  'Cronologia e estudo dos principais eventos da vida de Cristo.',
              'assetPath': 'assets/Biblia/rotas_biblia/eventosvidadeJesus.json',
              'dataKey': 'eventos',
              'pageBuilder': (List<dynamic> data) =>
                  EventosVidaDeJesusPage(eventos: data),
            },
            // Adicione outros estudos temáticos (personagens, etc.)
            // {
            //   'title': 'Estudo sobre Davi',
            //   'description': 'A vida e o reinado do Rei Davi.',
            //   'assetPath': 'assets/Biblia/estudos_personagens/davi.json', // Exemplo de caminho
            //   'dataKey': 'licoes', // Exemplo de chave
            //   'pageBuilder': (List<dynamic> data) => GenericStudyViewerPage(studyData: data, title: "Estudo sobre Davi"),
            // },
          ],
        },

        // Adicione mais categorias conforme necessário
      ];

  Future<void> _navigateToStudy(
      BuildContext context, Map<String, dynamic> studyItem) async {
    if (studyItem['isPlaceholder'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Este conteúdo estará disponível em breve!')),
      );
      return;
    }
    try {
      final String jsonString =
          await rootBundle.loadString(studyItem['assetPath']);
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      final List<dynamic>? studyDataList =
          jsonData[studyItem['dataKey']] as List<dynamic>?;

      if (studyDataList != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => studyItem['pageBuilder'](studyDataList),
          ),
        );
      } else if (context.mounted) {
        print(
            "Erro: A chave '${studyItem['dataKey']}' não foi encontrada ou não é uma lista no arquivo ${studyItem['assetPath']}. Conteúdo do JSON: $jsonData");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Não foi possível carregar os dados para "${studyItem['title']}".')),
        );
      }
    } catch (e) {
      print(
          "Erro ao carregar ou navegar para o estudo ${studyItem['title']}: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir "${studyItem['title']}".')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recursos de Estudo"),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10.0),
        itemCount: _studyCategories.length,
        itemBuilder: (context, categoryIndex) {
          final category = _studyCategories[categoryIndex];
          final List<Map<String, dynamic>> items = category['items'];

          return Card(
            color: const Color(0xFF232538), // Cor do card da categoria
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ExpansionTile(
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              title: Text(
                category['categoryTitle'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: items.map<Widget>((item) {
                bool isPlaceholder = item['isPlaceholder'] ?? false;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10.0),
                  leading: Icon(
                      isPlaceholder
                          ? Icons.hourglass_empty_outlined
                          : Icons
                              .article_outlined, // Ícone diferente para placeholder
                      color: isPlaceholder
                          ? Colors.white38
                          : const Color(0xFFCDE7BE)),
                  title: Text(
                    item['title'],
                    style: TextStyle(
                        color: isPlaceholder ? Colors.white54 : Colors.white,
                        fontSize: 16),
                  ),
                  subtitle: item['description'] != null
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            item['description'],
                            style: TextStyle(
                                color: isPlaceholder
                                    ? Colors.white38
                                    : Colors.white70,
                                fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : null,
                  trailing: isPlaceholder
                      ? null
                      : const Icon(Icons.arrow_forward_ios,
                          color: Colors.white70, size: 16),
                  onTap: () => _navigateToStudy(context, item),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
