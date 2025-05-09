// lib/pages/user_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for listEquals
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page/user_diary_page.dart';
import '../components/avatar/profile_picture.dart';
import '../components/user/user_info.dart';
import '../components/stats/stat_item.dart';
import '../components/tabs/tabs.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:redux/redux.dart';
import 'package:intl/intl.dart';

// Enum para o tipo de destaque
enum HighlightType { verses, comments }

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  Map<String, dynamic>? _localBooksMap;
  bool _isLoadingBooksMap = true;
  String _selectedTab = 'Destaques';
  HighlightType _selectedHighlightType = HighlightType.verses;

  @override
  void initState() {
    super.initState();
    _loadLocalBooksMap();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeInstance = StoreProvider.of<AppState>(context, listen: false);
      if (storeInstance.state.userState.userId != null) {
        storeInstance.dispatch(LoadUserStatsAction());
        storeInstance.dispatch(LoadUserCollectionsAction());
        storeInstance.dispatch(LoadUserDiariesAction());

        if (storeInstance.state.userState.userHighlights.isEmpty) {
          storeInstance.dispatch(LoadUserHighlightsAction());
        }
        if (storeInstance.state.userState.userCommentHighlights.isEmpty) {
          storeInstance.dispatch(LoadUserCommentHighlightsAction());
        }
        if (storeInstance.state.userState.userNotes.isEmpty) {
          storeInstance.dispatch(LoadUserNotesAction());
        }
        if (storeInstance.state.userState.readingHistory.isEmpty) {
          storeInstance.dispatch(LoadReadingHistoryAction());
        }
      }
    });
  }

  Future<void> _loadLocalBooksMap() async {
    try {
      final map = await BiblePageHelper.loadBooksMap();
      if (mounted) {
        setState(() {
          _localBooksMap = map;
          _isLoadingBooksMap = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar booksMap localmente em UserPage: $e");
      if (mounted) {
        setState(() {
          _isLoadingBooksMap = false;
        });
      }
    }
  }

  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _navigateToBibleVerse(String verseId) {
    final parts = verseId.split('_');
    if (parts.length == 3) {
      final bookAbbrev = parts[0];
      final chapter = int.tryParse(parts[1]);
      if (chapter != null) {
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
        print("Navegação para Bíblia solicitada: $bookAbbrev $chapter");
      }
    }
  }

  Widget _buildCommentHighlightCard(
      Map<String, dynamic> highlight, BuildContext context) {
    final String selectedSnippet =
        highlight['selectedSnippet'] ?? 'Trecho indisponível';
    final String fullCommentText =
        highlight['fullCommentText'] ?? 'Comentário completo indisponível';
    final String referenceText =
        highlight['verseReferenceText'] ?? 'Referência desconhecida';
    final String highlightId = highlight['id'] ?? '';

    return Card(
      color: const Color(0xFF3A3C3C),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${selectedSnippet}"',
              style: const TextStyle(
                color: Colors.amber, // Cor diferente para o trecho
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              "Contexto: ${fullCommentText.length > 100 ? fullCommentText.substring(0, 100) + "..." : fullCommentText}",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    referenceText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (highlightId.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: "Remover Marcação",
                    onPressed: () {
                      StoreProvider.of<AppState>(context, listen: false)
                          .dispatch(RemoveCommentHighlightAction(highlightId));
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTab == 'Destaques' &&
        _selectedHighlightType == HighlightType.verses &&
        _isLoadingBooksMap) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFCDE7BE)));
    }
    if (_localBooksMap == null &&
        (_selectedTab == 'Notas' ||
            _selectedTab == 'Histórico' ||
            _selectedTab == 'Salvos')) {
      return const Center(
          child: Text("Erro ao carregar dados dos livros.",
              style: TextStyle(color: Colors.redAccent)));
    }

    switch (_selectedTab) {
      case 'Lendo':
        return const Center(
          child: Text(
            'Seção de Livros em Leitura (Desativada Temporariamente)',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        );

      case 'Salvos':
        return StoreConnector<AppState,
            Map<String, List<Map<String, dynamic>>>>(
          converter: (store) => store.state.userState.savedTopicsContent,
          onInit: (store) {
            if (store.state.userState.topicSaves.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadUserCollectionsAction());
            }
            if (store.state.userState.savedTopicsContent.isEmpty &&
                store.state.userState.topicSaves.isNotEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadTopicsContentUserSavesAction());
            }
          },
          builder: (context, savedTopicsContent) {
            final topicSavesMap =
                StoreProvider.of<AppState>(context).state.userState.topicSaves;

            if (topicSavesMap.isEmpty) {
              return const Center(
                  child: Text("Nenhuma coleção salva.",
                      style: TextStyle(color: Colors.white70)));
            }
            if (savedTopicsContent.isEmpty && topicSavesMap.isNotEmpty) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFCDE7BE)));
            }

            if (savedTopicsContent.isEmpty && topicSavesMap.isEmpty) {
              return const Center(
                  child: Text("Nenhum tópico ou versículo salvo.",
                      style: TextStyle(color: Colors.white70)));
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: savedTopicsContent.entries.map((entry) {
                final collectionName = entry.key;
                final items = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 3.0,
                  color: const Color(0xFF313333),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white70,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(collectionName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined,
                              color: Colors.redAccent),
                          tooltip: "Excluir Coleção",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (dContext) => AlertDialog(
                                      backgroundColor: const Color(0xFF2C2F33),
                                      title: const Text("Confirmar Exclusão",
                                          style:
                                              TextStyle(color: Colors.white)),
                                      content: Text(
                                          "Tem certeza que deseja excluir a coleção '$collectionName' e todos os seus itens?",
                                          style:
                                              TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dContext),
                                            child: const Text("Cancelar",
                                                style: TextStyle(
                                                    color: Colors.white70))),
                                        TextButton(
                                            onPressed: () {
                                              StoreProvider.of<AppState>(
                                                      context,
                                                      listen: false)
                                                  .dispatch(
                                                      DeleteTopicCollectionAction(
                                                          collectionName));
                                              Navigator.pop(dContext);
                                            },
                                            child: const Text("Excluir",
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ));
                          },
                        ),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.only(bottom: 8.0),
                    children: items.map((item) {
                      final bool isVerse =
                          item['id']?.startsWith("bibleverses-") ?? false;
                      final String displayTitle =
                          item['titulo'] ?? 'Sem título';
                      final String bookAbbrev =
                          isVerse ? (item['id']?.split('-')[1] ?? '') : '';
                      final String bookNameFromMap = _localBooksMap?[bookAbbrev]
                              ?['nome'] ??
                          bookAbbrev.toUpperCase();
                      final String displaySubtitle = isVerse
                          ? bookNameFromMap
                          : (item['bookName'] ?? 'Origem desconhecida');

                      final String? coverUrl = item['cover'];
                      final String itemId = item['id'] ?? 'unknown_id';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        leading: coverUrl != null && coverUrl.isNotEmpty
                            ? (coverUrl.startsWith('assets/')
                                ? Image.asset(coverUrl,
                                    width: 50, height: 50, fit: BoxFit.cover)
                                : Image.network(coverUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                        isVerse
                                            ? Icons.book_outlined
                                            : Icons.topic_outlined,
                                        color: Colors.grey,
                                        size: 40)))
                            : Icon(
                                isVerse
                                    ? Icons.book_outlined
                                    : Icons.topic_outlined,
                                color: Colors.grey,
                                size: 40),
                        title: Text(displayTitle,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: displaySubtitle.isNotEmpty
                            ? Text(displaySubtitle,
                                style: const TextStyle(color: Colors.grey))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          tooltip: "Remover Item",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            StoreProvider.of<AppState>(context, listen: false)
                                .dispatch(DeleteSingleTopicFromCollectionAction(
                                    collectionName, itemId));
                          },
                        ),
                        onTap: () {
                          if (isVerse) {
                            final parts = itemId.split('-');
                            if (parts.length == 4) {
                              final verseIdForNav =
                                  "${parts[1]}_${parts[2]}_${parts[3]}";
                              _navigateToBibleVerse(verseIdForNav);
                            }
                          } else if (itemId != 'unknown_id') {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        TopicContentView(topicId: itemId)));
                          }
                        },
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            );
          },
        );

      case 'Destaques':
        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Versículos",
                      style: TextStyle(
                          color: _selectedHighlightType == HighlightType.verses
                              ? Colors.white
                              : Colors.grey[600],
                          fontWeight: FontWeight.bold)),
                  Switch(
                    value: _selectedHighlightType == HighlightType.comments,
                    onChanged: (value) {
                      setState(() {
                        _selectedHighlightType = value
                            ? HighlightType.comments
                            : HighlightType.verses;
                      });
                    },
                    activeColor: Theme.of(context).primaryColor,
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey.shade700,
                  ),
                  Text("Comentários",
                      style: TextStyle(
                          color:
                              _selectedHighlightType == HighlightType.comments
                                  ? Colors.white
                                  : Colors.grey[600],
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: StoreConnector<AppState, _HighlightsViewModel>(
                converter: (store) => _HighlightsViewModel.fromStore(store),
                builder: (context, highlightsVm) {
                  if (_selectedHighlightType == HighlightType.verses) {
                    if (_isLoadingBooksMap) {
                      // Só mostra loader para versículos se booksMap não carregou
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFCDE7BE)));
                    }
                    final highlights = highlightsVm.userVerseHighlights;
                    if (highlights.isEmpty) {
                      return const Center(
                          child: Text("Nenhum versículo destacado ainda.",
                              style: TextStyle(color: Colors.white70)));
                    }
                    final highlightList = highlights.entries.toList();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: highlightList.length,
                      itemBuilder: (context, index) {
                        final entry = highlightList[index];
                        final verseId = entry.key;
                        final colorHex = entry.value;
                        final color = Color(
                            int.parse(colorHex.replaceFirst('#', '0xff')));
                        final parts = verseId.split('_');
                        String referenceText = verseId;

                        if (parts.length == 3 &&
                            _localBooksMap != null &&
                            _localBooksMap!.containsKey(parts[0])) {
                          final bookData = _localBooksMap![parts[0]];
                          referenceText =
                              "${bookData?['nome'] ?? parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                        } else if (parts.length == 3) {
                          referenceText =
                              "${parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                        }

                        return Card(
                          color: const Color(0xFF313333),
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            leading: Container(
                                width: 10,
                                decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2))),
                            title: Text(referenceText,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            subtitle: FutureBuilder<String>(
                              future: BiblePageHelper.loadSingleVerseText(
                                  verseId, 'nvi'),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting)
                                  return const Text("Carregando texto...",
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 12));
                                if (snapshot.hasError ||
                                    !snapshot.hasData ||
                                    snapshot.data!.isEmpty)
                                  return const Text("Texto indisponível",
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12));
                                return Text(snapshot.data!,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 13,
                                        backgroundColor:
                                            color.withOpacity(0.3)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis);
                              },
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: "Remover Destaque",
                              onPressed: () {
                                StoreProvider.of<AppState>(context,
                                        listen: false)
                                    .dispatch(ToggleHighlightAction(verseId));
                              },
                            ),
                            onTap: () => _navigateToBibleVerse(verseId),
                          ),
                        );
                      },
                    );
                  } else {
                    // HighlightType.comments
                    final commentHighlights =
                        highlightsVm.userCommentHighlights;
                    if (commentHighlights.isEmpty) {
                      return const Center(
                          child: Text("Nenhum comentário marcado ainda.",
                              style: TextStyle(color: Colors.white70)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: commentHighlights.length,
                      itemBuilder: (context, index) {
                        final highlight = commentHighlights[index];
                        return _buildCommentHighlightCard(highlight, context);
                      },
                    );
                  }
                },
              ),
            ),
          ],
        );

      case 'Notas':
        return StoreConnector<AppState, Map<String, String>>(
          converter: (store) => store.state.userState.userNotes,
          onInit: (store) {
            if (store.state.userState.userNotes.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadUserNotesAction());
            }
          },
          builder: (context, notes) {
            if (notes.isEmpty) {
              return const Center(
                  child: Text("Nenhuma nota adicionada ainda.",
                      style: TextStyle(color: Colors.white70)));
            }
            final noteList = notes.entries.toList();
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: noteList.length,
              itemBuilder: (context, index) {
                final entry = noteList[index];
                final verseId = entry.key;
                final noteText = entry.value;
                final parts = verseId.split('_');
                String referenceText = verseId;
                if (parts.length == 3 &&
                    _localBooksMap != null &&
                    _localBooksMap!.containsKey(parts[0])) {
                  final bookData = _localBooksMap![parts[0]];
                  referenceText =
                      "${bookData?['nome'] ?? parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                } else if (parts.length == 3) {
                  referenceText =
                      "${parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                }
                return Card(
                  color: const Color(0xFF313333),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    leading: const Icon(Icons.note_alt_outlined,
                        color: Colors.blueAccent),
                    title: Text(referenceText,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(noteText,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9), fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Remover Nota",
                      onPressed: () {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(DeleteNoteAction(verseId));
                      },
                    ),
                    onTap: () => _navigateToBibleVerse(verseId),
                  ),
                );
              },
            );
          },
        );

      case 'Histórico':
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) => store.state.userState.readingHistory,
          onInit: (store) {
            if (store.state.userState.readingHistory.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadReadingHistoryAction());
            }
          },
          builder: (context, history) {
            if (history.isEmpty) {
              return const Center(
                  child: Text("Nenhum histórico de leitura encontrado.",
                      style: TextStyle(color: Colors.white70)));
            }

            final DateFormat formatter = DateFormat('dd/MM/yy HH:mm');

            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                final bookAbbrev = entry['bookAbbrev'] ?? '?';
                final chapter = entry['chapter'] ?? '?';
                final bookName = _localBooksMap?[bookAbbrev]?['nome'] ??
                    bookAbbrev.toUpperCase();
                final timestamp = entry['timestamp'] as DateTime?;
                final verseIdForNav = "${bookAbbrev}_${chapter}_1";

                return Card(
                  color: const Color(0xFF313333),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    leading: const Icon(Icons.history_edu_outlined,
                        color: Colors.white70),
                    title: Text(
                      "$bookName $chapter",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      timestamp != null
                          ? formatter.format(timestamp)
                          : "Data indisponível",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.white70),
                    onTap: () => _navigateToBibleVerse(verseIdForNav),
                  ),
                );
              },
            );
          },
        );

      case 'Diário':
        return const UserDiaryPage();

      default:
        return const Center(
            child: Text('Conteúdo não disponível.',
                style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildBookCard(Map<String, dynamic> bookDetails) {
    num progressValue = bookDetails['progress'] ?? 0;
    final progress = (progressValue.clamp(0, 100)) / 100.0;

    return Card(
      color: const Color(0xFF313333),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: (bookDetails['cover'] != null &&
                      bookDetails['cover'].isNotEmpty)
                  ? Image.network(
                      bookDetails['cover'],
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.book, size: 60, color: Colors.grey),
                    )
                  : const SizedBox(
                      width: 60,
                      height: 90,
                      child: Icon(Icons.book, size: 60, color: Colors.grey)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bookDetails['title'] ?? 'Sem título',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookDetails['author'] != null &&
                            bookDetails['author'].isNotEmpty
                        ? '${bookDetails['author']}'
                        : 'Autor desconhecido',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (progress > 0)
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(15),
                      backgroundColor: Colors.grey.shade700,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50),
                      ),
                    )
                  else
                    const Text("Não iniciado",
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _UserPageViewModel>(
      converter: (store) => _UserPageViewModel.fromStore(store),
      builder: (context, vm) {
        bool shouldShowGlobalLoader = _isLoadingBooksMap &&
            _selectedTab != 'Diário' &&
            _selectedTab != 'Lendo' &&
            !(_selectedTab == 'Destaques' &&
                _selectedHighlightType == HighlightType.comments);

        if (shouldShowGlobalLoader) {
          return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFCDE7BE))));
        }

        final userDetails = vm.userDetails;
        final topicosLidos = userDetails['Tópicos']?.toString() ?? '0';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: () async {
              final storeInstance =
                  StoreProvider.of<AppState>(context, listen: false);
              if (vm.userId != null) {
                storeInstance.dispatch(LoadUserStatsAction());
                storeInstance.dispatch(LoadUserCollectionsAction());
                storeInstance.dispatch(LoadUserDiariesAction());
                storeInstance.dispatch(LoadUserHighlightsAction());
                storeInstance.dispatch(LoadUserCommentHighlightsAction());
                storeInstance.dispatch(LoadUserNotesAction());
                storeInstance.dispatch(LoadReadingHistoryAction());
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kToolbarHeight - 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      ProfilePicture(),
                      const SizedBox(height: 16),
                      UserInfo(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: StatsContainer(
                              livros: "0",
                              topicos: topicosLidos,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: LogoutButton(),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Tabs(
                        onTabSelected: _onTabSelected,
                        selectedTab: _selectedTab,
                      ),
                      const Divider(color: Colors.white24, height: 1),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildTabContent(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserPageViewModel {
  final String? userId;
  final Map<String, dynamic> userDetails;
  final int booksInProgressCount;
  final int topicSavesCount;

  _UserPageViewModel({
    required this.userId,
    required this.userDetails,
    required this.booksInProgressCount,
    required this.topicSavesCount,
  });

  static _UserPageViewModel fromStore(Store<AppState> store) {
    return _UserPageViewModel(
      userId: store.state.userState.userId,
      userDetails: store.state.userState.userDetails ?? {},
      booksInProgressCount: store.state.userState.booksInProgress.length,
      topicSavesCount: store.state.userState.topicSaves.values
          .fold<int>(0, (prev, list) => prev + list.length),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserPageViewModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          mapEquals(userDetails, other.userDetails) &&
          booksInProgressCount == other.booksInProgressCount &&
          topicSavesCount == other.topicSavesCount;

  @override
  int get hashCode =>
      userId.hashCode ^
      userDetails.hashCode ^
      booksInProgressCount.hashCode ^
      topicSavesCount.hashCode;
}

class _HighlightsViewModel {
  final Map<String, String> userVerseHighlights;
  final List<Map<String, dynamic>> userCommentHighlights;

  _HighlightsViewModel({
    required this.userVerseHighlights,
    required this.userCommentHighlights,
  });

  static _HighlightsViewModel fromStore(Store<AppState> store) {
    return _HighlightsViewModel(
      userVerseHighlights: store.state.userState.userHighlights,
      userCommentHighlights: store.state.userState.userCommentHighlights,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HighlightsViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userVerseHighlights, other.userVerseHighlights) &&
          listEquals(userCommentHighlights, other.userCommentHighlights);

  @override
  int get hashCode =>
      userVerseHighlights.hashCode ^ userCommentHighlights.hashCode;
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 180, 115, 110),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(
          Icons.logout,
          color: Colors.white,
          size: 24,
        ),
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/login', (Route<dynamic> route) => false);
        },
        tooltip: 'Sair',
      ),
    );
  }
}
