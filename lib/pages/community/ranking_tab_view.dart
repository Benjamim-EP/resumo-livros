// lib/pages/community/ranking_tab_view.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';

// Componentes da UI
import 'package:septima_biblia/pages/community/podium_widget.dart';
import 'package:septima_biblia/pages/community/ranking_list_item.dart';
import 'package:septima_biblia/pages/community/user_ranking_card.dart';
import 'package:septima_biblia/pages/community/weekly_countdown_timer.dart'; // Importa o contador

// Modelo de Dados para o Ranking
class RankingUser {
  final String id;
  final String name;
  final String? photoURL;
  final double rankingScore;
  final int? previousRank;

  RankingUser({
    required this.id,
    required this.name,
    this.photoURL,
    required this.rankingScore,
    this.previousRank,
  });

  factory RankingUser.fromFirestore(
      DocumentSnapshot userProgressDoc, DocumentSnapshot userDoc) {
    final progressData = userProgressDoc.data() as Map<String, dynamic>? ?? {};
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    return RankingUser(
      id: userProgressDoc.id,
      name: userData['nome'] ?? 'Anônimo',
      photoURL: userData['photoURL'],
      rankingScore: (progressData['rankingScore'] as num?)?.toDouble() ?? 0.0,
      previousRank: userData['previousRank'] as int?,
    );
  }
}

// ViewModel para obter os dados do usuário logado do Redux
class _RankingViewModel {
  final String? loggedInUserId;
  final String? loggedInUserName;
  final String? loggedInUserPhotoUrl;

  _RankingViewModel({
    this.loggedInUserId,
    this.loggedInUserName,
    this.loggedInUserPhotoUrl,
  });

  static _RankingViewModel fromStore(Store<AppState> store) {
    return _RankingViewModel(
      loggedInUserId: store.state.userState.userId,
      loggedInUserName: store.state.userState.userDetails?['nome'],
      loggedInUserPhotoUrl: store.state.userState.userDetails?['photoURL'],
    );
  }
}

class RankingTabView extends StatefulWidget {
  const RankingTabView({super.key});

  @override
  State<RankingTabView> createState() => _RankingTabViewState();
}

class _RankingTabViewState extends State<RankingTabView> {
  late Future<List<RankingUser>> _rankingFuture;

  final Map<int, int> _rewards = {
    1: 700,
    2: 300,
    3: 100,
    4: 80,
    5: 70,
    6: 60,
    7: 50,
    8: 40,
    9: 30,
    10: 20
  };

  @override
  void initState() {
    super.initState();
    _rankingFuture = _fetchRanking();
  }

  /// Busca e combina os dados de progresso e de usuário do Firestore para montar o ranking.
  Future<List<RankingUser>> _fetchRanking() async {
    List<RankingUser> realUsers = [];
    try {
      final progressSnapshot = await FirebaseFirestore.instance
          .collection('userBibleProgress')
          .orderBy('rankingScore', descending: true)
          .limit(100)
          .get();

      if (progressSnapshot.docs.isNotEmpty) {
        final userIds = progressSnapshot.docs.map((doc) => doc.id).toList();

        Map<String, DocumentSnapshot> userDocsMap = {};
        for (var i = 0; i < userIds.length; i += 30) {
          final chunk = userIds.sublist(
              i, i + 30 > userIds.length ? userIds.length : i + 30);
          final usersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var doc in usersSnapshot.docs) {
            userDocsMap[doc.id] = doc;
          }
        }

        for (var progressDoc in progressSnapshot.docs) {
          final userDoc = userDocsMap[progressDoc.id];
          if (userDoc != null) {
            realUsers.add(RankingUser.fromFirestore(progressDoc, userDoc));
          }
        }
      }
    } catch (e) {
      print("Erro ao buscar ranking real do Firestore: $e");
    }

    realUsers.sort((a, b) => b.rankingScore.compareTo(a.rankingScore));
    return realUsers;
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _RankingViewModel>(
      converter: (store) => _RankingViewModel.fromStore(store),
      builder: (context, viewModel) {
        return FutureBuilder<List<RankingUser>>(
          future: _rankingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Erro ao carregar o ranking: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text("Ninguém no ranking ainda. Seja o primeiro!"));
            }

            final allUsers = snapshot.data!;
            RankingUser? loggedInUserRankingData;
            int? loggedInUserRank;
            final userIndex = allUsers
                .indexWhere((user) => user.id == viewModel.loggedInUserId);

            if (userIndex != -1) {
              loggedInUserRankingData = allUsers[userIndex];
              loggedInUserRank = userIndex + 1;
            }

            final podiumUsers = allUsers.take(3).toList();
            final listUsers =
                allUsers.length > 3 ? allUsers.sublist(3) : <RankingUser>[];

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _rankingFuture = _fetchRanking(); // Recarrega os dados
                });
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
                children: [
                  Text(
                    "🏆 Prêmios da Semana",
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  RankingRewardsList(rewards: _rewards),
                  const SizedBox(height: 24),
                  if (podiumUsers.isNotEmpty) PodiumWidget(users: podiumUsers),

                  // Adiciona o contador regressivo no espaço vazio
                  const SizedBox(height: 24),
                  const WeeklyCountdownTimer(),
                  const SizedBox(height: 24),

                  // Card do usuário logado
                  if (loggedInUserRankingData != null)
                    UserRankingCard(
                      name: loggedInUserRankingData.name,
                      score: loggedInUserRankingData.rankingScore
                          .toStringAsFixed(0),
                      rank: loggedInUserRank!,
                      photoUrl: loggedInUserRankingData.photoURL,
                    )
                  else
                    UserRankingCard(
                      name: viewModel.loggedInUserName ?? "Você",
                      score: "0",
                      rank: 0, // 0 indica que não está no ranking
                      photoUrl: viewModel.loggedInUserPhotoUrl,
                    ),
                  const SizedBox(height: 24),

                  // Título para o resto da lista
                  if (listUsers.isNotEmpty)
                    Text(
                      "Top 100 Leitores",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                  // Lista dos outros usuários no ranking
                  if (listUsers.isNotEmpty)
                    ...List.generate(listUsers.length, (index) {
                      final user = listUsers[index];
                      final rank = index + 4; // A lista começa na 4ª posição

                      // Não mostra o usuário logado novamente na lista se ele já apareceu no card
                      if (user.id == viewModel.loggedInUserId) {
                        return const SizedBox.shrink();
                      }

                      return RankingListItem(
                        rank: rank,
                        user: user, // Passa o objeto completo
                      )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                          .slideY(
                              begin: 0.5,
                              duration: 500.ms,
                              curve: Curves.easeOutCubic);
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Widgets de Recompensa (sem alterações)
class RankingRewardsList extends StatelessWidget {
  final Map<int, int> rewards;
  const RankingRewardsList({super.key, required this.rewards});
  @override
  Widget build(BuildContext context) {
    final rewardsList = rewards.entries.toList();
    return SizedBox(
      height: 125,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: rewardsList.length,
        itemBuilder: (context, index) {
          final entry = rewardsList[index];
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 4, right: 4),
            child: RewardCard(rank: entry.key, coins: entry.value),
          );
        },
      ),
    );
  }
}

class RewardCard extends StatelessWidget {
  final int rank;
  final int coins;
  const RewardCard({super.key, required this.rank, required this.coins});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color startColor, endColor, iconColor;
    double width = 90;
    switch (rank) {
      case 1:
        startColor = Colors.amber.shade300;
        endColor = Colors.amber.shade600;
        iconColor = Colors.amber.shade800;
        width = 100;
        break;
      case 2:
        startColor = Colors.grey.shade300;
        endColor = Colors.grey.shade500;
        iconColor = Colors.grey.shade700;
        break;
      case 3:
        startColor = Colors.brown.shade300;
        endColor = Colors.brown.shade500;
        iconColor = Colors.brown.shade700;
        break;
      default:
        startColor = theme.colorScheme.primary.withOpacity(0.5);
        endColor = theme.colorScheme.primary;
        iconColor = theme.colorScheme.onPrimary.withOpacity(0.8);
    }
    return Card(
      elevation: 4,
      shadowColor: endColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              "${rank}º LUGAR",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                shadows: const [Shadow(blurRadius: 2, color: Colors.black38)],
              ),
            ),
            Icon(Icons.monetization_on, color: iconColor, size: 28),
            Text(
              coins.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
