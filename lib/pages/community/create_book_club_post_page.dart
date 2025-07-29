// lib/pages/community/create_book_club_post_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

class CreateBookClubPostPage extends StatefulWidget {
  final String bookId;
  const CreateBookClubPostPage({super.key, required this.bookId});

  @override
  State<CreateBookClubPostPage> createState() => _CreateBookClubPostPageState();
}

class _CreateBookClubPostPageState extends State<CreateBookClubPostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    final store = StoreProvider.of<AppState>(context, listen: false);
    final userDetails = store.state.userState.userDetails;

    if (user == null || userDetails == null) {
      CustomNotificationService.showError(
          context, "Erro: Usuário não encontrado.");
      setState(() => _isLoading = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('bookClubs')
          .doc(widget.bookId)
          .collection('posts')
          .add({
        'authorId': user.uid,
        'authorName': userDetails['nome'] ?? 'Anônimo',
        'authorPhotoUrl': userDetails['photoURL'] ?? '',
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'likedBy': [],
        'replyCount': 0,
      });

      // Atualiza a última atividade do clube
      await FirebaseFirestore.instance
          .collection('bookClubs')
          .doc(widget.bookId)
          .update({'lastActivity': FieldValue.serverTimestamp()});

      if (mounted) {
        CustomNotificationService.showSuccess(
            context, "Sua discussão foi publicada!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(context, "Erro ao publicar: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Iniciar Discussão"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton(
              onPressed: _isLoading ? null : _submitPost,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Publicar"),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Título da Discussão (Opcional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: "Sua reflexão ou pergunta *",
                  hintText: "Compartilhe seus pensamentos sobre o livro...",
                  border: OutlineInputBorder(),
                ),
                maxLines: 10,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'Sua mensagem deve ter pelo menos 10 caracteres.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
