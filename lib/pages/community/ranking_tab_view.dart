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

// Modelo de Dados para o Ranking (sem alterações)
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

  factory RankingUser.fromMock(Map<String, dynamic> mockData) {
    return RankingUser(
      id: mockData['id'] ?? 'mock_id',
      name: mockData['name'] ?? 'Usuário Fictício',
      photoURL: mockData['photoURL'],
      rankingScore: (mockData['rankingScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ViewModel (sem alterações)
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

  // ===================================
  // <<< INÍCIO DA NOVA SEÇÃO DE DADOS >>>
  // ===================================
  // Mapa de recompensas, espelhando a lógica do backend.
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
  // ===================================
  // <<< FIM DA NOVA SEÇÃO DE DADOS >>>
  // ===================================

  @override
  void initState() {
    super.initState();
    _rankingFuture = _fetchAndFillRanking();
  }

  Future<List<RankingUser>> _fetchAndFillRanking() async {
    // ... (esta função permanece a mesma)
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
      print("Erro ao buscar ranking real (usando mock como fallback): $e");
    }

    if (realUsers.length < 30) {
      try {
        final String jsonString =
            await rootBundle.loadString('assets/mock_data/ranking_mock.json');
        final List<dynamic> mockDataList = json.decode(jsonString);
        final List<RankingUser> mockUsers =
            mockDataList.map((data) => RankingUser.fromMock(data)).toList();

        final realUserIds = realUsers.map((u) => u.id).toSet();

        for (var mockUser in mockUsers) {
          if (realUsers.length >= 30) break;
          if (!realUserIds.contains(mockUser.id)) {
            realUsers.add(mockUser);
          }
        }
      } catch (e) {
        print("Erro ao carregar dados mock de ranking: $e");
      }
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
                  _rankingFuture = _fetchAndFillRanking();
                });
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
                children: [
                  // ===================================
                  // <<< INÍCIO DA NOVA SEÇÃO DE UI >>>
                  // ===================================
                  Text(
                    "🏆 Prêmios da Semana",
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  RankingRewardsList(rewards: _rewards),
                  const SizedBox(height: 24),
                  // ===================================
                  // <<< FIM DA NOVA SEÇÃO DE UI >>>
                  // ===================================

                  if (podiumUsers.isNotEmpty) PodiumWidget(users: podiumUsers),

                  const SizedBox(height: 40),

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
                      rank: 0,
                      photoUrl: viewModel.loggedInUserPhotoUrl,
                    ),

                  const SizedBox(height: 24),

                  if (listUsers.isNotEmpty)
                    Text(
                      "Top 100 Leitores",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),

                  if (listUsers.isNotEmpty)
                    ...List.generate(listUsers.length, (index) {
                      final user = listUsers[index];
                      final rank = index + 4;

                      if (user.id == viewModel.loggedInUserId) {
                        return const SizedBox.shrink();
                      }

                      return RankingListItem(
                        rank: rank,
                        name: user.name,
                        photoUrl: user.photoURL,
                        score: user.rankingScore.toStringAsFixed(0),
                        previousRank: user.previousRank,
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

// ======================================================
// <<< INÍCIO DOS NOVOS WIDGETS DE RECOMPENSA >>>
// ======================================================

/// Widget que cria a lista horizontal de cartões de prêmios.
class RankingRewardsList extends StatelessWidget {
  final Map<int, int> rewards;

  const RankingRewardsList({super.key, required this.rewards});

  @override
  Widget build(BuildContext context) {
    // Converte o mapa para uma lista para fácil acesso pelo índice
    final rewardsList = rewards.entries.toList();

    return SizedBox(
      height: 125, // Altura da lista horizontal
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: rewardsList.length,
        itemBuilder: (context, index) {
          final entry = rewardsList[index];
          return Padding(
            // Adiciona um espaçamento entre os cartões
            padding: EdgeInsets.only(left: index == 0 ? 0 : 4, right: 4),
            child: RewardCard(
              rank: entry.key, // Posição
              coins: entry.value, // Quantidade de moedas
            ),
          );
        },
      ),
    );
  }
}

/// Widget para exibir um único cartão de prêmio.
class RewardCard extends StatelessWidget {
  final int rank;
  final int coins;

  const RewardCard({super.key, required this.rank, required this.coins});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Define cores e estilos com base na posição
    Color startColor, endColor, iconColor;
    double width = 90; // Largura padrão
    switch (rank) {
      case 1:
        startColor = Colors.amber.shade300;
        endColor = Colors.amber.shade600;
        iconColor = Colors.amber.shade800;
        width = 100; // O primeiro lugar é maior
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
            // Posição no Ranking
            Text(
              "${rank}º LUGAR",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                shadows: const [Shadow(blurRadius: 2, color: Colors.black38)],
              ),
            ),
            // Ícone de Moeda
            Icon(
              Icons.monetization_on,
              color: iconColor,
              size: 28,
            ),
            // Quantidade de Moedas
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
// ======================================================
// <<< FIM DOS NOVOS WIDGETS DE RECOMPENSA >>>
// ======================================================