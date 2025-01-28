// import 'package:flutter/material.dart';
// import 'package:resumo_dos_deuses_flutter/components/topicHeader/title_text.dart';
// import '../components/bookFrame/book_frame.dart'; // Importa o BookFrame
// import '../components/tags_group.dart'; // Importa o TagsGroup
// import '../components/books_section.dart'; // Importa BooksSection
// import '../components/topicHeader/topic_header.dart'; // Importa TopicHeader

// class Bookbytag extends StatelessWidget {
//   const Bookbytag({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: Scaffold(
//         body: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const TitleText(
//                 text: "tag escolhida"), // Cabeçalho com o label "tag escolhida"
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0), // Margem ao redor
//                 child: Wrap(
//                   children: List.generate(10, (index) {
//                     return const Padding(
//                       padding:
//                           EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
//                       child: BookFrame(), // Cada item da lista é um BookFrame
//                     );
//                   }),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
