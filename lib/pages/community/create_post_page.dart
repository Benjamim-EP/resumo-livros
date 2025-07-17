// lib/pages/community/create_post_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart'; // Importa nosso helper
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

class CreatePostPage extends StatefulWidget {
  // ✅ INÍCIO DA MUDANÇA: Adiciona parâmetros opcionais
  final String? postId;
  final Map<String, dynamic>? initialData;

  const CreatePostPage({
    super.key,
    this.postId,
    this.initialData,
  });
  // ✅ FIM DA MUDANÇA

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _versesController =
      TextEditingController(); // Para o range de versículos

  String _selectedCategory = 'apologetica';
  bool _isLoading = false;

  // ✅ NOVOS ESTADOS PARA OS SELETORES
  Map<String, dynamic>? _booksMap;
  String? _selectedBookAbbrev;
  int? _selectedChapter;
  List<int> _availableChapters = [];

  final List<Map<String, String>> _categories = [
    {'value': 'apologetica', 'label': 'Apologética (Defesa da Fé)'},
    {'value': 'teologia_sistematica', 'label': 'Teologia'},
    {'value': 'vida_crista', 'label': 'Vida Cristã e Aconselhamento'},
    {'value': 'duvidas_gerais', 'label': 'Dúvidas Gerais'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBooksData().then((_) {
      // ✅ INÍCIO DA MUDANÇA: Preenche o formulário com dados iniciais
      if (widget.initialData != null) {
        _titleController.text = widget.initialData!['title'] ?? '';
        _contentController.text = widget.initialData!['content'] ?? '';
        _versesController.text = widget.initialData!['refVerses'] ?? '';
        _selectedCategory = widget.initialData!['category'] ?? 'duvidas_gerais';

        // Pré-seleciona o livro e o capítulo
        final bookAbbrev = widget.initialData!['refBook'] as String?;
        if (bookAbbrev != null) {
          _onBookSelected(bookAbbrev); // Isso vai popular a lista de capítulos
          final chapter = widget.initialData!['refChapter'] as int?;
          if (chapter != null) {
            _selectedChapter = chapter;
          }
        }
        // Força um rebuild para garantir que os dropdowns sejam atualizados
        setState(() {});
      }
      // ✅ FIM DA MUDANÇA
    });
  }

  // ✅ NOVA FUNÇÃO PARA CARREGAR O MAPA DE LIVROS
  Future<void> _loadBooksData() async {
    final map = await BiblePageHelper.loadBooksMap();
    if (mounted) {
      setState(() {
        _booksMap = map;
      });
    }
  }

  // ✅ NOVA FUNÇÃO PARA ATUALIZAR OS CAPÍTULOS DISPONÍVEIS
  void _onBookSelected(String? bookAbbrev) {
    if (bookAbbrev == null || _booksMap == null) return;
    setState(() {
      _selectedBookAbbrev = bookAbbrev;
      _selectedChapter = null; // Reseta o capítulo ao trocar de livro
      final int chapterCount = _booksMap![bookAbbrev]?['capitulos'] ?? 0;
      _availableChapters = List<int>.generate(chapterCount, (i) => i + 1);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _versesController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    final userDetails = StoreProvider.of<AppState>(context, listen: false)
        .state
        .userState
        .userDetails;

    if (user == null || userDetails == null) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Você precisa estar logado para postar.");
        setState(() => _isLoading = false);
      }
      return;
    }

    // Monta os dados do post
    String? finalReference;
    if (_selectedBookAbbrev != null) {
      final bookName = _booksMap?[_selectedBookAbbrev]?['nome'] ?? '';
      if (_selectedChapter != null) {
        final verses = _versesController.text.trim();
        finalReference = verses.isNotEmpty
            ? '$bookName $_selectedChapter:$verses'
            : '$bookName $_selectedChapter';
      } else {
        finalReference = bookName;
      }
    }

    final postData = {
      "title": _titleController.text.trim(),
      "content": _contentController.text.trim(),
      "category": _selectedCategory,
      "bibleReference": finalReference,
      "refBook": _selectedBookAbbrev,
      "refChapter": _selectedChapter,
      "refVerses": _versesController.text.trim(),
      "lastUpdated": FieldValue.serverTimestamp(),
    };

    try {
      String successMessage;

      if (widget.postId != null) {
        // --- MODO DE EDIÇÃO ---
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .update(postData);
        successMessage = "Sua pergunta foi atualizada!";
      } else {
        // --- MODO DE CRIAÇÃO ---
        final newPostData = {
          ...postData,
          "authorId": user.uid,
          "authorName": userDetails['nome'] ?? 'Anônimo',
          "authorPhotoUrl": userDetails['photoURL'] ?? '',
          "tags": [],
          "timestamp": FieldValue.serverTimestamp(),
          "answerCount": 0,
          "upvoteCount": 0,
          "bestAnswerId": null,
        };
        await FirebaseFirestore.instance.collection('posts').add(newPostData);
        successMessage = "Sua pergunta foi postada!";
      }

      // ✅ INÍCIO DA CORREÇÃO PRINCIPAL
      // Se a escrita no Firestore foi bem-sucedida, agora lidamos com a UI.

      // É crucial que a navegação aconteça ANTES de mostrar a notificação,
      // para que a notificação apareça na tela correta (a lista de posts).
      if (mounted) {
        // 1. Navega de volta para a lista de posts
        // O `rootNavigator: true` ajuda a garantir que estamos usando o navegador principal do app.
        if (widget.postId != null) {
          // Modo Edição: Fecha a CreatePostPage e a PostDetailPage
          int popCount = 0;
          Navigator.of(context, rootNavigator: true)
              .popUntil((_) => popCount++ >= 2);
        } else {
          // Modo Criação: Fecha apenas a CreatePostPage
          Navigator.of(context, rootNavigator: true).pop();
        }

        // 2. Mostra a notificação de sucesso na nova tela visível
        // Usamos um microtask para garantir que a notificação só seja mostrada
        // depois que a navegação for completamente processada pelo Flutter.
        Future.microtask(() {
          if (navigatorKey.currentContext != null) {
            CustomNotificationService.showSuccess(
                navigatorKey.currentContext!, successMessage);
          }
        });
      }
      // ✅ FIM DA CORREÇÃO PRINCIPAL
    } catch (e) {
      print("Erro ao salvar post no cliente: $e");
      if (mounted) {
        CustomNotificationService.showError(
            context, "Ocorreu um erro ao salvar.");
        // Se deu erro, apenas desativamos o loading.
        setState(() => _isLoading = false);
      }
    }
    // O 'finally' foi removido para dar controle total do `_isLoading` dentro do `try/catch`.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Faça uma Pergunta"),
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
                  : const Text("Postar"),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Sua Pergunta",
                  hintText: "Seja claro e objetivo no título.",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'O título deve ter pelo menos 10 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ✅ SEÇÃO DE REFERÊNCIA BÍBLICA ATUALIZADA
              Text("Referência Bíblica (Opcional)",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_booksMap == null)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seletor de Livro
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedBookAbbrev,
                        hint: const Text("Livro"),
                        isExpanded: true,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        items: _booksMap!.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value['nome'],
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: _onBookSelected,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Seletor de Capítulo
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: _selectedChapter,
                        hint: const Text("Cap."),
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        // Desabilitado se nenhum livro for selecionado
                        onChanged: _selectedBookAbbrev == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedChapter = value;
                                });
                              },
                        items: _availableChapters.map((chapterNum) {
                          return DropdownMenuItem(
                            value: chapterNum,
                            child: Text(chapterNum.toString()),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // Campo de Versículos
              TextFormField(
                controller: _versesController,
                decoration: const InputDecoration(
                  labelText: "Versículos (Opcional)",
                  hintText: "Ex: 28 ou 28-30",
                  border: OutlineInputBorder(),
                ),
                enabled: _selectedChapter !=
                    null, // Só habilita se um capítulo for selecionado
              ),
              // FIM DA SEÇÃO DE REFERÊNCIA

              const SizedBox(height: 24),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: "Contexto (Opcional)",
                  hintText: "Adicione mais detalhes...",
                  border: OutlineInputBorder(),
                ),
                maxLines: 6,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Categoria",
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category['value'],
                    child: Text(category['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
