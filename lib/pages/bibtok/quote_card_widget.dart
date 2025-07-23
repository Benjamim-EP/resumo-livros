// lib/pages/bibtok/quote_card_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/bibtok/comments_modal.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';

class QuoteCardWidget extends StatefulWidget {
  final Map<String, dynamic> quoteData;
  const QuoteCardWidget({super.key, required this.quoteData});

  @override
  State<QuoteCardWidget> createState() => _QuoteCardWidgetState();
}

class _QuoteCardWidgetState extends State<QuoteCardWidget> {
  late int _likeCount;
  late bool _isLiked;
  bool _isLikeProcessing = false;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _likeCount = widget.quoteData['likeCount'] ?? 0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final List<dynamic> likedBy = widget.quoteData['likedBy'] ?? [];
    _isLiked = currentUserId != null && likedBy.contains(currentUserId);
  }

  Future<void> _toggleLike() async {
    if (_isLikeProcessing) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      _isLikeProcessing = true;
      _isLiked ? _likeCount-- : _likeCount++;
      _isLiked = !_isLiked;
    });

    final bool wasLikeAction = _isLiked;

    try {
      final quoteRef = FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quoteData['id']);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshSnap = await transaction.get(quoteRef);
        if (!freshSnap.exists) {
          transaction.set(quoteRef, {
            'text': widget.quoteData['text'],
            'author': widget.quoteData['author'],
            'book': widget.quoteData['book'],
            'likeCount': 1,
            'commentCount': 0,
            'likedBy': [currentUserId],
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final currentLikedBy =
              List<String>.from(freshSnap.data()?['likedBy'] ?? []);
          if (currentLikedBy.contains(currentUserId)) {
            transaction.update(quoteRef, {
              'likeCount': FieldValue.increment(-1),
              'likedBy': FieldValue.arrayRemove([currentUserId])
            });
          } else {
            transaction.update(quoteRef, {
              'likeCount': FieldValue.increment(1),
              'likedBy': FieldValue.arrayUnion([currentUserId])
            });
          }
        }
      });

      if (wasLikeAction) {
        final quoteText = widget.quoteData['text'] as String?;
        if (quoteText != null && quoteText.isNotEmpty) {
          _firestoreService
              .addRecentInteraction(currentUserId, quoteText)
              .then((_) {
            if (mounted) {
              StoreProvider.of<AppState>(context, listen: false)
                  .dispatch(LoadUserDetailsAction());
            }
          }).catchError((error) {
            print("Erro ao adicionar interação recente: $error");
          });
        }
      }
    } catch (e) {
      print("Erro ao curtir a frase: $e");
      setState(() {
        _isLiked ? _likeCount++ : _likeCount--;
        _isLiked = !_isLiked;
      });
    } finally {
      if (mounted) setState(() => _isLikeProcessing = false);
    }
  }

  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModal(
          quoteId: widget.quoteData['id'], quoteText: widget.quoteData['text']),
    );
  }

  // ===================================
  // <<< INÍCIO DA NOVA FUNÇÃO >>>
  // ===================================
  /// Calcula o tamanho da fonte dinamicamente com base no comprimento do texto.
  double _getFontSizeForText(String text) {
    const double baseSize = 26.0; // Tamanho para textos curtos
    const double minSize = 18.0; // Tamanho mínimo para textos muito longos
    final int textLength = text.length;

    // Define os limites de caracteres para os tamanhos de fonte
    const int shortThreshold = 120; // Abaixo disso, o tamanho é `baseSize`
    const int longThreshold = 300; // Acima disso, o tamanho é `minSize`

    if (textLength <= shortThreshold) {
      return baseSize;
    }

    if (textLength >= longThreshold) {
      return minSize;
    }

    // Interpolação linear para textos de tamanho intermediário
    // Calcula a "porcentagem" do caminho entre o limite curto e o longo
    final double progress =
        (textLength - shortThreshold) / (longThreshold - shortThreshold);
    // Aplica essa porcentagem à faixa de tamanhos de fonte disponíveis
    return baseSize - (progress * (baseSize - minSize));
  }
  // ===================================
  // <<< FIM DA NOVA FUNÇÃO >>>
  // ===================================

  @override
  Widget build(BuildContext context) {
    // ===================================
    // <<< MUDANÇA NO BUILD >>>
    // ===================================
    final String quoteText = widget.quoteData['text'] ?? '';
    final double dynamicFontSize = _getFontSizeForText(quoteText);
    // ===================================

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '"$quoteText"', // Usa a variável local
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      // Aplica o tamanho dinâmico aqui
                      fontSize: dynamicFontSize,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      shadows: const [
                        Shadow(blurRadius: 10, color: Colors.black)
                      ]),
                ),
                const SizedBox(height: 24),
                Text(
                  "- ${widget.quoteData['author']}, em '${widget.quoteData['book']}'",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)]),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.redAccent : Colors.white,
                    size: 32),
                onPressed: _toggleLike,
              ),
              Text(_likeCount.toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(Icons.comment_outlined,
                    color: Colors.white, size: 32),
                onPressed: _showCommentsModal,
              ),
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 32),
                onPressed: () {/* Adicionar lógica de compartilhamento */},
              ),
            ],
          ),
        )
      ],
    );
  }
}
