// lib/pages/devotional_page/promise_search_modal.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:septima_biblia/models/promise_model.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

// Classe para encapsular um resultado de busca com seu contexto
class PromiseSearchResult {
  final PromiseVerse verse;
  final List<String>
      contextPath; // Ex: ["PARTE UM", "Capítulo 1", "À Fé em Cristo"]

  PromiseSearchResult({required this.verse, required this.contextPath});
}

class PromiseSearchModal extends StatefulWidget {
  final Function(Map<String, String> promise) onPromiseSelected;

  const PromiseSearchModal({super.key, required this.onPromiseSelected});

  @override
  State<PromiseSearchModal> createState() => _PromiseSearchModalState();
}

class _PromiseSearchModalState extends State<PromiseSearchModal> {
  PromiseBook? _promiseBook;
  List<PromiseSearchResult> _searchResults = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadPromises();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPromises() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/promises/promessas.json');
      final jsonData = json.decode(jsonString);
      if (mounted) {
        setState(() {
          _promiseBook = PromiseBook.fromJson(jsonData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _performSearch(_searchController.text);
      }
    });
  }

  String _normalize(String input) {
    return unorm
        .nfd(input)
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .toLowerCase();
  }

  void _performSearch(String query) {
    if (query.isEmpty || _promiseBook == null) {
      setState(() => _searchResults = []);
      return;
    }

    final normalizedQuery = _normalize(query);
    final List<PromiseSearchResult> results = [];

    for (var part in _promiseBook!.parts) {
      for (var chapter in part.chapters) {
        for (var section in chapter.sections) {
          if (section.verses != null) {
            for (var verse in section.verses!) {
              if (_normalize(verse.text).contains(normalizedQuery) ||
                  _normalize(section.title).contains(normalizedQuery) ||
                  _normalize(chapter.title).contains(normalizedQuery)) {
                results.add(PromiseSearchResult(
                  verse: verse,
                  contextPath: [part.title, chapter.title, section.title],
                ));
              }
            }
          }
          if (section.subsections != null) {
            for (var subsection in section.subsections!) {
              for (var verse in subsection.verses) {
                if (_normalize(verse.text).contains(normalizedQuery) ||
                    _normalize(subsection.title).contains(normalizedQuery) ||
                    _normalize(section.title).contains(normalizedQuery) ||
                    _normalize(chapter.title).contains(normalizedQuery)) {
                  results.add(PromiseSearchResult(
                    verse: verse,
                    contextPath: [
                      part.title,
                      chapter.title,
                      section.title,
                      subsection.title
                    ],
                  ));
                }
              }
            }
          }
        }
      }
    }
    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar promessa por palavra-chave...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildResultsList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsList(ScrollController scrollController) {
    if (_searchController.text.isNotEmpty && _searchResults.isEmpty) {
      return const Center(child: Text("Nenhum resultado encontrado."));
    }
    if (_searchResults.isEmpty) {
      return const Center(child: Text("Digite algo para iniciar a busca."));
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            title: Text('"${result.verse.text}"',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                result.contextPath.join(' > '),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: Text(result.verse.reference,
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            onTap: () {
              widget.onPromiseSelected({
                'text': result.verse.text,
                'reference': result.verse.reference,
              });
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}
