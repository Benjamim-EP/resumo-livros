// import 'package:flutter/material.dart';
// import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart';
// import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
// import 'package:resumo_dos_deuses_flutter/redux/store.dart';
// import 'package:flutter_redux/flutter_redux.dart';

// class RotaTopicoPage extends StatelessWidget {
//   final String topicId;
//   final String bookId;

//   const RotaTopicoPage(
//       {super.key, required this.topicId, required this.bookId});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Tópicos Similares'),
//       ),
//       body: StoreConnector<AppState, List<Map<String, dynamic>>>(
//         onInit: (store) {
//           if (!store.state.topicState.similarTopics.containsKey(topicId)) {
//             print('Carregando tópicos similares para $topicId');
//             store.dispatch(LoadSimilarTopicsAction(topicId));
//           }
//         },
//         converter: (store) {
//           final topics = store.state.topicState.similarTopics[topicId] ?? [];
//           print('Converter: Tópicos similares para $topicId: $topics');
//           return topics;
//         },
//         builder: (context, similarTopics) {
//           if (similarTopics.isEmpty) {
//             return const Center(
//               child: CircularProgressIndicator(),
//             );
//           }

//           return ListView.builder(
//             itemCount: similarTopics.length,
//             itemBuilder: (context, index) {
//               final similarTopic = similarTopics[index];
//               final similarTopicId = similarTopic['similar_topic_id'];
//               final similarity = similarTopic['similarity'];
//               final bookTitle = similarTopic['bookTitle'] ?? 'Sem título';
//               final chapterTitle = similarTopic['chapterTitle'] ?? 'Sem título';

//               return Card(
//                 margin: const EdgeInsets.symmetric(vertical: 8.0),
//                 elevation: 4.0,
//                 child: ListTile(
//                   title: Text(
//                     'Livro: $bookTitle - Capítulo: $chapterTitle',
//                   ),
//                   subtitle: Text('Similaridade: $similarity'),
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) =>
//                             TopicContentView(topicId: similarTopicId),
//                       ),
//                     );
//                   },
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
