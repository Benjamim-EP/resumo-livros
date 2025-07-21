// lib/pages/community/create_post_page.dart (Versão Corrigida)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/svg.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

class CreatePostPage extends StatefulWidget {
  final String? postId;
  final Map<String, dynamic>? initialData;

  const CreatePostPage({
    super.key,
    this.postId,
    this.initialData,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _versesController = TextEditingController();

  String _selectedCategory = 'apologetica';
  bool _isLoading = false;
  bool _isGeneratingAIContent = false;

  Map<String, dynamic>? _booksMap;
  String? _selectedBookAbbrev;
  int? _selectedChapter;
  List<int> _availableChapters = [];
  bool _isPasswordProtected = false;
  final _passwordController = TextEditingController();
  bool _isAnonymous = false;

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
      if (widget.initialData != null) {
        _titleController.text = widget.initialData!['title'] ?? '';
        _contentController.text = widget.initialData!['content'] ?? '';
        _versesController.text = widget.initialData!['refVerses'] ?? '';
        _selectedCategory = widget.initialData!['category'] ?? 'duvidas_gerais';

        final bookAbbrev = widget.initialData!['refBook'] as String?;
        if (bookAbbrev != null) {
          _onBookSelected(bookAbbrev);
          final chapter = widget.initialData!['refChapter'] as int?;
          if (chapter != null) {
            _selectedChapter = chapter;
          }
        }
        setState(() {
          _isPasswordProtected =
              widget.initialData!['isPasswordProtected'] ?? false;
        });
      }
    });
  }

  Future<void> _loadBooksData() async {
    final map = await BiblePageHelper.loadBooksMap();
    if (mounted) {
      setState(() {
        _booksMap = map;
      });
    }
  }

  void _onBookSelected(String? bookAbbrev) {
    if (bookAbbrev == null || _booksMap == null) return;
    setState(() {
      _selectedBookAbbrev = bookAbbrev;
      _selectedChapter = null;
      final int chapterCount = _booksMap![bookAbbrev]?['capitulos'] ?? 0;
      _availableChapters = List<int>.generate(chapterCount, (i) => i + 1);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _versesController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isPasswordProtected && _passwordController.text.trim().length < 4) {
      CustomNotificationService.showError(
          context, "A senha deve ter pelo menos 4 caracteres.");
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        CustomNotificationService.showError(
            context, "Você precisa estar logado para postar.");
        setState(() => _isLoading = false);
      }
      return;
    }

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
      "isAnonymous": _isAnonymous,
      "category": _selectedCategory,
      "bibleReference": finalReference,
      "refBook": _selectedBookAbbrev,
      "refChapter": _selectedChapter,
      "refVerses": _versesController.text.trim(),
      "isPasswordProtected": _isPasswordProtected,
      "password": _isPasswordProtected && _passwordController.text.isNotEmpty
          ? _passwordController.text.trim()
          : null,
    };

    try {
      String successMessage;
      final callable =
          FirebaseFunctions.instanceFor(region: "southamerica-east1")
              .httpsCallable('createOrUpdatePost');
      final Map<String, dynamic> payload = Map.from(postData);

      if (widget.postId != null) {
        payload['postId'] = widget.postId;
        await callable.call(payload);
        successMessage = "Sua pergunta foi atualizada!";
      } else {
        await callable.call(payload);
        successMessage = "Sua pergunta foi postada!";
      }

      if (mounted) {
        if (widget.postId != null) {
          int popCount = 0;
          Navigator.of(context, rootNavigator: true)
              .popUntil((_) => popCount++ >= 2);
        } else {
          Navigator.of(context, rootNavigator: true).pop();
        }

        Future.microtask(() {
          if (navigatorKey.currentContext != null) {
            CustomNotificationService.showSuccess(
                navigatorKey.currentContext!, successMessage);
          }
        });
      }
    } on FirebaseFunctionsException catch (e) {
      // <<< MUDE "catch (e)" PARA ISSO
      print("Erro da Cloud Function ao salvar post: ${e.code} - ${e.message}");
      if (mounted) {
        // Mostra a mensagem de limite específica vinda do backend
        CustomNotificationService.showError(
            context, e.message ?? "Ocorreu um erro.");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Erro GERAL ao salvar post no cliente: $e");
      if (mounted) {
        CustomNotificationService.showError(
            context, "Ocorreu um erro inesperado ao salvar.");
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAIGenerationDialog() async {
    final TextEditingController descriptionController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Gerar Pergunta com IA"),
        content: TextField(
          controller: descriptionController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText:
                "Ex: 'Dúvidas sobre soberania de Deus vs livre arbítrio.'",
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(descriptionController.text);
            },
            child: const Text("Gerar"),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      _generateQuestionWithAI(result.trim());
    }
  }

  Future<void> _generateQuestionWithAI(String userDescription) async {
    setState(() => _isGeneratingAIContent = true);
    try {
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('generateForumQuestion');
      final result = await callable.call({
        'user_description': userDescription,
      });

      print('Resposta da função: ${result.data}');

      final data = result.data as Map<String, dynamic>?;
      if (data != null &&
          data['status'] == 'success' &&
          data['data'] != null &&
          data['data'] is Map) {
        final generatedData = Map<String, dynamic>.from(data['data']);
        setState(() {
          _titleController.text = generatedData['title'] ?? '';
          _contentController.text = generatedData['content'] ?? '';
        });
        CustomNotificationService.showSuccess(
            context, "Conteúdo gerado com IA!");
      } else {
        throw Exception(data?['message'] ?? 'Falha ao gerar conteúdo.');
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, e.message ?? "Erro ao se comunicar com a IA.");
      }
    } catch (e) {
      if (mounted) {
        print("Erro inesperado: $e");
        CustomNotificationService.showError(
            context, "Ocorreu um erro inesperado.");
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAIContent = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.postId == null ? "Faça uma Pergunta" : "Editar Pergunta"),
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
                  : Text(widget.postId == null ? "Postar" : "Salvar"),
            ),
          )
        ],
      ),
      body: _isGeneratingAIContent
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("A IA está elaborando sua pergunta..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- LAYOUT CORRIGIDO AQUI ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
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
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/buscasemantica.svg',
                            colorFilter: ColorFilter.mode(
                              Theme.of(context).colorScheme.primary,
                              BlendMode.srcIn,
                            ),
                            width: 24,
                            height: 24,
                          ),
                          tooltip: "Gerar pergunta com IA",
                          onPressed: _isGeneratingAIContent
                              ? null
                              : _showAIGenerationDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text("Referência Bíblica (Opcional)",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_booksMap == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _selectedBookAbbrev,
                              hint: const Text("Livro"),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
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
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              value: _selectedChapter,
                              hint: const Text("Cap."),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
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
                    TextFormField(
                      controller: _versesController,
                      decoration: const InputDecoration(
                        labelText: "Versículos (Opcional)",
                        hintText: "Ex: 28 ou 28-30",
                        border: OutlineInputBorder(),
                      ),
                      enabled: _selectedChapter != null,
                    ),
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
                    const SizedBox(height: 24),
                    // <<< INÍCIO DO NOVO WIDGET >>>
                    SwitchListTile(
                      title: const Text("Postar Anonimamente"),
                      subtitle: const Text(
                          "Seu nome e foto não serão exibidos nesta pergunta."),
                      value: _isAnonymous,
                      onChanged: (bool value) {
                        setState(() {
                          _isAnonymous = value;
                        });
                      },
                      secondary: const Icon(Icons.visibility_off_outlined),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text("Proteger com Senha"),
                            subtitle: const Text(
                                "Apenas usuários com a senha poderão ver o conteúdo."),
                            value: _isPasswordProtected,
                            onChanged: (bool value) {
                              setState(() {
                                _isPasswordProtected = value;
                              });
                            },
                          ),
                          if (_isPasswordProtected)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: widget.postId != null
                                      ? "Nova Senha (opcional)"
                                      : "Senha",
                                  hintText: "Mínimo 4 caracteres",
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
