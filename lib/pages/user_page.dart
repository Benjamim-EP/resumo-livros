// lib/pages/user_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for listEquals and mapEquals
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page/user_diary_page.dart';
import '../components/avatar/profile_picture.dart';
import '../components/user/user_info.dart';
import '../components/tabs/tabs.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:redux/redux.dart';
import 'package:intl/intl.dart';

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
        storeInstance.dispatch(LoadReadingHistoryAction());
        if (storeInstance.state.userState.userHighlights.isEmpty) {
          storeInstance.dispatch(LoadUserHighlightsAction());
        }
        if (storeInstance.state.userState.userCommentHighlights.isEmpty) {
          storeInstance.dispatch(LoadUserCommentHighlightsAction());
        }
        if (storeInstance.state.userState.userNotes.isEmpty) {
          storeInstance.dispatch(LoadUserNotesAction());
        }
        if (storeInstance.state.userState.booksInProgressDetails.isEmpty) {
          storeInstance.dispatch(LoadBooksDetailsAction());
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
    if (mounted) {
      setState(() {
        _selectedTab = tab;
      });
    }
  }

  void _navigateToBibleVerseAndTab(String verseId) {
    final parts = verseId.split('_');
    if (parts.length == 3) {
      final bookAbbrev = parts[0];
      final chapter = int.tryParse(parts[1]);
      if (chapter != null && context.mounted) {
        // Adicionado context.mounted
        final store = StoreProvider.of<AppState>(context, listen: false);
        store.dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
        store.dispatch(
            RequestBottomNavChangeAction(2)); // Assumindo que Bíblia é índice 2
        print(
            "UserPage: Solicitação para ir para Bíblia: $bookAbbrev $chapter, Aba 2");
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$selectedSnippet"',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              "No contexto de: ${fullCommentText.length > 100 ? "${fullCommentText.substring(0, 100)}..." : fullCommentText}",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
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
                        color: Colors.redAccent, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: "Remover Marcação do Comentário",
                    onPressed: () {
                      if (context.mounted) {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(
                                RemoveCommentHighlightAction(highlightId));
                      }
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
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) => store.state.userState.booksInProgressDetails,
          onInit: (store) {
            if (store.state.userState.booksInProgressDetails.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadBooksDetailsAction());
            }
          },
          builder: (context, booksInProgressDetails) {
            if (booksInProgressDetails.isEmpty) {
              return const Center(
                  child: Text("Nenhum livro em progresso.",
                      style: TextStyle(color: Colors.white70, fontSize: 16)));
            }
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: booksInProgressDetails.length,
              itemBuilder: (context, index) {
                final book = booksInProgressDetails[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookDetailsPage(bookId: book['id'] as String),
                      ),
                    );
                  },
                  child: _buildBookCard(book),
                );
              },
            );
          },
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
                      style: TextStyle(color: Colors.white70, fontSize: 16)));
            }
            if (savedTopicsContent.isEmpty && topicSavesMap.isNotEmpty) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFCDE7BE)));
            }
            if (savedTopicsContent.isEmpty && topicSavesMap.isEmpty) {
              return const Center(
                  child: Text("Nenhum tópico ou versículo salvo.",
                      style: TextStyle(color: Colors.white70, fontSize: 16)));
            }

            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                            child: Text(
                          collectionName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        )),
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
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dContext),
                                            child: const Text("Cancelar",
                                                style: TextStyle(
                                                    color: Colors.white70))),
                                        TextButton(
                                            onPressed: () {
                                              if (context.mounted) {
                                                StoreProvider.of<AppState>(
                                                        context,
                                                        listen: false)
                                                    .dispatch(
                                                        DeleteTopicCollectionAction(
                                                            collectionName));
                                              }
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
                    childrenPadding: const EdgeInsets.only(
                        bottom: 8.0, left: 8.0, right: 8.0),
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
                          ? "$bookNameFromMap ${item['id']?.split('-')[2]}"
                          : (item['bookName'] ?? 'Origem desconhecida');
                      final String? coverUrl = item['cover'];
                      final String itemId = item['id'] ?? 'unknown_id';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
                        leading: coverUrl != null && coverUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6.0),
                                child: (coverUrl.startsWith('assets/')
                                    ? Image.asset(coverUrl,
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.cover)
                                    : Image.network(coverUrl,
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                            isVerse
                                                ? Icons.menu_book_rounded
                                                : Icons.article_outlined,
                                            color: Colors.grey[600],
                                            size: 35))))
                            : Icon(
                                isVerse
                                    ? Icons.menu_book_rounded
                                    : Icons.article_outlined,
                                color: Colors.grey[600],
                                size: 35),
                        title: Text(
                          displayTitle,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: displaySubtitle.isNotEmpty
                            ? Text(displaySubtitle,
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 12))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 22),
                          tooltip: "Remover Item",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (context.mounted) {
                              StoreProvider.of<AppState>(context, listen: false)
                                  .dispatch(
                                      DeleteSingleTopicFromCollectionAction(
                                          collectionName, itemId));
                            }
                          },
                        ),
                        onTap: () {
                          if (isVerse) {
                            final parts = itemId.split('-');
                            if (parts.length == 4) {
                              final verseIdForNav =
                                  "${parts[1]}_${parts[2]}_${parts[3]}";
                              _navigateToBibleVerseAndTab(verseIdForNav);
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
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: SegmentedButton<HighlightType>(
                segments: const <ButtonSegment<HighlightType>>[
                  ButtonSegment<HighlightType>(
                      value: HighlightType.verses,
                      label: Text('Versículos'),
                      icon: Icon(Icons.menu_book)),
                  ButtonSegment<HighlightType>(
                      value: HighlightType.comments,
                      label: Text('Comentários'),
                      icon: Icon(Icons.comment_bank_outlined)),
                ],
                selected: <HighlightType>{_selectedHighlightType},
                onSelectionChanged: (Set<HighlightType> newSelection) {
                  if (mounted) {
                    setState(() {
                      _selectedHighlightType = newSelection.first;
                    });
                  }
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  selectedForegroundColor: Colors.black,
                  selectedBackgroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
            Expanded(
              child: StoreConnector<AppState, _HighlightsViewModel>(
                converter: (store) => _HighlightsViewModel.fromStore(store),
                builder: (context, highlightsVm) {
                  if (_selectedHighlightType == HighlightType.verses) {
                    if (_isLoadingBooksMap) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFCDE7BE)));
                    }
                    final highlights = highlightsVm.userVerseHighlights;
                    if (highlights.isEmpty) {
                      return const Center(
                          child: Text("Nenhum versículo destacado ainda.",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16)));
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                            leading: Container(
                                width: 12,
                                decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4))),
                            title: Text(referenceText,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            subtitle: FutureBuilder<String>(
                              future: BiblePageHelper.loadSingleVerseText(
                                  verseId, 'nvi'),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Text("Carregando texto...",
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 12));
                                }
                                if (snapshot.hasError ||
                                    !snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return const Text("Texto indisponível",
                                      style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12));
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(snapshot.data!,
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                );
                              },
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: "Remover Destaque",
                              onPressed: () {
                                if (context.mounted) {
                                  StoreProvider.of<AppState>(context,
                                          listen: false)
                                      .dispatch(ToggleHighlightAction(verseId));
                                }
                              },
                            ),
                            onTap: () => _navigateToBibleVerseAndTab(verseId),
                          ),
                        );
                      },
                    );
                  } else {
                    final commentHighlights =
                        highlightsVm.userCommentHighlights;
                    if (commentHighlights.isEmpty) {
                      return const Center(
                          child: Text("Nenhum comentário marcado ainda.",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16)));
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
                      style: TextStyle(color: Colors.white70, fontSize: 16)));
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                    leading: const Icon(Icons.note_alt_outlined,
                        color: Colors.blueAccent, size: 28),
                    title: Text(referenceText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(noteText,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Remover Nota",
                      onPressed: () {
                        if (context.mounted) {
                          StoreProvider.of<AppState>(context, listen: false)
                              .dispatch(DeleteNoteAction(verseId));
                        }
                      },
                    ),
                    onTap: () => _navigateToBibleVerseAndTab(verseId),
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
                      style: TextStyle(color: Colors.white70, fontSize: 16)));
            }
            final DateFormat formatter = DateFormat('dd/MM/yy \'às\' HH:mm');
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                    leading: const Icon(Icons.history_edu_outlined,
                        color: Colors.white70, size: 28),
                    title: Text(
                      "$bookName $chapter",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        timestamp != null
                            ? formatter.format(timestamp.toLocal())
                            : "Data indisponível",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 18, color: Colors.white70),
                    onTap: () => _navigateToBibleVerseAndTab(verseIdForNav),
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
                style: TextStyle(color: Colors.white, fontSize: 16)));
    }
  }

  Widget _buildBookCard(Map<String, dynamic> bookDetails) {
    num progressValueNum = 0;
    if (bookDetails['progress'] is num) {
      progressValueNum = bookDetails['progress'];
    } else if (bookDetails['progress'] is String) {
      progressValueNum = num.tryParse(bookDetails['progress'] as String) ?? 0;
    }
    final double progress = (progressValueNum.clamp(0, 100)) / 100.0;

    return Card(
      color: const Color(0xFF313333),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: (bookDetails['cover'] != null &&
                      bookDetails['cover'].isNotEmpty)
                  ? Image.network(
                      bookDetails['cover'],
                      width: 70,
                      height: 105,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 70,
                        height: 105,
                        color: Colors.grey[700],
                        child: Icon(Icons.book_outlined,
                            size: 40, color: Colors.grey[400]),
                      ),
                    )
                  : Container(
                      width: 70,
                      height: 105,
                      color: Colors.grey[700],
                      child: Icon(Icons.book_outlined,
                          size: 40, color: Colors.grey[400]),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bookDetails['title'] ?? 'Sem título',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bookDetails['author'] != null &&
                            bookDetails['author'].isNotEmpty
                        ? 'Por: ${bookDetails['author']}'
                        : 'Autor desconhecido',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  if (progress > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(15),
                          backgroundColor: Colors.grey.shade700,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${(progress * 100).toStringAsFixed(0)}% concluído",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    )
                  else
                    Text("Não iniciado",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 18),
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

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: RefreshIndicator(
            color: Theme.of(context).primaryColor,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            onRefresh: () async {
              final storeInstance =
                  StoreProvider.of<AppState>(context, listen: false);
              if (vm.userId != null && context.mounted) {
                // Adicionado context.mounted
                storeInstance.dispatch(LoadUserStatsAction());
                storeInstance.dispatch(LoadUserCollectionsAction());
                storeInstance.dispatch(LoadUserDiariesAction());
                storeInstance.dispatch(LoadUserHighlightsAction());
                storeInstance.dispatch(LoadUserCommentHighlightsAction());
                storeInstance.dispatch(LoadUserNotesAction());
                storeInstance.dispatch(LoadReadingHistoryAction());
                storeInstance.dispatch(LoadBooksDetailsAction());
              }
            },
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  ProfilePicture(),
                                  const SizedBox(height: 12),
                                  UserInfo(),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.settings_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28),
                              tooltip: 'Configurações',
                              onPressed: () {
                                if (context.mounted) {
                                  // Adicionado context.mounted
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/userSettings');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Tabs(
                          onTabSelected: _onTabSelected,
                          selectedTab: _selectedTab,
                        ),
                        const Divider(
                            color: Colors.white24, height: 1, thickness: 0.5),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildTabContent(),
                  ),
                ],
              ),
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
  final int topicSavesCount;
  final int userDiariesCount;

  _UserPageViewModel({
    required this.userId,
    required this.userDetails,
    required this.topicSavesCount,
    required this.userDiariesCount,
  });

  static _UserPageViewModel fromStore(Store<AppState> store) {
    int totalSavedItems = 0;
    store.state.userState.topicSaves.forEach((collectionName, items) {
      totalSavedItems += items.length;
    });

    return _UserPageViewModel(
      userId: store.state.userState.userId,
      userDetails: store.state.userState.userDetails ?? {},
      topicSavesCount: totalSavedItems,
      userDiariesCount: store.state.userState.userDiaries.length,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserPageViewModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          mapEquals(userDetails, other.userDetails) &&
          topicSavesCount == other.topicSavesCount &&
          userDiariesCount == other.userDiariesCount;

  @override
  int get hashCode =>
      userId.hashCode ^
      userDetails.hashCode ^
      topicSavesCount.hashCode ^
      userDiariesCount.hashCode;
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
