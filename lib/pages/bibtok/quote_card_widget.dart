// lib/pages/bibtok/quote_card_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart'; // <<< NOVO IMPORT
import 'package:septima_biblia/pages/bibtok/comments_modal.dart';
import 'package:septima_biblia/redux/actions.dart'; // <<< NOVO IMPORT
import 'package:septima_biblia/redux/store.dart'; // <<< NOVO IMPORT
import 'package:septima_biblia/services/firestore_service.dart'; // <<< NOVO IMPORT

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

  // ===================================
  // <<< INÍCIO DA NOVA SEÇÃO >>>
  // ===================================
  // Instancia o serviço do Firestore para usar na função de curtir.
  final FirestoreService _firestoreService = FirestoreService();
  // ===================================
  // <<< FIM DA NOVA SEÇÃO >>>
  // ===================================

  @override
  void initState() {
    super.initState();
    _likeCount = widget.quoteData['likeCount'] ?? 0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final List<dynamic> likedBy = widget.quoteData['likedBy'] ?? [];
    _isLiked = currentUserId != null && likedBy.contains(currentUserId);
  }

  // ===================================
  // <<< FUNÇÃO _toggleLike ATUALIZADA >>>
  // ===================================
  Future<void> _toggleLike() async {
    if (_isLikeProcessing) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Atualização otimista da UI
    setState(() {
      _isLikeProcessing = true;
      _isLiked ? _likeCount-- : _likeCount++;
      _isLiked = !_isLiked;
    });

    // Armazena a ação que está sendo feita (curtir ou descurtir)
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
            // Lógica de descurtir
            transaction.update(quoteRef, {
              'likeCount': FieldValue.increment(-1),
              'likedBy': FieldValue.arrayRemove([currentUserId])
            });
          } else {
            // Lógica de curtir
            transaction.update(quoteRef, {
              'likeCount': FieldValue.increment(1),
              'likedBy': FieldValue.arrayUnion([currentUserId])
            });
          }
        }
      });

      // --- LÓGICA DE INTERAÇÃO ADICIONADA AQUI ---
      // Se a ação foi de curtir (e não descurtir), adiciona ao histórico de interações.
      if (wasLikeAction) {
        final quoteText = widget.quoteData['text'] as String?;
        if (quoteText != null && quoteText.isNotEmpty) {
          print("BibTok: Adicionando frase curtida às interações recentes.");
          // Chamada assíncrona ao Firestore em segundo plano. Não esperamos por ela.
          _firestoreService
              .addRecentInteraction(currentUserId, quoteText)
              .then((_) {
            // Após a interação ser salva com sucesso, despachamos a ação
            // para recarregar os detalhes do usuário no Redux,
            // o que atualizará o feed personalizado na próxima vez que for carregado.
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
      // Reverte a UI em caso de erro
      setState(() {
        _isLiked ? _likeCount++ : _likeCount--;
        _isLiked = !_isLiked;
      });
    } finally {
      if (mounted) setState(() => _isLikeProcessing = false);
    }
  }
  // ===================================
  // <<< FIM DA ATUALIZAÇÃO >>>
  // ===================================

  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsModal(
          quoteId: widget.quoteData['id'], quoteText: widget.quoteData['text']),
    );
  }

  @override
  Widget build(BuildContext context) {
    // O método build permanece o mesmo
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
                  '"${widget.quoteData['text']}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
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
