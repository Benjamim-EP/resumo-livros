// lib/pages/community/book_club_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/pages/community/book_club_card.dart';
import 'package:septima_biblia/pages/community/book_club_detail_page.dart';
import 'package:septima_biblia/pages/community/book_club_grid_card.dart';
// 1. IMPORTAR O PACOTE SharedPreferences
import 'package:shared_preferences/shared_preferences.dart';

class BookClubListPage extends StatefulWidget {
  const BookClubListPage({super.key});

  @override
  State<BookClubListPage> createState() => _BookClubListPageState();
}

class _BookClubListPageState extends State<BookClubListPage> {
  // 2. DEFINIR A CHAVE DE PREFERÊNCIA E O ESTADO
  static const String _viewModeKey = 'book_club_view_mode';
  bool _isGridView = false; // O valor padrão será carregado no initState

  @override
  void initState() {
    super.initState();
    // 3. CARREGAR A PREFERÊNCIA QUANDO A TELA É INICIADA
    _loadViewPreference();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    // Lê o valor salvo. Se não houver, o padrão é 'false' (visualização em lista).
    if (mounted) {
      setState(() {
        _isGridView = prefs.getBool(_viewModeKey) ?? false;
      });
    }
  }

  // 4. SALVAR A PREFERÊNCIA QUANDO O USUÁRIO MUDA
  Future<void> _saveViewPreference(bool isGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewModeKey, isGrid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clubes do Livro"),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isGridView
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded),
            tooltip:
                _isGridView ? "Visualizar em Lista" : "Visualizar em Grade",
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
                // 5. CHAMA A FUNÇÃO DE SALVAR AO MUDAR
                _saveViewPreference(_isGridView);
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookClubs')
            .orderBy('lastActivity', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Erro ao carregar os clubes."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("Nenhum clube do livro encontrado."));
          }

          final clubs = snapshot.data!.docs;

          // A lógica de alternância permanece a mesma
          if (_isGridView) {
            return GridView.builder(
              padding: const EdgeInsets.all(12.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio: 3 / 4,
              ),
              itemCount: clubs.length,
              itemBuilder: (context, index) {
                final clubDoc = clubs[index];
                final data = clubDoc.data() as Map<String, dynamic>;
                return BookClubGridCard(
                  bookId: clubDoc.id,
                  title: data['bookTitle'] ?? 'Sem Título',
                  coverUrl: data['bookCover'] ?? '',
                  participantCount: data['participantCount'] ?? 0,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              BookClubDetailPage(bookId: clubDoc.id)),
                    );
                  },
                );
              },
            );
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: clubs.length,
              itemBuilder: (context, index) {
                final clubDoc = clubs[index];
                final data = clubDoc.data() as Map<String, dynamic>;
                return BookClubCard(
                  bookId: clubDoc.id,
                  title: data['bookTitle'] ?? 'Sem Título',
                  author: data['authorName'] ?? 'Desconhecido',
                  coverUrl: data['bookCover'] ?? '',
                  participantCount: data['participantCount'] ?? 0,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              BookClubDetailPage(bookId: clubDoc.id)),
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
