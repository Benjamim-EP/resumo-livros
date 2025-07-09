// lib/pages/community/community_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para os dados do ranking
class RankingUser {
  final String id;
  final String name;
  final String? photoURL;
  final double rankingScore;
  final int bibleCompletionCount;
  final double currentProgressPercent;

  RankingUser({
    required this.id,
    required this.name,
    this.photoURL,
    required this.rankingScore,
    required this.bibleCompletionCount,
    required this.currentProgressPercent,
  });

  factory RankingUser.fromFirestore(
      DocumentSnapshot userProgressDoc, DocumentSnapshot userDoc) {
    final progressData = userProgressDoc.data() as Map<String, dynamic>? ?? {};
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    return RankingUser(
      id: userProgressDoc.id,
      name: userData['nome'] ?? 'Usuário Anônimo',
      photoURL: userData['photoURL'],
      rankingScore: (progressData['rankingScore'] as num?)?.toDouble() ?? 0.0,
      bibleCompletionCount: progressData['bibleCompletionCount'] as int? ?? 0,
      currentProgressPercent:
          (progressData['currentProgressPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late Future<List<RankingUser>> _rankingFuture;

  @override
  void initState() {
    super.initState();
    _rankingFuture = _fetchRanking();
  }

  Future<List<RankingUser>> _fetchRanking() async {
    try {
      // 1. Busca os 100 melhores scores da coleção de progresso
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('userBibleProgress')
          .orderBy('rankingScore', descending: true)
          .limit(100)
          .get();

      if (progressSnapshot.docs.isEmpty) {
        return [];
      }

      // 2. Extrai os IDs dos usuários do ranking
      final userIds = progressSnapshot.docs.map((doc) => doc.id).toList();

      // 3. Busca os detalhes desses usuários na coleção 'users'
      // O Firestore permite buscar até 30 IDs por vez com `whereIn`.
      // Dividiremos em chunks se necessário.
      Map<String, DocumentSnapshot> userDocsMap = {};
      const chunkSize = 30;
      for (var i = 0; i < userIds.length; i += chunkSize) {
        final chunk = userIds.sublist(
            i, i + chunkSize > userIds.length ? userIds.length : i + chunkSize);
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (var doc in usersSnapshot.docs) {
          userDocsMap[doc.id] = doc;
        }
      }

      // 4. Combina os dados de progresso e de usuário
      List<RankingUser> rankingList = [];
      for (var progressDoc in progressSnapshot.docs) {
        final userDoc = userDocsMap[progressDoc.id];
        if (userDoc != null) {
          rankingList.add(RankingUser.fromFirestore(progressDoc, userDoc));
        }
      }

      return rankingList;
    } catch (e) {
      print("Erro ao buscar o ranking: $e");
      // Lança a exceção para que o FutureBuilder possa mostrar o erro
      throw Exception('Não foi possível carregar o ranking.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O AppBar já está na MainAppScreen, então não precisamos dele aqui
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _rankingFuture = _fetchRanking();
          });
        },
        child: FutureBuilder<List<RankingUser>>(
          future: _rankingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('Nenhum ranking disponível ainda.'));
            }

            final rankingUsers = snapshot.data!;

            return ListView.builder(
              itemCount: rankingUsers.length,
              itemBuilder: (context, index) {
                final user = rankingUsers[index];
                final rank = index + 1;
                return _buildRankingTile(user, rank, context);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRankingTile(RankingUser user, int rank, BuildContext context) {
    final theme = Theme.of(context);
    Color rankColor;
    if (rank == 1) {
      rankColor = Colors.amber.shade600;
    } else if (rank == 2) {
      rankColor = Colors.grey.shade400;
    } else if (rank == 3) {
      rankColor = Colors.brown.shade400;
    } else {
      rankColor = theme.colorScheme.primary.withOpacity(0.7);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rankColor,
          child: Text(
            '$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(user.name),
        subtitle: Text(
            'Score: ${user.rankingScore.toStringAsFixed(0)} • Progresso: ${user.currentProgressPercent.toStringAsFixed(1)}%'),
        trailing: user.bibleCompletionCount > 0
            ? Chip(
                avatar:
                    Icon(Icons.star, color: Colors.amber.shade800, size: 16),
                label: Text('${user.bibleCompletionCount}x'),
                labelStyle: const TextStyle(fontSize: 12),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}
