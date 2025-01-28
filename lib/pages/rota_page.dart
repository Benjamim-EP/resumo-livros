import 'package:flutter/material.dart';
import 'package:arrow_path/arrow_path.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/pages/components/min_topic_card.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RotaPage extends StatefulWidget {
  @override
  _RotaPageState createState() => _RotaPageState();
}

class _RotaPageState extends State<RotaPage> {
  // Controle de quais livros estão visíveis
  List<bool> _visibleBooks = [];
  bool isPremium = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StoreConnector<AppState, Map<String, dynamic>>(
        converter: (store) => store.state.userState.userDetails ?? {},
        onDidChange: (previousDetails, newDetails) {
          setState(() {
            isPremium = _getPremiumStatus(newDetails);
          });
        },
        onInit: (store) {
          if (store.state.userState.tribeTopicsByFeature.isEmpty) {
            store.dispatch(LoadTopicsByFeatureAction());
          }
        },
        builder: (context, userDetails) {
          final tribeTopicsByFeature =
              store.state.userState.tribeTopicsByFeature;

          if (tribeTopicsByFeature.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupedBooks = _groupBooksById(tribeTopicsByFeature);
          final books = _generateBookNodes(groupedBooks);

          if (_visibleBooks.isEmpty) {
            _visibleBooks = List.generate(
              books.length,
              (index) => index == 0 || isPremium,
            );
          }

          return InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.5,
            maxScale: 2.5,
            child: Stack(
              children: [
                CustomPaint(
                  painter: BooksGraphPainter(books, _visibleBooks),
                  size: const Size(2000, 2000),
                ),
                ...books.asMap().entries.map((entry) {
                  final index = entry.key;
                  final book = entry.value;
                  final isLocked = !isPremium && index > 0;

                  return Visibility(
                    visible: _visibleBooks[index],
                    child: Positioned(
                      left: book.position.dx,
                      top: book.position.dy,
                      child: GestureDetector(
                        onTap: () => _onBookTap(index),
                        child: _BookWidget(
                          book: book,
                          topics: book.topics,
                          isLocked: isLocked,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onBookTap(int index) {
    setState(() {
      if (index + 1 < _visibleBooks.length) {
        _visibleBooks[index + 1] = true; // Permite desbloquear visualmente
      }
    });
  }

  bool _getPremiumStatus(Map<String, dynamic>? userDetails) {
    if (userDetails == null) return false;

    final premiumData = userDetails['isPremium'] as Map<String, dynamic>?;

    if (premiumData != null) {
      final expirationTimestamp = premiumData['expiration'];

      if (expirationTimestamp != null && expirationTimestamp is Timestamp) {
        final expirationDate = expirationTimestamp.toDate();
        final now = DateTime.now();
        return now.isBefore(expirationDate); // Se ainda for válido, é premium
      }
    }
    return false; // Se não houver dados premium válidos
  }

  // Função para agrupar tópicos por bookId
  Map<String, List<Map<String, dynamic>>> _groupBooksById(
      Map<String, List<Map<String, dynamic>>> tribeTopicsByFeature) {
    final Map<String, List<Map<String, dynamic>>> groupedBooks = {};
    for (var entry in tribeTopicsByFeature.entries) {
      for (final topic in entry.value) {
        final bookId = topic['bookId'];
        if (bookId != null) {
          groupedBooks.putIfAbsent(bookId, () => []).add(topic);
        }
      }
    }
    return groupedBooks;
  }

  // Função para gerar BookNodes dinamicamente
  List<BookNode> _generateBookNodes(
      Map<String, List<Map<String, dynamic>>> groupedBooks) {
    final List<BookNode> bookNodes = [];
    const double initialX = 100; // Posição inicial x
    const double initialY = 100; // Posição inicial y
    const double verticalSpacing = 150; // Espaço entre os livros

    groupedBooks.forEach((bookId, topics) {
      if (topics.isNotEmpty) {
        final firstTopic = topics.first;
        final currentIndex = bookNodes.length;

        // Calcula posição com base no índice
        final position = Offset(
          initialX,
          initialY + currentIndex * verticalSpacing,
        );

        bookNodes.add(BookNode(
          bookId: bookId,
          title: _truncateString(firstTopic['bookName'] ?? 'Sem título', 15),
          image: firstTopic['cover'] ?? 'assets/default_book.jpg',
          position: position,
          connections: currentIndex > 0 ? [currentIndex - 1] : [],
          topics: topics, // Passa os tópicos aqui
        ));
      }
    });

    return bookNodes;
  }

  // Trunca o título para um limite de caracteres
  String _truncateString(String text, int maxLength) {
    return text.length > maxLength
        ? '${text.substring(0, maxLength)}...'
        : text;
  }
}

class BooksGraphPainter extends CustomPainter {
  final List<BookNode> books;
  final List<bool> visibleBooks;

  BooksGraphPainter(this.books, this.visibleBooks);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < books.length; i++) {
      if (!visibleBooks[i]) continue; // Ignora livros não visíveis
      final book = books[i];
      for (final connection in book.connections) {
        if (connection < books.length && visibleBooks[connection]) {
          final target = books[connection];

          // Cria um caminho curvo para a seta
          final path = Path()
            ..moveTo(
                book.position.dx + 35, book.position.dy + 50) // Ponto inicial
            ..quadraticBezierTo(
              (book.position.dx + target.position.dx) / 2, // Controle da curva
              (book.position.dy + target.position.dy) / 2 - 50, // Altura
              target.position.dx + 35,
              target.position.dy,
            );

          // Adiciona a seta ao caminho
          final arrowPath = ArrowPath.make(
            path: path,
            tipLength: 15.0,
            tipAngle: 45.0,
          );

          // Desenha o caminho no canvas
          canvas.drawPath(arrowPath, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class _BookWidget extends StatelessWidget {
  final BookNode book;
  final List<Map<String, dynamic>> topics;
  final bool isLocked;

  const _BookWidget({
    required this.book,
    required this.topics,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Image.network(
              book.image,
              height: 100,
              width: 70,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/default_book.jpg',
                  height: 100,
                  width: 70,
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                IconButton(
                  icon: const Icon(Icons.info, color: Colors.white, size: 16),
                  onPressed: isLocked ? null : () => _showTopicsDialog(context),
                ),
              ],
            ),
          ],
        ),
        if (isLocked)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Icon(Icons.lock, color: Colors.white, size: 24),
              ),
            ),
          ),
      ],
    );
  }

  void _showTopicsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: 300,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tópicos de ${book.title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: topics.length,
                    itemBuilder: (context, index) {
                      final topic = topics[index];

                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: MinTopicCard(
                          title: topic['titulo'] ?? 'Sem título',
                          content: topic['conteudo'] ?? 'Sem conteúdo',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BookNode {
  final String bookId;
  final String title;
  final String image;
  final Offset position;
  final List<int> connections;
  final List<Map<String, dynamic>> topics; // Adicione os tópicos

  BookNode({
    required this.bookId,
    required this.title,
    required this.image,
    required this.position,
    required this.connections,
    required this.topics,
  });
}
