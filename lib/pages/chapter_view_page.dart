import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/save_topic_dialog.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/sidebar_indicator.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/similar_topic_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/widgets_chapter_view/topic_cards.dart';

class ChapterViewPage extends StatefulWidget {
  final List<dynamic> chapters;
  final int index;
  final String bookId;

  const ChapterViewPage({
    super.key,
    required this.chapters,
    required this.index,
    required this.bookId,
  });

  @override
  _ChapterViewPageState createState() => _ChapterViewPageState();
}

class _ChapterViewPageState extends State<ChapterViewPage> {
  int _currentTopicIndex = 0; // Índice do tópico atual
  final Set<String> _readTopics = {}; // Tópicos já marcados como lidos
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapters[widget.index];
    final topics = chapter['topicos'] as List<dynamic>? ?? [];
    print(chapter);
    return Scaffold(
      appBar: AppBar(
        title: Text(chapter['titulo'] ?? 'Sem título'),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (page) {
              setState(() => _currentTopicIndex = page);
            },
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topicId = topics[index]['topicoId'];
              return Column(
                children: [
                  Expanded(
                    child: TopicCard(
                      topicId: topicId,
                      bookId: widget.bookId,
                      chapterId: chapter['capituloId'], // Passando o capituloId
                      readTopics: _readTopics,
                      onShowSimilar: (topicId) =>
                          _showSimilarTopics(context, topicId),
                      onSaveTopic: _showSaveDialog,
                    ),
                  ),
                ],
              );
            },
          ),
          SidebarIndicator(
            currentIndex: _currentTopicIndex,
            totalItems: topics.length,
          ),
        ],
      ),
    );
  }

  void _showSimilarTopics(BuildContext context, String topicId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF313333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => SimilarTopicsView(topicId: topicId),
    );
  }

  void _showSaveDialog(String topicId) {
    showDialog(
      context: context,
      builder: (_) => SaveTopicDialog(topicId: topicId),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:flutter_redux/flutter_redux.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
// import 'package:resumo_dos_deuses_flutter/pages/rota_topico_page.dart';
// import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart';
// import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
// import 'package:resumo_dos_deuses_flutter/redux/store.dart';

// class ChapterViewPage extends StatefulWidget {
//   final List<dynamic> chapters;
//   final int index;
//   final String bookId;

//   const ChapterViewPage({
//     super.key,
//     required this.chapters,
//     required this.index,
//     required this.bookId,
//   });

//   @override
//   _ChapterViewPageState createState() => _ChapterViewPageState();
// }

// class _ChapterViewPageState extends State<ChapterViewPage> {
//   int _currentTopicIndex = 0; // Índice do tópico atual
//   final Set<String> _readTopics = {}; // Tópicos já marcados como lidos
//   bool _isReading = false; // Controle de leitura
//   late PageController _pageController;

//   @override
//   void initState() {
//     super.initState();
//     _pageController = PageController(initialPage: 0);
//   }

//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final chapter = widget.chapters[widget.index];
//     final topics =
//         chapter['topicos'] as List<dynamic>? ?? []; // Lista de tópicos

//     if (_currentTopicIndex >= topics.length) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text(chapter['titulo'] ?? 'Sem título'),
//         ),
//         body: const Center(
//           child: Text('Todos os tópicos foram lidos!'),
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(chapter['titulo'] ?? 'Sem título'),
//       ),
//       body: Stack(
//         children: [
//           // PageView para navegação vertical entre tópicos
//           PageView.builder(
//             controller: _pageController,
//             scrollDirection: Axis.vertical,
//             onPageChanged: (page) {
//               final topic = topics[page];
//               final topicId = topic['topicoId'];

//               setState(() {
//                 _currentTopicIndex = page;
//               });

//               _markTopicAsRead(widget.bookId, topicId);
//             },
//             itemCount: topics.length,
//             itemBuilder: (context, topicIndex) {
//               final topic = topics[topicIndex];
//               final topicId = topic['topicoId'];

//               return StoreConnector<AppState, Map<String, String?>>(
//                 onInit: (store) {
//                   if (!store.state.topicState.topicsContent
//                       .containsKey(topicId)) {
//                     store.dispatch(LoadTopicContentAction(topicId));
//                   }
//                 },
//                 converter: (store) {
//                   return {
//                     'content': store.state.topicState.topicsContent[topicId],
//                     'titulo': store.state.topicState.topicsTitles[topicId],
//                   };
//                 },
//                 builder: (context, topicData) {
//                   final topicContent = topicData['content'];
//                   final topicTitle = topicData['titulo'] ?? 'Tópico';

//                   if (topicContent == null) {
//                     return const Center(child: CircularProgressIndicator());
//                   }

//                   return Card(
//                     margin: const EdgeInsets.all(16.0),
//                     elevation: 4.0,
//                     color: const Color(
//                         0xFF313333), // Cor de fundo do card alterada
//                     shape: _readTopics.contains(topicId)
//                         ? RoundedRectangleBorder(
//                             side: const BorderSide(
//                                 color: Color.fromARGB(255, 109, 151, 110),
//                                 width: 2),
//                             borderRadius: BorderRadius.circular(8),
//                           )
//                         : null,
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           MarkdownBody(
//                             data: '## **$topicTitle**',
//                             styleSheet: MarkdownStyleSheet(
//                               h2: const TextStyle(
//                                 fontSize: 24, // Tamanho do texto
//                                 fontWeight: FontWeight.bold, // Negrito
//                                 color: Color(0xFFEAF4F4), // Cor personalizada
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 16),
//                           MarkdownBody(
//                             data: topicContent,
//                             styleSheet: MarkdownStyleSheet(
//                               p: const TextStyle(
//                                 fontSize: 16,
//                                 color: Color(
//                                     0xFFEAF4F4), // Cor do texto principal (opcional)
//                               ),
//                             ),
//                           ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.end,
//                             children: [
//                               TextButton(
//                                 onPressed: () =>
//                                     _showSimilarTopics(context, topicId),
//                                 child: const Text('Ver tópicos similares'),
//                               ),
//                               TextButton(
//                                 onPressed: () =>
//                                     _showSaveDialog(context, topicId),
//                                 child: const Text('Salvar'),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               );
//             },
//           ),
//           // Barra indicadora vertical na esquerda
//           Positioned(
//             left: 8.0,
//             top: 16.0,
//             bottom: 16.0,
//             child: Container(
//               width: 4.0,
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade300, // Cor da barra
//                 borderRadius: BorderRadius.circular(4.0),
//               ),
//               child: Stack(
//                 children: [
//                   Positioned(
//                     top: _calculateIndicatorPosition(topics.length),
//                     child: Container(
//                       width: 4.0,
//                       height: 20.0, // Altura do indicador
//                       decoration: BoxDecoration(
//                         color: Colors.blue, // Cor do indicador
//                         borderRadius: BorderRadius.circular(4.0),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Calcula a posição do indicador com base no índice atual do tópico.
//   double _calculateIndicatorPosition(int totalTopics) {
//     if (totalTopics <= 1) return 0.0;
//     final usableHeight =
//         MediaQuery.of(context).size.height - 32.0; // Altura disponível
//     final step = usableHeight / totalTopics; // Altura por tópico
//     return step * _currentTopicIndex;
//   }

//   void _showSimilarTopics(BuildContext context, String topicId) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: const Color(0xFF313333),
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
//       ),
//       builder: (context) {
//         return DraggableScrollableSheet(
//           initialChildSize: 0.8, // Começa ocupando 80% da tela
//           minChildSize: 0.3, // Altura mínima de 30%
//           maxChildSize: 0.8, // Altura máxima de 80%
//           expand: false,
//           builder: (context, scrollController) {
//             return StoreConnector<AppState, List<Map<String, dynamic>>>(
//               onInit: (store) {
//                 if (!store.state.topicState.similarTopics
//                     .containsKey(topicId)) {
//                   store.dispatch(LoadSimilarTopicsAction(topicId));
//                 }
//               },
//               converter: (store) =>
//                   store.state.topicState.similarTopics[topicId] ?? [],
//               builder: (context, similarTopics) {
//                 if (similarTopics.isEmpty) {
//                   return const Center(
//                     child: CircularProgressIndicator(
//                       color: Color(0xFFCDE7BE),
//                     ),
//                   );
//                 }

//                 return Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Tópicos Similares',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: Color(0xFFE9E8E8),
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       Expanded(
//                         child: ListView.builder(
//                           scrollDirection: Axis.horizontal, // Scroll horizontal
//                           controller: scrollController,
//                           itemCount: similarTopics.length,
//                           itemBuilder: (context, index) {
//                             final similarTopic = similarTopics[index];
//                             final similarTopicId =
//                                 similarTopic['similar_topic_id'];
//                             final similarity = similarTopic['similarity'];
//                             final bookTitle =
//                                 similarTopic['bookTitle'] ?? 'Sem título';
//                             final chapterTitle =
//                                 similarTopic['titulo'] ?? 'Sem título';
//                             final cover = similarTopic['cover'];
//                             final bookId =
//                                 similarTopic['bookId']; // ID do livro

//                             return Container(
//                               width: 200, // Largura de cada item
//                               margin: const EdgeInsets.only(right: 12.0),
//                               child: Card(
//                                 color: const Color(0xFF626666), // Cor do card
//                                 elevation: 4.0,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12.0),
//                                 ),
//                                 child: Padding(
//                                   padding: const EdgeInsets.all(12.0),
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       // Capa do livro (adicionado clique para BookDetailsPage)
//                                       if (cover != null)
//                                         GestureDetector(
//                                           onTap: () {
//                                             Navigator.push(
//                                               context,
//                                               MaterialPageRoute(
//                                                 builder: (_) => BookDetailsPage(
//                                                   bookId: bookId,
//                                                 ),
//                                               ),
//                                             );
//                                           },
//                                           child: ClipRRect(
//                                             borderRadius:
//                                                 BorderRadius.circular(8.0),
//                                             child: Image.network(
//                                               cover,
//                                               width: double.infinity,
//                                               height: 250,
//                                               fit: BoxFit.fill,
//                                               errorBuilder: (context, error,
//                                                       stackTrace) =>
//                                                   const Icon(
//                                                 Icons.broken_image,
//                                                 size: 80,
//                                                 color: Colors.grey,
//                                               ),
//                                             ),
//                                           ),
//                                         )
//                                       else
//                                         GestureDetector(
//                                           onTap: () {
//                                             Navigator.push(
//                                               context,
//                                               MaterialPageRoute(
//                                                 builder: (_) => BookDetailsPage(
//                                                   bookId: bookId,
//                                                 ),
//                                               ),
//                                             );
//                                           },
//                                           child: const Icon(
//                                             Icons.book,
//                                             size: 80,
//                                             color: Colors.grey,
//                                           ),
//                                         ),
//                                       const SizedBox(height: 8),
//                                       // Título do livro
//                                       Text(
//                                         'Livro: $bookTitle',
//                                         style: const TextStyle(
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: 16,
//                                           color:
//                                               Color(0xFFE9E8E8), // Cor do texto
//                                         ),
//                                         maxLines: 2,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                       const SizedBox(height: 8),
//                                       // Título do capítulo
//                                       Text(
//                                         'Tópico: $chapterTitle',
//                                         style: const TextStyle(
//                                           fontSize: 14,
//                                           color: Color(0xFFE9E8E8),
//                                         ),
//                                         maxLines: 2,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                       const SizedBox(height: 8),
//                                       // Similaridade
//                                       Text(
//                                         'Similaridade: $similarity',
//                                         style: const TextStyle(
//                                           color: Colors.grey,
//                                           fontSize: 12,
//                                         ),
//                                       ),
//                                       const Spacer(),
//                                       // Botão de ver mais
//                                       TextButton(
//                                         onPressed: () {
//                                           Navigator.push(
//                                             context,
//                                             MaterialPageRoute(
//                                               builder: (_) => TopicContentView(
//                                                 topicId: similarTopicId,
//                                               ),
//                                             ),
//                                           );
//                                         },
//                                         child: const Text(
//                                           'Ir para o Tópico',
//                                           style: TextStyle(
//                                             color: Color(0xFFCDE7BE),
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   void _markTopicAsRead(String bookId, String topicId) {
//     if (!_readTopics.contains(topicId)) {
//       setState(() {
//         _isReading = true;
//       });

//       Future.delayed(const Duration(seconds: 4), () {
//         if (mounted && _isReading && !_readTopics.contains(topicId)) {
//           setState(() {
//             _readTopics.add(topicId);
//             _isReading = false;
//           });

//           StoreProvider.of<AppState>(context).dispatch(
//             MarkTopicAsReadAction(bookId, topicId),
//           );
//         }
//       });
//     }
//   }

//   void _showSaveDialog(BuildContext context, String topicId) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return StoreConnector<AppState, Map<String, List<String>>>(
//           onInit: (store) {
//             if (store.state.userState.topicSaves.isEmpty) {
//               store.dispatch(LoadUserCollectionsAction());
//             }
//           },
//           converter: (store) => store.state.userState.topicSaves,
//           builder: (context, topicSaves) {
//             final TextEditingController collectionController =
//                 TextEditingController();

//             return AlertDialog(
//               title: const Text('Salvar Tópico'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text('Selecione ou crie uma coleção:'),
//                   if (topicSaves.isNotEmpty)
//                     ...topicSaves.keys.map((collectionName) {
//                       return ListTile(
//                         title: Text(collectionName),
//                         onTap: () {
//                           if (!topicSaves[collectionName]!.contains(topicId)) {
//                             StoreProvider.of<AppState>(context).dispatch(
//                               SaveTopicToCollectionAction(
//                                   collectionName, topicId),
//                             );
//                             Navigator.of(context).pop();
//                           } else {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                   content: Text(
//                                       'Tópico já está salvo na coleção "$collectionName".')),
//                             );
//                           }
//                         },
//                       );
//                     }).toList(),
//                   TextField(
//                     controller: collectionController,
//                     decoration: const InputDecoration(
//                       hintText: 'Nova coleção',
//                     ),
//                   ),
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     final newCollection = collectionController.text.trim();
//                     if (newCollection.isNotEmpty) {
//                       StoreProvider.of<AppState>(context).dispatch(
//                         SaveTopicToCollectionAction(newCollection, topicId),
//                       );
//                       Navigator.of(context).pop();
//                     }
//                   },
//                   child: const Text('Criar e Salvar'),
//                 ),
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: const Text('Cancelar'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
// }
