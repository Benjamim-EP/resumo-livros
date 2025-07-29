// lib/pages/community/book_club_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/pages/community/book_club_card.dart'; // Widget que vamos criar a seguir
import 'package:septima_biblia/pages/community/book_club_detail_page.dart'; // Tela de destino

class BookClubListPage extends StatelessWidget {
  const BookClubListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Query para buscar os clubes, ordenando pela atividade mais recente
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
          return const Center(child: Text("Nenhum clube do livro encontrado."));
        }

        final clubs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: clubs.length,
          itemBuilder: (context, index) {
            final clubDoc = clubs[index];
            final data = clubDoc.data() as Map<String, dynamic>;
            final bookId = clubDoc.id;

            return BookClubCard(
              bookId: bookId,
              title: data['bookTitle'] ?? 'Sem Título',
              author: data['authorName'] ?? 'Desconhecido',
              coverUrl: data['bookCover'] ?? '',
              participantCount: data['participantCount'] ?? 0,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookClubDetailPage(bookId: bookId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
