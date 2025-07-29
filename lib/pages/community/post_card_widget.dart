// lib/pages/community/post_card_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

class PostCardWidget extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String bookId;
  final String postId; // Adicionado para a ação de like
  final VoidCallback onTap;

  const PostCardWidget({
    super.key,
    required this.postData,
    required this.bookId,
    required this.postId,
    required this.onTap,
  });

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget> {
  // Estado local para atualização otimista
  late int _likeCount;
  late bool _isLiked;
  bool _isProcessingLike = false;

  @override
  void initState() {
    super.initState();
    _updateStateFromWidget();
  }

  @override
  void didUpdateWidget(covariant PostCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincroniza o estado local se os dados do Firestore mudarem
    if (widget.postData['likeCount'] != oldWidget.postData['likeCount']) {
      _updateStateFromWidget();
    }
  }

  void _updateStateFromWidget() {
    final likedBy = List<String>.from(widget.postData['likedBy'] ?? []);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    setState(() {
      _likeCount = widget.postData['likeCount'] ?? 0;
      _isLiked = currentUserId != null && likedBy.contains(currentUserId);
    });
  }

  Future<void> _toggleLike() async {
    if (_isProcessingLike) return;

    final originalIsLiked = _isLiked;
    final originalLikeCount = _likeCount;

    // 1. Atualização Otimista da UI
    setState(() {
      _isProcessingLike = true;
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });

    try {
      // 2. Despacha a ação para o middleware
      await StoreProvider.of<AppState>(context, listen: false)
          .dispatch(ToggleBookClubPostLikeAction(
            bookId: widget.bookId,
            postId: widget.postId,
            isLiked: _isLiked,
          ))
          .future; // O .future espera o middleware concluir ou falhar
    } catch (e) {
      // 3. Reversão em caso de erro
      if (mounted) {
        CustomNotificationService.showError(
            context, "Erro ao registrar o like.");
        setState(() {
          _isLiked = originalIsLiked;
          _likeCount = originalLikeCount;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingLike = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ... (resto da lógica de build que você já tinha)
    final timestamp = widget.postData['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('dd/MM/yy').format(timestamp.toDate())
        : '';
    final authorPhotoUrl = widget.postData['authorPhotoUrl'] as String?;
    final authorName = widget.postData['authorName'] ?? 'Anônimo';
    final title = widget.postData['title'] as String?;
    final content = widget.postData['content'] as String? ?? '';
    final replyCount = (widget.postData['replyCount'] ?? 0).toString();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho com Autor e Data
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        (authorPhotoUrl != null && authorPhotoUrl.isNotEmpty)
                            ? NetworkImage(authorPhotoUrl)
                            : null,
                    child: (authorPhotoUrl == null || authorPhotoUrl.isEmpty)
                        ? Text(authorName.isNotEmpty ? authorName[0] : '?')
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$authorName • $date',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Título (se houver)
              if (title != null && title.isNotEmpty)
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              if (title != null && title.isNotEmpty) const SizedBox(height: 8),

              // Conteúdo
              Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 12),

              // --- RODAPÉ COM BOTÕES DE AÇÃO ---
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                        _isLiked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 20,
                        color: _isLiked
                            ? theme.colorScheme.primary
                            : theme.iconTheme.color),
                    onPressed: _toggleLike,
                  ),
                  Text(_likeCount.toString(),
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 16),
                  Icon(Icons.comment_outlined,
                      size: 20, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 6),
                  Text(replyCount, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
