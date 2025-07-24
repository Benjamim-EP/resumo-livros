// lib/pages/bibtok/quote_card_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/bibtok/comments_modal.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/pages/sharing/shareable_image_generator_page.dart';
import 'package:septima_biblia/services/analytics_service.dart';

class QuoteCardWidget extends StatefulWidget {
  final Map<String, dynamic> quoteData;
  // Callback para notificar o pai (BibTokPage) sobre uma mudança na curtida.
  final void Function(String quoteId, bool isNowLiked, int newLikeCount)
      onLikeChanged;
  // Callback para notificar o pai que o modal de comentários foi fechado,
  // para que ele possa atualizar a contagem de comentários.
  final void Function(String quoteId) onCommentPosted;

  const QuoteCardWidget({
    super.key,
    required this.quoteData,
    required this.onLikeChanged,
    required this.onCommentPosted,
  });

  @override
  State<QuoteCardWidget> createState() => _QuoteCardWidgetState();
}

class _QuoteCardWidgetState extends State<QuoteCardWidget> {
  // O estado local é usado para uma resposta instantânea da UI.
  late int _likeCount;
  late bool _isLiked;
  bool _isLikeProcessing = false;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Inicializa o estado local com os dados recebidos do widget pai.
    _updateStateFromWidget();
  }

  /// Sincroniza o estado local do widget com os dados recebidos do pai.
  /// Isso é crucial para quando o widget é reconstruído após rolar a tela.
  @override
  void didUpdateWidget(covariant QuoteCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se os dados de curtida do pai mudaram, atualiza a UI local.
    if (widget.quoteData['likeCount'] != _likeCount ||
        _isLikedByCurrentUser(widget.quoteData) != _isLiked) {
      _updateStateFromWidget();
    }
  }

  /// Função central para atualizar o estado local a partir dos `props` (widget.quoteData).
  void _updateStateFromWidget() {
    setState(() {
      _likeCount = widget.quoteData['likeCount'] ?? 0;
      _isLiked = _isLikedByCurrentUser(widget.quoteData);
    });
  }

  /// Helper para verificar se o usuário atual curtiu a frase.
  bool _isLikedByCurrentUser(Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final List<dynamic> likedBy = data['likedBy'] ?? [];
    return currentUserId != null && likedBy.contains(currentUserId);
  }

  /// Lida com o toque no botão de curtir.
  Future<void> _toggleLike() async {
    if (_isLikeProcessing) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // 1. Atualização Otimista da UI Local:
    // A UI responde instantaneamente, antes da confirmação do backend.
    setState(() {
      _isLikeProcessing = true;
      _isLiked ? _likeCount-- : _likeCount++;
      _isLiked = !_isLiked;
    });

    // 2. Notifica o Pai:
    // Avisa a BibTokPage sobre a mudança para que ela atualize sua lista de dados.
    widget.onLikeChanged(widget.quoteData['id'], _isLiked, _likeCount);

    final bool wasLikeAction = _isLiked;

    try {
      // 3. Persistência no Backend (Firestore):
      // A lógica de transação no Firestore permanece a mesma.
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
          });
        }
      }
    } catch (e) {
      print("Erro ao curtir a frase: $e");
      // 4. Reversão em caso de erro:
      // Se a chamada ao Firestore falhar, desfaz a mudança na UI local.
      setState(() {
        _isLiked ? _likeCount++ : _likeCount--;
        _isLiked = !_isLiked;
      });
      // E também avisa o pai para que ele reverta o estado.
      widget.onLikeChanged(widget.quoteData['id'], _isLiked, _likeCount);
    } finally {
      if (mounted) setState(() => _isLikeProcessing = false);
    }
  }

  /// Mostra o modal de comentários e notifica o pai quando ele é fechado.
  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModal(
          quoteId: widget.quoteData['id'], quoteText: widget.quoteData['text']),
    ).whenComplete(() {
      // Quando o modal é fechado, chama o callback para que a BibTokPage
      // possa buscar a nova contagem de comentários do Firestore.
      widget.onCommentPosted(widget.quoteData['id']);
    });
  }

  /// Calcula o tamanho da fonte com base no comprimento do texto da citação.
  double _getFontSizeForText(String text) {
    const double baseSize = 26.0;
    const double minSize = 18.0;
    final int textLength = text.length;
    const int shortThreshold = 120;
    const int longThreshold = 300;
    if (textLength <= shortThreshold) return baseSize;
    if (textLength >= longThreshold) return minSize;
    final double progress =
        (textLength - shortThreshold) / (longThreshold - shortThreshold);
    return baseSize - (progress * (baseSize - minSize));
  }

  @override
  Widget build(BuildContext context) {
    final String quoteText = widget.quoteData['text'] ?? '';
    final double dynamicFontSize = _getFontSizeForText(quoteText);
    final String author = widget.quoteData['author'] ?? 'Autor Desconhecido';
    final String book = widget.quoteData['book'] ?? 'Livro Desconhecido';
    final String quoteId = widget.quoteData['id'] ?? 'default_id';
    final String reference = "- $author, em '$book'";
    final String imageUrl = "https://picsum.photos/seed/$quoteId/450/800";
    // Usa a contagem de comentários do estado do widget pai (que é atualizado)
    final int commentCount = widget.quoteData['commentCount'] ?? 0;

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
                  '"$quoteText"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
                  reference,
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
              // Exibe a contagem de comentários
              Text(commentCount.toString(),
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 32),
                onPressed: () {
                  AnalyticsService.instance.logEvent(
                    name: 'share_attempt',
                    parameters: {
                      'content_type': 'bibtok_quote',
                      'quote_id': quoteId
                    },
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShareableImageGeneratorPage(
                        verseText: quoteText,
                        verseReference: reference,
                        imageUrl: imageUrl,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        )
      ],
    );
  }
}
